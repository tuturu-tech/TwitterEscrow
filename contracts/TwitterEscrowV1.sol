// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@chainlink/contracts/src/v0.8/ChainlinkClient.sol";
import "hardhat/console.sol";

contract APIConsumerTwitter is ChainlinkClient {
    using Chainlink for Chainlink.Request;

      bool public twitter;

      address private oracle;
      mapping(string => bytes32) jobIds;
      uint256 private fee;

      function parseTweetIds(string[] memory _tweetIds) pure internal returns (string memory) {
          string memory result = "";
          for (uint256 i=0; i < _tweetIds.length; i++) {
              result = string(abi.encodePacked(result,",", _tweetIds[i]));
          }
          return result;
      }

      /**
       * Network: Kovan
       * Oracle: 0xc57B33452b4F7BB189bB5AfaE9cc4aBa1f7a4FD8 (Chainlink Devrel
       * Node)
       * Job ID: d5270d1c311941d0b08bead21fea7747
       * Fee: 0.1 LINK
       */
      constructor() {
          setPublicChainlinkToken();
          oracle = 0x521E899DD6c47ea8DcA360Fc46cA41e5A904d28b;
          jobIds["Timeline"] = "e5ce0aaf603d4aa2be36b62bb296ce96";
          jobIds["Lookup"] = "438fb98017e94736ba2329964c164a6c";
          fee = 0.1 * 10 ** 18; // (Varies by network and job)
      }

      /**
       * Create a Chainlink request to retrieve API response, find the target
       * data, then multiply by 1000000000000000000 (to remove decimal places from data).
       */
      function requestTwitterTimelineData(string memory _userId, string memory _tweetHash ) public returns (bytes32 requestId)
      {
          Chainlink.Request memory request = buildChainlinkRequest(jobIds["Timeline"], address(this), this.fulfill.selector);


          request.add("userid", _userId);
          request.add("tweetHash", _tweetHash);
          request.add("endpoint", "user_timeline.json");

          // Sends the request
          return sendChainlinkRequestTo(oracle, request, fee);
      }

      function requestTwitterLookupData(string memory _tweetId, string memory _tweetHash) public returns (bytes32 requestId)
      {
          Chainlink.Request memory request = buildChainlinkRequest(jobIds["Lookup"], address(this), this.fulfill.selector);


          request.add("tweetids", _tweetId);
          request.add("tweetHash", _tweetHash);
          request.add("endpoint", "lookup.json");

          // Sends the request
          return sendChainlinkRequestTo(oracle, request, fee);
      }

      /**
       * Receive the response in the form of uint256
       */
      function fulfill(bytes32 _requestId, bool _twitter) public recordChainlinkFulfillment(_requestId)
      {
          twitter = _twitter;
      }

      // function withdrawLink() external {} - Implement a withdraw function to avoid locking your LINK in the contract

}

contract TwitterEscrowV1 is Ownable, ReentrancyGuard {
    using Counters for Counters.Counter;
    Counters.Counter private _taskIds;

    enum Status{Pending, Open, Fulfilled, Closed, Canceled, Expired} // 0, 1, 2, 3, 4 Respectively

    struct Task {
        Status status;
        address sponsor;
        address promoter;
        string tweetContent; // Could have only content and hash it in contract
        bytes32 tweetHash; // OR could have only hash and have the content on a regular database
        uint256 taskReward; // How much it pays out to promoter if finished successfully
        address rewardToken; // Which token will it pay out
        uint256 taskFee;
    }

    mapping(uint256 => Task) public taskIdentifier; 
    Task[] public taskList;
    //mapping(address => uint256[]) public taskSponsors; // sponsor address mapped to array of taskIds
    //mapping(address => uint256[]) public taskPromoters; // promoter address mapped to array of taskIds
    address[] public allowedTokens;
    mapping (address => uint256) contractBalance;
    uint256 commissionFee = 0.01 ether; // Hardcoded for now, should use Chainlink Price feed in future

    constructor(address[] memory _allowedTokens) {
        allowedTokens = _allowedTokens;
        _taskIds.increment();
    }

    function createTask(address _promoter, string memory _tweetContent, uint256 _taskReward, address _token) external payable {
        // Takes in task specification and creates a task
        require(_taskReward > 0, "Task reward must be greater than 0"); // Reward can't be 0
        require(tokenIsAllowed(_token), "That token is not allowed."); // Token must be on the list of allowed tokens
        require(_promoter != msg.sender, "Promoter can't be the sender");
        uint256 _taskBalance = _taskReward + commissionFee;

        IERC20(_token).transferFrom(msg.sender, address(this), _taskBalance);
        bytes32 _tweetHash = keccak256(abi.encodePacked(_tweetContent));

        Task memory newTask = Task(
            Status.Pending,
            msg.sender,
            _promoter,
            _tweetContent,
            _tweetHash,
            _taskReward,
            _token,
            commissionFee
        );

        taskIdentifier[_taskIds.current()] = newTask; // Sets the taskId
        taskList.push(newTask);
        _taskIds.increment();
    }

    function fulfillTaskTimeline(uint256 _taskId, string memory _userid ) external returns(bool) {
        Task memory thisTask = taskIdentifier[_taskId];
        require(thisTask.promoter == msg.sender, "Only the promoter can fulfill a task");
        require(thisTask.status == Status.Open, "Only open tasks can be fulfilled");

        taskIdentifier[_taskId].status = Status.Fulfilled;
    }

    function fulfillTaskLookup(uint256 _taskId, string[] memory _tweetIds) external returns (bool) {
        Task memory thisTask = taskIdentifier[_taskId];
        require(thisTask.promoter == msg.sender, "Only the promoter can fulfill a task");
        require(thisTask.status == Status.Open, "Only open tasks can be fulfilled");


        taskIdentifier[_taskId].status = Status.Fulfilled;
    }

    /*
        This function is only used if the Task has been fulfilled.
        Currently the function doesn't delete tasks once they are completed, it just changes them to closed and 
        reduces their balance.

        Should consider if we want to delete finished tasks or somehow archive them? Might be useful to keep.
     */
    function withdrawReward(uint256 _taskId) external nonReentrant { 
        // Only the assigned promoter can withdraw
        Task memory thisTask = taskIdentifier[_taskId];
        require(msg.sender == thisTask.promoter, "Not the promoter!");
        // Promoter can only withdraw if they have completed the promotion
        require(thisTask.status == Status.Fulfilled, "The task was not completed!");

        // Fee goes into the contract overall balance
        contractBalance[thisTask.rewardToken] = contractBalance[thisTask.rewardToken] + thisTask.taskFee;
        thisTask.taskFee = 0;

        // Promoter can only withdraw the reward amount
        uint256 reward = thisTask.taskReward;
        thisTask.taskReward = 0;
        IERC20(thisTask.rewardToken).transfer(msg.sender, reward);

        // Task status is set to closed
        thisTask.status = Status.Closed;

        // Task in memory is transfered to storage
        taskIdentifier[_taskId] = thisTask;
    }

    function withdrawFunds(uint256 _taskId) external nonReentrant { // Used if job fails
        // Only Sponsors can call this
        Task memory thisTask = taskIdentifier[_taskId];
        require(thisTask.sponsor == msg.sender, "Only the task sponsor can withdraw funds");
        require(thisTask.status == Status.Canceled || thisTask.status == Status.Expired, "Funds cannot be withdrawn if the task is not canceled or expired");
        // They can only withdraw a certain amount

        uint256 refundableFunds = thisTask.taskReward + thisTask.taskFee;
        thisTask.taskReward = 0;
        thisTask.taskFee = 0;
        IERC20(thisTask.rewardToken).transfer(msg.sender, refundableFunds);
    }

    /*
        Cancel the task if it was not fulfilled until the deadline.
    */
    function cancelTask(uint256 _taskId) public{
        require(taskIdentifier[_taskId].status == Status.Pending, "Only pending tasks can be canceled");
        require(taskIdentifier[_taskId].sponsor == msg.sender, "Only the task sponsor can cancel the task");
        taskIdentifier[_taskId].status = Status.Canceled;
    }

    function getTaskStatus(uint256 _taskId) public view returns(Status) {
        return taskIdentifier[_taskId].status;
    }

    function getTask(uint256 _taskId) public view returns (Task memory) {
        return taskIdentifier[_taskId];
    }


    /*
        Check if a token is allowed to be used as payment.
    */
    function tokenIsAllowed(address _token) public view returns (bool) {
       for (
            uint256 allowedTokensIndex = 0;
            allowedTokensIndex < allowedTokens.length;
            allowedTokensIndex++
        ) {
            if (allowedTokens[allowedTokensIndex] == _token) {
                return true;
            }
        }
        return false;
    }

    /* 
        Gets all allowed tokens
    */
    function getAllowedTokens() public view returns (address[] memory){
        return allowedTokens;
    }

    /* 
        Gets all tasks. Currently it gets tasks no matter what their status is.
    */
    function getAllTasks() public view returns (Task[] memory) {
        return taskList;
    }

    /* 
        Gets all the tasks with the field status = Open.

        This function could be made flexible by passing the required status (Open, Closed, etc.) as a function
        argument, in which case the function would fetch any task with that status.
    */
    function getAllOpenTasks() public view returns (Task[] memory) {
        Task[] memory openTasks;
        uint256 openTaskIndex = 0;
        for (uint256 i = 0; i < taskList.length; i++) {
            if (taskList[i].status == Status.Open) {
                openTasks[openTaskIndex] = taskList[i];
                openTaskIndex += 1;
            }
        }

        return openTasks;
    }

    function getContractBalance(address _token) public view returns (uint256) {
        return contractBalance[_token];
    }

}