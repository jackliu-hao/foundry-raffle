// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.18;

import {Test , console} from "forge-std/Test.sol";
import {DeployRaffle} from "../../script/DeployRaffle.s.sol";
import{Raffle} from "../../src/Raffle.sol";
import {HelpConfig} from "../../script/HelperConfig.s.sol";
import {VRFCoordinatorV2Mock} from "@chainlink/contracts/src/v0.8/mocks/VRFCoordinatorV2Mock.sol";

contract RaffleTest is Test {

    /** 事件 */
    event EnterRaffle(address indexed player);

    Raffle raffle ;
    // 创建用户 
    address public PLAYER = makeAddr("player");

    //用户的余额
    uint256 public constant PLAYER_BALANCE = 10 ether;

    //HelpConfig 的一些配置
    address public  vrfCoordinator;
    uint256 public  entranceFee;
    uint256 public  interval;
    bytes32 public  gasLane;
    uint64  public subscriptionId;
    uint32  public callbackGasLimit;
    address public  link;

     //先执行setUp
    function setUp() external {
        
        DeployRaffle deployedRaffle = new DeployRaffle();
        HelpConfig helpConfig ;
        (raffle,helpConfig) = deployedRaffle.run();

        (
             entranceFee  , //入场券的价格
             interval ,  //轮询的时间
             vrfCoordinator , // VRF Coordinator
             gasLane ,  // gas限制
             subscriptionId , //订阅的id
             callbackGasLimit,  // 回调的gas限制
             link ,
        ) = helpConfig.activateNetWorkConfig();

        // vm.deal(PLAYER,PLAYER_BALANCE);
    }

    function testRaffleInitalRaffleState() public view {
        assert(raffle.getRaffleState() == Raffle.RaffleState.OPEN);
    }

    function testRaffleRevertWhenNotEnoughEth() public {
        //指定用户操作 
        vm.prank(PLAYER);
        vm.expectRevert(Raffle.Raffle__NotEnoughETHSend.selector);
        raffle.enterRaffle();
    }

    function testRaffleEnoughETH() public {
        // vm.prank(PLAYER); 
        //使用startPrank 可以指定，在此中间的所有交易都是同一个人
        vm.startPrank(PLAYER);
        console.log(PLAYER);
        //给新用户转一些钱
        vm.deal(PLAYER,PLAYER_BALANCE);
        console.log(raffle.getEntranceFee());
        raffle.enterRaffle{value: entranceFee}();
        assertEq(raffle.getPlayer(0) , PLAYER);
        vm.stopPrank();
    }

    function testEmitsEventOnEntrance() public {

        vm.prank(PLAYER);
        vm.deal(PLAYER,PLAYER_BALANCE);
        vm.expectEmit(true,false,false,false,address(raffle));
        emit EnterRaffle(PLAYER);
        raffle.enterRaffle{value: entranceFee}();
    }

    modifier  skipFork  {
        if (block.chainid != 31337){
            return ;
        }
        _;
    }
    function testCantEnterWhenRaffleIsCalculating() public  skipFork{
         vm.startPrank(PLAYER);
         vm.deal(PLAYER,PLAYER_BALANCE);
         raffle.enterRaffle{value: entranceFee}();
         //设置blockTime
         vm.warp(block.timestamp + interval + 1);
         // 将block+1
         vm.roll(block.number + 1);
         raffle.performUpkeep("");
         //此时应该不能继续参与
         vm.expectRevert(Raffle.Raffle_NotOpen.selector);
         raffle.enterRaffle{value: entranceFee}();
         vm.stopPrank();
    }

    function testCheckUpKeepReturnsFalseIfhasNoBalance() public skipFork{
        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1);
        (bool upkeepNeeded,) = raffle.checkUpkeep("");
        assertEq(upkeepNeeded,false);
    }

    function testCheckUpKeepReturnsFalseIfRaffleNotOpen() public skipFork{
        vm.prank(PLAYER);
        vm.deal(PLAYER,PLAYER_BALANCE);
        raffle.enterRaffle{value: entranceFee}();
        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1);
        raffle.performUpkeep("");
        (bool upkeepNeeded,) = raffle.checkUpkeep("");
        assertEq(upkeepNeeded,false);
    }
    function testPerformeWhenCheckUpKeepReturnsFalse() public  skipFork{
        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1);
        //期待抛出异常
        vm.expectRevert(
            abi.encodeWithSelector(Raffle.Raffle_UpkeepNotNeeded.selector, 
                                                address(raffle).balance,
                                                 raffle.getPlayerLength(),
                                                 raffle.getRaffleState()
                                                )
                        ); 
        raffle.performUpkeep("");
    }

    function testPerformUpkeepCanOnlyRunIfCheckUpkeepIsTrue() public  skipFork{
        vm.prank(PLAYER);
        vm.deal(PLAYER,PLAYER_BALANCE);
        raffle.enterRaffle{value: entranceFee}();
        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1);
        //act
        raffle.performUpkeep("");    
    }

    /**
     * 用来测试 获取到合约中释放的事件
     */
    function testPerformUpKeepUpdataRaffleStateAndEmitRequestId() public  skipFork{
        vm.prank(PLAYER);
        vm.deal(PLAYER,PLAYER_BALANCE);
        raffle.enterRaffle{value: entranceFee}();
        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1);
        // vm.expectEmit(true,false,false,false,address(raffle));
        // emit RequestRandomness()
        // vm.recordLogs();
        // raffle.performUpkeep(""); // emit requestId
        // Vm.Log[] memory entries = vm.getRecordedLogs();
        // bytes32 requestId = entries[1].topics[1];

        // console.log(requestId);
   }

    // function testFulfillRandomWordsCanOnlyBeCalledAfterPerformUpkeep(){
    //     vm.prank(PLAYER);
    //     vm.deal(PLAYER,PLAYER_BALANCE);
    //     raffle.enterRaffle{value: entranceFee}();
    //     vm.warp(block.timestamp + interval + 1);
    //     vm.roll(block.number + 1);

    //     //Act
    //     vm.expectRevert("nonexistent request");
    //     raffle.performUpkeep("");
    //     uint256 requestId = raffle.getRequestId();
    //     vm.expectRevert(abi.encodeWithSelector())
    // }
    
    function testFullfillRandomWordsPicksAWinnerResetsAndSendsMoeny() public skipFork{
       // arrange
       uint256 additionalEntrants = 5;
       uint256 startingIndex = 1;
       // 参与抽奖
       for(uint256 i = startingIndex; i < startingIndex + additionalEntrants; i++){
            address player = address(uint160(i));
            vm.prank(player);
            vm.deal(player, PLAYER_BALANCE);
            raffle.enterRaffle{value:entranceFee}();
       }
        // vm.recordLogs();
        // raffle.performUpkeep(""); // emit requestId
        // Vm.Log[] memory entries = vm.getRecordedLogs(); //Identifier not found or not unique.
        // bytes32 requestId = entries[1].topics[1];
        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1);
        
        raffle.performUpkeep("");

       // 模拟获取随机数，这里本地并没有VRF ， 选取获胜者
       VRFCoordinatorV2Mock(vrfCoordinator).fulfillRandomWords(
            uint256( raffle.getRequestId()),
            address(raffle)
       );

       console.log("raffle balance: %s" , address(raffle).balance);

       //获取最近选取的获胜者
       console.log(raffle.getWinnerIndex() );
       address[] memory  recentWinner =  raffle.getWinnerHistory();
       console.log("windder is : %s" , recentWinner[recentWinner.length - 1]);
       assert(recentWinner[recentWinner.length - 1] != address(0));
       assert(raffle.getPlayerLength() == 0);
    }
   
}