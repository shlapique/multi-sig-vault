pragma solidity ^0.8.28;

import {UUPSUpgradeable} from "@openzeppelin/contracts/proxy/utils/UUPSUpgradeable.sol";
import {Initializable} from "@openzeppelin/contracts/proxy/utils/Initializable.sol";

import {console} from "forge-std/console.sol";

contract MultiSig is Initializable, UUPSUpgradeable {
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

    constructor() {
        _disableInitializers();
    }

    modifier onlyOwner() {
        require(isOwner(msg.sender), "Not owner");
        _;
    }
    
    function initialize(address[] memory _owners, uint256 _threshold) public initializer {
        require(_threshold > 0, "Threshold must be > 0");
        require(_owners.length >= _threshold, "Owners < threshold");

        for (uint i = 0; i < _owners.length; i++) {
            require(_owners[i] != address(0), "Invalid owner address");
            owners.push(_owners[i]);
        }
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
        if (transactions[_txId].confirmationCount >= threshold) {
            _executeTransaction(_txId);
        }
    }
    
    function _executeTransaction(uint256 _txId) internal {
        require(!transactions[_txId].executed, "Already executed");
        require(
            transactions[_txId].confirmationCount >= threshold,
            "Not enough confirmations"
        );
        
        transactions[_txId].executed = true;
        (bool success, ) = transactions[_txId].to.call{value: transactions[_txId].value}(
            transactions[_txId].data
        );
        console.log("Tx success:", success);
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

    event FundsDeposited(uint256 amount);
    receive() external payable {
        emit FundsDeposited(msg.value);
    }

    function _authorizeUpgrade(address) internal override onlyOwner {}
}
