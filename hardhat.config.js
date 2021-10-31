require("@nomiclabs/hardhat-waffle");
require("dotenv").config();

module.exports = {
  defaultNetwork: "hardhat",
  networks: {
    kovan: {
      url: process.env.ALCHEMY_KOVAN_KEY,
      accounts: [
        process.env.TESTNET_PRIVATE_KEY,
        process.env.TESTNET_SECOND_PRIVATE_KEY,
      ],
    },
  },
  solidity: "0.8.4",
};
