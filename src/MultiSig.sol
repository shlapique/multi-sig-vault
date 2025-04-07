// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {EIP712} from "@openzeppelin/contracts/utils/cryptography/EIP712.sol";
import {ECDSA} from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import {Initializable} from "@openzeppelin/contracts/proxy/utils/Initializable.sol";

contract MultiSig is EIP712, Initializable {
    address public singleton;
    address[] public owners;
    uint256 public threshold;
    uint256 public nonce;

    struct Transaction {
        address to;
        uint256 value;
        bytes data;
        bool executed;
    }

    struct UpgradeProposal {
        address newSingleton;
        bytes32 txHash;
        uint256 approvals;
    }

    mapping(uint256 => Transaction) public transactions;
    mapping(uint256 => UpgradeProposal) public upgradeProposals;
    mapping(uint256 => mapping(address => bool)) public isConfirmed;
    mapping(bytes32 => mapping(address => bool)) public usedSignatures;
    mapping(address => bool) public isOwner;


    bytes32 private constant _TX_TYPEHASH = 
        keccak256("Transaction(address to,uint256 value,bytes data,uint256 nonce)");

    event TransactionSubmitted(uint256 indexed txId);
    event TransactionConfirmed(uint256 indexed txId, address indexed owner);
    event TransactionExecuted(uint256 indexed txId);
    event UpgradeProposed(uint256 indexed proposalId, address newSingleton);
    event UpgradeApproved(uint256 indexed proposalId, address owner);

    constructor() EIP712("MultiSig", "1") {
        _disableInitializers();
    }

    function initialize(address[] memory _owners, uint256 _threshold) external initializer {
        require(owners.length == 0, "Already initialized");
        require(_threshold > 0, "Invalid threshold");
        threshold = _threshold;
        singleton = address(this);
        for (uint i = 0; i < _owners.length; i++) {
            require(!isOwner[_owners[i]], "Duplicate owner");
            isOwner[_owners[i]] = true;
            owners.push(_owners[i]);
        }
    }

    function submitTransaction(
        address _to,
        uint256 _value,
        bytes calldata _data
    ) external returns (uint256 txId) {
        require(_isOwner(msg.sender), "Not owner");
        txId = nonce++;
        transactions[txId] = Transaction(_to, _value, _data, false);
        emit TransactionSubmitted(txId);
    }

    function confirmTransaction(uint256 _txId) external {
        require(_isOwner(msg.sender), "Not owner");
        require(!isConfirmed[_txId][msg.sender], "Already confirmed");
        require(transactions[_txId].to != address(0), "Transaction does not exist");
        
        isConfirmed[_txId][msg.sender] = true;
        emit TransactionConfirmed(_txId, msg.sender);

        Transaction storage txn = transactions[_txId];
        if (!txn.executed) {
            uint256 confirmCount;
            for (uint256 i = 0; i < owners.length; i++) {
                if (isConfirmed[_txId][owners[i]]) confirmCount++;
            }
            
            if (confirmCount >= threshold) {
                txn.executed = true;
                (bool success, ) = txn.to.call{value: txn.value}(txn.data);
                require(success, "Tx failed");
                emit TransactionExecuted(_txId);
            }
        }
    }
    
    function getTransaction(uint256 _txId) public view returns (
        address to,
        uint256 value,
        bytes memory data,
        bool executed
    ) {
        Transaction memory txn = transactions[_txId];
        return (txn.to, txn.value, txn.data, txn.executed);
    }

    function getUpgradeProposal(uint256 _proposalId) public view returns (
        address newSingleton,
        bytes32 txHash,
        uint256 approvals
    ) {
        UpgradeProposal memory proposal = upgradeProposals[_proposalId];
        return (proposal.newSingleton, proposal.txHash, proposal.approvals);
    }

    function getUpgradeProposalTxHash(uint256 _proposalId) public view returns (bytes32) {
        return upgradeProposals[_proposalId].txHash;
    }

    function getOwnersCount() public view returns (uint256) {
        return owners.length;
    }

    function proposeUpgrade(address _newSingleton) external returns (uint256 proposalId) {
        require(_isOwner(msg.sender), "Not owner");
        proposalId = nonce++;
        bytes32 txHash = _hashTypedDataV4(
            keccak256(abi.encode(
                keccak256("Upgrade(address singleton)"),
                _newSingleton
            ))
        );
        upgradeProposals[proposalId] = UpgradeProposal(_newSingleton, txHash, 0);
        emit UpgradeProposed(proposalId, _newSingleton);
    }

    function approveUpgrade(uint256 _proposalId, bytes calldata _signature) external {
        UpgradeProposal storage proposal = upgradeProposals[_proposalId];
        bytes32 txHash = proposal.txHash;
        
        bytes32 prefixedHash = _hashTypedDataV4(txHash);
        address signer = ECDSA.recover(prefixedHash, _signature);

        require(_isOwner(signer), "Not owner");
        require(!usedSignatures[txHash][signer], "Signature reused");

        usedSignatures[txHash][signer] = true; 
        proposal.approvals++;

        if (proposal.approvals >= threshold) {
            singleton = proposal.newSingleton;
            proposal.approvals = 0;
        }
        emit UpgradeApproved(_proposalId, signer);
    }

    function submitThresholdChange(uint256 _newThreshold) external returns (uint256 txId) {
        require(_isOwner(msg.sender), "Not owner");
        require(_newThreshold <= owners.length, "Threshold exceeds owners");
        txId = nonce++;
        transactions[txId] = Transaction(
            address(this),
            0,
            abi.encodeWithSignature("updateThreshold(uint256)", _newThreshold),
            false
        );
    }

    function getDomainSeparator() public view returns (bytes32) {
        return _domainSeparatorV4();
    }
    
    function updateThreshold(uint256 _newThreshold) external {
        require(msg.sender == address(this), "Unauthorized");
        threshold = _newThreshold;
    }

    function _isOwner(address _addr) internal view returns (bool) {
        return isOwner[_addr];
    }
    receive() external payable {}
}
