
import React, { useState } from 'react';
import './App.css';
import { KeyPair, mnemonicToPrivateKey } from '@ton/crypto';
import { WalletContractV5R1, TonClient, Address, toNano, beginCell, Cell, storeStateInit, StateInit } from '@ton/ton';
import { WalletV5R1SendArgsSinged } from '@ton/ton/dist/wallets/v5r1/WalletContractV5R1'
import { TonConnectButton, useTonConnectUI, SendTransactionRequest } from '@tonconnect/ui-react';
import extJson from "./contract/subsription-ext.compiled.json";
import { Opcodes, SubscriptionExtV5, subscriptionV5ConfigToCell } from "./ext-plus";

const EXT_CODE = Cell.fromBase64(extJson.base64);

interface ButtonProps {
    onConnect: () => void;
}

interface DeployButtonProps {
    onDeploy: () => void;
}

interface DisconnectButtonProps {
    onDisconnect: () => void;
}

interface ManualButtonProps {
    onManual: () => void;
}

interface SeedButtonProps {
    onSeedConvert: () => void;
}

const randomizeInteger = (min: number, max: number): number => {
    return min + Math.floor((max - min + 1) * Math.random());
};

// Компонент для кнопки "Deploy"
const DeployButton: React.FC<DeployButtonProps> = ({ onDeploy }) => {
    return (
        <button className="Ext-deploy" onClick={onDeploy}>
            Задеплоить контракт
        </button>
    );
};

const ConnectButton: React.FC<ButtonProps> = ({ onConnect }) => {
    return (
        <button className="Ext-connect" onClick={onConnect}>
            + Плагин
        </button>
    );
};

// Компонент для кнопки "Disconnect"
const DisconnectButton: React.FC<DisconnectButtonProps> = ({ onDisconnect }) => {
    return (
        <button className="Ext-disconnect" onClick={onDisconnect}>
            - Плагин
        </button>
    );
};

// Компонент для кнопки "Manual"
const ManualButton: React.FC<ManualButtonProps> = ({ onManual }) => {
    return (
        <button className="Ext-manual" onClick={onManual}>
            Запросить подписку
        </button>
    );
};

const ConvertSeed: React.FC<SeedButtonProps> = ({ onSeedConvert }) => {
    return (
        <button className="Seed-parser" onClick={onSeedConvert}>
            Распарсить сид фразу
        </button>
    );
};

const App: React.FC = () => {
    const [connectInput, setConnectInput] = useState(''); // Состояние для первого input
    const [seedInput, setSeedInput] = useState(''); // Состояние для первого input
    const [adminInput, setAdminInput] = useState(''); // Состояние для первого input
    const [disconnectInput, setDisconnectInput] = useState(''); // Состояние для второго input
    const [extensionAddress, setExtAddress] = useState(''); // Состояние для второго input
    const [secretKey, setSecretKey] = useState('');
    const [walletAddress, setWalletAddress] = useState<Address | undefined>(undefined);
    const [keyPair, setKeyPair] = useState<KeyPair | undefined>(undefined);
    const [ExtAddresses, setExtensionAddresses] = useState<Address[] | undefined>(undefined);
    const [deployedExt, setDeployedExt] = useState<string | undefined>(undefined);

    const [tonConnectUI, setOptions] = useTonConnectUI();

    async function getSeqno(walletAddress: String) {
        const url = `https://tonapi.io/v2/wallet/${walletAddress}/seqno`;
    
        try {
            const response = await fetch(url);
            if (!response.ok) {
                throw new Error(`Error: ${response.status}`);
            }
    
            const data = await response.json();
            return data.seqno; // Assuming the seqno is a field in the returned JSON
        } catch (error) {
            console.error("Error fetching seqno:", error);
        }
    }

    const handleParseSeed = async () => {
        let localSecretKeyUtils = await mnemonicToPrivateKey(seedInput.split(" "));

        let wallet = WalletContractV5R1.create({ workchain: 0, publicKey: localSecretKeyUtils.publicKey });

        setWalletAddress(wallet.address);
        setKeyPair(localSecretKeyUtils)
        setSecretKey(`-- Адрес кошелька --<br/>${wallet.address.toString({bounceable: false})}<br/>-- Секретный ключ загружен --<br/>${localSecretKeyUtils.secretKey.toString("hex")}`);

        try{
            const client = new TonClient({
                endpoint: 'https://toncenter.com/api/v2/jsonRPC',
              });
            let contract = client.open(wallet);
            let ext_addresses = await contract.getExtensionsArray();

            setExtensionAddresses(ext_addresses);
        } catch (error) {
            console.log(error);
        }

        alert(`Secret key ${localSecretKeyUtils.secretKey.toString("hex")}`);
    };

    const connectExt = async () => {
        const client = new TonClient({
            endpoint: 'https://toncenter.com/api/v2/jsonRPC',
          });

        let workchain = 0; 

        if (!keyPair?.publicKey){
            alert("Нету ключей");
            return;
        }

        let wallet = WalletContractV5R1.create({ workchain, publicKey: keyPair?.publicKey });
        let contract = client.open(wallet);

        const userAddress = wallet.address;
        const extensionAddressParsed = Address.parse(connectInput);

        if (!keyPair?.secretKey){
            alert("Secret key not set")
            return;
        }

        let seqno = await getSeqno(userAddress.toString())

        try {
            const args: WalletV5R1SendArgsSinged = {
                authType: "external",
                seqno: seqno,
                secretKey: keyPair.secretKey
            };
            
            let data = await contract.sendAddExtension({
                ...args,
                extensionAddress: extensionAddressParsed
            });

            alert(data);

            let ext_addresses = await contract.getExtensionsArray();

            setExtensionAddresses(ext_addresses);
        } catch (error) {
            console.log(error);
        }
    }

    const disconnectExt = async () => {
        const client = new TonClient({
            endpoint: 'https://toncenter.com/api/v2/jsonRPC',
        });

        if (!keyPair?.publicKey){
            alert("Нету ключей");
            return;
        }

        let workchain = 0; // Usually you need a workchain 0

        let wallet = WalletContractV5R1.create({ workchain, publicKey: keyPair?.publicKey });
        let contract = client.open(wallet);

        const userAddress = wallet.address;
        const extensionAddressParsed = Address.parse(disconnectInput);

        if (!keyPair?.secretKey){
            alert("Secret key not set")
            return;
        }

        let seqno = await getSeqno(userAddress.toString())

        try {
            const args: WalletV5R1SendArgsSinged = {
                authType: "external",
                seqno: seqno,
                secretKey: keyPair.secretKey
            };

            let data = await contract.sendRemoveExtension({
                ...args,
                extensionAddress: extensionAddressParsed
            });

            alert(data);

            let ext_addresses = await contract.getExtensionsArray();

            setExtensionAddresses(ext_addresses);
        } catch (error) {
            console.log(error);
        }
    }

    const sendPayment = async () => {
        const client = new TonClient({
            endpoint: 'https://toncenter.com/api/v2/jsonRPC',
          });

        let workchain = 0; 

        if (!keyPair?.publicKey){
            alert("Нету ключей");
            return;
        }

        let wallet = WalletContractV5R1.create({ workchain, publicKey: keyPair?.publicKey });
        let contract = client.open(wallet);

        let extAddress = Address.parse(extensionAddress);

        if (!keyPair?.secretKey){
            alert("Secret key not set")
            return;
        }

        let msg = beginCell()
                        .storeUint(0x22de8175, 32)
                    .endCell();

        const tx: SendTransactionRequest = {
            validUntil: Date.now() + 5 * 60 * 1000,
            messages: [
                {
                    address: extAddress.toString(),
                    amount: toNano("0.1") + "",
                    payload: msg.toBoc().toString("base64")
                }
            ]
        }
        await tonConnectUI.sendTransaction(
            tx
        )
    }

    const deployContract = async () => {
        if (!tonConnectUI.account){
            alert("Подключите кошелек")
            return;
        }

        const unixTime = Math.floor(Date.now() / 1000);
        let userAddress = Address.parse(tonConnectUI.account.address);
        let beneficiary = Address.parse(adminInput);

        let subscriptionConfig = {
            wallet: userAddress,
            beneficiary: beneficiary,
            amount: toNano(0.001),
            period: 60,
            start_time: unixTime,
            timeout: 0,
            last_payment_time: 0,
            last_request_time: 0,
            failed_attempts: 0,
            subscription_id: randomizeInteger(0, 10000000),
        }

        let subscriptionPlugin = SubscriptionExtV5.createFromConfig(
            subscriptionConfig, EXT_CODE
        );

        const stateInit: StateInit={
            code: subscriptionPlugin.init!.code,
            data: subscriptionPlugin.init!.data
        }

        const initCell = beginCell().store(storeStateInit(stateInit)).endCell().toBoc().toString('base64')

        const tx: SendTransactionRequest = {
            validUntil: Date.now() + 5 * 60 * 1000,
            messages: [
                {
                    address: subscriptionPlugin.address.toString(),
                    amount: toNano("0.1") + "",
                    stateInit: initCell
                }
            ]
        }

        setDeployedExt(subscriptionPlugin.address.toString());

        await tonConnectUI.sendTransaction(tx);
    }

    return (
        <div className="App">
            <header className="App-header">
                <div className='App-deployer'>
                    <p className='title-text'>Деплой расширения</p>
                    <p className='description-text'>Для начала подключите кошелек</p>
                    <TonConnectButton />
                    <p className='description-text'>Теперь введите кошелек на который будут уходить деньги с подписки/Сейчас сумма подписки стоит по дефолту 0.001 TON, в UI это пока не изменить</p>
                        <input 
                            className="Seed-input" 
                            placeholder="Админ кошелек/Бенецифиар"
                            value={adminInput} // Привязка значения состояния к input
                            onChange={(e) => setAdminInput(e.target.value)} // Обновление состояния при изменении значения
                        />
                    <DeployButton onDeploy={deployContract}/>
                    <p className='description-text'>{`Теперь скопируйте просчитанный адрес: ${deployedExt} и вставьте в поле для добавления расширений`}</p>
                </div>
                <div className='App-ext-actions'>
                    <p className='warning-text'>ПРЕДУПРЕЖДЕНИЕ!!!<br/>ДАННЫЙ САЙТ РАБОТАЕТ ТОЛЬКО НА ВАШЕМ УСТРОЙСТВЕ. ТАК КАК ТЕКУЩИЕ ВЕРСИИ КОШЕЛЬКОВ НЕ ПОДДЕРЖИВАЮТ ИНТЕГРАЦИЮ РАСШИРЕНИЙ ЧЕРЕЗ TONCONNECT, МЫ ВЫНУЖДЕНЫ ЗАПРАШИВАТЬ SEED ФРАЗУ. НИКОГДА НЕ ПЕРЕДАВАЙТЕ ЕЕ ПОСТОРОНИМ - ЭТО ДАСТ ИМ ПРЯМОЙ ДОСТУП К ВАШЕМУ КОШЕЛЬКУ И ДЕНЬГАМ. НА ДАННЫЙ МОМЕНТ ПОДДЕРЖИВАЕТСЯ ТОЛЬКО W5 версия кошелька</p>
                    <p className='description-text'>Введите сид фразу кошелька к которому вы хотите прикрепить расширение и нажмите кнопку чтоб ее распарсить</p>
                    <div className="Ext-column">
                        <input 
                            className="Seed-input" 
                            placeholder="Ваша сид фраза"
                            value={seedInput} // Привязка значения состояния к input
                            onChange={(e) => setSeedInput(e.target.value)} // Обновление состояния при изменении значения
                        />
                        <ConvertSeed onSeedConvert={handleParseSeed} />
                        <p
                        className="secretKeyText"
                        dangerouslySetInnerHTML={{ __html: secretKey }}
                        ></p>
                    </div>
                    <div className="Ext-column">
                        <p className='description-text'>Тут нужно ввести адрес расширения, задеплоенного выше</p>
                        <input 
                            className="Ext-input" 
                            placeholder="Адрес расширения для добавления"
                            value={connectInput} // Привязка значения состояния к input
                            onChange={(e) => setConnectInput(e.target.value)} // Обновление состояния при изменении значения
                        />
                        <p className='description-text'>Нажмите кнопку чтоб добавить расширение на кошелек</p>
                        <ConnectButton onConnect={connectExt} />
                    </div>
                    <div className="Ext-column">
                        <input 
                            className="Ext-disconnect-input" 
                            placeholder="Адрес расширения для исключения"
                            value={disconnectInput} // Привязка значения состояния к input
                            onChange={(e) => setDisconnectInput(e.target.value)} // Обновление состояния при изменении значения
                        />
                        <DisconnectButton onDisconnect={disconnectExt} />
                        <input 
                            className="Ext-disconnect-input" 
                            placeholder="Адрес расширения которое вы добавили к своему кошельку"
                            value={extensionAddress} // Привязка значения состояния к input
                            onChange={(e) => setExtAddress(e.target.value)} // Обновление состояния при изменении значения
                        />
                        <p className='description-text'>Нажмите для теста снятия средств за подписку</p>
                        <ManualButton onManual={sendPayment} />
                    </div>
                    <div>
                    {ExtAddresses && ExtAddresses.length > 0 ? (
                        ExtAddresses.map((addr, index) => (
                        <p key={index}>{addr?.toString({bounceable: false})}</p>
                        ))
                    ) : (
                        <p>Расширений нет</p>
                    )}
                    </div>
                </div>
            </header>
        </div>
    );
}

export default App;
