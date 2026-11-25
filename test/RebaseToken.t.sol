// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {RebaseToken} from "../src/RebaseToken.sol";
import {Vault} from "../src/Vault.sol";
import {IRebaseToken} from "../src/interfaces/IRebaseToken.sol";

contract RebaseTokenTest is Test {
    RebaseToken public token;
    Vault public vault;

    address public owner = makeAddr("owner");
    address public user = makeAddr("user");
    address public user2 = makeAddr("user2");

    function setUp() public {
        vm.startPrank(owner);
        token = new RebaseToken();
        vault = new Vault(IRebaseToken(address(token)));
        token.grantMintAndBurnRole(address(vault));
        vm.stopPrank();

        vm.deal(owner, 1 ether);
        vm.prank(owner);
        (bool ok,) = payable(address(vault)).call{value: 1 ether}("");
        require(ok, "funding vault failed");
    }

    function _deposit(address who, uint256 amount) internal {
        vm.deal(who, amount); // give the user some ETH to deposit
        vm.prank(who);
        vault.deposit{value: amount}();
    }

    function testInterestGrowsLinearly(uint256 amount) public {
        amount = bound(amount, 1e5, type(uint96).max);
        _deposit(user, amount);

        uint256 start = token.balanceOf(user);
        assertEq(start, amount);

        vm.warp(block.timestamp + 1 days);
        uint256 afterDay1 = token.balanceOf(user);

        vm.warp(block.timestamp + 1 days);
        uint256 afterDay2 = token.balanceOf(user);

        assertGt(afterDay1, start);
        assertGt(afterDay2, afterDay1);
        assertApproxEqAbs(afterDay2 - afterDay1, afterDay1 - start, 1);
    }

    function testPrincipleBalanceDoesNotGrow() public {
        _deposit(user, 1 ether);
        vm.warp(block.timestamp + 1 days); // skip to the next day 

        assertEq(token.principleBalanceOf(user), 1 ether);
        assertGt(token.balanceOf(user), 1 ether);
    }

    function testRedeemStraightAfterDeposit() public {
        _deposit(user, 1 ether);
        assertEq(token.balanceOf(user), 1 ether);

        vm.prank(user);
        vault.redeem(type(uint256).max);

        assertEq(token.balanceOf(user), 0);
        assertEq(user.balance, 1 ether);
    }

    function testRedeemAfterTimePassed() public {
        _deposit(user, 1 ether);
        vm.warp(block.timestamp + 1 days);

        uint256 expected = token.balanceOf(user);
        assertGt(expected, 1 ether); // make sure interest has accrued

        vm.prank(user); // next call should be from that user 
        vault.redeem(type(uint256).max);

        assertEq(token.balanceOf(user), 0);
        assertEq(user.balance, expected);
    }

    function testInterestCanOnlyDecrease() public {
        uint256 initialRate = token.getInterestRate();

        vm.prank(owner);
        token.setInterestRate(initialRate - 1e10);
        uint256 currentRate = token.getInterestRate();
        assertEq(currentRate, initialRate - 1e10);

        vm.prank(owner);
        vm.expectRevert(
            abi.encodeWithSelector(
                RebaseToken.RebaseToken__InterestRateCanOnlyDecrease.selector, currentRate, currentRate
            )
        );
        token.setInterestRate(currentRate);

        vm.prank(owner);
        vm.expectRevert(
            abi.encodeWithSelector(
                RebaseToken.RebaseToken__InterestRateCanOnlyDecrease.selector, currentRate, initialRate
            )
        );
        token.setInterestRate(initialRate);

        assertEq(token.getInterestRate(), currentRate);
    }
}
