# Инструкция по подключению смарт-контракта к веб-сайту

## 1. Развертывание контракта
Перед интеграцией на сайт, необходимо развернуть контракт в сети Ethereum (или другой EVM-совместимой сети). Это можно сделать через Remix, Hardhat или Foundry.

### Способы развертывания
#### Remix
1. Перейдите на [Remix](https://remix.ethereum.org/).
2. Создайте новый файл, вставьте код контракта.
3. Скомпилируйте и разверните контракт, выбрав нужную сеть.
4. Сохраните адрес развернутого контракта.

#### Hardhat
1. Создайте проект Hardhat (`npx hardhat` → создать скрипт деплоя).
2. Включите контракт в `scripts/deploy.js`.
3. Запустите `npx hardhat run scripts/deploy.js --network goerli` (или другую сеть).

## 2. Установка необходимых библиотек
На веб-сайте используйте `ethers.js` или `web3.js` для взаимодействия с контрактом.

### Установка Ethers.js
```sh
npm install ethers
```

## 3. Подключение контракта к фронтенду
Создайте файл `contract.js` и добавьте следующее:
```js
import { ethers } from "ethers";

const contractAddress = "ВАШ_КОНТРАКТНЫЙ_АДРЕС";
const abi = [
// Вставьте ABI контракта сюда (можно получить в Remix или Hardhat)
];

export const getContract = () => {
  if (!window.ethereum) throw new Error("MetaMask не установлен");
  const provider = new ethers.providers.Web3Provider(window.ethereum);
  const signer = provider.getSigner();
  return new ethers.Contract(contractAddress, abi, signer);
};
```

## 4. Функция покупки билета
В файле `App.js` добавьте:
```js
import { getContract } from "./contract";

const buyTicket = async (contestId, amount, isETH) => {
  try {
    const contract = getContract();
    const tx = isETH
      ? await contract.buyTicket(contestId, true, { value: amount })
      : await contract.buyTicket(contestId, false, amount);
    await tx.wait();
    console.log("Билет куплен!");
  } catch (error) {
    console.error("Ошибка покупки билета", error);
  }
};
```

## 5. Кнопка для покупки билета
В файле `App.js`:
```jsx
<button onClick={() => buyTicket(1, ethers.utils.parseEther("0.01"), true)}>
  Купить билет за ETH
</button>
```

## 6. Вывод списка победителей
Добавьте функцию:
```js
const declareWinners = async (contestId, winners, amounts) => {
  try {
    const contract = getContract();
    const tx = await contract.declareWinners(contestId, winners, amounts);
    await tx.wait();
    console.log("Победители объявлены!");
  } catch (error) {
    console.error("Ошибка объявления победителей", error);
  }
};
```

## 7. Функция для получения выигрыша
```js
const claimPrize = async (contestId) => {
  try {
    const contract = getContract();
    const tx = await contract.claimPrize(contestId);
    await tx.wait();
    console.log("Выигрыш получен!");
  } catch (error) {
    console.error("Ошибка получения выигрыша", error);
  }
};
