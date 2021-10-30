const main = async () => {
  const twitterContractFactory = await hre.ethers.getContractFactory(
    "TwitterEscrowV1"
  );
  const twitterContract = await twitterContractFactory.deploy();

  await twitterContract.deployed();
  console.log("Contract deployed to:", twitterContract.address);
};

const runMain = async () => {
  try {
    await main();
    process.exit(0);
  } catch (error) {
    console.log(error);
    process.exit(1);
  }
};

runMain();
