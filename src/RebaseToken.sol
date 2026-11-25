// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";

contract RebaseToken is ERC20, Ownable, AccessControl {
    error RebaseToken__InterestRateCanOnlyDecrease(uint256 oldRate, uint256 newRate);

    uint256 private constant PRECISION_FACTOR = 1e18;
    bytes32 private constant MINT_AND_BURN_ROLE = keccak256("MINT_AND_BURN_ROLE");

    uint256 private s_interestRate = 5e10;
    mapping(address => uint256) private s_userInterestRate;
    mapping(address => uint256) private s_userLastUpdatedTimestamp;

    event InterestRateSet(uint256 newInterestRate);

    constructor() ERC20("Rebase Token", "RBT") Ownable(msg.sender) {}

    function grantMintAndBurnRole(address account) external onlyOwner {
        _grantRole(MINT_AND_BURN_ROLE, account);
    }

    function setInterestRate(uint256 newRate) external onlyOwner {
        if (newRate >= s_interestRate) {
            revert RebaseToken__InterestRateCanOnlyDecrease(s_interestRate, newRate);
        }
        s_interestRate = newRate;
        emit InterestRateSet(newRate);
    }

    function mint(address to, uint256 amount) external onlyRole(MINT_AND_BURN_ROLE) {
        _mintAccruedInterest(to);
        s_userInterestRate[to] = s_interestRate;
        _mint(to, amount);
    }

    function burn(address from, uint256 amount) external onlyRole(MINT_AND_BURN_ROLE) {
        if (amount == type(uint256).max) amount = balanceOf(from);
        _mintAccruedInterest(from);
        _burn(from, amount);
    }

    function balanceOf(address user) public view override returns (uint256) {
        return super.balanceOf(user) * _interestMultiplier(user) / PRECISION_FACTOR;
    }

    function principleBalanceOf(address user) external view returns (uint256) {
        return super.balanceOf(user);
    }

    function transfer(address to, uint256 amount) public override returns (bool) {
        _mintAccruedInterest(msg.sender);
        _mintAccruedInterest(to);
        if (amount == type(uint256).max) amount = balanceOf(msg.sender);
        if (balanceOf(to) == 0) s_userInterestRate[to] = s_userInterestRate[msg.sender];
        return super.transfer(to, amount);
    }

    function transferFrom(address from, address to, uint256 amount) public override returns (bool) {
        _mintAccruedInterest(from);
        _mintAccruedInterest(to);
        if (amount == type(uint256).max) amount = balanceOf(from);
        if (balanceOf(to) == 0) s_userInterestRate[to] = s_userInterestRate[from];
        return super.transferFrom(from, to, amount);
    }

    function getInterestRate() external view returns (uint256) {
        return s_interestRate;
    }

    function getUserInterestRate(address user) external view returns (uint256) {
        return s_userInterestRate[user];
    }

    function _interestMultiplier(address user) internal view returns (uint256) {
        uint256 elapsed = block.timestamp - s_userLastUpdatedTimestamp[user];
        return PRECISION_FACTOR + (s_userInterestRate[user] * elapsed);
    }

    function _mintAccruedInterest(address user) internal {
        uint256 increase = balanceOf(user) - super.balanceOf(user);
        s_userLastUpdatedTimestamp[user] = block.timestamp;
        if (increase > 0) _mint(user, increase);
    }
}
