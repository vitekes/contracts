# simple-counter

## Project structure

-   `contracts` - source code of all the smart contracts of the project and their dependencies.
-   `wrappers` - wrapper classes (implementing `Contract` from ton-core) for the contracts, including any [de]serialization primitives and compilation functions.
-   `tests` - tests for the contracts.
-   `scripts` - scripts used by the project, mainly the deployment scripts.

## How to use

### Build

`npx blueprint build` or `yarn blueprint build`

### Test

`npx blueprint test` or `yarn blueprint test`

### Deploy or run another script

`npx blueprint run` or `yarn blueprint run`

### Add a new contract

`npx blueprint create ContractName` or `yarn blueprint create ContractName`


# 🎯 Contest Smart Contract (TON Blockchain)

Этот проект реализует **смарт-контракт на Tact** для участия в конкурсах, с возможностью оплаты в **TON / USDT**, назначения победителей и вывода выигрышей.  
💎 **Интеграция с TonConnect** позволяет пользователям взаимодействовать с контрактом через TON-кошельки.

## 📌 **Функционал**
✅ **Оплата участия** в конкурсе (TON / USDT)  
✅ **Комиссия 5%**, кроме указанных кошельков  
✅ **Владелец** контракта назначает победителей  
✅ **Победители могут вывести выигрыш** (`claim`)

---

## 🚀 **Установка и запуск**

### 1️⃣ **Клонируем проект**
```sh
git clone https://github.com/your-repo/contest-ton.git
cd contest-ton
```

### 2️⃣ **Устанавливаем зависимости**
```sh
npm install
```

### 3️⃣ **Компилируем смарт-контракт**
```sh
npx tact build contest-payment.tact
```

### 4️⃣ **Запускаем тесты**
```sh
npx tsx test.ts
```

### 5️⃣ **Запускаем фронтенд**
```sh
npm start
```

---

## 📡 **Деплой контракта**
1. **Заполни** `deploy.ts` адресами
2. **Разверни контракт**
```sh
npx tsx deploy.ts
```
3. **Скопируй адрес контракта** в `.env`

---

## 🖥 **Frontend-интеграция**

### 1️⃣ **Подключение кошелька**
```tsx
import { tonConnect } from "../tonConnect";

const connectWallet = async () => {
    await tonConnect.connectWallet();
};
```

### 2️⃣ **Оплата участия**
```ts
import { payForContest } from "../utils/pay";

payForContest(1, "10"); // 10 TON за участие в конкурсе #1
```

### 3️⃣ **Вывод выигрыша**
```ts
import { claimWinnings } from "../utils/claim";

claimWinnings(1); // Забираем выигрыш в конкурсе #1
```

---

## 🔧 **Разработка**
- **Контракт:** `contracts/contest-payment.tact`
- **Тесты:** `test.ts`
- **Фронтенд:** `src/`
- **Функции взаимодействия:** `src/utils/`

---

## 🛠 **Технологии**
🟢 **Tact** – язык для смарт-контрактов TON  
🟢 **TonConnect** – интеграция кошельков  
🟢 **ton-core** – работа с TVM  
🟢 **React + TypeScript**

