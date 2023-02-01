require('dotenv').config();
require("@nomicfoundation/hardhat-toolbox");

/** @type import('hardhat/config').HardhatUserConfig */
module.exports = {
  solidity: "0.8.17",
  settings : {
    optimizer : {
      enabled : true,
      runs : 200,
    }
  },
  networks: {
    etherMain: {
      url: process.env.APP_ETHERMAIN_RPC_URL,
      accounts: [process.env.OWNER_PRIVATE_KEY],
    },
    sepolia: {
      url: process.env.APP_SEPOLIA_RPC_URL,
      accounts: [process.env.APP_PRIVATE_KEY],
    },
    mumbai: {
      url : process.env.APP_MUMBAI_RPC_URL,
      accounts: [process.env.APP_PRIVATE_KEY],
    },
    local: {
      url: "http://localhost:8545/",
      accounts: ['0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80', '0x59c6995e998f97a5a0044966f0945389dc9e86dae88c7a8412f4603b6b78690d',]
    },
  },
  etherscan: {
    apiKey: process.env.APP_ETHERSCAN_API_KEY
  }
};
