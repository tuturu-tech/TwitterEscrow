// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "hardhat/console.sol";

interface IAPIConsumerTwitter{
    function requestTwitterTimelineData(string memory _userId, string memory _tweetHash ) external returns (bytes32 requestId);
    function requestTwitterLookupData(string[] memory _tweetIds, string memory _tweetHash) external returns (bytes32 requestId);
    function getIsSuccessful() external view returns (bool);
}

contract TwitterEscrowV1 is Ownable, ReentrancyGuard {
    using Counters for Counters.Counter;
    Counters.Counter private _taskIds;

    enum Status{Pending, Open, Fulfilled, Closed, Canceled, Expired} // 0, 1, 2, 3, 4 Respectively

    struct Task {
        Status status;
        address sponsor;
        address promoter;
        //string tweetContent; // Could have only content and hash it in contract
        string tweetHash; // OR could have only hash and have the content on a regular database
        uint256 taskReward; // How much it pays out to promoter if finished successfully
        address rewardToken; // Which token will it pay out
        uint256 taskFee;
    }

    address private APIConsumerTwitterAddress;
    mapping(uint256 => Task) public taskIdentifier; 
    Task[] public taskList;
    //mapping(address => uint256[]) public taskSponsors; // sponsor address mapped to array of taskIds
    //mapping(address => uint256[]) public taskPromoters; // promoter address mapped to array of taskIds
    address[] public allowedTokens;
    mapping (address => uint256) contractBalance;
    uint256 commissionFee = 0.01 ether; // Hardcoded for now, should use Chainlink Price feed in future

    constructor(address[] memory _allowedTokens, address _APIConsumerTwitterAddress) {
        APIConsumerTwitterAddress = _APIConsumerTwitterAddress;
        allowedTokens = _allowedTokens;
        _taskIds.increment();
    }

    function createTask(address _promoter, string memory _tweetHash, uint256 _taskReward, address _token) external payable {
        // Takes in task specification and creates a task
        require(_taskReward > 0, "Task reward must be greater than 0"); // Reward can't be 0
        require(tokenIsAllowed(_token), "That token is not allowed."); // Token must be on the list of allowed tokens
        require(_promoter != msg.sender, "Promoter can't be the sender");
        uint256 _taskBalance = _taskReward + commissionFee;

        IERC20(_token).transferFrom(msg.sender, address(this), _taskBalance);
        //bytes32 _tweetHash = keccak256(abi.encodePacked(_tweetContent));

        Task memory newTask = Task(
            Status.Open,
            msg.sender,
            _promoter,
            //_tweetContent,
            _tweetHash,
            _taskReward,
            _token,
            commissionFee
        );

        taskIdentifier[_taskIds.current()] = newTask; // Sets the taskId
        taskList.push(newTask);
        _taskIds.increment();
    }

    /* 
        !!REMOVE FROM PRODUCTION!!
        This is a mock function for local testing purposes
    */
    function fulfillTask(uint256 _taskId) external {
        taskIdentifier[_taskId].status = Status.Fulfilled;
    }

    function fulfillTaskTimeline(uint256 _taskId, string memory _userid ) external returns(bool) {
        Task memory thisTask = taskIdentifier[_taskId];
        require(thisTask.promoter == msg.sender, "Only the promoter can fulfill a task");
        require(thisTask.status == Status.Open, "Only open tasks can be fulfilled");
        IAPIConsumerTwitter(APIConsumerTwitterAddress).requestTwitterTimelineData(_userid, thisTask.tweetHash);
        bool isSuccessful = IAPIConsumerTwitter(APIConsumerTwitterAddress).getIsSuccessful();
        if (isSuccessful) {
            taskIdentifier[_taskId].status = Status.Fulfilled;
            return true;
        } else {
            return false;
        }
    }

    function fulfillTaskLookup(uint256 _taskId, string[] memory _tweetIds) external returns (bool) {
        Task memory thisTask = taskIdentifier[_taskId];
        require(thisTask.promoter == msg.sender, "Only the promoter can fulfill a task");
        require(thisTask.status == Status.Open, "Only open tasks can be fulfilled");
        
        IAPIConsumerTwitter(APIConsumerTwitterAddress).requestTwitterLookupData(_tweetIds, thisTask.tweetHash);
        bool isSuccessful = IAPIConsumerTwitter(APIConsumerTwitterAddress).getIsSuccessful();
        if (isSuccessful) {
            taskIdentifier[_taskId].status = Status.Fulfilled;
        } else {
            revert();
        }

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
                openTaskIndex = openTaskIndex + 1;
            }
        }

        return openTasks;
    }

    function getContractBalance(address _token) public view returns (uint256) {
        return contractBalance[_token];
    }

    function setAPIConsumerTwitterAddress(address _APIConsumerTwitterAddress) external returns(address) {
        APIConsumerTwitterAddress = _APIConsumerTwitterAddress;
        return APIConsumerTwitterAddress;
    }

    function getAPIConsumerTwitterAddress() external view returns (address) {
        return APIConsumerTwitterAddress;
    }

}