pragma solidity ^0.8.28;

import {Script} from "forge-std/Script.sol";
import {MultiSig} from "../src/MultiSig.sol";
import {console} from "forge-std/console.sol";

contract DeployMultiSig is Script {
    function run() external {
        address[] memory owners = new address[](3);
        owners[0] = vm.envAddress("OWNER_1"); 
        owners[1] = vm.envAddress("OWNER_2");
        owners[2] = vm.envAddress("OWNER_3");
        
        // 2/3 multisig
        uint256 threshold = 2;
        
        vm.startBroadcast();
        MultiSig multisig = new MultiSig(owners, threshold);
        vm.stopBroadcast();
        
        console.log("MultiSig deployed at:", address(multisig));
    }
}
