// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.18;

import {Script} from "forge-std/Script.sol";
// import {MockV3Aggregator} from "../test/mocks/MockV3Aggregator.sol";
import {VRFCoordinatorV2Mock} from "@chainlink/contracts/src/v0.8/mocks/VRFCoordinatorV2Mock.sol";
import {LinkToken} from "../test/mocks/LinkToken.sol";

contract HelpConfig is Script {

    NetworkConfig public activateNetWorkConfig;


    struct  NetworkConfig {
        uint256 entranceFee  ; //入场券的价格
        uint256 interval ;  //轮询的时间
        address vrfCoordinator ; // VRF Coordinator
        bytes32 gasLane ;  // gas限制
        uint64 subscriptionId ; //订阅的id
        uint32 callbackGasLimit;  // 回调的gas限制
        address link ;
        uint256 deployKey ;
    }

    constructor (){
        if (block.chainid == 421614){
            activateNetWorkConfig = getArbitrumEthConfig();
        }else {
            activateNetWorkConfig = getOrCreateAnvilEthConfig();
        }
    }

    function getArbitrumEthConfig() public view returns(NetworkConfig memory) {

        NetworkConfig memory ArbitrumConfig = NetworkConfig({
            entranceFee: 0.01 ether, //入场券的价格
            interval: 30, //轮询的时间 秒
            // Arbitrum-testNet
            vrfCoordinator: 0x50d47e4142598E3411aA864e08a44284e471AC6f, //VRF address
            gasLane:  0x027f94ff1465b3525f9fc03e9ff7d6d2c0953482246dd6ae07570c45d6631414, 
            subscriptionId: 299, // 后面需要更新
            callbackGasLimit: 500000,
            link: 0xb1D4538B4571d411F07960EF2838Ce337FE1E80E ,
            deployKey: vm.envUint("PRIVATE_KEY")
        });
        return ArbitrumConfig;
    }

    function getOrCreateAnvilEthConfig() public   returns(NetworkConfig memory) {

        //已经部署过的话，就不用部署了
        if (activateNetWorkConfig.vrfCoordinator != address(0)){
            return activateNetWorkConfig;
        }
        uint96 baseFee = 0.25 ether; //  0.25 LINK
        uint96 gasPriceLink = 1e9; // link per gas

        // deploy mocks 
        vm.startBroadcast();
        VRFCoordinatorV2Mock mockPriceFeed = new VRFCoordinatorV2Mock(baseFee,gasPriceLink);
        LinkToken linkToken = new LinkToken();
        vm.stopBroadcast();

        // //return the mock address
        // 对于本地的，需要模拟一个link
        NetworkConfig memory anvilConfig = NetworkConfig({
            entranceFee: 0.01 ether, //入场券的价格
            interval: 30, //轮询的时间 秒
            // Arbitrum-testNet
            vrfCoordinator: address(mockPriceFeed), //VRF address
            gasLane:  0x027f94ff1465b3525f9fc03e9ff7d6d2c0953482246dd6ae07570c45d6631414, 
            subscriptionId: 0, // 后面需要更新
            callbackGasLimit: 500000,
            link: address(linkToken),
            deployKey: 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80
        });
        return anvilConfig;
    }


}