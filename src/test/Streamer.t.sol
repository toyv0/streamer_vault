// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.10;

// import { Addresses } from "../utils/Addresses";
import {ERC20, ERC4626} from "solmate/mixins/ERC4626.sol";
import {SafeTransferLib} from "solmate/utils/SafeTransferLib.sol";
import {Vm} from "forge-std/Vm.sol";
import {Streamer} from "../Streamer.sol";
import "ds-test/test.sol";

import "forge-std/console.sol";

contract StreamerTest is DSTest {
    Vm private vm = Vm(HEVM_ADDRESS);
    Streamer private streamer;

    address fusePool18CToken = 0x17b1A2E012cC4C31f83B90FF11d3942857664efc;

    address constant feiAddress = 0x956f47f50a910163d8bf957cf5846d573e7f87ca;

    address constant balAddress = 0xba100000625a3754423978a60c9317c58a424e3D;

    address constant balDAO = 0xb618F903ad1d00d6F7b92f5b0954DcdC056fC533;
    ERC20 bal = ERC20(balAddress);
    ERC20 fei = ERC20(feiAddress);

    address constant owner = address(1);
    address constant accountOwner = address(2);
    address constant authorizedAddress = address(3);

    function setUp() public {
        vm.prank(balDAO);
        bal.transfer(accountOwner, 21_000e18);

        vm.prank(feiAddress);
        fei.transfer(accountOwner, 21_000e18);

        streamer = new Streamer(fusePool18CToken, owner);
    }

    function testDepositERC20() public {
        uint256 amount = 100;

        vm.startPrank(accountOwner);
        bal.approve(address(streamer), amount);
        streamer.deposit(balAddress, amount);
        vm.stopPrank();

        uint256 accountOwnerBalance = streamer.getERC20Balance(balAddress, accountOwner);
        assertEq(accountOwnerBalance, 100);
    }

    function testWithdrawFromAuthorizedAddress() public {
        uint256 depositAmount = 100;
        uint256 withdrawAmount = 50;
        uint256 accountOwnerBalance;

        vm.startPrank(accountOwner);
        bal.approve(address(streamer), depositAmount);
        streamer.deposit(balAddress, depositAmount);
        streamer.authorizeAddress(authorizedAddress);
        vm.stopPrank();

        vm.startPrank(authorizedAddress);
        bal.approve(address(streamer), withdrawAmount);
        streamer.withdrawFrom(accountOwner, balAddress, withdrawAmount);
        vm.stopPrank();
        
        accountOwnerBalance = streamer.getERC20Balance(balAddress, accountOwner);
        assertEq(accountOwnerBalance, 50);
    }

    function testDepositToYeildStrategy() public {
        uint256 depositAmount = 100;
    }
}


