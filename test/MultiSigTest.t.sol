// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Test, console} from "forge-std/Test.sol";
import {MultiSig} from "../src/MultiSig.sol";
import {MultiSigFactory} from "../src/MultiSigFactory.sol";

contract MultiSigTest is Test {
    MultiSigFactory public factory;
    MultiSig public multisig;
    
    address[] public owners;
    uint256 public constant THRESHOLD = 2;
    
    address public ALICE = vm.addr(0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80);
    address public BOB = vm.addr(0x59c6995e998f97a5a0044966f0945389dc9e86dae88c7a8412f4603b6b78690d);
    address public CHARLIE = vm.addr(0x5dbe7d45b4b6e9f0a9a0f453f0a9d21a8e5d0c0a9d21a8e5d0c0a9d21a8e5d0c);
    address public constant EVE = address(0x3);
    
    Receiver public receiver;

    function setUp() public {
        owners.push(ALICE);
        owners.push(BOB);
        owners.push(CHARLIE);
        
        factory = new MultiSigFactory();
        address proxy = factory.createWallet(owners, THRESHOLD);
        multisig = MultiSig(payable(proxy));
        
        receiver = new Receiver();
        vm.deal(address(multisig), 10 ether);
    }

    function test_InitialState() public view {
        assertEq(multisig.threshold(), THRESHOLD);
        assertEq(multisig.owners(0), ALICE);
        assertEq(multisig.owners(1), BOB);
        assertEq(multisig.getOwnersCount(), 3);
    }

    function test_FullTransactionFlow() public {
        vm.prank(ALICE);
        uint256 txId = multisig.submitTransaction(address(receiver), 1 ether, hex"01");
        
        vm.prank(ALICE);
        multisig.confirmTransaction(txId);
        (,,, bool executed) = multisig.getTransaction(txId);
        assertFalse(executed);

        vm.prank(BOB);
        multisig.confirmTransaction(txId);
        
        (,,, executed) = multisig.getTransaction(txId);
        assertTrue(executed);
        assertEq(receiver.receivedValue(), 1 ether);
    }

    function test_InsufficientConfirmations() public {
        vm.prank(ALICE);
        uint256 txId = multisig.submitTransaction(address(receiver), 1 ether, hex"");
        
        vm.prank(ALICE);
        multisig.confirmTransaction(txId);

        (,,, bool executed) = multisig.getTransaction(txId);
        assertFalse(executed); 
    }

    function test_DoubleConfirmation() public {
        vm.prank(ALICE);
        uint256 txId = multisig.submitTransaction(address(receiver), 1 ether, hex"");
        
        vm.prank(ALICE);
        multisig.confirmTransaction(txId);
        
        vm.expectRevert("Already confirmed");
        vm.prank(ALICE);
        multisig.confirmTransaction(txId);
    }

    // function test_FullUpgradeFlow() public {
    //     MultiSig newSingleton = new MultiSig();
        
    //     
    //     vm.prank(ALICE);
    //     uint256 proposalId = multisig.proposeUpgrade(address(newSingleton));
    //     bytes32 txHash = multisig.getUpgradeProposalTxHash(proposalId);
        
    //    
    //     bytes32 prefixedHash = keccak256(abi.encodePacked("\x19\x01", multisig.DOMAIN_SEPARATOR(), txHash));
        
    //   
    //     (uint8 v1, bytes32 r1, bytes32 s1) = vm.sign(0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80, prefixedHash);
    //     bytes memory sigAlice = abi.encodePacked(r1, s1, v1);
        
    //  
    //     (uint8 v2, bytes32 r2, bytes32 s2) = vm.sign(0x59c6995e998f97a5a0044966f0945389dc9e86dae88c7a8412f4603b6b78690d, prefixedHash);
    //     bytes memory sigBob = abi.encodePacked(r2, s2, v2);
        
    // 
    //     multisig.approveUpgrade(proposalId, sigAlice);
    //     multisig.approveUpgrade(proposalId, sigBob);
        
    //     (,, uint256 approvals) = multisig.getUpgradeProposal(proposalId);
    //     assertEq(approvals, 2, "Should have 2 approvals");
    //     assertEq(multisig.singleton(), address(newSingleton), "Singleton not updated");
    // }

    function test_UpgradeSignatureReuse() public {
        MultiSig newSingleton = new MultiSig();
        
        vm.prank(ALICE);
        uint256 proposalId = multisig.proposeUpgrade(address(newSingleton));
        
        bytes32 txHash = multisig.getUpgradeProposalTxHash(proposalId);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80, txHash);
        bytes memory sig = abi.encodePacked(r, s, v);
        
        multisig.approveUpgrade(proposalId, sig);
        vm.expectRevert("Signature reused");
        multisig.approveUpgrade(proposalId, sig);
    }

    function test_NonOwnerSubmission() public {
        vm.prank(EVE);
        vm.expectRevert("Not owner");
        multisig.submitTransaction(address(receiver), 0, hex"");
    }

    function test_InvalidThresholdChange() public {
        vm.prank(ALICE);
        vm.expectRevert("Threshold exceeds owners");
        multisig.submitThresholdChange(4);
    }

    function test_SelfDestructReceiver() public {
        Receiver sdr = new Receiver();
        vm.deal(address(multisig), 1 ether);
        
        vm.prank(ALICE);
        uint256 txId = multisig.submitTransaction(address(sdr), 1 ether, hex"");
        
        vm.prank(ALICE);
        multisig.confirmTransaction(txId);
        vm.prank(BOB);
        multisig.confirmTransaction(txId);
        
        assertEq(address(sdr).balance, 1 ether);
    }

    function test_MultipleWalletCreation() public {
        address[] memory owners2 = new address[](2);
        owners2[0] = ALICE;
        owners2[1] = BOB;
        
        address[] memory owners4 = new address[](4);
        owners4[0] = ALICE;
        owners4[1] = BOB;
        owners4[2] = CHARLIE;
        owners4[3] = address(0x4);

        address wallet2 = factory.createWallet(owners2, 1);
        address wallet4 = factory.createWallet(owners4, 3);

        assertEq(MultiSig(payable(wallet2)).getOwnersCount(), 2);
        assertEq(MultiSig(payable(wallet4)).getOwnersCount(), 4);
        assertEq(MultiSig(payable(wallet2)).threshold(), 1);
        assertEq(MultiSig(payable(wallet4)).threshold(), 3);
    }

    function test_SingletonUpgradePreservesState() public {
        uint256 initialBalance = address(multisig).balance;
        address initialSingleton = multisig.singleton();
        
        MultiSig newSingleton = new MultiSig();
        
        vm.prank(ALICE);
        uint256 proposalId = multisig.proposeUpgrade(address(newSingleton));
        
        bytes32 txHash = multisig.getUpgradeProposalTxHash(proposalId);
        (uint8 v1, bytes32 r1, bytes32 s1) = vm.sign(0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80, txHash);
        (uint8 v2, bytes32 r2, bytes32 s2) = vm.sign(0x59c6995e998f97a5a0044966f0945389dc9e86dae88c7a8412f4603b6b78690d, txHash);
        
        multisig.approveUpgrade(proposalId, abi.encodePacked(r1, s1, v1));
        multisig.approveUpgrade(proposalId, abi.encodePacked(r2, s2, v2));
        
        assertEq(multisig.singleton(), address(newSingleton));
        assertEq(address(multisig).balance, initialBalance);
        assertNotEq(initialSingleton, address(newSingleton));
    }

    function test_ConfirmationCombinations() public {
        vm.prank(ALICE);
        uint256 txId = multisig.submitTransaction(address(receiver), 1 ether, hex"01");
        
        vm.prank(ALICE);
        multisig.confirmTransaction(txId);
        vm.prank(BOB);
        multisig.confirmTransaction(txId);
        (,,, bool executed) = multisig.getTransaction(txId);
        assertTrue(executed);
        
        vm.prank(ALICE);
        uint256 txId2 = multisig.submitTransaction(address(receiver), 1 ether, hex"01");
        vm.prank(ALICE);
        multisig.confirmTransaction(txId2);
        vm.prank(CHARLIE);
        multisig.confirmTransaction(txId2);
        (,,, executed) = multisig.getTransaction(txId2);
        assertTrue(executed);
        
        vm.prank(BOB);
        uint256 txId3 = multisig.submitTransaction(address(receiver), 1 ether, hex"01");
        vm.prank(BOB);
        multisig.confirmTransaction(txId3);
        vm.prank(CHARLIE);
        multisig.confirmTransaction(txId3);
        (,,, executed) = multisig.getTransaction(txId3);
        assertTrue(executed);
    }

    function test_InsufficientConfirmationsForThreeOwners() public {
        vm.prank(ALICE);
        uint256 txId = multisig.submitTransaction(address(receiver), 1 ether, hex"");
        
        vm.prank(ALICE);
        multisig.confirmTransaction(txId);
        
        (,,, bool executed) = multisig.getTransaction(txId);
        assertFalse(executed, "Transaction should not execute yet");

        vm.prank(BOB);
        multisig.confirmTransaction(txId);
        
        (,,, executed) = multisig.getTransaction(txId);
        assertTrue(executed, "Transaction should auto-execute");
        assertEq(receiver.receivedValue(), 1 ether, "Receiver balance should update");
    }

    function test_ThresholdChangeFlow() public {
        vm.prank(ALICE);
        uint256 txId = multisig.submitThresholdChange(3);
        
        vm.prank(ALICE);
        multisig.confirmTransaction(txId);
        vm.prank(BOB);
        multisig.confirmTransaction(txId);
        vm.prank(CHARLIE);
        multisig.confirmTransaction(txId);
        
        (,,, bool executed) = multisig.getTransaction(txId);
        assertTrue(executed);
        assertEq(multisig.threshold(), 3);
    }

}

contract Receiver {
    bytes public receivedData;
    uint256 public receivedValue;
    
    receive() external payable {
        receivedValue = msg.value;
    }
    
    fallback() external payable {
        receivedData = msg.data;
        receivedValue = msg.value;
    }
}
