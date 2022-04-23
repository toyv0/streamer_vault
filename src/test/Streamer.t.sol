// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.10;

// import { Addresses } from "../utils/Addresses";
import {ERC20, ERC4626} from "solmate/mixins/ERC4626.sol";
import {SafeTransferLib} from "solmate/utils/SafeTransferLib.sol";
import {Vm} from "forge-std/Vm.sol";
import {Streamer} from "../Streamer.sol";
import "ds-test/test.sol";

contract StreamerTest is DSTest {
    Vm private vm = Vm(HEVM_ADDRESS);
    Streamer private streamer;

    address fusePool18CToken = 0x17b1A2E012cC4C31f83B90FF11d3942857664efc;

    address constant balAddress = 0xba100000625a3754423978a60c9317c58a424e3D;
    address constant balDAO = 0xb618F903ad1d00d6F7b92f5b0954DcdC056fC533;
    ERC20 bal = ERC20(balAddress);

    address constant owner = address(1);
    address constant accountOwner = address(2);
    address constant whitelistedAddress = address(3);

    function setUp() public {
        // vm.prank(balDAO);
        // bal.transfer(accountOwner, 21_000e18);

        streamer = new Streamer();
    }

    function testDeposit() public {
        uint256 amount = 100;
        address receiver = address(1);

        vm.startPrank(accountOwner);
        streamer.deposit(balAddress, amount);
        uint256 accountOwnerBalance = streamer.getAccountBalance();
        vm.stopPrank();

        assertEq(accountOwnerBalance, 0);
    }
}
