import React from 'react';
import ReactDOM from 'react-dom/client';
import './index.css';
import App from './App';
import { Buffer } from 'buffer';
import { TonConnectUIProvider } from '@tonconnect/ui-react';

window.Buffer = window.Buffer || Buffer;

const root = ReactDOM.createRoot(
  document.getElementById('root') as HTMLElement
);

root.render(
  <TonConnectUIProvider manifestUrl="https://raw.githubusercontent.com/XaBbl4/pytonconnect/main/pytonconnect-manifest.json">
    <React.StrictMode>
      <App />
    </React.StrictMode>
  </TonConnectUIProvider>
);
