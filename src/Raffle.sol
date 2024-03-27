
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import {VRFCoordinatorV2Interface} from "@chainlink/contracts/src/v0.8/interfaces/VRFCoordinatorV2Interface.sol";
import {VRFConsumerBaseV2} from "@chainlink/contracts/src/v0.8/VRFConsumerBaseV2.sol"; 
/**
 * @title 抽奖的合约
 * @author 11u
 * @notice 这个合约是一个简单的抽奖合约
 * @dev  Implements chainlink VRFv2
 */
contract Raffle is VRFConsumerBaseV2 {

    //自定义错误,参与抽奖的门票钱不够
    error Raffle__NotEnoughETHSend();
    //时间不够
    error Raffle_NotEnoughTimePassed();
    //转账失败
    error Raffle_TransferFailed();
    // 还没开放
    error Raffle_NotOpen();
    //不能自动执行
    error Raffle_UpkeepNotNeeded(uint256 currentBalance, uint256 numPlayers, uint256 raffleState);

    //枚举
    enum RaffleState {
        OPEN, //开放  0 
        CALCULATING  //计算，计算期间不允许再次参与抽奖 1
    }

    uint16 private constant REQUEST_CONFIRMTIONS  = 3 ;
    uint32 private constant NUM_WORDS = 1;


    //参与抽奖的费用
    uint256 private immutable i_entranceFee;
    //参与者数组
    address payable[] private s_players;
    //抽奖的持续时间
    uint256 private immutable i_interval;
    //上一轮的开奖时间
    uint256 private s_lastTimeStamp;
    //历史获胜者获胜者
    address[] private s_winnerHistory;
    // 此时活动的状态
    RaffleState private s_raffleState;
    // requestId
    uint256 private s_requestId;
    // windder_index 
    uint256 private s_windderIndex;
    // avf的一些配置
    VRFCoordinatorV2Interface private immutable i_vrfCoordinator;
    bytes32 private immutable i_gasLane;
    uint64 private immutable i_subscriptionId;
    uint32 private immutable i_callbackGasLimit;


    //事件 ,参与抽奖
    event EnterRaffle(address indexed player);
    //抽奖结束,找到获胜者
    event PickedWinner(address indexed winner);
    // 开奖请求
    event RequestedRaffleWinner(uint256 indexed requestId);


    constructor(
        uint256 entranceFee , 
        uint256 interval ,
        address vrfCoordinator ,
        bytes32 gasLane,
        uint64 subscriptionId,
        uint32 callbackGasLimit
        ) VRFConsumerBaseV2(vrfCoordinator)   {
        //super(vrfCoordinator);
        i_entranceFee = entranceFee;
        i_interval = interval;
        s_lastTimeStamp = block.timestamp;
        i_vrfCoordinator = VRFCoordinatorV2Interface(vrfCoordinator);
        i_gasLane = gasLane;
        i_subscriptionId = subscriptionId;
        i_callbackGasLimit = callbackGasLimit;
        //默认状态时OPEN状态
        s_raffleState = RaffleState.OPEN;
    }

    //参与抽奖的函数
    function enterRaffle() external payable {
        //保证此时时处于开放状态
        if (s_raffleState != RaffleState.OPEN){
            revert Raffle_NotOpen();
        }
        // require(msg.value >= i_entranceFee, Raffle__NotEnoughETHSend()); 目前并不支持这种写法
        if (msg.value < i_entranceFee){
            revert Raffle__NotEnoughETHSend();
        }

        s_players.push(payable(msg.sender));
        //施放事件
        emit EnterRaffle(msg.sender);
    }

    /**
     * @dev 用于执行检查是否需要自动执行 , 这里只是用于模拟，当满足这些条件时，会调用performUpkeep
     * 这些情况下应该返回true
     * 1、当前时间戳 - 上次开奖时间戳 > 抽奖时间间隔
     * 2、抽奖合约处于open状态
     * 3、抽奖合约的余额大于0 （存在玩家抽奖）
     * 4、订阅已经用了LINK资助 ??? 
     */
    function checkUpkeep(bytes memory /** checkData */ ) public view  returns (bool upkeepNeeded, bytes memory /** performData */ ){

        bool timeHasPassed = (block.timestamp - s_lastTimeStamp ) >= i_interval;
        bool isOpen = (s_raffleState == RaffleState.OPEN);
        bool hasBalance = address(this).balance > 0;
        bool hasPlayers = s_players.length > 0;
        upkeepNeeded = (timeHasPassed && isOpen && hasBalance && hasPlayers);

        return (upkeepNeeded, "0x0");
    }

    function performUpkeep(bytes calldata /** performData */ ) external {
        //检查是否满足条件
        (bool upkeepNeeded, ) = checkUpkeep("");
        if (!upkeepNeeded){
            revert Raffle_UpkeepNotNeeded(
                address(this).balance,
                s_players.length,
                uint256(s_raffleState)
            );
        }
        //将状态设置为计算中
        s_raffleState = RaffleState.CALCULATING;
        //当执行 requestRandomWords 的时候，会触发到VRFCoordinatorV2合约的 fulfillRandomWords函数
        // fulfillRandomWords函数用来处理pickWinner
          uint256 requestId = i_vrfCoordinator.requestRandomWords(
            i_gasLane,
            i_subscriptionId,
            REQUEST_CONFIRMTIONS,
            i_callbackGasLimit,
            NUM_WORDS
        );

        // emit RequestedRaffleWinner(requestId);
        s_requestId = requestId;
        
    }

    //选择获胜者
    // function pickWinner() public {
    //     //获取当前时间戳,以秒为单位
    //     // require(block.timestamp - s_lastTimeStamp > i_interval, Raffle_NotEnoughTimePassed());
    //     if ((block.timestamp - s_lastTimeStamp) < i_interval){
    //         revert Raffle_NotEnoughTimePassed();
    //     }
    //     //将状态设置为计算中
    //     s_raffleState = RaffleState.CALCULATING;
    //     //获取随机数
    //      /**uint256 requestId =*/ i_vrfCoordinator.requestRandomWords(
    //         i_gasLane,
    //         i_subscriptionId, 
    //         REQUEST_CONFIRMTIONS, // 链上需要确认几次后才能返回随机数
    //         i_callbackGasLimit,  //回调后需要支付的gas费用
    //         NUM_WORDS  // 随机数的数量，这里可以是常量
    //     );
        
    // }
    // 已经拿到了随机数，现在需要选取获胜者
    function fulfillRandomWords(
            uint256  /* requestId */ ,
            uint256[] memory randomWords
        ) internal override {
            uint256 indexOfWinner =  randomWords[0] % s_players.length;
            s_windderIndex = indexOfWinner;
            //找到了获胜者的地址
            address payable winner = s_players[indexOfWinner];
            s_winnerHistory.push(winner);
            // 将状态设置为开放
            s_raffleState = RaffleState.OPEN;
            //清空数组
            s_players = new address payable[](0);
            // 更新lasttimestamp
            s_lastTimeStamp = block.timestamp;
            //向获胜者转账
            //释放事件
            emit PickedWinner(winner);
            (bool sucess ,)  = winner.call{value: address(this).balance}("");
            if (!sucess){
                revert Raffle_TransferFailed();
            }
            // //释放一个事件
            // emit PickedWinner(winner);
        }

    /**
     * Getter functions
     */
    function getEntranceFee() public view returns (uint256) {
        return i_entranceFee;
    }
    function getRaffleState() public view returns (RaffleState) {
        return s_raffleState;
    }
    function getPlayer(uint256 index) public view returns (address) {
        return s_players[index];
    }

    function getPlayerLength() public view returns (uint256) {
        return s_players.length;
    }

    function getRequestId() public view returns (uint256) {
        return s_requestId;
    }

    function getWinnerHistory() public view returns (address[] memory) {
        return s_winnerHistory;
    }

    function getWinnerIndex() public view returns (uint256) {
        return s_windderIndex;
    }

}