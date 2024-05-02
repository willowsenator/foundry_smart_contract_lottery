// SPX-License-Identifier: MIT
pragma solidity 0.8.18;

/**
 * @title A sample Raffle contract
 * @author Omar Fernando Moreno Benito
 * @notice This contract is for creating a sample Raffle
 * @dev Implements Chainlink VRFv2
 */
contract Raffle {
    /**Errors */
    error Raffle__InsufficientEthSent();

    /** Immutable Variables */
    uint256 private immutable i_entranceFee;
    uint256 private immutable i_interval;
    address private immutable i_vrfCoordinator;

    /** Store variables */
    address payable[] private s_players;
    uint256 private s_lastTimeStamp;

    /**Events */
    event EnteredRaffle(address indexed player);

    constructor(uint256 entranceFee, uint256 interval, address vrfCoordinator) {
        i_entranceFee = entranceFee;
        i_interval = interval;
        i_vrfCoordinator = vrfCoordinator;

        s_lastTimeStamp = block.timestamp;
    }

    function enterRaffle() external payable {
        if (msg.value < i_entranceFee) {
            revert Raffle__InsufficientEthSent();
        }

        s_players.push(payable(msg.sender));
        emit EnteredRaffle(msg.sender);
    }

    function pickWinner() public {
        if ((block.timestamp - s_lastTimeStamp) < i_interval) {
            revert();
        }

        uint256 requestID = i_vrfCoordinator.requestRandomWords(
            VRFV2PlusClient.RandomWordsRequest({
                keyHash: keyHash,
                subId: subId,
                requestConfirmations: requestConfirmations,
                callbackGasLimit: callbackGasLimit,
                numWords: numWords,
                extraArgs: VRFV2PlusClient._argsToBytes(
                    VRFV2PlusClient.ExtraArgsV1({nativePayment: true})
                )
            })
        );
    }

    /** Getter Function*/
    function getEntranceFee() external view returns (uint256) {
        return i_entranceFee;
    }
}
