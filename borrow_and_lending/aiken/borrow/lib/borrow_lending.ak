use aiken/builtin
use aiken/dict.{Dict}
use aiken/hash.{Blake2b_224, Hash}
use aiken/list
use aiken/transaction.{InlineDatum, Output, ScriptContext, Spend}
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

pub type Borrower {
  amount_borrowed: Lovelace,
  collateral_amount: Lovelace,
  collateral_token: Address,
}

pub type LendingPool {
  pool_token_account: Address,
  borrow_tokens: List<Address>,
  collateral_tokens: List<Address>,
  // token -> amount in pool
  total_lending_pool: Dict<Address, Lovelace>,
  // lender -> token -> amountLent
  lenders: Dict<(Address, Address), Lovelace>,
  // borrower -> token -> Borrower
  borrowers: Dict<(Address, Address), Borrower>,
}

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
    when dict.get(lending_pool.lenders, (lender_address, collateral_token)) is {
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

  expect list.length(contract_outputs) == 1
  expect Some(output) = list.at(contract_outputs, 0)

  expect
    builtin.serialise_data(output.datum) == builtin.serialise_data(
      updated_lending_pool,
    )
  True
}

fn borrow(
  ctx: ScriptContext,
  lending_pool: LendingPool,
  lender_address: Address,
  borrower: VerificationKeyHash,
  borrow_token: Address,
  borrow_amount: Lovelace,
  coll_token: Address,
  coll_amount: Lovelace,
) {
  let tx = ctx.transaction
  let contract_outputs =
    get_outputs_by_address(tx.outputs, lending_pool.pool_token_account)
  expect utils.must_be_signed_by(tx, borrower)
  expect borrow_amount > 0
  expect is_valid_token(borrow_token, lending_pool.borrow_tokens)
  expect is_valid_token(coll_token, lending_pool.collateral_tokens)
  let current_collateral =
    when dict.get(lending_pool.lenders, (lender_address, coll_token)) is {
      Some(value) -> value
      None -> 0
    }
  expect current_collateral >= coll_amount
  expect coll_amount >= 2 * borrow_amount
  let current_value_borrow =
    when dict.get(lending_pool.borrowers, (lender_address, borrow_token)) is {
      Some(value) -> 1
      None -> 0
    }
  expect 0 = current_value_borrow

  let updated_lenders =
    dict.insert(
      lending_pool.lenders,
      (lender_address, coll_token),
      current_collateral - coll_amount,
      fn(key1, key2) { Less },
    )

  let updated_borrowers =
    dict.insert(
      lending_pool.borrowers,
      (lender_address, borrow_token),
      Borrower {
        amount_borrowed: borrow_amount,
        collateral_amount: coll_amount,
        collateral_token: coll_token,
      },
      fn(key1, key2) { Less },
    )

  let current_liquidity =
    when dict.get(lending_pool.total_lending_pool, borrow_token) is {
      Some(value) -> value
      None -> 0
    }
  expect current_liquidity >= borrow_amount

  // Validation: Borrower must receive the correct borrow amount
  let borrower_outputs = get_outputs_by_vkh(tx.outputs, borrower)
  let borrower_received = get_ada_from_outputs(borrower_outputs)
  expect borrower_received == borrow_amount
  let current_value =
    when dict.get(lending_pool.total_lending_pool, coll_token) is {
      Some(value) -> value
      None -> 0
    }

  let updated_total_lending_pool =
    dict.insert(
      lending_pool.total_lending_pool,
      borrow_token,
      current_value - borrow_amount,
      fn(key1, key2) { Less },
    )

  // Create the updated lending pool
  let updated_lending_pool =
    LendingPool {
      pool_token_account: lending_pool.pool_token_account,
      collateral_tokens: lending_pool.collateral_tokens,
      borrow_tokens: lending_pool.borrow_tokens,
      lenders: updated_lenders,
      total_lending_pool: updated_total_lending_pool,
      borrowers: updated_borrowers,
    }

  // Validate the output state of the lending pool
  expect Some(output) =
    list.find(
      tx.outputs,
      fn(o) { o.address == lending_pool.pool_token_account },
    )

  expect list.length(contract_outputs) == 1
  expect Some(output) = list.at(contract_outputs, 0)

  expect
    builtin.serialise_data(output.datum) == builtin.serialise_data(
      updated_lending_pool,
    )
  True
}

pub fn repay(
  ctx: ScriptContext,
  lending_pool: LendingPool,
  lender_address: Address,
  borrower: VerificationKeyHash,
  borrow_token: Address,
) {
  let tx = ctx.transaction

  expect utils.must_be_signed_by(tx, borrower)

  let borrower_loan =
    dict.get(lending_pool.borrowers, (lender_address, borrow_token))
  expect Some(active_loan) = borrower_loan

  // Ensure repayment amount is present in the outputs
  let contract_outputs =
    get_outputs_by_address(tx.outputs, lending_pool.pool_token_account)
  let repayment_amount = get_ada_from_outputs(contract_outputs)
  expect repayment_amount >= active_loan.amount_borrowed
  let current_liquidity =
    when dict.get(lending_pool.total_lending_pool, borrow_token) is {
      Some(value) -> value
      None -> 0
    }
  let updated_total_lending_pool =
    dict.insert(
      lending_pool.total_lending_pool,
      borrow_token,
      current_liquidity + active_loan.amount_borrowed,
      fn(key1, key2) { Less },
    )
  let updated_borrowers =
    dict.filter(
      lending_pool.borrowers,
      fn(key, _value) { key != (lender_address, borrow_token) },
    )

  let coll_amount = active_loan.collateral_amount
  let coll_token = active_loan.collateral_token
  let current_collateral =
    when dict.get(lending_pool.lenders, (lender_address, coll_token)) is {
      Some(value) -> value
      None -> 0
    }
  let updated_lenders =
    dict.insert(
      lending_pool.lenders,
      (lender_address, coll_token),
      coll_amount + current_collateral,
      fn(key1, key2) { Less },
    )
  // Create the updated lending pool state
  let updated_lending_pool =
    LendingPool {
      pool_token_account: lending_pool.pool_token_account,
      collateral_tokens: lending_pool.collateral_tokens,
      borrow_tokens: lending_pool.borrow_tokens,
      // Remove the loan
      borrowers: updated_borrowers,
      // Return the collateral to the pool
      lenders: updated_lenders,
      // Add the repaid amount back to the lending pool's total liquidity
      total_lending_pool: updated_total_lending_pool,
    }

  // Validate the output state of the lending pool
  expect Some(output) =
    list.find(
      tx.outputs,
      fn(o) { o.address == lending_pool.pool_token_account },
    )

  expect list.length(contract_outputs) == 1
  expect Some(output) = list.at(contract_outputs, 0)

  expect
    builtin.serialise_data(output.datum) == builtin.serialise_data(
      updated_lending_pool,
    )
  True
}

pub fn withdraw(
  ctx: ScriptContext,
  lending_pool: LendingPool,
  lender_address: Address,
  lender: VerificationKeyHash,
  collateral_token: Address,
) {
  let tx = ctx.transaction
  expect utils.must_be_signed_by(tx, lender)
  let contract_outputs =
    get_outputs_by_address(tx.outputs, lending_pool.pool_token_account)
  let current_coll =
    dict.get(lending_pool.lenders, (lender_address, collateral_token))
  expect Some(current_collateral) = current_coll
  expect current_collateral > 0
  let current_liquidity =
    when dict.get(lending_pool.total_lending_pool, collateral_token) is {
      Some(value) -> value
      None -> 0
    }
  expect current_collateral <= current_liquidity

  // Validation: Ensure the lender receives the correct withdrawal amount
  let lender_outputs = get_outputs_by_vkh(tx.outputs, lender)
  let lender_received = get_ada_from_outputs(lender_outputs)
  expect lender_received == current_collateral

  let updated_total_lending_pool =
    dict.insert(
      lending_pool.total_lending_pool,
      collateral_token,
      current_liquidity - current_collateral,
      fn(key1, key2) { Less },
    )

  let updated_lenders =
    dict.filter(
      lending_pool.lenders,
      fn(key, _value) { key != (lender_address, collateral_token) },
    )
  // Create the updated lending pool
  let updated_lending_pool =
    LendingPool {
      pool_token_account: lending_pool.pool_token_account,
      collateral_tokens: lending_pool.collateral_tokens,
      borrow_tokens: lending_pool.borrow_tokens,
      // Remove the lender
      lenders: updated_lenders,
      // Reduce the total lending pool balance for the collateral token
      total_lending_pool: updated_total_lending_pool,
      borrowers: lending_pool.borrowers,
    }
  expect Some(output) =
    list.find(
      tx.outputs,
      fn(o) { o.address == lending_pool.pool_token_account },
    )

  expect list.length(contract_outputs) == 1
  expect Some(output) = list.at(contract_outputs, 0)

  expect
    builtin.serialise_data(output.datum) == builtin.serialise_data(
      updated_lending_pool,
    )
  True
}

pub fn is_valid_token(token: Address, valid_tokens: List<Address>) -> Bool {
  list.has(valid_tokens, token)
}
