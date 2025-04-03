pragma solidity ^0.8.28;

import {Script} from "forge-std/Script.sol";
import {MultiSig} from "../src/MultiSig.sol";
import {console} from "forge-std/console.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

contract DeployMultiSig is Script {
    function run() external {
        address[] memory owners = new address[](3);
        owners[0] = vm.envAddress("OWNER_1"); 
        owners[1] = vm.envAddress("OWNER_2");
        owners[2] = vm.envAddress("OWNER_3");
        
        // 2/3 multisig
        uint256 threshold = 2;
        
        vm.startBroadcast();

        MultiSig multisig = new MultiSig();

        bytes memory initData = abi.encodeWithSelector(
            MultiSig.initialize.selector,
            owners,
            threshold
        );

        ERC1967Proxy proxy = new ERC1967Proxy(address(multisig), initData);
        
        vm.stopBroadcast();
        
        console.log("MultiSig deployed at:", address(multisig));
        console.log("@Proxy@ deployed at:", address(proxy));
    }
}
