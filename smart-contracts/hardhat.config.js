require("@nomicfoundation/hardhat-toolbox");

/** @type import('hardhat/config').HardhatUserConfig */
module.exports = {
  solidity: {
    version: "0.8.28",
    settings: {
      optimizer: {
        enabled: true,
        runs: 200
      }
    }
  },
  networks: {
    localhost: {
      url: "http://127.0.0.1:8545",
      chainID: 1337,
      gas: 6500000,
      gasPrice: 1000000000,
      // Replace 'YOUR_PRIVATE_KEY' with a valid private key string (without 0x) for local testing,
      // or use an environment variable, e.g. process.env.PRIVATE_KEY
      // accounts: process.env.PRIVATE_KEY ? [process.env.PRIVATE_KEY] : ["b37a2494f2330ee4fdf516b38bad42b8e27e35e810abf1baf1fb51ad880872ed"]
      accounts: process.env.PRIVATE_KEY ? [process.env.PRIVATE_KEY] : ["e6181caaffff94a09d7e332fc8da9884d99902c7874eb74354bdcadf411929f1"]
      // accounts: [
      //   // These are the private keys from your genesis.json
      //   // DO NOT use these in production!
      //   "e6181caaffff94a09d7e332fc8da9884d99902c7874eb74354bdcadf411929f1", // Account with 200 ETH
      //   "5ad8b28507578c429dfa9f178d7f742f4861716ee956eb75648a7dbc5ffe915d", // Account with lots of ETH
      //   "f23f92ed543046498d7616807b18a8f304855cb644df25bc7d0b0b37d8a66019",  // Another well-funded account
      //   "7f012b2a11fc651c9a73ac13f0a298d89186c23c2c9a0e83206ad6e274ba3fc7",
      //   "60bbe10a196a4e71451c0f6e9ec9beab454c2a5ac0542aa5b8b733ff5719fec3"
      // ],
    }
  }
};
