// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

import {DeployRaffle} from "../../script/DeployRaffle.s.sol";
import {Raffle} from "../../src/Raffle.sol";
import {Test, console} from "forge-std/Test.sol";
import {HelperConfig} from "../../script/HelperConfig.s.sol";
import {Vm} from "forge-std/Vm.sol";
import {VRFCoordinatorV2Mock} from "@chainlink/contracts/src/v0.8/mocks/VRFCoordinatorV2Mock.sol";

contract RaffleTest is Test {
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

    Raffle raffle;
    Config config;
    HelperConfig helperConfig;

    event EnteredRaffle(address indexed player);

    address public PLAYER = makeAddr("player");
    uint256 public constant STARTING_USER_BALANCE = 10 ether;

    uint256 constant ADDITIONAL_ENTRANTS = 5;
    uint256 constant STARTING_INDEX = 1;

    function setUp() external {
        DeployRaffle deployer = new DeployRaffle();
        (raffle, helperConfig) = deployer.run();

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

        vm.deal(PLAYER, STARTING_USER_BALANCE);
    }

    function testRaffleInitializeInOpenState() public view {
        assert(raffle.getRaffleState() == 0);
    }

    function testRaffleRevertsWhenYouDontPayEnough() public {
        vm.prank(PLAYER);
        vm.expectRevert(Raffle.Raffle__InsufficientEthSent.selector);
        raffle.enterRaffle{value: config.entranceFee - 1}();
    }

    function testRaffleRevertsWhenYouPayNothing() public {
        vm.prank(PLAYER);
        vm.expectRevert(Raffle.Raffle__InsufficientEthSent.selector);
        raffle.enterRaffle();
    }

    function testRaffleRecordsPlayerWhenEnter() public {
        vm.prank(PLAYER);
        raffle.enterRaffle{value: config.entranceFee}();

        address playerRecorded = raffle.getPlayer(0);
        assert(playerRecorded == PLAYER);
    }

    function testEmitsEventOnEntrance() public {
        vm.prank(PLAYER);
        vm.expectEmit(true, false, false, false, address(raffle));
        emit EnteredRaffle(PLAYER);

        raffle.enterRaffle{value: config.entranceFee}();
    }

    function testCantEnterRaffleWhenIsCalculating() public {
        vm.prank(PLAYER);
        raffle.enterRaffle{value: config.entranceFee}();
        vm.warp(block.timestamp + config.interval + 1);
        vm.roll(block.number + 1);

        raffle.performUpkeep("");
        vm.expectRevert(Raffle.Raffle__RaffleNotOpen.selector);

        vm.prank(PLAYER);
        raffle.enterRaffle{value: config.entranceFee}();
    }

    function testCheckUpkeepReturnsFalseIfNotBalance() public {
        vm.warp(block.timestamp + config.interval + 1);
        vm.roll(block.number);

        (bool upkeepNeeded, ) = raffle.checkUpkeep("");

        assert(!upkeepNeeded);
    }

    function testCheckUpkeepReturnsFalseIfRaffleIsNotOpened() public {
        vm.prank(PLAYER);
        raffle.enterRaffle{value: config.entranceFee}();
        vm.warp(block.timestamp + config.interval + 1);
        vm.roll(block.number + 1);
        raffle.performUpkeep("");

        (bool upkeepNeeded, ) = raffle.checkUpkeep("");

        assert(!upkeepNeeded);
    }

    function testCheckUpkeepReturnsFalseIfRaffleIfEnoughTimeHasntPassed()
        public
        view
    {
        (bool upkeepNeeded, ) = raffle.checkUpkeep("");

        assert(!upkeepNeeded);
    }

    function testCheckUpkeepReturnsTrueWhenParametersAreGood() public {
        vm.prank(PLAYER);
        vm.warp(block.timestamp + config.interval + 1);
        vm.roll(block.number + 1);
        raffle.enterRaffle{value: config.entranceFee}();

        (bool upkeepNeeded, ) = raffle.checkUpkeep("");

        assert(upkeepNeeded);
    }

    function testPerformUpkeepCanOnlyRunIfCheckUpkeepIsTrue() public {
        vm.prank(PLAYER);
        vm.warp(block.timestamp + config.interval + 1);
        vm.roll(block.number + 1);
        raffle.enterRaffle{value: config.entranceFee}();

        raffle.performUpkeep("");
    }

    function testPerformUpkeepRevertIfCheckUpKeepIsFalse() public {
        uint256 balance = 0;
        uint256 numPlayers = 0;
        uint256 raffleState = 0;

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
        raffle.enterRaffle{value: config.entranceFee}();
        vm.warp(block.timestamp + config.interval + 1);
        vm.roll(block.number + 1);
        _;
    }

    function testPerformUpkeepUpdatesRaffleStateAndEmitsRequestId()
        public
        raffleEnteredAndTimePassed
    {
        vm.recordLogs();
        raffle.performUpkeep("");
        Vm.Log[] memory entries = vm.getRecordedLogs();
        bytes32 requestId = entries[1].topics[1];
        uint256 rState = raffle.getRaffleState();

        assert(uint256(requestId) > 0);
        assert(rState == 1);
    }

    modifier skipFork() {
        if (block.chainid != 31337) {
            return;
        }
        _;
    }

    function testFulfillRandomWordsCanOnlyBeCalledAfterPerformUpkeep(
        uint256 randomRequestId
    ) public raffleEnteredAndTimePassed skipFork {
        vm.expectRevert("nonexistent request");
        VRFCoordinatorV2Mock(config.vrfCoordinator).fulfillRandomWords(
            randomRequestId,
            address(raffle)
        );
    }

    function testFulfillRandomWordsPicksAWinnerResetAndSendMoney()
        public
        raffleEnteredAndTimePassed
        skipFork
    {
        for (
            uint256 i = STARTING_INDEX;
            i < STARTING_INDEX + ADDITIONAL_ENTRANTS;
            i++
        ) {
            hoax(address(uint160(i)), STARTING_USER_BALANCE);
            raffle.enterRaffle{value: config.entranceFee}();
        }

        uint256 prize = config.entranceFee * (ADDITIONAL_ENTRANTS + 1);

        vm.recordLogs();
        raffle.performUpkeep("");
        Vm.Log[] memory entries = vm.getRecordedLogs();
        bytes32 requestId = entries[1].topics[1];
        uint256 previousTimeStamp = raffle.getLastTimeStamp();

        VRFCoordinatorV2Mock(config.vrfCoordinator).fulfillRandomWords(
            uint256(requestId),
            address(raffle)
        );

        assert(raffle.getRaffleState() == 0);
        assert(raffle.getRecentWinner() != address(0));
        assert(raffle.getNumberOfPlayers() == 0);
        assert(previousTimeStamp < raffle.getLastTimeStamp());
        assert(
            raffle.getRecentWinner().balance ==
                STARTING_USER_BALANCE + prize - config.entranceFee
        );
    }
}
