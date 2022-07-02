require("@nomiclabs/hardhat-waffle");
require("@nomiclabs/hardhat-etherscan");
require("hardhat-gas-reporter");
require("dotenv").config();
require("solidity-docgen");

// This is a sample Hardhat task. To learn how to create your own go to
// https://hardhat.org/guides/create-task.html
task("accounts", "Prints the list of accounts", async (taskArgs, hre) => {
  const accounts = await hre.ethers.getSigners();

  for (const account of accounts) {
    console.log(account.address);
  }
});

// You need to export an object to set up your config
// Go to https://hardhat.org/config/ to learn more

/**
 * @type import('hardhat/config').HardhatUserConfig
 */
module.exports = {
  solidity: {
    compilers: [
      {
        version: "0.8.15",
        settings: {
          optimizer: {
            enabled: false,
            runs: 200,
          },
        },
      },
      {
        version: "0.5.0",
        settings: {
          optimizer: {
            enabled: false,
            runs: 200,
          },
        },
      },
    ],
  },
  networks: {
    hardhat: {
      forking: {
        url: process.env.POLYGON,
        blockNumber: 30163528, // block pinning gives x20 perfromance due to caching as stated on hardhat docs
        enabled: true,
      },
    },
    mainnet_polygon: {
      url: process.env.POLYGON || "",
      accounts:
        process.env.PRIVATE_KEY !== undefined ? [process.env.PRIVATE_KEY] : [],
    },
    mumbai: {
      url: process.env.MUMBAI || "",
      accounts:
        process.env.PRIVATE_KEY !== undefined ? [process.env.PRIVATE_KEY] : [],
    },
    kovan: {
      url: process.env.KOVAN || "",
      accounts:
        process.env.PRIVATE_KEY !== undefined ? [process.env.PRIVATE_KEY] : [],
      gas: "auto",
      gasMultiplier: 2,
    },
    mainnet_eth: {
      url: process.env.BSC_TEST || "",
      accounts:
        process.env.PRIVATE_KEY !== undefined ? [process.env.PRIVATE_KEY] : [],
    },
    bsc: {
      url: process.env.BSC_MAINNET || "",
      accounts:
        process.env.PRIVATE_KEY !== undefined ? [process.env.PRIVATE_KEY] : [],
    },
  },
  gasReporter: {
    enabled: true,
    currency: "USD",
  },
  etherscan: {
    apiKey: {
      polygonMumbai: process.env.MUMBAI_ETHERSCAN,
    },
  },
};
