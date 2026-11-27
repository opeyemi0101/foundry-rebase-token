// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {RebaseToken} from "../../src/RebaseToken.sol";
import {Vault} from "../../src/Vault.sol";

contract Handler is Test {
    RebaseToken public token;
    Vault public vault;
    address public owner;
    address[] internal actors;

    // set to true if the owner ever manages to raise the rate
    bool public rateIncreased;

    constructor(RebaseToken _token, Vault _vault, address _owner) {
        token = _token;
        vault = _vault;
        owner = _owner;
        for (uint256 i = 0; i < 3; i++) {
            actors.push(makeAddr(string.concat("actor", vm.toString(i))));
        }
    }

    function getActors() external view returns (address[] memory) {
        return actors;
    }

    function deposit(uint256 actorSeed, uint256 amount) public {
        address actor = actors[actorSeed % actors.length];
        amount = bound(amount, 1e5, 100 ether);
        vm.deal(actor, amount);
        vm.prank(actor);
        vault.deposit{value: amount}();
    }

    function redeem(uint256 actorSeed, uint256 amount) public {
        address actor = actors[actorSeed % actors.length];
        uint256 bal = token.balanceOf(actor);
        if (bal == 0) return;
        amount = bound(amount, 1, bal);
        vm.prank(actor);
        vault.redeem(amount);
    }

    function transfer(uint256 fromSeed, uint256 toSeed, uint256 amount) public {
        address from = actors[fromSeed % actors.length];
        address to = actors[toSeed % actors.length];
        if (from == to) return;
        uint256 bal = token.balanceOf(from);
        if (bal == 0) return;
        amount = bound(amount, 1, bal);
        vm.prank(from);
        token.transfer(to, amount);
    }

    function warp(uint256 secs) public {
        secs = bound(secs, 1, 1 days);
        vm.warp(block.timestamp + secs);
    }

    function lowerRate(uint256 newRate) public {
        uint256 current = token.getInterestRate();
        if (current == 0) return;
        newRate = bound(newRate, 0, current - 1);
        vm.prank(owner);
        token.setInterestRate(newRate);
    }

    // tries to raise the rate; it must always revert
    function tryRaiseRate(uint256 newRate) public {
        uint256 current = token.getInterestRate();
        newRate = bound(newRate, current, type(uint256).max);
        vm.prank(owner);
        try token.setInterestRate(newRate) {
            rateIncreased = true;
        } catch {}
    }
}
