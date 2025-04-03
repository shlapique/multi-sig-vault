pragma solidity ^0.8.28;

import {Test} from "forge-std/Test.sol";
import {MultiSig} from "../src/MultiSig.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

contract MultiSigTest is Test {
    MultiSig public multisig;
    ERC1967Proxy public proxy;
    address[] public owners;
    address public constant ALICE = address(0x1);
    address public constant BOB = address(0x2);
    address public constant EVE = address(0x3);
    uint256 public threshold = 2;
    

    function setUp() public {
        owners.push(ALICE);
        owners.push(BOB);
        
        MultiSig implementation = new MultiSig();
        
        bytes memory initData = abi.encodeWithSelector(
            MultiSig.initialize.selector,
            owners,
            threshold
        );
        
        proxy = new ERC1967Proxy(
            address(implementation),
            initData
        );
        multisig = MultiSig(payable(address(proxy)));
    }
    
    function test_Initialization() public view {
        assertEq(multisig.threshold(), threshold);
        address[] memory storedOwners = multisig.getOwners();
        assertEq(storedOwners.length, owners.length);
        assertEq(storedOwners[0], ALICE);
        assertEq(storedOwners[1], BOB);
    }
    
    function test_SubmitAndExecuteTransaction() public {
        Receiver receiver = new Receiver();
        bytes memory testData = hex"1234";
        
        vm.prank(ALICE);
        multisig.submitTransaction(address(receiver), 0, testData);
        uint256 txId = multisig.transactionsLength() - 1;
        
        vm.prank(ALICE);
        multisig.confirmTransaction(txId);
        
        vm.prank(BOB);
        multisig.confirmTransaction(txId);
        
        (, , , bool executed, ) = multisig.getTransaction(txId);
        assertTrue(executed);
        assertTrue(receiver.called());
        assertEq(receiver.receivedData(), testData);
    }
    
    function test_RevertWhen_NonOwnerTriesToConfirm() public {
        Receiver receiver = new Receiver();
        
        vm.prank(ALICE);
        multisig.submitTransaction(address(receiver), 0, hex"1234");
        uint256 txId = multisig.transactionsLength() - 1;
        
        vm.prank(EVE);
        vm.expectRevert();
        multisig.confirmTransaction(txId);
    }

    function test_UpgradePreservesState() public {
        vm.prank(ALICE);
        multisig.submitTransaction(address(0), 1 ether, hex"");
        uint256 txId = multisig.transactionsLength() - 1;
        
        MultiSig newImplementation = new MultiSig();
        
        vm.prank(ALICE);
        multisig.upgradeToAndCall(address(newImplementation), "");
        
        assertEq(multisig.threshold(), threshold);
        address[] memory currentOwners = multisig.getOwners();
        assertEq(currentOwners.length, 2);
        assertEq(currentOwners[0], ALICE);
        assertEq(currentOwners[1], BOB);
        assertEq(multisig.transactionsLength(), 1);
        
        (, uint256 value, , , ) = multisig.getTransaction(txId);
        assertEq(value, 1 ether);
    }
    
    function test_OnlyOwnerCanUpgrade() public {
        MultiSig newImplementation = new MultiSig();
        
        vm.prank(EVE);
        vm.expectRevert("Not owner");
        multisig.upgradeToAndCall(address(newImplementation), "");
    }
}

contract Receiver {
    bool public called;
    bytes public receivedData;
    
    receive() external payable {
        called = true;
    }
    
    fallback() external payable {
        called = true;
        receivedData = msg.data;
    }
}
