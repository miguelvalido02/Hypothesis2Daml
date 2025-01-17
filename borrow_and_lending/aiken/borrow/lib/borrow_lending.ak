use aiken/dict.{Dict}
use aiken/hash.{Blake2b_224, Hash}
use aiken/list
use aiken/transaction.{ScriptContext}
use aiken/transaction/credential.{
  Address, VerificationKey, VerificationKeyCredential,
}
use aiken/transaction/value
use utils.{
  get_ada_from_inputs, get_ada_from_outputs, get_outputs_by_address,
  get_outputs_by_vkh, get_own_input, must_be_signed_by,
}

pub type VerificationKeyHash =
  Hash<Blake2b_224, VerificationKey>

pub type Lovelace =
  Int

type Borrower {
  amount_borrowed: Lovelace,
  collateral_amount: Lovelace,
  collateral_token: Address,
}

type LendingPool {
  pool_token_account: Address,
  borrow_tokens: List<Address>,
  collateral_tokens: List<Address>,
  total_lending_pool: Dict<Address, Lovelace>,
  // token -> amount in pool
  lenders: Dict<(Address, Address), Lovelace>,
  // lender -> token -> amountLent
  borrowers: Dict<(Address, Address), Borrower>,
}

// borrower -> token -> Borrower

pub fn lend(
  ctx: ScriptContext,
  lending_pool: LendingPool,
  lender_address: Address,
  lender: VerificationKeyHash,
  collateral_token: Address,
  amount: Lovelace,
) {
  let tx = ctx.transaction

  expect and {
      utils.must_be_signed_by(tx, lender),
      amount > 0,
      is_valid_token(collateral_token, lending_pool.collateral_tokens),
    }

  // Ensure contract receives the correct amount
  let contract_outputs =
    get_outputs_by_address(tx.outputs, lending_pool.pool_token_account)
  let received_amount = get_ada_from_outputs(contract_outputs)
  expect received_amount == get_ada_from_inputs(tx.inputs) + amount
  let current_value =
    when dict.get(lending_pool.total_lending_pool, collateral_token) is {
      Some(value) -> value
      None -> 0
    }
  let updated_total_lending_pool =
    dict.insert(
      lending_pool.total_lending_pool,
      collateral_token,
      current_value + amount,
      fn(key1, key2) { Less },
    )
  let current_value_lender =
    when
      dict.get(
        lending_pool.lenders,
        (lending_pool.pool_token_account, collateral_token),
      )
    is {
      Some(value) -> value
      None -> 0
    }
  let updated_lenders =
    dict.insert(
      lending_pool.lenders,
      (lender_address, collateral_token),
      current_value_lender + amount,
      fn(key1, key2) { Less },
    )
  // Create the updated lending pool
  let updated_lending_pool =
    LendingPool {
      pool_token_account: lending_pool.pool_token_account,
      borrow_tokens: lending_pool.borrow_tokens,
      collateral_tokens: lending_pool.collateral_tokens,
      total_lending_pool: updated_total_lending_pool,
      lenders: updated_lenders,
      borrowers: lending_pool.borrowers,
    }

  // Ensure the new UTXO matches the updated lending pool state
  expect Some(output) =
    list.find(
      tx.outputs,
      fn(o) { o.address == lending_pool.pool_token_account },
    )
  let contract_output = output

  expect InlineDatum(untyped_datum) = contract_output.datum
  expect contract_output_datum: LendingPool = untyped_datum

  expect contract_output_datum == updated_lending_pool
}

fn borrow(
  ctx: ScriptContext,
  lending_pool: LendingPool,
  borrower: VerificationKeyHash,
  borrow_token: Address,
  borrow_amount: Lovelace,
  coll_token: Address,
  coll_amount: Lovelace,
) {
  let tx = ctx.transaction

  expect utils.must_be_signed_by(tx, borrower)
  expect borrow_amount > 0
  expect is_valid_token(borrow_token, lending_pool.borrow_tokens)
  expect is_valid_token(coll_token, lending_pool.collateral_tokens)
  let current_collateral =
    lending_pool.lenders.get((lending_pool.pool_token_account, coll_token)).unwrap_or(
      0,
    )
  expect current_collateral >= coll_amount
  expect coll_amount >= 2 * borrow_amount
  expect None =
    lending_pool.borrowers.get((lending_pool.pool_token_account, borrow_token))
  let current_liquidity =
    lending_pool.total_lending_pool.get(borrow_token).unwrap_or(0)
  expect current_liquidity >= borrow_amount

  // Validation: Borrower must receive the correct borrow amount
  let borrower_outputs = get_outputs_by_vkh(tx.outputs, borrower)
  let borrower_received = get_ada_from_outputs(borrower_outputs)
  expect borrower_received == borrow_amount

  // Create the updated lending pool
  let updated_lending_pool =
    LendingPool {
      pool_token_account: lending_pool.pool_token_account,
      collateral_tokens: lending_pool.collateral_tokens,
      borrow_tokens: lending_pool.borrow_tokens,
      lenders: lending_pool.lenders.insert(
        (lending_pool.pool_token_account, coll_token),
        current_collateral - coll_amount,
      ),
      total_lending_pool: lending_pool.total_lending_pool.insert(
        borrow_token,
        current_liquidity - borrow_amount,
      ),
      borrowers: lending_pool.borrowers.insert(
        (lending_pool.pool_token_account, borrow_token),
        Borrower {
          amount_borrowed: borrow_amount,
          collateral_amount: coll_amount,
          collateral_token: coll_token,
        },
      ),
    }

  // Validate the output state of the lending pool
  expect Some(output) =
    list.find(
      tx.outputs,
      fn(o) { o.address == lending_pool.pool_token_account },
    )
  let contract_output = output

  expect InlineDatum(untyped_datum) = contract_output.datum
  expect contract_output_datum: LendingPool = untyped_datum

  expect contract_output_datum == updated_lending_pool
}

pub fn repay(
  ctx: ScriptContext,
  lending_pool: LendingPool,
  borrower: VerificationKeyHash,
  borrow_token: Address,
) {
  let tx = ctx.transaction

  expect utils.must_be_signed_by(tx, borrower)

  let borrower_loan =
    lending_pool.borrowers.get((lending_pool.pool_token_account, borrow_token))
  expect Some(active_loan) = borrower_loan

  // Ensure repayment amount is present in the outputs
  let contract_outputs =
    get_outputs_by_address(tx.outputs, lending_pool.pool_token_account)
  let repayment_amount = get_ada_from_outputs(contract_outputs)
  expect repayment_amount >= active_loan.amount_borrowed

  // Create the updated lending pool state
  let updated_lending_pool =
    LendingPool {
      pool_token_account: lending_pool.pool_token_account,
      collateral_tokens: lending_pool.collateral_tokens,
      borrow_tokens: lending_pool.borrow_tokens,
      // Remove the loan
      borrowers: lending_pool.borrowers.remove(
        (lending_pool.pool_token_account, borrow_token),
      ),
      // Return the collateral to the pool
      lenders: lending_pool.lenders.insert(
        (lending_pool.pool_token_account, active_loan.collateral_token),
        lending_pool.lenders.get(
          (lending_pool.pool_token_account, active_loan.collateral_token),
        ).unwrap_or(
          0,
        ) + active_loan.collateral_amount,
      ),
      // Add the repaid amount back to the lending pool's total liquidity
      total_lending_pool: lending_pool.total_lending_pool.insert(
        borrow_token,
        lending_pool.total_lending_pool.get(borrow_token).unwrap_or(0) + active_loan.amount_borrowed,
      ),
    }

  // Validate the output state of the lending pool
  expect Some(output) =
    list.find(
      tx.outputs,
      fn(o) { o.address == lending_pool.pool_token_account },
    )
  let contract_output = output

  expect InlineDatum(untyped_datum) = contract_output.datum
  expect contract_output_datum: LendingPool = untyped_datum

  expect contract_output_datum == updated_lending_pool
}

fn withdraw(
  ctx: ScriptContext,
  lending_pool: LendingPool,
  lender: VerificationKeyHash,
  collateral_token: Address,
) {
  let tx = ctx.transaction
  expect utils.must_be_signed_by(tx, lender)
  let amount_lent =
    lending_pool.lenders.get(
      (lending_pool.pool_token_account, collateral_token),
    ).unwrap_or(
      0,
    )
  expect amount_lent > 0
  let total_pool_balance =
    lending_pool.total_lending_pool.get(collateral_token).unwrap_or(0)
  expect amount_lent <= total_pool_balance

  // Validation: Ensure the lender receives the correct withdrawal amount
  let lender_outputs = get_outputs_by_vkh(tx.outputs, lender)
  let lender_received = get_ada_from_outputs(lender_outputs)
  expect lender_received == amount_lent

  // Create the updated lending pool
  let updated_lending_pool =
    LendingPool {
      pool_token_account: lending_pool.pool_token_account,
      collateral_tokens: lending_pool.collateral_tokens,
      borrow_tokens: lending_pool.borrow_tokens,
      // Remove the lender
      lenders: lending_pool.lenders.remove(
        (lending_pool.pool_token_account, collateral_token),
      ),
      // Reduce the total lending pool balance for the collateral token
      total_lending_pool: lending_pool.total_lending_pool.insert(
        collateral_token,
        total_pool_balance - amount_lent,
      ),
      borrowers: lending_pool.borrowers,
    }

  expect Some(output) =
    list.find(
      tx.outputs,
      fn(o) { o.address == lending_pool.pool_token_account },
    )
  let contract_output = output

  expect InlineDatum(untyped_datum) = contract_output.datum
  expect contract_output_datum: LendingPool = untyped_datum

  expect contract_output_datum == updated_lending_pool
}

fn is_valid_token(token: Address, valid_tokens: List<Address>) -> Bool {
  valid_tokens.contains(token)
}
