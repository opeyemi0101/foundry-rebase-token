// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {RebaseToken} from "../../src/RebaseToken.sol";
import {Vault} from "../../src/Vault.sol";
import {IRebaseToken} from "../../src/interfaces/IRebaseToken.sol";
import {Handler} from "./Handler.sol";

contract RebaseTokenInvariantTest is Test {
    RebaseToken public token;
    Vault public vault;
    Handler public handler;

    address public owner = makeAddr("owner");
    uint256 public constant INITIAL_RATE = 5e10;

    function setUp() public {
        vm.startPrank(owner);
        token = new RebaseToken();
        vault = new Vault(IRebaseToken(address(token)));
        token.grantMintAndBurnRole(address(vault));
        vm.stopPrank();

        // plenty of ETH so the vault can always pay out interest
        vm.deal(address(vault), 1_000_000 ether);

        handler = new Handler(token, vault, owner);
        targetContract(address(handler));
    }

    function invariant_interestRateNeverIncreases() public view {
        assertFalse(handler.rateIncreased());
        assertLe(token.getInterestRate(), INITIAL_RATE);
    }

    function invariant_balanceNeverBelowPrinciple() public view {
        address[] memory actors = handler.getActors();
        for (uint256 i = 0; i < actors.length; i++) {
            assertGe(token.balanceOf(actors[i]), token.principleBalanceOf(actors[i]));
        }
    }
}
