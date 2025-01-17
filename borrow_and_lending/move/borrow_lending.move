module borrow_lending::borrow_lending {
    use sui::tx_context::{Self, TxContext};
    use sui::object::{Self, UID};
    use sui::transfer;
    use sui::coin;
    use std::option::{Self, Option};
    use sui::dynamic_field;

    const COLLATERAL_MULTIPLIER: u64 = 2;

    const ErrorInvalidToken: u64 = 1;
    const ErrorInsufficientCollateral: u64 = 2;
    const ErrorInsufficientAmount: u64 = 3;
    const ErrorLoanAlreadyExists: u64 = 4;
    const ErrorInsufficientLiquidity: u64 = 5;
    const ErrorLoanNotFound: u64 = 6;

    struct LendingPool<phantom T> has key {
        id: UID,
        state: u64,
        pool_token_account: address,
        borrow_tokens: vector<address>,
        collateral_tokens: vector<address>,
        total_lending_pool: vector<u64>, // token -> amount in pool
        lenders: vector<(address, address, u64)>, // lender -> token -> amountLent
        borrowers: vector<(address, address, Borrower<T>)>, // borrower -> token -> Borrower
    }

    struct Borrower<phantom T> has store {
        amount_borrowed: u64,
        collateral_amount: u64,
        collateral_token: address,
    }

    public entry fun initialize<T>(
        pool_token_account: address,
        borrow_tokens: vector<address>,
        collateral_tokens: vector<address>,
        ctx: &mut TxContext
    ) {
        assert!(borrow_tokens.len() > 0, ErrorInsufficientAmount);
        assert!(collateral_tokens.len() > 0, ErrorInsufficientAmount);
        let lending_pool = LendingPool {
            id: object::new(ctx),
            pool_token_account: pool_token_account,
            borrow_tokens: borrow_tokens,
            collateral_tokens: collateral_tokens,
            total_lending_pool: vector::empty(),
            lenders: vector::empty(),
            borrowers: vector::empty(),
        };
        transfer::share_object(lending_pool);
    }

    public entry fun lend<T>(
        contract: &mut LendingPool<T>,
        money: coin::Coin<T>,
        ctx: &mut TxContext
    ) {
        let collateral_token = coin::type_(&money);
        assert!(is_valid_token(&collateral_token, &contract.collateral_tokens), ErrorInvalidToken);

        let amount = coin::value(&money);
        assert!(amount > 0, ErrorInsufficientAmount);

        let sender = tx_context::sender(ctx);

        if let Some(mut pool_coin) = dynamic_field::borrow_mut<address, coin::Coin<T>>(&mut contract.id, collateral_token) {
            // If collateral exists, merge `money` into the existing pool coin
            coin::merge(&mut pool_coin, money);
        } else {
            // If no collateral exists for this token in the pool, add `money` as the initial collateral
            dynamic_field::add(&mut contract.id, collateral_token, money);
        }

        // Update or add the lender's entry in the `contract.lenders` vector
        if let Some(idx) = vector::index_of(&contract.lenders, (sender, collateral_token)) {
            vector::borrow_mut(&mut contract.lenders, idx).2 += amount;
        } else {
            vector::push_back(&mut contract.lenders, (sender, collateral_token, amount));
        }

        update_total_lending_pool(&mut contract.total_lending_pool, collateral_token, amount);
    }



    public entry fun borrow<T>(
        contract: &mut LendingPool<T>,
        borrow_token: address,
        borrow_amount: u64,
        collateral_token: address,
        collateral_amount: u64,
        ctx: &mut TxContext
    ) {
        assert!(is_valid_token(&borrow_token, &contract.borrow_tokens), ErrorInvalidToken);
        assert!(is_valid_token(&collateral_token, &contract.collateral_tokens), ErrorInvalidToken);
        assert!(borrow_amount > 0, ErrorInsufficientAmount);
        assert!(collateral_amount > 0, ErrorInsufficientAmount);

        let sender = tx_context::sender(ctx);

        let lender_index = vector::index_of(&contract.lenders, (sender, collateral_token)).expect(ErrorInsufficientCollateral);
        let collateral_balance = vector::borrow(&contract.lenders, lender_index).2;
        
        assert!(collateral_amount >= COLLATERAL_MULTIPLIER * borrow_amount, ErrorInsufficientCollateral);
        assert!(collateral_balance >= collateral_amount, ErrorInsufficientCollateral);

        assert!(
            !borrower_exists(&contract.borrowers, sender, borrow_token),
            ErrorLoanAlreadyExists
        );

        let total_pool_balance = get_total_pool_balance(&contract.total_lending_pool, borrow_token);
        assert!(total_pool_balance >= borrow_amount, ErrorInsufficientLiquidity);

        let pool_coin = dynamic_field::remove<address, coin::Coin<T>>(&mut contract.id, borrow_token)
            .expect(ErrorInsufficientLiquidity);

        // Adjust the pool coin if it's larger than the borrow amount
        let (borrowed_coin, remaining_coin) = coin::split(pool_coin, borrow_amount);

        if coin::value(&remaining_coin) > 0 {
            dynamic_field::add(&mut contract.id, borrow_token, remaining_coin);
        }

        update_total_lending_pool(&mut contract.total_lending_pool, borrow_token, -borrow_amount);

        vector::borrow_mut(&mut contract.lenders, lender_index).2 -= collateral_amount;

        vector::push_back(&mut contract.borrowers, (
            sender,
            borrow_token,
            Borrower {
                amount_borrowed: borrow_amount,
                collateral_amount: collateral_amount,
                collateral_token: collateral_token,
            }
        ));

        transfer::public_transfer(borrowed_coin, sender);

    
    }

    public entry fun repay<T>(
        contract: &mut LendingPool<T>,
        borrow_token: address,
        ctx: &mut TxContext
    ) {
        assert!(is_valid_token(&borrow_token, &contract.borrow_tokens), ErrorInvalidToken);

        let sender = tx_context::sender(ctx);
        let borrower_index = find_borrower_index(&contract.borrowers, sender, borrow_token);
        assert!(borrower_index.is_some(), ErrorLoanNotFound);
        let borrower_data = vector::borrow(&contract.borrowers, borrower_index.unwrap());

        let repayment_amount = borrower_data.amount_borrowed;
        let collateral_token = borrower_data.collateral_token;
        let collateral_amount = borrower_data.collateral_amount;

        let repayment_coin = dynamic_field::remove<address, coin::Coin<T>>(&mut contract.id, sender).expect(ErrorInsufficientLiquidity);
        let (repayment_coin, remaining) = coin::split(repayment_coin, repayment_amount);
        if coin::value(&remaining) > 0 {
            dynamic_field::add(&mut contract.id, sender, remaining);
        }
        transfer::public_transfer(repayment_coin, contract.pool_token_account);

        vector::swap_remove(&mut contract.borrowers, borrower_index.unwrap());

        if let Some(lender_index) = vector::index_of(&contract.lenders, (sender, collateral_token)) {
            vector::borrow_mut(&mut contract.lenders, lender_index).2 += collateral_amount;
        } else {
            vector::push_back(&mut contract.lenders, (sender, collateral_token, collateral_amount));
        }

        update_total_lending_pool(&mut contract.total_lending_pool, borrow_token, repayment_amount);
    }

    public entry fun withdraw<T>(
    contract: &mut LendingPool<T>,
    collateral_token: address,
    amount: u64,
    ctx: &mut TxContext
    ) {
        assert!(is_valid_token(&collateral_token, &contract.collateral_tokens), ErrorInvalidToken);
        assert!(amount > 0, ErrorInsufficientAmount);

        let sender = tx_context::sender(ctx);

        let lender_index = vector::index_of(&contract.lenders, (sender, collateral_token));
        assert!(lender_index.is_some(), ErrorInsufficientCollateral);
        let lender_balance = vector::borrow_mut(&mut contract.lenders, lender_index);

        assert!(lender_balance.2 >= amount, ErrorInsufficientCollateral);

        let pool_balance = get_total_pool_balance(&contract.total_lending_pool, collateral_token);
        assert!(pool_balance >= amount, ErrorInsufficientLiquidity);

        lender_balance.2 -= amount;

        let pool_coin = dynamic_field::remove<address, coin::Coin<T>>(&mut contract.id, collateral_token).expect(ErrorInsufficientLiquidity);
        let (withdraw_coin, remaining_coin) = coin::split(pool_coin, amount);

        if coin::value(&remaining_coin) > 0 {
            dynamic_field::add(&mut contract.id, collateral_token, remaining_coin);
        }
        update_total_lending_pool(&mut contract.total_lending_pool, collateral_token, -amount);

        transfer::public_transfer(withdraw_coin, sender);
    }


    // Helper functions

    fun is_valid_token(token: &address, valid_tokens: &vector<address>) -> bool {
        vector::contains(valid_tokens, *token)
    }

    fun update_total_lending_pool(total_lending_pool: &mut vector<u64>, token: address, amount: u64) {
        for i in 0..vector::length(total_lending_pool) {
            let entry = vector::borrow_mut(total_lending_pool, i);
            if entry.0 == token {
                entry.1 += amount;
                return;
            }
        }
        vector::push_back(total_lending_pool, (token, amount));
    }

    fun borrower_exists(borrowers: &vector<(address, address, Borrower<T>)>, borrower: address, token: address) -> bool {
        for entry in borrowers {
            if entry.0 == borrower && entry.1 == token {
                return true;
            }
        }
        false
    }

    fun find_borrower_index(borrowers: &vector<(address, address, Borrower<T>)>, borrower: address, token: address) -> u64 {
        for i in 0..vector::length(borrowers) {
            let entry = vector::borrow(borrowers, i);
            if entry.0 == borrower && entry.1 == token {
                return i;
            }
        }
        panic!(ErrorLoanAlreadyExists);
    }

    fun get_total_pool_balance(total_lending_pool: &vector<u64>, token: address) -> u64 {
        for entry in total_lending_pool {
            if entry.0 == token {
                return entry.1;
            }
        }
        0
    }
}
