import { ethers } from "hardhat";
import { OpToolsLockerV1 } from "../typechain-types";

const LOCKER_ADDRESS = "0xF32E20dE2ec3e7630dDe035012789a82aEa3e600";

async function main() {
  const Locker = await ethers.getContractFactory('OpToolsLockerV1');
  //const locker = await Locker.deploy();
  //await locker.deployed();
  //console.log('Locker deployed at ' + locker.address);

  const locker = Locker.attach(
    LOCKER_ADDRESS
  ) as OpToolsLockerV1

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