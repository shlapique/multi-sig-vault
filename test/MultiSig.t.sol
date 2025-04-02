pragma solidity ^0.8.28;

import {Test} from "forge-std/Test.sol";
import {MultiSig} from "../src/MultiSig.sol";

contract MultiSigTest is Test {
    MultiSig public multisig;
    address[] public owners;
    address public constant ALICE = address(0x1);
    address public constant BOB = address(0x2);
    address public constant EVE = address(0x3);
    uint256 public threshold = 2;
    
    function setUp() public {
        owners = [ALICE, BOB];
        multisig = new MultiSig(owners, threshold);
    }
    
    function test_Initialization() public view {
        assertEq(multisig.threshold(), threshold);
        address[] memory storedOwners = multisig.getOwners();
        assertEq(storedOwners.length, owners.length);
        assertEq(storedOwners[0], owners[0]);
        assertEq(storedOwners[1], owners[1]);
    }
    
    function test_SubmitAndExecuteTransaction() public {
        Receiver receiver = new Receiver();
        
        vm.prank(ALICE);
        multisig.submitTransaction(address(receiver), 0, hex"1234");
        uint256 txId = multisig.transactionsLength() - 1;
        
        vm.prank(ALICE);
        multisig.confirmTransaction(txId);
        
        vm.prank(BOB);
        multisig.confirmTransaction(txId);
        
        vm.prank(ALICE);
        multisig.executeTransaction(txId);
        
        (, , , bool executed, ) = multisig.transactions(txId);
        assertTrue(executed);
        assertTrue(receiver.called());
    }
    
    function test_RevertWhen_NonOwnerTriesToConfirm() public {
        Receiver receiver = new Receiver();
        
        vm.prank(ALICE);
        multisig.submitTransaction(address(receiver), 0, hex"1234");
        uint256 txId = multisig.transactionsLength() - 1;
        
        vm.prank(EVE);
        vm.expectRevert("Not owner");
        multisig.confirmTransaction(txId);
    }
    
    function test_RevertWhen_ExecuteWithoutEnoughConfirmations() public {
        Receiver receiver = new Receiver();
        
        vm.prank(ALICE);
        multisig.submitTransaction(address(receiver), 0, hex"1234");
        uint256 txId = multisig.transactionsLength() - 1;
        
        vm.prank(ALICE);
        multisig.confirmTransaction(txId);
        
        vm.prank(ALICE);
        vm.expectRevert("Not enough confirmations");
        multisig.executeTransaction(txId);
    }
}

contract Receiver {
    bool public called;
    
    receive() external payable {
        called = true;
    }
    
    fallback() external payable {
        called = true;
    }
}
