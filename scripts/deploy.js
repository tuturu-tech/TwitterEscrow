const main = async () => {
  const linkAddressKovan = "0xa36085F69e2889c224210F603D836748e7dC0088";

  const APIConsumerTwitterContractFactory = await hre.ethers.getContractFactory(
    "APIConsumerTwitter"
  );
  const APIConsumerTwitterContract =
    await APIConsumerTwitterContractFactory.deploy();
  await APIConsumerTwitterContract.deployed();
  console.log(
    "APIConsumerTwitter contract deployed to:",
    APIConsumerTwitterContract.address
  );

  const mockERC20ContractFactory = await hre.ethers.getContractFactory(
    "MockERC20"
  );
  const mockContract = await mockERC20ContractFactory.deploy();
  await mockContract.deployed();
  console.log("Mock Token address:", mockContract.address);

  const twitterContractFactory = await hre.ethers.getContractFactory(
    "TwitterEscrowV1"
  );
  const twitterContract = await twitterContractFactory.deploy(
    [mockContract.address],
    APIConsumerTwitterContract.address
  );

  await twitterContract.deployed();
  console.log("Escrow contract deployed to:", twitterContract.address);
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
