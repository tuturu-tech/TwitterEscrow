const deployMocks = async () => {
  const mockERC20ContractFactory = await hre.ethers.getContractFactory(
    "MockERC20"
  );
  const mockContract = await mockERC20ContractFactory.deploy();
  await mockContract.deployed();

  console.log("Mock token deployed to:", mockContract.address);
  return mockContract;
};

const main = async () => {
  [owner, addr1, addr2, ...addrs] = await ethers.getSigners();

  const mockERC20ContractFactory = await hre.ethers.getContractFactory(
    "MockERC20"
  );
  const mockContract = await mockERC20ContractFactory.deploy();
  await mockContract.deployed();

  console.log("Mock token deployed to:", mockContract.address);

  //const token = deployMocks();
  const twitterContractFactory = await hre.ethers.getContractFactory(
    "TwitterEscrowV1"
  );
  const twitterContract = await twitterContractFactory.deploy([
    mockContract.address,
  ]);
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
