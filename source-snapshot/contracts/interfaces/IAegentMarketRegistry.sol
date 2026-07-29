// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

interface IAegentMarketRegistry {
    enum MarketMode {
        OPEN,
        LIMITED_WINDOW,
        REDEMPTION_ONLY,
        PAUSED,
        POST_LAUNCH_REDEMPTION
    }

    struct PurchaseTerms {
        MarketMode mode;
        uint8 phaseId;
        uint64 configVersion;
        uint256 agntPerUsd18;
        uint64 phaseEndsAt;
        uint64 windowId;
        uint64 windowStartAt;
        uint64 windowEndAt;
        uint256 windowTotalAgntCap;
        uint256 windowWalletAgntCap;
        bool enabled;
    }

    struct RedemptionTerms {
        MarketMode mode;
        uint8 phaseId;
        uint64 configVersion;
        uint256 agntPerUsd18;
        uint64 phaseEndsAt;
        bool enabled;
    }

    function saleStart() external view returns (uint64);

    function saleEnd() external view returns (uint64);

    function authorizedSwap() external view returns (address);

    function redemptionContract() external view returns (address);

    function mode() external view returns (MarketMode);

    function configVersion() external view returns (uint64);

    function currentPhase()
        external
        view
        returns (uint8 phaseId, uint256 agntPerUsd18, uint256 secondsRemaining);

    function purchaseTerms() external view returns (PurchaseTerms memory terms);

    function redemptionTerms()
        external
        view
        returns (RedemptionTerms memory terms);

    function isPurchaseEnabled() external view returns (bool);

    function isRedemptionEnabled() external view returns (bool);
}
