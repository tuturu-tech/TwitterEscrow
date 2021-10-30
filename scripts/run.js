const deployMocks = async () => {
  const mockERC20ContractFactory = await hre.ethers.getContractFactory(
    "MockERC20"
  );
  const mockContract = await mockERC20ContractFactory.deploy();
  await mockContract.deployed();

  console.log("Mock token deployed to:", mockContract.address);
  return mockContract.address;
};

const main = async () => {
  [owner, addr1, addr2, ...addrs] = await ethers.getSigners();
  const tokenAddress = deployMocks();
  const twitterContractFactory = await hre.ethers.getContractFactory(
    "TwitterEscrowV1"
  );
  const twitterContract = await twitterContractFactory.deploy([tokenAddress]);

  await twitterContract.deployed();
  console.log("Contract deployed to:", twitterContract.address);

  const tweetContent = "This tweet";
  const taskReward = "1000000000000000000";

  await twitterContract.createTask(
    addr1.address,
    tweetContent,
    taskReward,
    tokenAddress
  );

  await twitterContract.createTask(
    addr1.address,
    "Second tweet",
    taskReward,
    tokenAddress
  );

  const taskList = await twitterContract.getAllTasks();
  console.log(taskList);
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
