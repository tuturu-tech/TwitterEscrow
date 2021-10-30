const { expect } = require("chai");
const keccak256 = require("keccak256");

describe("TwitterEscrowV1", function () {
  let twitterEscrow;
  let twitterContract;
  let owner;
  let addr1;
  let addr2;
  let addrs;
  let mockToken;

  beforeEach(async function () {
    [owner, addr1, addr2, ...addrs] = await ethers.getSigners();
    mockERCTokenContract = await ethers.getContractFactory("MockERC20");
    mockERCToken = await mockERCTokenContract.deploy();
    await mockERCToken.deployed();
    mockToken = await mockERCToken.address;

    twitterContract = await ethers.getContractFactory("TwitterEscrowV1");
    twitterEscrow = await twitterContract.deploy([mockToken]);
    await twitterEscrow.deployed();
  });

  describe("Contract deployed correctly", async function () {
    it("Should set the right owner", async function () {
      const _owner = await twitterEscrow.owner();
      expect(_owner).to.equal(owner.address);
    });

    it("Should set the right allowed token", async function () {
      const allowedTokens = await twitterEscrow.getAllowedTokens();
      expect(allowedTokens[0]).to.equal(mockToken);
    });
  });

  describe("Task creation", async function () {
    const tweetContent = "This tweet";
    const taskReward = "1000000000000000000";
    const taskFee = "10000000000000000";
    let createdTask;

    beforeEach(async function () {
      await twitterEscrow.createTask(
        addr1.address,
        tweetContent,
        taskReward,
        mockToken
      );

      createdTask = await twitterEscrow.taskIdentifier(1);
    });

    it("Should successfuly create a task", async function () {
      expect(createdTask).to.exist;
    });

    it("Should have the correct status", async function () {
      expect(createdTask.status).to.equal(0);
    });

    it("Should assign sponsor to function caller", async function () {
      expect(createdTask.sponsor).to.equal(owner.address);
    });

    it("Should assign promoter to the right address", async function () {
      expect(createdTask.promoter).to.equal(addr1.address);
    });

    it("Should have the expected tweetContent", async function () {
      expect(createdTask.tweetContent).to.equal(tweetContent);
    });

    it("Should have the expected tweetReward", async function () {
      const rwrd = createdTask.taskReward.toString();
      expect(rwrd).to.equal(taskReward);
    });

    it("Should hash the tweet correctly", async function () {
      const hash = "0x" + keccak256(tweetContent).toString("hex");
      expect(createdTask.tweetHash.toString()).to.equal(hash);
    });

    it("Should have the correct token address", async function () {
      expect(createdTask.rewardToken).to.equal(mockToken);
    });

    it("Should have the correct task fee", async function () {
      const fee = toString(createdTask.taskFee);
      expect(createdTask.taskFee).to.equal(taskFee);
    });

    it("Created task should be added to task list with ID 1", async function () {});
  });
});
