const { task } = require("hardhat/config");

// accounts that hardhat can spin
task("accounts", "Prints the list of accounts").setAction(async () => {
  const accounts = await ethers.getSigners();
  for (const account of accounts) {
    console.log(account.address);
  }
});

module.exports = {};
