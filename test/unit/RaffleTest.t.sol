// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

import {DeployRaffle} from "../../script/DeployRaffle.s.sol";
import {Raffle} from "../../src/Raffle.sol";
import {Test, console} from "forge-std/Test.sol";
import {HelperConfig} from "../../script/HelperConfig.s.sol";
import {Vm} from "forge-std/Vm.sol";

contract RaffleTest is Test {
    Raffle raffle;
    HelperConfig helperConfig;

    uint256 entranceFee;
    uint256 interval;
    address vrfCoordinator;
    bytes32 gasLane;
    uint64 subscriptionId;
    uint32 callbackGasLimit;
    address link;

    /* Events */
    event EnteredRaffle(address indexed player);

    address public PLAYER = makeAddr("player");
    uint256 public constant STARTING_USER_BALANCE = 10 ether;

    function setUp() external {
        DeployRaffle deployer = new DeployRaffle();
        (raffle, helperConfig) = deployer.run();

        (
            entranceFee,
            interval,
            vrfCoordinator,
            gasLane,
            subscriptionId,
            callbackGasLimit,
            link
        ) = helperConfig.activeNetworkConfig();

        vm.deal(PLAYER, STARTING_USER_BALANCE);
    }

    ////////////////////////////
    /// Raffle //////////////////
    ////////////////////////////
    function testRaffleInitializeInOpenState() public view {
        assert(raffle.getRaffleState() == Raffle.RaffleState.OPEN);
    }

    function testRaffleRevertsWhenYouDontPayEnough() public {
        console.log(entranceFee);
        vm.prank(PLAYER);
        vm.expectRevert(Raffle.Raffle__InsufficientEthSent.selector);
        raffle.enterRaffle{value: entranceFee - 1}();
    }

    function testRaffleRevertsWhenYouPayNothing() public {
        console.log(entranceFee);
        vm.prank(PLAYER);
        vm.expectRevert(Raffle.Raffle__InsufficientEthSent.selector);
        raffle.enterRaffle();
    }

    function testRaffleRecordsPlayerWhenEnter() public {
        vm.prank(PLAYER);
        raffle.enterRaffle{value: entranceFee}();

        address playerRecorded = raffle.getPlayer(0);
        assert(playerRecorded == PLAYER);
    }

    function testEmitsEventOnEntrance() public {
        vm.prank(PLAYER);
        vm.expectEmit(true, false, false, false, address(raffle));
        emit EnteredRaffle(PLAYER);

        raffle.enterRaffle{value: entranceFee}();
    }

    function testCantEnterRaffleWhenIsCalculating() public {
        vm.prank(PLAYER);
        raffle.enterRaffle{value: entranceFee}();
        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1);

        raffle.performUpkeep("");
        vm.expectRevert(Raffle.Raffle__RaffleNotOpen.selector);

        vm.prank(PLAYER);
        raffle.enterRaffle{value: entranceFee}();
    }

    //////////////////////
    /////////checkUpkeep///////
    ///////////////////////////

    function testCheckUpkeepReturnsFalseIfNotBalance() public {
        // Arrange
        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number);

        // Act
        (bool upkeepNeeded, ) = raffle.checkUpkeep("");

        // Assert
        assert(!upkeepNeeded);
    }

    function testCheckUpkeepReturnsFalseIfRaffleIsNotOpened() public {
        // Arrange
        vm.prank(PLAYER);
        raffle.enterRaffle{value: entranceFee}();
        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1);
        raffle.performUpkeep("");

        // Act
        (bool upkeepNeeded, ) = raffle.checkUpkeep("");

        // Assert
        assert(!upkeepNeeded);
    }

    function testCheckUpkeepReturnsFalseIfRaffleIfEnoughTimeHasntPassed()
        public
        view
    {
        // Act
        (bool upkeeNeeded, ) = raffle.checkUpkeep("");

        // Assert
        assert(!upkeeNeeded);
    }

    function testCheckUpkeepReturnsTrueWhenParametersAreGood() public {
        // Arrange
        vm.prank(PLAYER);
        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1);
        raffle.enterRaffle{value: entranceFee}();

        // Act
        (bool upkeeNeeded, ) = raffle.checkUpkeep("");

        // Assert
        assert(upkeeNeeded);
    }

    ///////////////////
    // PerformUpkeep //
    ///////////////////
    function testPerformUpkeepCanOnlyRunIfCheckUpkeepIsTrue() public {
        // Arrange
        vm.prank(PLAYER);
        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1);
        raffle.enterRaffle{value: entranceFee}();

        // Act / Assert
        raffle.performUpkeep("");
    }

    function testPerformUpkeepRevertIfCheckUpKeepIsFalse() public {
        // Arrange
        uint256 balance = 0;
        uint256 numPlayers = 0;
        Raffle.RaffleState raffleState = Raffle.RaffleState.OPEN;

        // Act / Assert
        vm.expectRevert(
            abi.encodeWithSelector(
                Raffle.Raffle__UpkeepNotNeed.selector,
                balance,
                numPlayers,
                raffleState
            )
        );

        raffle.performUpkeep("");
    }

    modifier raffleEnteredAndTimePassed() {
        vm.prank(PLAYER);
        raffle.enterRaffle{value: entranceFee}();
        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1);
        _;
    }

    function testPerformUpkeepUpdatesRaffleStateAndEmitsRequestId()
        public
        raffleEnteredAndTimePassed
    {
        // Act
        vm.recordLogs();
        raffle.performUpkeep(""); // emit requestId
        Vm.Log[] memory entries = vm.getRecordedLogs();
        bytes32 requestId = entries[1].topics[1];
        Raffle.RaffleState rState = raffle.getRaffleState();

        assert(uint256(requestId) > 0);
        assert(rState == Raffle.RaffleState.CALCULATING);
    }
}
