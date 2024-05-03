// SPX-License-Identifier: MIT
pragma solidity 0.8.18;

import {VRFCoordinatorV2Interface} from "@chainlink/contracts/src/v0.8/interfaces/VRFCoordinatorV2Interface.sol";
import {VRFConsumerBaseV2} from "@chainlink/contracts/src/v0.8/VRFConsumerBaseV2.sol";

/**
 * @title A sample Raffle contract
 * @author Omar Fernando Moreno Benito
 * @notice This contract is for creating a sample Raffle
 * @dev Implements Chainlink VRFv2
 */
contract Raffle is VRFConsumerBaseV2 {
    /**Errors */
    error Raffle__InsufficientEthSent();
    error Raffle__TransferFailed();
    error Raffle__NotWaitEnoughTimeToPickWinner();

    /**State Variables */
    uint16 private constant REQUEST_CONFIRMATIONS = 3;
    uint32 private constant NUM_WORDS = 1;

    /** Immutable Variables */
    uint256 private immutable i_entranceFee;
    uint256 private immutable i_interval;
    VRFCoordinatorV2Interface private immutable i_vrfCoordinator;
    bytes32 private immutable i_gasLane;
    uint64 private immutable i_subscriptionId;
    uint32 private immutable i_callbackGasLimit;

    /** Store variables */
    address payable[] private s_players;
    address private s_recentWinner;
    uint256 private s_lastTimeStamp;

    /**Events */
    event EnteredRaffle(address indexed player);

    constructor(
        uint256 entranceFee,
        uint256 interval,
        address vrfCoordinator,
        bytes32 gasLane,
        uint64 subscriptionId,
        uint32 callbackGasLimit
    ) VRFConsumerBaseV2(vrfCoordinator) {
        i_entranceFee = entranceFee;
        i_interval = interval;
        i_vrfCoordinator = VRFCoordinatorV2Interface(vrfCoordinator);
        i_gasLane = gasLane;
        i_subscriptionId = subscriptionId;
        i_callbackGasLimit = callbackGasLimit;

        s_lastTimeStamp = block.timestamp;
    }

    function enterRaffle() external payable {
        if (msg.value < i_entranceFee) {
            revert Raffle__InsufficientEthSent();
        }

        s_players.push(payable(msg.sender));
        // 1. Make migration easier
        // 2. Make front end "indexing" easier
        emit EnteredRaffle(msg.sender);
    }

    // 1. Get a random number
    // 2. Use the random number to pick a player
    // 3. Automatically called
    function pickWinner() public {
        // check to see if enough time has passed
        if ((block.timestamp - s_lastTimeStamp) < i_interval) {
            revert Raffle__NotWaitEnoughTimeToPickWinner();
        }

        // 1. Request RNG from Chainlink
        // 2. Get the random number
        uint256 requestId = i_vrfCoordinator.requestRandomWords(
            i_gasLane,
            i_subscriptionId,
            REQUEST_CONFIRMATIONS,
            i_callbackGasLimit,
            NUM_WORDS
        );
    }

    function fulfillRandomWords(
        uint256 _requestId,
        uint256[] memory _randomWords
    ) internal override {
        // 1. Use the random number to pick a winner
        uint256 index = _randomWords[0] % s_players.length;
        address payable winner = s_players[index];
        s_recentWinner = winner;

        // 2. Transfer the money to the winner
        (bool success, ) = winner.call{value: address(this).balance}("");
        if (!success) {
            revert Raffle__TransferFailed();
        }

        // 3. Reset the players array
        s_players = new address payable[](0);
        s_lastTimeStamp = block.timestamp;
    }

    /** Getter Function*/
    function getEntranceFee() external view returns (uint256) {
        return i_entranceFee;
    }
}
