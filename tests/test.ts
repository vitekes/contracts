import { Blockchain, SandboxContract, TreasuryContract } from "@ton-community/sandbox";
import { Address, toNano } from "ton-core";
import { ContestPayment } from "./output/contest-payment"; // Импорт скомпилированного контракта

async function run() {
    const blockchain = await Blockchain.create(); // Создаем тестовый блокчейн

    const owner = await blockchain.treasury("owner"); // Кошелек владельца
    const user1 = await blockchain.treasury("user1"); // Участник конкурса
    const user2 = await blockchain.treasury("user2"); // Другой участник

    // Разворачиваем контракт
    const contract = blockchain.openContract(await ContestPayment.fromInit(owner.address));
    await contract.send(owner.sender(), { value: toNano("1") }, "Deploy");

    console.log("Contract deployed at:", contract.address.toString());

    // Участник платит за участие (в TON)
    await contract.send(user1.sender(), { value: toNano("10") }, { $$type: "pay", contestId: 1 });

    console.log("User1 paid for contest");

    // Владелец устанавливает победителей
    await contract.send(owner.sender(), { value: toNano("0.05") }, {
        $$type: "setWinners",
        contestId: 1,
        winners: { [user1.address.toString()]: toNano("9.5") }
    });

    console.log("Winner set");

    // Победитель получает выплату
    await contract.send(user1.sender(), { value: toNano("0.05") }, { $$type: "claim", contestId: 1 });

    console.log("User1 claimed winnings");

    // Проверяем баланс
    console.log("User1 balance after claim:", await blockchain.getBalance(user1.address));
}

run();