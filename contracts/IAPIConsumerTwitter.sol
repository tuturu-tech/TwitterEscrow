// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

interface IAPIConsumerTwitter{
    function requestTwitterTimelineData(string memory _userId, string memory _tweetHash ) external returns (bytes32 requestId);
    function requestTwitterLookupData(string[] memory _tweetIds, string memory _tweetHash) external returns (bytes32 requestId);
    function getIsSuccessful() external view returns (bool);
}