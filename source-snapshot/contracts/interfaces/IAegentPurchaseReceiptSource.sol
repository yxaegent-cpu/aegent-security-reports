// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

/// @title IAegentPurchaseReceiptSource
/// @notice Read-only source for wallet-bound presale purchase cost basis.
/// @dev Values are cumulative and never decrease. The redemption contract
///      uses them as a non-transferable refund entitlement.
interface IAegentPurchaseReceiptSource {
    function totalAgntSold()
        external
        view
        returns (uint256 amount);

    function totalUsdContributed18()
        external
        view
        returns (uint256 amount);

    function walletAgntBought(address wallet)
        external
        view
        returns (uint256 amount);

    function walletUsdContributed18(address wallet)
        external
        view
        returns (uint256 amount);
}
