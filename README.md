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

# 📖 **Документация по контракту `ContestPayment` (TON + Tact)**

Этот контракт позволяет:
- ✅ **Принимать оплату** за участие в конкурсах (**TON / USDT**)
- ✅ **Брать комиссию** с участников (настраиваемый процент)
- ✅ **Назначать победителей** (только владелец)
- ✅ **Выдавать выигрыши** победителям через `claim()`
- ✅ **Добавлять кошельки без комиссии**

---

## 🚀 **Развёртывание контракта**
### 1️⃣ **Компиляция контракта**
```sh
npx tact build contest-payment.tact
```
Файл `.tact` скомпилируется в `.fift` и `.fc`.

### 2️⃣ **Развёртывание в сеть**
Добавьте свой кошелёк в `deploy.ts` и выполните:
```sh
npx tsx deploy.ts
```
После успешного деплоя получите **адрес контракта**.

---

## 📡 **Методы контракта**
### 🔹 **1. Оплата участия (`pay` / `payUSDT`)**
#### Входные параметры:
- `contestId: Int` – ID конкурса
- `msg.value()` (TON) / `msg.body().amount` (USDT) – сумма оплаты
- Автоматически удерживается комиссия **(процент настраивается)**

#### Вызов с фронта (TON):
```ts
import { payForContest } from "../utils/pay";
payForContest(1, "10"); // Участвовать в конкурсе #1 (10 TON)
```

#### Вызов с фронта (USDT):
```ts
import { payForContestUSDT } from "../utils/pay";
payForContestUSDT(1, "100"); // Участвовать в конкурсе #1 (100 USDT)
```

---

### 🔹 **2. Установка победителей (`setWinners`)**
📌 *Только владелец!*
#### Входные параметры:
- `contestId: Int` – ID конкурса
- `winners: Map<address, Int>` – победители и их выигрыши

#### Вызов с фронта:
```ts
import { setWinners } from "../utils/admin";
setWinners(1, { "EQ...1": "50", "EQ...2": "30" }); // Назначить победителей
```

---

### 🔹 **3. Вывод выигрыша (`claim`)**
#### Входные параметры:
- `contestId: Int` – ID конкурса
- Вызывает **только победитель**

#### Вызов с фронта:
```ts
import { claimWinnings } from "../utils/claim";
claimWinnings(1); // Получить выигрыш за конкурс #1
```

---

### 🔹 **4. Добавление кошельков без комиссии (`addFeeExempt`)**
📌 *Только владелец!*
#### Входные параметры:
- `address: address` – кошелёк без комиссии

#### Вызов с фронта:
```ts
import { addFeeExempt } from "../utils/admin";
addFeeExempt("EQ..."); // Добавить кошелёк в исключения
```

---

### 🔹 **5. Изменение комиссии (`ChangePersend`)**
📌 *Только владелец!*
#### Входные параметры:
- `persent: Int` – новый процент комиссии

#### Вызов с фронта:
```ts
import { changeFee } from "../utils/admin";
changeFee(3); // Установить комиссию 3%
```

---

## 🎯 **Frontend-интеграция (TonConnect)**
### Установка зависимостей
```sh
npm install @tonconnect/sdk ton-core
```

### **Инициализация `TonConnect`**
```ts
import { TonConnect } from "@tonconnect/sdk";
export const tonConnect = new TonConnect({
    manifestUrl: "https://yourdomain.com/tonconnect-manifest.json"
});
```

### **Подключение кошелька**
```tsx
import { tonConnect } from "../tonConnect";

const connectWallet = async () => {
    await tonConnect.connectWallet();
};
```

---
