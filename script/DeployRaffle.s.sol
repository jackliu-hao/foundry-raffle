// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.18;

import {Script,console} from "forge-std/Script.sol";
import {Raffle} from "../src/Raffle.sol";
import {HelpConfig} from "./HelperConfig.s.sol";
import {CreateSubscription} from "../script/Interactions.s.sol";
import {FUndSubscription} from "../script/Interactions.s.sol";
import {AddConsumer} from "../script/Interactions.s.sol";

contract DeployRaffle is Script {

    function run() external returns(Raffle raffle , HelpConfig helpConfig) {
         helpConfig = new HelpConfig();

        (   uint256 entranceFee  , //入场券的价格
            uint256 interval , //轮询的时间
            address vrfCoordinator , // VRF Coordinator
            bytes32 gasLane ,  // gas限制
            uint64 subscriptionId , //订阅的id
            uint32 callbackGasLimit,  // 回调的gas限制
            address linktoken,
            uint256 deployKey
        )  = helpConfig.activateNetWorkConfig();

        //更新subID
        if (subscriptionId == 0){
            CreateSubscription createSubscription = new CreateSubscription();
            subscriptionId = createSubscription.ceateSubscrtion(vrfCoordinator,deployKey);
            //现在需要在部署的时候自动充点钱
            FUndSubscription fundSubscription1 = new FUndSubscription();
            fundSubscription1.fundSubscription(vrfCoordinator,subscriptionId,linktoken,deployKey);
        }
        vm.startBroadcast();
        
        raffle  = new Raffle(
            entranceFee,
            interval,
            vrfCoordinator,
            gasLane,
            subscriptionId,
            callbackGasLimit
        );
         vm.stopBroadcast();
        //订阅，就是添加消费者
        AddConsumer addConsumer = new AddConsumer();
        addConsumer.addConsumer(address(raffle),vrfCoordinator,subscriptionId,deployKey);

       
        console.log("contart address is : %s ",address(raffle));
    }
}