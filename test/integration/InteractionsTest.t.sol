// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

import {Test} from "forge-std/Test.sol";
import {DeployRaffle} from "../../script/DeployRaffle.s.sol";
import {Raffle} from "../../src/Raffle.sol";
import {HelperConfig} from "../../script/HelperConfig.s.sol";
import {console} from "forge-std/console.sol";

contract InteractionsTest is Test {
    struct Config {
        uint256 entranceFee;
        uint256 interval;
        address vrfCoordinator;
        bytes32 gasLane;
        uint64 subscriptionId;
        uint32 callbackGasLimit;
        address link;
        uint256 deployerKey;
    }

    Config config;

    function testDeployRaffle() public {
        DeployRaffle deployer = new DeployRaffle();
        (Raffle raffle, HelperConfig helperConfig) = deployer.run();

        (
            config.entranceFee,
            config.interval,
            config.vrfCoordinator,
            config.gasLane,
            config.subscriptionId,
            config.callbackGasLimit,
            config.link,
            config.deployerKey
        ) = helperConfig.activeNetworkConfig();

        assert(address(raffle) != address(0));

        // Check the raffle values
        assertEq(raffle.getRaffleState(), 0);
        assertEq(raffle.getEntranceFee(), 0.1 ether);
        assertEq(raffle.getNumberOfPlayers(), 0);
        assertEq(raffle.getRecentWinner(), address(0));
        assert(raffle.getSubscriptionId() != 0);

        // Check the config values
        assertEq(config.entranceFee, 0.1 ether);
        assertEq(config.interval, 30);
        assert(config.vrfCoordinator != address(0));
        assertEq(config.callbackGasLimit, 500000);
        assert(config.link != address(0));
        assert(config.deployerKey != 0);
    }
}
