// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "hardhat/console.sol";

contract TwitterEscrowV1 is Ownable, ReentrancyGuard {

    using Counters for Counters.Counter;
    Counters.Counter private _taskIds;

    enum Status{Pending, Open, Fulfilled, Closed, Canceled} // 0, 1, 2, 3, 4 Respectively

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
    mapping(address => uint256[]) public taskSponsors; // sponsor address mapped to array of jobIds
    mapping(address => uint256[]) public taskPromoters; // promoter address mapped to array of jobIds
    address[] public allowedTokens;
    uint256 commissionBalance;
    uint256 commissionFee = 0.01 ether; // Hardcoded for now, should use Chainlink Price feed in future

    constructor(address[] memory _allowedTokens) {
        allowedTokens = _allowedTokens;
        _taskIds.increment();
    }

    function createTask(address _promoter, string memory _tweetContent, uint256 _taskReward, address _token) payable public {
        // Takes in task specification and creates a task
        require(_taskReward > 0); // Reward can't be 0
        require(tokenIsAllowed(_token)); // Token must be on the list of allowed tokens
        uint256 _taskBalance = _taskReward + commissionFee;
        bool test = IERC20(_token).approve(address(this), _taskBalance); // Doesn't work
        IERC20(_token).transferFrom(msg.sender, address(this), _taskBalance);
        bytes32 _tweetHash = keccak256(abi.encodePacked(_tweetContent));
        Status _status = Status.Pending;

        Task memory newTask = Task(
            _status,
            msg.sender,
            _promoter,
            _tweetContent,
            _tweetHash,
            _taskReward,
            _token,
            commissionFee
        );
        taskIdentifier[_taskIds.current()] = newTask; // Sets the taskId
        _taskIds.increment();
        taskList.push(newTask);
    }

    function fulfillTask(uint256 _taskId) public {
        // EA stuff
    }

    // Used if job was finished successfully, nonReentrant ensures it can only be run once
    function withdrawReward(uint256 _taskId) external nonReentrant { 
        // Only the assigned promoter can withdraw
        Task memory thisTask = taskIdentifier[_taskId];
        require(msg.sender == thisTask.promoter, "Not the promoter!");
        // Promoter can only withdraw if they have completed the promotion
        require(thisTask.status == Status.Fulfilled, "The task was not completed!");

        // Fee goes into the contract overall balance
        commissionBalance = commissionBalance + thisTask.taskFee;
        thisTask.taskFee = 0;
        // Promoter can only withdraw the reward amount
        uint256 reward = thisTask.taskReward;
        thisTask.taskReward = 0;
        IERC20(thisTask.rewardToken).transfer(msg.sender, reward);
        // Task status is set to closed
        thisTask.status = Status.Closed;
        // Task is memory is transfered to storage
        taskIdentifier[_taskId] = thisTask;
    }

    function withdrawFunds(uint256 _taskId) public { // Used if job fails
        // Only Sponsors can call this
        // They can only withdraw a certain amount
        // They can only withdraw if the Job end date has passed and the promotion failed
        // They can only withdraw if the Job is still active
    }

    function cancelTask(uint256 _taskId) public{
        // Cancel agreement if the job was not fulfilled and the grace period is still on

    }

    function getTaskStatus(uint256 _taskId) public view returns(Status) {
        return taskIdentifier[_taskId].status;
    }

    function getTask(uint256 _taskId) public view returns (Task memory) {
        return taskIdentifier[_taskId];
    }

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

    function getAllowedTokens() public view returns (address[] memory){
        return allowedTokens;
    }

    function getAllTasks() public view returns (Task[] memory) {
        return taskList;
    }

}