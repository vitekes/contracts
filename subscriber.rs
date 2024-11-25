use anchor_lang::prelude::*;
use anchor_spl::token::{self, Mint, Token, TokenAccount, Transfer};

declare_id!("YourProgramIdHere");

#[program]
pub mod subscription_service {
    use super::*;

    // Инициация подписки
    pub fn create_subscription(
        ctx: Context<CreateSubscription>,
        amount: u64,
        duration: u64,
    ) -> Result<()> {
        let subscription = &mut ctx.accounts.subscription;
        subscription.subscriber = *ctx.accounts.subscriber.key;
        subscription.amount = amount;
        subscription.duration = duration;
        subscription.start_time = Clock::get()?.unix_timestamp as u64;
        subscription.last_payment_time = Clock::get()?.unix_timestamp as u64;
        subscription.is_active = true;

        msg!("Subscription created for {} lamports or tokens every {} seconds", amount, duration);
        Ok(())
    }

    // Списание SOL по подписке
    pub fn charge_subscription_sol(ctx: Context<ChargeSubscriptionSol>) -> Result<()> {
        let subscription = &mut ctx.accounts.subscription;
        let current_time = Clock::get()?.unix_timestamp as u64;

        // Проверяем, активна ли подписка и наступило ли время для нового платежа
        require!(subscription.is_active, SubscriptionError::InactiveSubscription);
        require!(
            current_time >= subscription.last_payment_time + subscription.duration,
            SubscriptionError::PaymentNotDue
        );

        // Выполняем списание SOL
        let ix = anchor_lang::solana_program::system_instruction::transfer(
            &ctx.accounts.subscriber.key(),
            &ctx.accounts.receiver.key(),
            subscription.amount,
        );
        anchor_lang::solana_program::program::invoke(
            &ix,
            &[
                ctx.accounts.subscriber.to_account_info(),
                ctx.accounts.receiver.to_account_info(),
            ],
        )?;

        // Обновляем время последнего платежа
        subscription.last_payment_time = current_time;
        msg!("Charged {} lamports from subscription", subscription.amount);
        Ok(())
    }

    // Списание SPL-токенов по подписке
    pub fn charge_subscription_tokens(ctx: Context<ChargeSubscriptionTokens>) -> Result<()> {
        let subscription = &mut ctx.accounts.subscription;
        let current_time = Clock::get()?.unix_timestamp as u64;

        // Проверяем, активна ли подписка и наступило ли время для нового платежа
        require!(subscription.is_active, SubscriptionError::InactiveSubscription);
        require!(
            current_time >= subscription.last_payment_time + subscription.duration,
            SubscriptionError::PaymentNotDue
        );

        // Перенос токенов
        token::transfer(ctx.accounts.into_transfer_to_receiver_context(), subscription.amount)?;

        // Обновляем время последнего платежа
        subscription.last_payment_time = current_time;
        msg!("Charged {} tokens from subscription", subscription.amount);
        Ok(())
    }
}

#[derive(Accounts)]
pub struct CreateSubscription<'info> {
    #[account(init, payer = subscriber, space = 8 + Subscription::LEN)]
    pub subscription: Account<'info, Subscription>, // Аккаунт подписки
    #[account(mut)]
    pub subscriber: Signer<'info>, // Подписчик
    #[account(mut)]
    pub system_program: Program<'info, System>, // Системная программа
}

#[derive(Accounts)]
pub struct ChargeSubscriptionSol<'info> {
    #[account(mut)]
    pub subscription: Account<'info, Subscription>, // Аккаунт подписки
    #[account(mut)]
    pub subscriber: Signer<'info>, // Подписчик
    /// CHECK: Мы уверены, что receiver безопасен, так как это просто кошелёк
    #[account(mut)]
    pub receiver: AccountInfo<'info>, // Получатель
    pub system_program: Program<'info, System>, // Системная программа
}

#[derive(Accounts)]
pub struct ChargeSubscriptionTokens<'info> {
    #[account(mut)]
    pub subscription: Account<'info, Subscription>, // Аккаунт подписки
    #[account(mut)]
    pub subscriber: Signer<'info>, // Подписчик
    #[account(mut)]
    pub subscriber_token_account: Account<'info, TokenAccount>, // Токеновый аккаунт подписчика
    #[account(mut)]
    pub receiver_token_account: Account<'info, TokenAccount>, // Токеновый аккаунт получателя
    pub token_program: Program<'info, Token>, // Токенная программа Solana
}

// Аккаунт подписки
#[account]
pub struct Subscription {
    pub subscriber: Pubkey,        // Кошелёк подписчика
    pub amount: u64,              // Сумма платежа
    pub duration: u64,            // Интервал подписки (в секундах)
    pub start_time: u64,          // Время начала подписки
    pub last_payment_time: u64,   // Время последнего платежа
    pub is_active: bool,          // Активна ли подписка
}

impl Subscription {
    pub const LEN: usize = 32 + 8 + 8 + 8 + 8 + 1; // Размер аккаунта
}

impl<'info> ChargeSubscriptionTokens<'info> {
    pub fn into_transfer_to_receiver_context(
        &self,
    ) -> CpiContext<'_, '_, '_, 'info, Transfer<'info>> {
        let cpi_accounts = Transfer {
            from: self.subscriber_token_account.to_account_info(),
            to: self.receiver_token_account.to_account_info(),
            authority: self.subscriber.to_account_info(),
        };
        CpiContext::new(self.token_program.to_account_info(), cpi_accounts)
    }
}

// Ошибки
#[error_code]
pub enum SubscriptionError {
    #[msg("The subscription is not active.")]
    InactiveSubscription,
    #[msg("Payment is not due yet.")]
    PaymentNotDue,
}
