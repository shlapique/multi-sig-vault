// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";
import {MultiSigFactory} from "../src/MultiSigFactory.sol";
import {MultiSig} from "../src/MultiSig.sol";

contract Deploy is Script {
    function run() external {
        address[] memory owners = new address[](3);
        owners[0] = vm.envAddress("OWNER_1"); 
        owners[1] = vm.envAddress("OWNER_2");
        owners[2] = vm.envAddress("OWNER_3");
        // uint256 threshold = 2;
            
        vm.startBroadcast();
        
        MultiSigFactory factory = new MultiSigFactory();
        console.log("@Factory@ deployed at:", address(factory));

        // address multisig = factory.createWallet(owners, threshold);
        // console.log("MultiSig deployed at:", multisig);

        vm.stopBroadcast();
    }
}
