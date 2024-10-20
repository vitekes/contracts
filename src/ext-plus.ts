import {
    Address,
    beginCell,
    Cell,
    Contract,
    contractAddress,
    ContractProvider,
    Sender,
    SendMode,
    toNano
} from '@ton/core';


export type SubscriptionExtV5Config = {
    wallet: Address;
    beneficiary: Address;
    amount: bigint;
    period: number;
    start_time: number;
    timeout: number;
    last_payment_time: number;
    last_request_time: number;
    failed_attempts: number
    subscription_id: number;
};

export function subscriptionV5ConfigToCell(config: SubscriptionExtV5Config): Cell {
    return beginCell()
        .storeAddress(config.wallet)
        .storeAddress(config.beneficiary)
        .storeCoins(config.amount)
        .storeUint(config.period, 32)
        .storeUint(config.start_time, 32)
        .storeUint(config.timeout, 32)
        .storeUint(config.last_payment_time, 32)
        .storeUint(config.last_request_time, 32)
        .storeUint(config.failed_attempts, 8)
        .storeUint(config.subscription_id, 32)
        .endCell();
}

export const Opcodes = {
    destruct : "destruct",
    payment_request : 0x22de8175,
    fallback : "fallback",
    subscription : "subscription",
    signature_disallow : "signature_disallow",
    extension_action : 0x6578746E,
    auth_extension: 0x0ec3c86d
};

export class SubscriptionExtV5 implements Contract {
    constructor(readonly address: Address, readonly init?: { code: Cell; data: Cell }) {}

    static createFromAddress(address: Address) {
        return new SubscriptionExtV5(address);
    }

    static createFromConfig(config: SubscriptionExtV5Config, code: Cell, workchain = 0) {
        const data = subscriptionV5ConfigToCell(config);
        const init = { code, data };
        return new SubscriptionExtV5(contractAddress(workchain, init), init);
    }

    async sendDeploy(provider: ContractProvider, via: Sender, value: bigint) {
        await provider.internal(via, {
            value,
            sendMode: SendMode.PAY_GAS_SEPARATELY,
            body: beginCell().endCell()
        });
    }

    async sendExternalForRequestPayment(provider: ContractProvider, via: Sender) {
        await provider.external(
            beginCell().endCell()
        );
    }

    async sendInternalRequestPayment(provider: ContractProvider, via: Sender){
        await provider.internal(via, {
            value: toNano("0.05"),
            sendMode: SendMode.PAY_GAS_SEPARATELY,
            body: beginCell()
                .storeUint(Opcodes.payment_request, 32)
                .endCell()
        });
    }

    async sendInternalMessage(
        provider: ContractProvider,
        via: Sender,
        opts: {
            value: bigint;
            body: Cell;
        }
    ) {
        await provider.internal(via, {
            value: opts.value,
            sendMode: SendMode.PAY_GAS_SEPARATELY,
            body: beginCell()
                .storeSlice(opts.body.beginParse())
                .endCell()
        });
    }

    async getSubscriptionData(provider: ContractProvider) {
        const result = (await provider.get('get_subscription_data', [])).stack;

        // (slice, slice, int, int, int, int, int, int, int, int)
        let wallet = result.readAddress();
        let beneficiary = result.readAddress();
        let amount = result.readBigNumber(); 
        let period = result.readNumber(); 
        let start_time = result.readNumber();
        let timeout = result.readNumber(); 
        let last_payment_time = result.readNumber(); 
        let last_request_time = result.readNumber(); 
        let failed_attempts = result.readNumber(); 
        let subscription_id = result.readNumber();

        return {wallet, beneficiary, amount, period, start_time, timeout, last_payment_time, last_request_time, failed_attempts, subscription_id};
    }
}
