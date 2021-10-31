const { BigNumber } = require("@ethersproject/bignumber");
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
    mockAPIConsumerAddress = addr2.address; // Only used for local testing without APIConsumer

    mockERCTokenContract = await ethers.getContractFactory("MockERC20");
    mockERCToken = await mockERCTokenContract.deploy();
    await mockERCToken.deployed();
    mockToken = await mockERCToken.address;

    twitterContract = await ethers.getContractFactory("TwitterEscrowV1");
    twitterEscrow = await twitterContract.deploy(
      [mockToken],
      mockAPIConsumerAddress
    );
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
    const tweetHash = "0x" + keccak256(tweetContent).toString("hex");
    const taskReward = "1000000000000000000";
    const taskFee = "10000000000000000";
    let createdTask;
    let expectedBalance = "1010000000000000000";

    beforeEach(async function () {
      let tx = await mockERCToken.approve(
        twitterEscrow.address,
        ethers.constants.MaxUint256
      );
      await tx.wait();

      await twitterEscrow.createTask(
        addr1.address,
        tweetHash,
        taskReward,
        mockToken
      );

      createdTask = await twitterEscrow.taskIdentifier(1);
    });

    it("Should have expected contract balance", async function () {
      let balance = await mockERCToken.balanceOf(twitterEscrow.address);
      expect(balance.toString()).to.equal(expectedBalance);
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

    /*it("Should have the expected tweetContent", async function () {
      expect(createdTask.tweetContent).to.equal(tweetContent);
    });*/

    it("Should have the expected tweetReward", async function () {
      const rwrd = createdTask.taskReward.toString();
      expect(rwrd).to.equal(taskReward);
    });

    /*  it("Should hash the tweet correctly", async function () {
      const hash = "0x" + keccak256(tweetContent).toString("hex");
      expect(createdTask.tweetHash.toString()).to.equal(hash);
    }); */

    it("Should have the correct token address", async function () {
      expect(createdTask.rewardToken).to.equal(mockToken);
    });

    it("Should have the correct task fee", async function () {
      const fee = toString(createdTask.taskFee);
      expect(createdTask.taskFee).to.equal(taskFee);
    });

    it("Created task should be added to Array of tasks", async function () {
      let taskArr = await twitterEscrow.getAllTasks();
      expect(taskArr.length).to.equal(1);
    });
  });

  describe("Task fulfillment and withdrawal", async function () {
    const tweetContent = "This tweet";
    const tweetHash = "0x" + keccak256(tweetContent).toString("hex");
    const tweetHash2 = "0x" + keccak256("Second task").toString("hex");
    const taskReward = "1000000000000000000";
    const taskFee = "10000000000000000";
    let createdTask;
    let fulfilledTask;
    let expectedBalance = "1010000000000000000";
    let tx;

    beforeEach(async function () {
      tx = await mockERCToken.approve(
        twitterEscrow.address,
        ethers.constants.MaxUint256
      );
      await tx.wait();

      await twitterEscrow.createTask(
        addr1.address,
        tweetHash,
        taskReward,
        mockToken
      );

      await twitterEscrow.createTask(
        addr2.address,
        tweetHash2,
        taskReward,
        mockToken
      );

      createdTask = await twitterEscrow.taskIdentifier(1);
      await twitterEscrow.fulfillTask(2);
      fulfilledTask = await twitterEscrow.taskIdentifier(2);
    });

    it("Task with ID 1 should be fulfilled", function () {
      expect(fulfilledTask.status).to.equal(2);
    });

    it("Should fail if task is not fulfilled", async function () {
      await expect(
        twitterEscrow.connect(addr1).withdrawReward(1)
      ).to.be.revertedWith("The task was not completed!");
    });

    it("Should fail if msg.sender is not promoter", async function () {
      await expect(
        twitterEscrow.connect(addr1).withdrawReward(2)
      ).to.be.revertedWith("Not the promoter!");
    });

    it("Should succeed if contract is fulfilled and caller is promoter", async function () {
      await expect(twitterEscrow.connect(addr2).withdrawReward(2)).to.not.be
        .reverted;
    });

    it("Should send the reward if successful and update all balances", async function () {
      // Ensure initial balance is 0
      let balance = await mockERCToken.balanceOf(addr2.address);
      expect(balance.toString()).to.equal("0");

      await twitterEscrow.connect(addr2).withdrawReward(2);

      // Get updated balance
      balance = await mockERCToken.balanceOf(addr2.address);
      expect(balance.toString()).to.equal(taskReward);

      balance = await twitterEscrow.getContractBalance(mockToken);
      expect(balance.toString()).to.equal(taskFee);
    });
  });
});
