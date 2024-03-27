// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.18;

import {Script,console} from "forge-std/Script.sol";
import {HelpConfig} from "./HelperConfig.s.sol";
import {VRFCoordinatorV2Mock} from "@chainlink/contracts/src/v0.8/mocks/VRFCoordinatorV2Mock.sol";
import {LinkToken} from "../test/mocks/LinkToken.sol";
import {DevOpsTools} from "lib/foundry-devops/src/DevOpsTools.sol";
contract CreateSubscription is Script {

    function createSubscription () public returns (uint64){
        HelpConfig helpConfig = new HelpConfig();
        ( , , address  vrfCoordinator, , , ,, uint256 deployKey ) = helpConfig.activateNetWorkConfig();
        // address  vrfCoordinator = helpConfig.activateNetWorkConfig().vrfCoordinator; xxx

        return ceateSubscrtion(vrfCoordinator,deployKey);

    } 

    function ceateSubscrtion(address vrfCoordinator,uint256 deployKey) public returns (uint64) {
        vm.startBroadcast(deployKey);
        uint64 subID = VRFCoordinatorV2Mock(vrfCoordinator).createSubscription();
        vm.stopBroadcast();
        console.log("subscription id : %s" , subID);
        console.log("please update subscription id in HelperConfig.s.sol");
        return subID;
    }

    function run() external returns(uint64){
        uint64 subscriptionId = createSubscription();
        return subscriptionId;
    }

}

contract FUndSubscription is Script {

    uint96 public constant FUND_AMOUNT = 3 ether;

    
    function fundSubscriptionUsingConfig()  public{
        HelpConfig helpConfig = new HelpConfig();
    (
         , //入场券的价格
         , //轮询的时间
        address vrfCoordinator , // VRF Coordinator
         ,  // gas限制
        uint64 subscriptionId ,//订阅的id
        , // 回调的gas限制
        address link 
        ,
        uint256 deployKey
    ) = helpConfig.activateNetWorkConfig();
    
    fundSubscription(vrfCoordinator,subscriptionId,link,deployKey);

    }

    function fundSubscription(address vrfCoordinator,uint64 subscriptionId,address link,uint256 deployKey) public {
        console.log("On chainID : %s" , block.chainid);
        console.log("subscription id : %s" , subscriptionId);
        console.log("Using vrfCoordinator : %s" , vrfCoordinator) ;
       
        // 根据当前区块链的链ID，选择不同的方式来为VRF订阅进行资金充值
        if (block.chainid == 31337){
            vm.startBroadcast(deployKey); // 开始广播交易
            //_bound如果本地链，使用LinkToken合约的transferAndCall方法进行资金转移并调用指定合约
            VRFCoordinatorV2Mock(vrfCoordinator).fundSubscription(subscriptionId,FUND_AMOUNT);
            vm.stopBroadcast(); // 停止广播交易
        }else{
            vm.startBroadcast(deployKey); // 开始广播交易
            // 如果是测试链，使用VRFCoordinatorV2Mock合约的fundSubscription方法为指定订阅充值
            LinkToken(link).transferAndCall(
                vrfCoordinator,
                uint256(FUND_AMOUNT),
                abi.encode(subscriptionId)
                );
            vm.stopBroadcast(); // 停止广播交易
        }
    }
    

    function run() external{
        fundSubscriptionUsingConfig();
    }
}

contract AddConsumer is Script {

    function run() public {
        
        // 把 Raffle 添加到消费者
        address consumerAddress = DevOpsTools.get_most_recent_deployment(
            "Raffle",
            block.chainid
        );
        console.log("consumer address : %s" , consumerAddress);
        addConsumerUsingConfig(
            consumerAddress
        );
    }

    function addConsumerUsingConfig(address consumerAddress) public {
        HelpConfig helpConfig = new HelpConfig();
        (,, address  vrfCoordinator, , , uint64 subscriptionId  , ,uint256 deployKey) = helpConfig.activateNetWorkConfig();

        addConsumer(consumerAddress,vrfCoordinator,subscriptionId,deployKey);
    }
    function addConsumer(address consumerAddress,address vrfCoordinator,uint64 subscriptionId,uint256 deployKey) public {
        console.log("On chainID : %s" , block.chainid);
        console.log("subscription id : %s" , subscriptionId);
        console.log("Using vrfCoordinator : %s" , vrfCoordinator) ;
        console.log("consumer address : %s" , consumerAddress);
        console.log("deploy key : %s" , deployKey);
        vm.startBroadcast(deployKey);
        VRFCoordinatorV2Mock(vrfCoordinator).addConsumer(subscriptionId,consumerAddress);
        vm.stopBroadcast();
    }
}

