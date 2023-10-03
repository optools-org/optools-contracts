import { ethers } from "hardhat";

const LOCKER_ADDRESS = "0xF32E20dE2ec3e7630dDe035012789a82aEa3e600";

async function main() {
  const Locker = await ethers.getContractFactory('OpToolsLockerV1');
  //const locker = await Locker.deploy();
  //await locker.deployed();

  const locker = Locker.attach(
    LOCKER_ADDRESS
  );

  console.log('Locker deployed at ' + locker.address);

  const enableDepositingTx = await locker.setDepositsEnabled(true);
  await enableDepositingTx.wait();

  console.log('Deposits have been enabled!');
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});