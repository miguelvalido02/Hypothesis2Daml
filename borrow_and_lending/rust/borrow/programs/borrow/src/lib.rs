// Borrow and lending © 2025 by Miguel Valido is licensed under CC BY 4.0 

use anchor_lang::prelude::*;
use anchor_spl::token::{self, Transfer, TokenAccount, Token};

declare_id!("DwkmwaYRJe3VUzj5Yyb2VK34kr2sGUBFH1HU6MjMHGPY");

#[account]
pub struct LendingPool {
    pub is_initialized: bool,
    pub pool_token_account: Pubkey,
    pub lenders: Vec<(Pubkey, Pubkey, u64)>, // lender -> token -> amountLent
    pub borrowers: Vec<(Pubkey, Pubkey, Borrower)>, // borrower -> token -> Borrower
    pub total_lending_pool: Vec<(Pubkey, u64)>, // token -> amount in pool
    pub borrow_tokens: Vec<Pubkey>, // List of borrow tokens
    pub collateral_tokens: Vec<Pubkey>, // List of collateral tokens
}

impl LendingPool {
    pub fn is_valid_collateral_token(&self, token: Pubkey) -> bool {
        self.collateral_tokens.contains(&token)
    }

    pub fn is_valid_borrow_token(&self, token: Pubkey) -> bool {
        self.borrow_tokens.contains(&token)
    }
}



#[program]
pub mod borrow {
    use super::*;

    pub fn initialize(
        ctx: Context<Initialize>,
        borrow_tokens: Vec<Pubkey>,
        collateral_tokens: Vec<Pubkey>,
        pool_token_account: Pubkey,
    ) -> Result<()> {
        let lending_pool = &mut ctx.accounts.lending_pool;
        require!(!lending_pool.is_initialized, InitializeError::PoolAlreadyInitialized);

        lending_pool.borrow_tokens = borrow_tokens;
        lending_pool.collateral_tokens = collateral_tokens;
        lending_pool.pool_token_account = pool_token_account;
        lending_pool.is_initialized = true;

        Ok(())
    }

    pub fn lend(ctx: Context<Lend>, collateral_token: Pubkey, amount: u64) -> Result<()> {
        let lending_pool = &mut ctx.accounts.lending_pool;
        require!(amount > 0, LendError::LendAmountMustBeGreaterThanZero);
        require!(
            lending_pool.is_valid_collateral_token(collateral_token),
            LendError::InvalidCollateralToken
        );
    
        // Transfer tokens to the pool
        let cpi_accounts = Transfer {
            from: ctx.accounts.lender_token_account.to_account_info(),
            to: ctx.accounts.pool_token_account.to_account_info(),
            authority: ctx.accounts.lender.to_account_info(),
        };
        let cpi_program = ctx.accounts.token_program.to_account_info();
        let cpi_ctx = CpiContext::new(cpi_program, cpi_accounts);
        token::transfer(cpi_ctx, amount)?;
    
        // Upsert the lender entry in the `lenders` Vec
        let lender_key = ctx.accounts.lender.key();
        let mut lender_found = false;
        for entry in lending_pool.lenders.iter_mut() {
            if entry.0 == lender_key && entry.1 == collateral_token {
                entry.2 += amount;
                lender_found = true;
                break;
            }
        }
        if !lender_found {
            lending_pool.lenders.push((lender_key, collateral_token, amount));
        }
    
        // Upsert the total lending pool entry in the `total_lending_pool` Vec
        let mut pool_found = false;
        for entry in lending_pool.total_lending_pool.iter_mut() {
            if entry.0 == collateral_token {
                entry.1 += amount;
                pool_found = true;
                break;
            }
        }
        if !pool_found {
            lending_pool.total_lending_pool.push((collateral_token, amount));
        }
    
        Ok(())
    }
    

    pub fn borrow(
        ctx: Context<Borrow>,
        borrow_token: Pubkey,
        borrow_amount: u64,
        collateral_token: Pubkey,
        collateral_amount: u64,
    ) -> Result<()> {
        let lending_pool = &mut ctx.accounts.lending_pool;
        require!(borrow_amount > 0, BorrowError::BorrowAmountMustBeGreaterThanZero);
        require!(
            lending_pool.is_valid_borrow_token(borrow_token),
            BorrowError::InvalidBorrowToken
        );
        require!(
            lending_pool.is_valid_collateral_token(collateral_token),
            BorrowError::InvalidCollateralToken
        );
    
        // Check if the borrower has enough collateral lent
        let borrower_key = ctx.accounts.borrower.key();
        let mut collateral_found = false;
        for entry in lending_pool.lenders.iter_mut() {
            if entry.0 == borrower_key && entry.1 == collateral_token {
                require!(entry.2 >= collateral_amount, BorrowError::InsufficientCollateralLent);
                entry.2 -= collateral_amount;
                collateral_found = true;
                break;
            }
        }
        require!(collateral_found, BorrowError::InsufficientCollateralLent);
    
        require!(
            collateral_amount > 2 * borrow_amount,
            BorrowError::CollateralMustBe2xBorrowAmount
        );
    
        // Check if the borrower already has a loan with the same borrow token
        for entry in lending_pool.borrowers.iter() {
            if entry.0 == borrower_key && entry.1 == borrow_token {
                require!(entry.2.has_repaid, BorrowError::LoanAlreadyExists);
            }
        }
    
        // Check if there's enough liquidity in the pool
        let mut liquidity_found = false;
        for entry in lending_pool.total_lending_pool.iter_mut() {
            if entry.0 == borrow_token {
                require!(entry.1 >= borrow_amount, BorrowError::NotEnoughLiquidity);
                entry.1 -= borrow_amount;
                liquidity_found = true;
                break;
            }
        }
        require!(liquidity_found, BorrowError::NotEnoughLiquidity);
    
        // Transfer borrow tokens to the borrower
        let cpi_accounts = Transfer {
            from: ctx.accounts.pool_token_account.to_account_info(),
            to: ctx.accounts.borrower_token_account.to_account_info(),
            authority: ctx.accounts.pool_authority.to_account_info(),
        };
        let cpi_program = ctx.accounts.token_program.to_account_info();
        let cpi_ctx = CpiContext::new(cpi_program, cpi_accounts);
        token::transfer(cpi_ctx, borrow_amount)?;
    
        // Add the borrower to the borrowers Vec
        lending_pool.borrowers.push((
            borrower_key,
            borrow_token,
            Borrower {
                amount_borrowed: borrow_amount,
                collateral_amount,
                collateral_token,
                has_repaid: false,
            },
        ));
    
        Ok(())
    }
    

    pub fn withdraw(ctx: Context<Withdraw>, collateral_token: Pubkey) -> Result<()> {
        let lending_pool = &mut ctx.accounts.lending_pool;
        let lender_key = ctx.accounts.lender.key();
    
        // Find the amount lent by the lender for the specified collateral token
        let mut amount_lent = None;
        for entry in lending_pool.lenders.iter_mut() {
            if entry.0 == lender_key && entry.1 == collateral_token {
                amount_lent = Some(entry.2);
                break;
            }
        }
    
        let amount_lent = amount_lent.ok_or(WithdrawError::NoAssetsToWithdraw)?;
        require!(amount_lent > 0, WithdrawError::NoAssetsToWithdraw);
    
        // Check the pool balance for the specified collateral token
        let mut pool_balance = None;
        for entry in lending_pool.total_lending_pool.iter_mut() {
            if entry.0 == collateral_token {
                pool_balance = Some(entry.1);
                break;
            }
        }
    
        let pool_balance = pool_balance.ok_or(WithdrawError::InsufficientPoolBalance)?;
        require!(amount_lent <= pool_balance, WithdrawError::InsufficientPoolBalance);
    
        // Verify that the mint matches the collateral token
        require!(
            ctx.accounts.pool_token_account.mint == collateral_token,
            WithdrawError::InvalidCollateralToken
        );
    
        // Transfer the tokens back to the lender
        let cpi_accounts = Transfer {
            from: ctx.accounts.pool_token_account.to_account_info(),
            to: ctx.accounts.lender_token_account.to_account_info(),
            authority: ctx.accounts.pool_authority.to_account_info(),
        };
        let cpi_program = ctx.accounts.token_program.to_account_info();
        let cpi_ctx = CpiContext::new(cpi_program, cpi_accounts);
        token::transfer(cpi_ctx, amount_lent)?;
    
        // Update the lender's entry in the `lenders` Vec
        for entry in lending_pool.lenders.iter_mut() {
            if entry.0 == lender_key && entry.1 == collateral_token {
                entry.2 = 0;
                break;
            }
        }
    
        // Deduct the amount from the `total_lending_pool` Vec
        for entry in lending_pool.total_lending_pool.iter_mut() {
            if entry.0 == collateral_token {
                entry.1 -= amount_lent;
                break;
            }
        }
    
        Ok(())
    }
    



    pub fn repay(ctx: Context<Repay>, borrow_token: Pubkey) -> Result<()> {
        let lending_pool = &mut ctx.accounts.lending_pool;

        require!(!lending_pool.borrowers.iter()
                .find(|entry| entry.0 == ctx.accounts.borrower.key() && entry.1 == borrow_token)
                .map_or(false, |borrower| borrower.2.has_repaid),
            RepayError::LoanAlreadyRepaid
        );
        let borrower = lending_pool.borrowers.iter_mut().find(|entry| entry.0 == ctx.accounts.borrower.key() && entry.1 == borrow_token);
        if borrower.is_none() {
            return Err(RepayError::NoLoanToRepay.into());
        }
        let borrower = borrower.unwrap().2;
            
        //Repay borrow
        let cpi_accounts = Transfer {
            from: ctx.accounts.borrower_token_account.to_account_info(),
            to: ctx.accounts.pool_token_account.to_account_info(),
            authority: ctx.accounts.borrower.to_account_info(),
        };
        let cpi_program = ctx.accounts.token_program.to_account_info();
        let cpi_ctx = CpiContext::new(cpi_program, cpi_accounts);
        let repayment_amount = borrower.amount_borrowed;
        token::transfer(cpi_ctx, repayment_amount)?;

        //Return collateral
        let collateral_token = borrower.collateral_token;
        let collateral_amount = borrower.collateral_amount;
        require!(
        ctx.accounts.pool_token_account.mint == collateral_token,
        RepayError::InvalidCollateralToken
        );
        let cpi_accounts = Transfer {
            from: ctx.accounts.pool_token_account.to_account_info(),
            to: ctx.accounts.borrower_token_account.to_account_info(),
            authority: ctx.accounts.pool_authority.to_account_info(),
        };
        let cpi_program = ctx.accounts.token_program.to_account_info();
        let cpi_ctx = CpiContext::new(cpi_program, cpi_accounts);
        token::transfer(cpi_ctx, collateral_amount)?;
        lending_pool.total_lending_pool.iter_mut().find(|entry| entry.0 == borrow_token).unwrap().1 += repayment_amount;

        Ok(())
    }
}

// Borrower struct to track borrowed amounts and collateral
#[derive(AnchorSerialize, AnchorDeserialize, Clone,Copy)]
pub struct Borrower {
    pub amount_borrowed: u64,
    pub collateral_amount: u64,
    pub collateral_token: Pubkey,
    pub has_repaid: bool,
}

// Context for initializing the lending pool
#[derive(Accounts)]
pub struct Initialize<'info> {
    #[account(init, payer = admin, seeds = [b"lending_pool"], bump, space = 8 + 4096*2)]
    pub lending_pool: Account<'info, LendingPool>,
    #[account(mut)]
    pub admin: Signer<'info>,
    pub system_program: Program<'info, System>,
}

#[derive(Accounts)]
pub struct Lend<'info> {
    #[account(mut)]
    pub lender: Signer<'info>,
    #[account(mut)]
    pub lending_pool: Account<'info, LendingPool>, // Shared lending pool
    #[account(mut)]
    pub lender_token_account: Account<'info, TokenAccount>,
    #[account(mut)]
    pub pool_token_account: Account<'info, TokenAccount>,
    pub token_program: Program<'info, Token>,
}

#[derive(Accounts)]
pub struct Borrow<'info> {
    #[account(mut)]
    pub borrower: Signer<'info>,
    #[account(mut)]
    pub lending_pool: Account<'info, LendingPool>,
    #[account(mut)]
    pub borrower_token_account: Account<'info, TokenAccount>,
    #[account(mut)]
    pub pool_token_account: Account<'info, TokenAccount>,
    #[account(mut)]
    pub pool_authority: Signer<'info>,
    pub token_program: Program<'info, Token>,
}

#[derive(Accounts)]
pub struct Withdraw<'info> {
    #[account(mut)]
    pub lender: Signer<'info>,
    #[account(mut)]
    pub lending_pool: Account<'info, LendingPool>,
    #[account(mut)]
    pub lender_token_account: Account<'info, TokenAccount>,
    #[account(mut)]
    pub pool_token_account: Account<'info, TokenAccount>,
    #[account(mut)]
    pub pool_authority: Signer<'info>,
    pub token_program: Program<'info, Token>,
}



#[derive(Accounts)]
pub struct Repay<'info> {
    #[account(mut)]
    pub borrower: Signer<'info>,
    #[account(mut)]
    pub lending_pool: Account<'info, LendingPool>,
    #[account(mut)]
    pub borrower_token_account: Account<'info, TokenAccount>,
    #[account(mut)]
    pub pool_token_account: Account<'info, TokenAccount>,
    #[account(mut)]
    pub pool_authority: Signer<'info>,
    pub token_program: Program<'info, Token>,
}


#[error_code]
pub enum InitializeError {
    #[msg("The lending pool has already been initialized")]
    PoolAlreadyInitialized,
}


#[error_code]
pub enum LendError {
    #[msg("Lending amount must be greater than zero")]
    LendAmountMustBeGreaterThanZero,
    #[msg("Invalid collateral token")]
    InvalidCollateralToken,
}

#[error_code]
pub enum BorrowError {
    #[msg("Borrow amount must be greater than zero")]
    BorrowAmountMustBeGreaterThanZero,
    #[msg("Invalid borrow token")]
    InvalidBorrowToken,
    #[msg("Invalid collateral token")]
    InvalidCollateralToken,
    #[msg("Insufficient collateral lent")]
    InsufficientCollateralLent,
    #[msg("Loan already exists")]
    LoanAlreadyExists,
    #[msg("Not enough liquidity in the pool")]
    NotEnoughLiquidity,
    #[msg("Collateral must be 2x borrow amount")]
    CollateralMustBe2xBorrowAmount,
}

#[error_code]
pub enum WithdrawError {
    #[msg("No assets to withdraw")]
    NoAssetsToWithdraw,
    #[msg("Insufficient pool balance")]
    InsufficientPoolBalance,
    #[msg("Invalid collateral token")]
    InvalidCollateralToken,
}

#[error_code]
pub enum RepayError {
    #[msg("No loan to repay")]
    NoLoanToRepay,
    #[msg("Loan already repaid")]
    LoanAlreadyRepaid,
    #[msg("Not enough collateral in pool")]
    NotEnoughCollateralInPool,
    #[msg("Invalid collateral token")]
    InvalidCollateralToken,
}

