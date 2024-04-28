// SPX-License-Identifier: MIT
pragma solidity 0.8.18;

/**
 * @title A sample Raffle contract
 * @author Omar Fernando Moreno Benito
 * @notice This contract is for creating a sample Raffle
 * @dev Implements Chainlink VRFv2
 */
contract Raffle {
    error Raffle__InsufficientEthSent();
    uint256 private immutable i_entranceFee;
    address payable[] private s_players;

    /**Events */
    event EnteredRaffle(address indexed player);

    constructor(uint256 entranceFee){
        i_entranceFee = entranceFee;
    }

    function enterRaffle() external payable {
        if(msg.value < i_entranceFee){
            revert Raffle__InsufficientEthSent();
        }

        s_players.push(payable(msg.sender));
        emit EnteredRaffle(msg.sender);
    }

    function pickWinner() public {}

    /** Getter Function*/
    function getEntranceFee() external view returns(uint256){
        return i_entranceFee;
    }
}