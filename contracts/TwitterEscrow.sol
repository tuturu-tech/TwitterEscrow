// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

contract TwitterEscrow {
    // Define job structure
    // Define 

    struct Job {
        address sponsor;
        address promoter;
        bytes32 tweetHash;
    }


    mapping(address => Job) jobCreators;
    mapping(address => Job[]) jobPromoters;

    function createJob() public {
        // Takes in job specification and creates a job
    }

    function withdrawPayment() public {
        // Only promoters can call this
        // They can only withdraw a certain amount
        // They can only withdraw if they have completed the promotion
        // They can only withdraw if contract is still active
        // They can only withdraw once
    }
}