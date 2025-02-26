import { toNano } from '@ton/core';
import { Lotery } from '../wrappers/Lotery';
import { NetworkProvider } from '@ton/blueprint';

export async function run(provider: NetworkProvider) {
    const lotery = provider.open(await Lotery.fromInit());

    await lotery.send(
        provider.sender(),
        {
            value: toNano('0.05'),
        },
        {
            $$type: 'Deploy',
            queryId: 0n,
        }
    );

    await provider.waitForDeploy(lotery.address);

    // run methods on `lotery`
}
