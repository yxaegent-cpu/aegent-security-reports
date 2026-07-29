// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IAegentMarketRegistry} from "./interfaces/IAegentMarketRegistry.sol";

/// @title AegentSaleProceedsVault
/// @notice Holds BNB, USDT and USDC sale proceeds until the presale ends.
/// @dev The beneficiary is immutable. Release is permissionless after saleEnd so
///      funds cannot be held hostage by a missing operator transaction.
contract AegentSaleProceedsVault {
    using SafeERC20 for IERC20;

    error ZeroAddress();
    error AddressHasNoCode(address candidate);
    error InvalidAssetConfiguration();
    error UnsupportedToken(address token);
    error ProceedsLocked(uint256 unlocksAt, uint256 currentTimestamp);
    error NothingToRelease(address asset);
    error NativeTransferFailed();

    event NativeProceedsReleased(address indexed beneficiary, uint256 amount);
    event TokenProceedsReleased(
        address indexed token,
        address indexed beneficiary,
        uint256 amount
    );

    IAegentMarketRegistry public immutable marketRegistry;
    IERC20 public immutable usdt;
    IERC20 public immutable usdc;
    address payable public immutable beneficiary;

    constructor(
        address marketRegistry_,
        address usdt_,
        address usdc_,
        address payable beneficiary_
    ) {
        if (
            marketRegistry_ == address(0) ||
            usdt_ == address(0) ||
            usdc_ == address(0) ||
            beneficiary_ == address(0)
        ) {
            revert ZeroAddress();
        }
        if (
            marketRegistry_ == usdt_ ||
            marketRegistry_ == usdc_ ||
            usdt_ == usdc_ ||
            beneficiary_ == marketRegistry_ ||
            beneficiary_ == usdt_ ||
            beneficiary_ == usdc_
        ) {
            revert InvalidAssetConfiguration();
        }
        _requireCode(marketRegistry_);
        _requireCode(usdt_);
        _requireCode(usdc_);

        marketRegistry = IAegentMarketRegistry(marketRegistry_);
        usdt = IERC20(usdt_);
        usdc = IERC20(usdc_);
        beneficiary = beneficiary_;
    }

    function releaseNative() external {
        _requireUnlocked();
        uint256 amount = address(this).balance;
        if (amount == 0) {
            revert NothingToRelease(address(0));
        }
        (bool sent, ) = beneficiary.call{value: amount}("");
        if (!sent) {
            revert NativeTransferFailed();
        }
        emit NativeProceedsReleased(beneficiary, amount);
    }

    function releaseToken(address token) external {
        _requireUnlocked();
        if (token != address(usdt) && token != address(usdc)) {
            revert UnsupportedToken(token);
        }
        uint256 amount = IERC20(token).balanceOf(address(this));
        if (amount == 0) {
            revert NothingToRelease(token);
        }
        IERC20(token).safeTransfer(beneficiary, amount);
        emit TokenProceedsReleased(token, beneficiary, amount);
    }

    function _requireUnlocked() internal view {
        uint256 unlocksAt = marketRegistry.saleEnd();
        if (block.timestamp < unlocksAt) {
            revert ProceedsLocked(unlocksAt, block.timestamp);
        }
    }

    function _requireCode(address candidate) internal view {
        if (candidate.code.length == 0) {
            revert AddressHasNoCode(candidate);
        }
    }

    receive() external payable {}
}
