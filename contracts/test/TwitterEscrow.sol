/*
// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

contract TwitterEscrow {

    enum Status{Pending, Open, Fulfilled, Closed, Canceled} // 0, 1, 2, 3 Respectivelly

    struct Job {
        // Defines basic job structure
        // Job name, description, etc. can be kept off-chain on a regular database
        Status status;
        uint256 jobId;
        address sponsor;

        mapping(uint256 => Task) tasks; // Maps task Ids to Tasks
    }

    mapping (uint256 => Task[]) jobs; 

    struct Task {
        Status status;

        address promoter;
        string tweetContent; // Could have only content and hash it in contract
        bytes32 tweetHash; // OR could have only hash and have the content on a regular database
        uint256 taskReward; // How much it pays out to promoter if finished successfully
    }
    //mapping(uint256 => Job[]) public allJobs;
    mapping(address => uint256[]) public jobCreators; // sponsor address mapped to array of jobIds
    mapping(address => uint256[]) public jobPromoters; // promoter address mapped to array of jobIds

    function createJob() public {
        // Takes in job specification and creates a job
    }

    function withdrawPayment(uint256 _jobId) public { // Used if job was finished successfully
        // Only promoters can call this
        // They can only withdraw a certain amount
        // They can only withdraw if they have completed the promotion
        // They can only withdraw if Job is still active
        // They can only withdraw once
    }

    function withdrawFunds(uint256 _jobId) public { // Used if job fails
        // Only Sponsors can call this
        // They can only withdraw a certain amount
        // They can only withdraw if the Job end date has passed and the promotion failed
        // They can only withdraw if the Job is still active
    }

    function cancelAgreement(uint256 _jobId) public{
        // Cancel agreement if the job was not fulfilled and the grace period is still on
    }
    
    function getJobStatus(uint256 _jobId) public view returns(Status) {
        return allJobs[_jobId].status;
    }

    function getJobDetails(uint256 _jobId) public view returns (Job memory) {
        return allJobs[_jobId];
    }
    
    function getTaskStatus(uint256 _jobId, uint256 _taskId) public view returns(Status) {
        Job memory fetchedJob = allJobs[_jobId];
        Task memory fetchedTask = fetchedJob.tasks[_taskId];
        return fetchedTask.status;
    }

    function getTaskDetails(uint256 _jobId, uint256 _taskId) public view returns (Task memory) {

    }

}
*/