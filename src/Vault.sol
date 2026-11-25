// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IRebaseToken} from "./interfaces/IRebaseToken.sol";

contract Vault {
    error Vault__RedeemFailed();

    IRebaseToken private immutable i_rebaseToken;

    event Deposit(address indexed user, uint256 amount);
    event Redeem(address indexed user, uint256 amount);

    constructor(IRebaseToken rebaseToken) {
        i_rebaseToken = rebaseToken;
    }

    receive() external payable {}

    function deposit() external payable {
        i_rebaseToken.mint(msg.sender, msg.value);
        emit Deposit(msg.sender, msg.value);
    }

    function redeem(uint256 amount) external {
        if (amount == type(uint256).max) amount = i_rebaseToken.balanceOf(msg.sender);
        i_rebaseToken.burn(msg.sender, amount);
        (bool ok,) = payable(msg.sender).call{value: amount}("");
        if (!ok) revert Vault__RedeemFailed();
        emit Redeem(msg.sender, amount);
    }

    function getRebaseToken() external view returns (address) {
        return address(i_rebaseToken);
    }
}
