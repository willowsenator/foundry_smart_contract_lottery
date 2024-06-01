// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import {Script, console} from "forge-std/Script.sol";
import {HelperConfig} from "./HelperConfig.s.sol";
import {VRFCoordinatorV2Mock} from "@chainlink/contracts/src/v0.8/mocks/VRFCoordinatorV2Mock.sol";
import {LinkToken} from "../test/mocks/LinkToken.sol";
import {DevOpsTools} from "lib/foundry-devops/src/DevOpsTools.sol";

struct Config {
    address vrfCoordinator;
    uint64 subscriptionId;
    address link;
    uint256 deployerKey;
}

contract CreateSubscription is Script {
    Config config;

    function createSubscriptionUsingConfig() public returns (uint64) {
        HelperConfig helperConfig = new HelperConfig();
        (, , config.vrfCoordinator, , , , , config.deployerKey) = helperConfig
            .activeNetworkConfig();
        return createSubscription(config.vrfCoordinator, config.deployerKey);
    }

    function createSubscription(
        address vrfCoordinator,
        uint256 deployerKey
    ) public returns (uint64) {
        console.log("Creating subscription on ChainId: %d", block.chainid);
        vm.startBroadcast(deployerKey);
        uint64 subId = VRFCoordinatorV2Mock(vrfCoordinator)
            .createSubscription();
        vm.stopBroadcast();
        console.log("Your subId: %d", subId);
        console.log(
            "Please update your subscriptionId in HelperConfig.s.sol file."
        );
        return subId;
    }

    function run() external returns (uint64) {
        return createSubscriptionUsingConfig();
    }
}

contract FundSubscription is Script {
    Config config;
    uint96 public constant FUND_AMOUNT = 3 ether;

    function fundSubscriptionUsingConfig() public {
        HelperConfig helperConfig = new HelperConfig();
        (
            ,
            ,
            config.vrfCoordinator,
            ,
            config.subscriptionId,
            ,
            config.link,
            config.deployerKey
        ) = helperConfig.activeNetworkConfig();
        fundSubscription(
            config.vrfCoordinator,
            config.subscriptionId,
            config.link,
            config.deployerKey
        );
    }

    function fundSubscription(
        address vrfCoordinator,
        uint64 subscriptionId,
        address link,
        uint256 deployerKey
    ) public {
        console.log("Funding subscription: ", subscriptionId);
        console.log("VRF Coordinator: ", vrfCoordinator);
        console.log("On ChainId:", block.chainid);

        vm.startBroadcast(deployerKey);
        if (block.chainid == 31337) {
            VRFCoordinatorV2Mock(vrfCoordinator).fundSubscription(
                subscriptionId,
                FUND_AMOUNT
            );
        } else {
            LinkToken(link).transferAndCall(
                vrfCoordinator,
                FUND_AMOUNT,
                abi.encode(subscriptionId)
            );
        }
        vm.stopBroadcast();
    }

    function run() external {
        fundSubscriptionUsingConfig();
    }
}

contract AddConsumer is Script {
    Config config;

    function addConsumer(
        address raffle,
        address vrfCoordinator,
        uint64 subscriptionId,
        uint256 deployerKey
    ) public {
        console.log("Adding consumer to raffle: ", raffle);
        console.log("VRF Coordinator: ", vrfCoordinator);
        console.log("SubscriptionId: ", subscriptionId);

        vm.startBroadcast(deployerKey);
        VRFCoordinatorV2Mock(vrfCoordinator).addConsumer(
            subscriptionId,
            raffle
        );
        vm.stopBroadcast();
    }

    function addConsumerUsingConfig(address raffle) public {
        HelperConfig helperConfig = new HelperConfig();
        (
            ,
            ,
            config.vrfCoordinator,
            ,
            config.subscriptionId,
            ,
            ,
            config.deployerKey
        ) = helperConfig.activeNetworkConfig();
        addConsumer(
            raffle,
            config.vrfCoordinator,
            config.subscriptionId,
            config.deployerKey
        );
    }

    function run() external {
        address raffle = DevOpsTools.get_most_recent_deployment(
            "Raffle",
            block.chainid
        );
        addConsumerUsingConfig(raffle);
    }
}
