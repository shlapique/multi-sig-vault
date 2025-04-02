// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {console} from "forge-std/console.sol";

contract MultiSig {
    address[] public owners;
    uint256 public threshold;
    
    struct Transaction {
        address to;
        uint256 value;
        bytes data;
        bool executed;
        uint256 confirmationCount;
    }
    
    Transaction[] public transactions;
    mapping(uint256 => mapping(address => bool)) public isConfirmed;
    
    event TransactionSubmitted(uint256 indexed txId, address indexed sender);
    event TransactionConfirmed(uint256 indexed txId, address indexed owner);
    event TransactionExecuted(uint256 indexed txId);
    
    modifier onlyOwner() {
        require(isOwner(msg.sender), "Not owner");
        _;
    }
    
    constructor(address[] memory _owners, uint256 _threshold) {
        require(_threshold > 0, "Threshold must be > 0");
        require(_owners.length >= _threshold, "Owners < threshold");
        
        owners = _owners;
        threshold = _threshold;
    }
    
    function submitTransaction(address _to, uint256 _value, bytes memory _data) external onlyOwner {
        uint256 txId = transactions.length;
        transactions.push(Transaction({
            to: _to,
            value: _value,
            data: _data,
            executed: false,
            confirmationCount: 0
        }));
        emit TransactionSubmitted(txId, msg.sender);
    }
    
    function confirmTransaction(uint256 _txId) external onlyOwner {
        require(_txId < transactions.length, "Invalid tx");
        require(!isConfirmed[_txId][msg.sender], "Already confirmed");
        require(!transactions[_txId].executed, "Already executed");
        
        isConfirmed[_txId][msg.sender] = true;
        transactions[_txId].confirmationCount++;
        
        emit TransactionConfirmed(_txId, msg.sender);
    }
    
    function executeTransaction(uint256 _txId) external onlyOwner {
        require(!transactions[_txId].executed, "Already executed");
        require(
            transactions[_txId].confirmationCount >= threshold,
            "Not enough confirmations"
        );
        
        transactions[_txId].executed = true;
        (bool success, ) = transactions[_txId].to.call{value: transactions[_txId].value}(
            transactions[_txId].data
        );
        console.log("Tx success:", success); // Добавьте эту строку
        require(success, "Tx failed");
        
        emit TransactionExecuted(_txId);
    }
    
    function isOwner(address _addr) private view returns (bool) {
        for (uint256 i = 0; i < owners.length; i++) {
            if (owners[i] == _addr) {
                return true;
            }
        }
        return false;
    }
    
    function getOwners() external view returns (address[] memory) {
        return owners;
    }

    function transactionsLength() public view returns (uint256) {
        return transactions.length;
    }

    function getTransaction(uint256 _txId) public view returns (
        address to,
        uint256 value,
        bytes memory data,
        bool executed,
        uint256 confirmationCount
    ) {
        Transaction storage t = transactions[_txId];
        return (t.to, t.value, t.data, t.executed, t.confirmationCount);
    }
    receive() external payable {}
}
