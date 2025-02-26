import { Blockchain, SandboxContract, TreasuryContract } from '@ton/sandbox';
import { toNano } from '@ton/core';
import { Lotery } from '../wrappers/Lotery';
import '@ton/test-utils';

describe('Lotery', () => {
    let blockchain: Blockchain;
    let deployer: SandboxContract<TreasuryContract>;
    let lotery: SandboxContract<Lotery>;

    beforeEach(async () => {
        blockchain = await Blockchain.create();

        lotery = blockchain.openContract(await Lotery.fromInit());

        deployer = await blockchain.treasury('deployer');

        const deployResult = await lotery.send(
            deployer.getSender(),
            {
                value: toNano('0.05'),
            },
            {
                $$type: 'Deploy',
                queryId: 0n,
            }
        );

        expect(deployResult.transactions).toHaveTransaction({
            from: deployer.address,
            to: lotery.address,
            deploy: true,
            success: true,
        });
    });

    it('should deploy', async () => {
        // the check is done inside beforeEach
        // blockchain and lotery are ready to use
    });
});
