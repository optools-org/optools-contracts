import { HardhatUserConfig } from 'hardhat/config';
import '@nomicfoundation/hardhat-toolbox';
import '@nomicfoundation/hardhat-ethers';

require('dotenv').config();

const config: HardhatUserConfig = {
  solidity: {
    version: '0.8.19',
  },
  networks: {
    'ethereum': {
      url: process.env.ETHEREUM_RPC as string,
      accounts: [process.env.WALLET_KEY as string]
    },
    'ethereum-goerli': {
      url: process.env.ETHEREUM_GOERLI_RPC as string,
      accounts: [process.env.WALLET_KEY as string],
    },
    'opbnb': {
      url: process.env.OPBNB_RPC as string,
      chainId: 204,
      accounts: [process.env.WALLET_KEY as string],
      gasPrice: 20000000000,
    }
  },
  defaultNetwork: 'hardhat',

  // Hardhat expects etherscan here, even if you're using Blockscout.
  etherscan: {
    apiKey: {
      ethereum: process.env.ETHERSCAN_API_KEY as string,
      "ethereum-goerli": process.env.ETHERSCAN_API_KEY as string
    },
    customChains: [
      {
        network: 'ethereum',
        chainId: 1,
        urls: {
          apiURL: "https://api.etherscan.io/api",
          browserURL: "https://etherscan.io"
        }
      },
      {
        network: "ethereum-goerli",
        chainId: 5,
        urls: {
          apiURL: "https://api-goerli.etherscan.io/api",
          browserURL: "https://goerli.etherscan.io"
        }
      }
    ]
  },
};

export default config;