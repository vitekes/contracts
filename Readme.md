# 🚀 Инструкция по интеграции TRON-смарт-контракта с React

## 📌 Требования:
- Node.js & npm
- Установленный TronLink (кошелек для TRON)
- Развернутый контракт в TRON

---

## 1️⃣ Установка TronWeb

Для взаимодействия с TRON установите TronWeb:

```bash
npm install tronweb
```

---

## 2️⃣ Настройка TronWeb

Создайте файл `src/tronService.js` и добавьте:

```javascript
import TronWeb from "tronweb";

const TRON_NODE = "https://api.trongrid.io"; // Mainnet
const USDT_CONTRACT = "ТВОЙ_АДРЕС_USDT";
const LOTTERY_CONTRACT = "ТВОЙ_АДРЕС_КОНТРАКТА";

const tronWeb = new TronWeb({ fullHost: TRON_NODE, privateKey: "" });

export const getContract = async () => {
  return await tronWeb.contract().at(LOTTERY_CONTRACT);
};
```

---

## 3️⃣ Функция покупки билета

Добавьте в `tronService.js`:

```javascript
export const buyTicket = async (contestId, amount) => {
  if (!window.tronWeb || !window.tronWeb.ready) {
    alert("TronLink не подключен!");
    return;
  }
  const contract = await getContract();
  const sender = window.tronWeb.defaultAddress.base58;
  const amountInSun = tronWeb.toSun(amount);

  const usdtContract = await tronWeb.contract().at(USDT_CONTRACT);
  await usdtContract.approve(LOTTERY_CONTRACT, amountInSun).send({ from: sender });
  
  const tx = await contract.buyTicket(contestId, amountInSun).send({ from: sender });
  console.log("Транзакция отправлена:", tx);
};
```

---

## 4️⃣ Кнопка для покупки билета (React компонент)

Создайте `src/components/BuyTicket.js`:

```javascript
import React, { useState } from "react";
import { buyTicket } from "../tronService";

const BuyTicket = () => {
  const [contestId, setContestId] = useState("");
  const [amount, setAmount] = useState("");

  const handleBuyTicket = async () => {
    if (!contestId || !amount) {
      alert("Введите ID конкурса и сумму!");
      return;
    }
    await buyTicket(contestId, amount);
  };

  return (
    <div>
      <input type="number" placeholder="ID Конкурса" value={contestId} onChange={(e) => setContestId(e.target.value)} />
      <input type="number" placeholder="Сумма (USDT)" value={amount} onChange={(e) => setAmount(e.target.value)} />
      <button onClick={handleBuyTicket}>Купить билет</button>
    </div>
  );
};

export default BuyTicket;
```

---

## 5️⃣ Функция назначения победителей (Для админа)

```javascript
export const setWinners = async (contestId, winners, winningAmounts) => {
  if (!window.tronWeb || !window.tronWeb.ready) {
    alert("TronLink не подключен!");
    return;
  }
  const contract = await getContract();
  const sender = window.tronWeb.defaultAddress.base58;

  const tx = await contract.setWinners(contestId, winners, winningAmounts).send({ from: sender });
  console.log("Победители установлены:", tx);
};
```

---

## 6️⃣ Функция клейминга выигрыша

```javascript
export const claimPrize = async (contestId) => {
  if (!window.tronWeb || !window.tronWeb.ready) {
    alert("TronLink не подключен!");
    return;
  }
  const contract = await getContract();
  const sender = window.tronWeb.defaultAddress.base58;
  
  const tx = await contract.claimPrize(contestId).send({ from: sender });
  console.log("Приз успешно получен:", tx);
};
```

---

## 🎯 Итог
✅ **Пользователи покупают билеты через TronLink**  
✅ **Админ назначает победителей**  
✅ **Пользователи клеймят выигрыши**

🚀 Теперь ваш сайт на React работает с TRON-смарт-контрактом!