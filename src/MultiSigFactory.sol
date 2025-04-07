// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Clones} from "@openzeppelin/contracts/proxy/Clones.sol";
import {MultiSig} from "./MultiSig.sol";

contract MultiSigFactory {
    address public immutable singletonMaster;
    address public lastDeployed;

    constructor() {
        singletonMaster = address(new MultiSig());
    }

    function createWallet(address[] memory _owners, uint256 _threshold) external returns (address) {
        // check for uniq owners
        require(_threshold > 0 && _threshold <= _owners.length, "Invalid threshold");
        for (uint i = 0; i < _owners.length; i++) {
            require(_owners[i] != address(0), "Invalid owner");
            for (uint j = i + 1; j < _owners.length; j++) {
                require(_owners[i] != _owners[j], "Duplicate owner");
            }
        }
        address proxy = Clones.clone(singletonMaster);
        MultiSig(payable(proxy)).initialize(_owners, _threshold);
        lastDeployed = proxy;
        return proxy;
    }

    function getLastDeployed() external view returns (address) {
        return lastDeployed;
    }
}
