use anchor_lang::prelude::*;
use anchor_spl::token::{self, Mint, Token, TokenAccount, Transfer};

// Программный идентификатор (зависит от вашей программы)
declare_id!("YourProgramIdHere");

#[program]
pub mod donation_and_payment {
    use super::*;

    
    pub fn donate_sol(ctx: Context<DonateSol>, amount: u64) -> Result<()> {
        let user = &ctx.accounts.user;
        let vault = &mut ctx.accounts.vault;

        
        vault.total_sol_donations += amount;
        msg!("Received {} lamports as donation", amount);

        Ok(())
    }

    
    pub fn donate_tokens(ctx: Context<DonateTokens>, amount: u64) -> Result<()> {
        let vault = &mut ctx.accounts.vault;

        // Перенос токенов на хранилище
        token::transfer(ctx.accounts.into_transfer_to_vault_context(), amount)?;

      
        vault.total_token_donations += amount;
        msg!("Received {} tokens as donation", amount);

        Ok(())
    }

   
    pub fn pay_with_sol(ctx: Context<PayWithSol>, amount: u64) -> Result<()> {
        let user = &ctx.accounts.user;
        let vault = &mut ctx.accounts.vault;

       
        vault.total_sol_payments += amount;
        msg!("Received {} lamports as payment", amount);

        Ok(())
    }


    pub fn pay_with_tokens(ctx: Context<PayWithTokens>, amount: u64) -> Result<()> {
        let vault = &mut ctx.accounts.vault;

       
        token::transfer(ctx.accounts.into_transfer_to_vault_context(), amount)?;

      
        vault.total_token_payments += amount;
        msg!("Received {} tokens as payment", amount);

        Ok(())
    }
}

#[derive(Accounts)]
pub struct DonateSol<'info> {
    #[account(mut)]
    pub user: Signer<'info>, // Плательщик
    #[account(mut)]
    pub vault: Account<'info, Vault>, // Хранилище
    pub system_program: Program<'info, System>, // Системная программа Solana
}

#[derive(Accounts)]
pub struct DonateTokens<'info> {
    #[account(mut)]
    pub user: Signer<'info>, // Плательщик
    #[account(mut)]
    pub user_token_account: Account<'info, TokenAccount>, // Токеновый аккаунт пользователя
    #[account(mut)]
    pub vault_token_account: Account<'info, TokenAccount>, // Токеновый аккаунт хранилища
    pub token_program: Program<'info, Token>, // Токенная программа Solana
}

#[derive(Accounts)]
pub struct PayWithSol<'info> {
    #[account(mut)]
    pub user: Signer<'info>, // Плательщик
    #[account(mut)]
    pub vault: Account<'info, Vault>, // Хранилище
    pub system_program: Program<'info, System>, // Системная программа Solana
}

#[derive(Accounts)]
pub struct PayWithTokens<'info> {
    #[account(mut)]
    pub user: Signer<'info>, // Плательщик
    #[account(mut)]
    pub user_token_account: Account<'info, TokenAccount>, // Токеновый аккаунт пользователя
    #[account(mut)]
    pub vault_token_account: Account<'info, TokenAccount>, // Токеновый аккаунт хранилища
    pub token_program: Program<'info, Token>, // Токенная программа Solana
}

#[account]
pub struct Vault {
    pub total_sol_donations: u64,
    pub total_sol_payments: u64,
    pub total_token_donations: u64,
    pub total_token_payments: u64,
}

// Контекст передачи токенов
impl<'info> DonateTokens<'info> {
    pub fn into_transfer_to_vault_context(
        &self,
    ) -> CpiContext<'_, '_, '_, 'info, Transfer<'info>> {
        let cpi_accounts = Transfer {
            from: self.user_token_account.to_account_info(),
            to: self.vault_token_account.to_account_info(),
            authority: self.user.to_account_info(),
        };
        CpiContext::new(self.token_program.to_account_info(), cpi_accounts)
    }
}

impl<'info> PayWithTokens<'info> {
    pub fn into_transfer_to_vault_context(
        &self,
    ) -> CpiContext<'_, '_, '_, 'info, Transfer<'info>> {
        let cpi_accounts = Transfer {
            from: self.user_token_account.to_account_info(),
            to: self.vault_token_account.to_account_info(),
            authority: self.user.to_account_info(),
        };
        CpiContext::new(self.token_program.to_account_info(), cpi_accounts)
    }
}
