import { HardhatUserConfig } from 'hardhat/config';
import '@nomicfoundation/hardhat-toolbox';
import '@nomicfoundation/hardhat-ethers';
import '@nomicfoundation/hardhat-chai-matchers';

import '@openzeppelin/hardhat-upgrades';
import '@typechain/hardhat';
import 'hardhat-gas-reporter';
import 'solidity-coverage';
import 'hardhat/types';

require('dotenv').config();

const config: HardhatUserConfig = {
  defaultNetwork: 'hardhat',
  networks: {
    hardhat: {
      chainId: 1337,
    },
  },
  solidity: {
    compilers: [
      {
        version: '0.8.19',
        settings: {
          optimizer: {
            enabled: true,
            runs: 200,
          },
        },
      },
    ],
  },
  paths: {
    artifacts: './artifacts',
    cache: './cache',
    sources: ['./contracts', './test/foundry/mocks'],
    tests: './test',
  },
  mocha: {
    timeout: 100000,
  },
  typechain: {
    outDir: 'types',
    target: 'ethers-v6',
  },
};

export default config;
