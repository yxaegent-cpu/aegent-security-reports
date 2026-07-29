// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {Ownable2Step} from "@openzeppelin/contracts/access/Ownable2Step.sol";
import {IAegentMarketRegistry} from "./interfaces/IAegentMarketRegistry.sol";
import {IAegentRegistryBound} from "./interfaces/IAegentRegistryBound.sol";
import {IAegentRedemptionEndpoint} from "./interfaces/IAegentRedemptionEndpoint.sol";

/// @title AegentMarketRegistry
/// @notice On-chain authority for presale phase, purchase mode and limited-window terms.
/// @dev The sale schedule and rates are immutable. Operations can only select a safe mode
///      and configure a bounded limited window before activating it.
contract AegentMarketRegistry is IAegentMarketRegistry, Ownable2Step {
    uint256 public constant PHASE_ONE_RATE = 10e18;
    uint256 public constant PHASE_TWO_RATE = 7e18;
    uint256 public constant PHASE_THREE_RATE = 3e18;
    uint256 public constant PHASE_ONE_CUTOFF = 60 days;
    uint256 public constant PHASE_TWO_CUTOFF = 30 days;
    uint256 public constant SALE_DURATION = 90 days;
    bytes32 public constant SWAP_ENDPOINT_KIND =
        keccak256("AEGENT_SWAP_V2");
    bytes32 public constant REDEMPTION_ENDPOINT_KIND =
        keccak256("AEGENT_REDEMPTION_V2");

    struct LimitedWindow {
        uint64 id;
        uint64 startAt;
        uint64 endAt;
        uint256 totalAgntCap;
        uint256 walletAgntCap;
    }

    error InvalidSaleEnd(uint64 supplied);
    error InvalidSaleSchedule();
    error SaleAlreadyEnded();
    error PostLaunchModeTooEarly();
    error RedemptionOnlyModeTooLate();
    error LimitedWindowNotConfigured();
    error LimitedWindowConfigurationLocked();
    error InvalidLimitedWindow();
    error InvalidSwap(address candidate);
    error InvalidRedemptionContract(address candidate);
    error InvalidCommittedEndpoints();
    error OwnershipRenunciationDisabled();

    event MarketModeChanged(
        MarketMode indexed previousMode,
        MarketMode indexed newMode,
        address indexed operator
    );
    event LimitedWindowConfigured(
        uint64 indexed windowId,
        uint64 startAt,
        uint64 endAt,
        uint256 totalAgntCap,
        uint256 walletAgntCap
    );
    uint64 public immutable saleStart;
    uint64 public immutable saleEnd;
    address public immutable authorizedSwap;
    address public immutable redemptionContract;
    MarketMode public mode = MarketMode.PAUSED;
    uint64 public configVersion;
    LimitedWindow public limitedWindow;

    constructor(
        uint64 saleStart_,
        uint64 saleEnd_,
        address authorizedSwap_,
        address redemptionContract_,
        address initialOwner
    ) Ownable(initialOwner) {
        if (saleEnd_ <= block.timestamp) {
            revert InvalidSaleEnd(saleEnd_);
        }
        if (
            saleStart_ >= saleEnd_ ||
            saleEnd_ - saleStart_ != SALE_DURATION
        ) {
            revert InvalidSaleSchedule();
        }
        if (
            authorizedSwap_ == address(0) ||
            redemptionContract_ == address(0) ||
            authorizedSwap_ == redemptionContract_
        ) {
            revert InvalidCommittedEndpoints();
        }
        saleStart = saleStart_;
        saleEnd = saleEnd_;
        authorizedSwap = authorizedSwap_;
        redemptionContract = redemptionContract_;
    }

    function setMode(MarketMode newMode) external onlyOwner {
        if (newMode == MarketMode.OPEN || newMode == MarketMode.LIMITED_WINDOW) {
            if (block.timestamp >= saleEnd) {
                revert SaleAlreadyEnded();
            }
        }

        if (newMode == MarketMode.LIMITED_WINDOW && limitedWindow.id == 0) {
            revert LimitedWindowNotConfigured();
        }

        if (newMode == MarketMode.REDEMPTION_ONLY && block.timestamp >= saleEnd) {
            revert RedemptionOnlyModeTooLate();
        }

        if (
            newMode == MarketMode.POST_LAUNCH_REDEMPTION &&
            block.timestamp < saleEnd
        ) {
            revert PostLaunchModeTooEarly();
        }

        MarketMode previousMode = mode;
        mode = newMode;
        configVersion += 1;
        emit MarketModeChanged(previousMode, newMode, msg.sender);
    }

    function configureLimitedWindow(
        uint64 startAt,
        uint64 endAt,
        uint256 totalAgntCap,
        uint256 walletAgntCap
    ) external onlyOwner {
        if (mode == MarketMode.LIMITED_WINDOW) {
            revert LimitedWindowConfigurationLocked();
        }
        if (
            startAt < block.timestamp ||
            startAt < saleStart ||
            startAt >= endAt ||
            endAt > saleEnd ||
            totalAgntCap == 0 ||
            walletAgntCap == 0 ||
            walletAgntCap > totalAgntCap
        ) {
            revert InvalidLimitedWindow();
        }

        uint64 nextWindowId = limitedWindow.id + 1;
        configVersion += 1;
        limitedWindow = LimitedWindow({
            id: nextWindowId,
            startAt: startAt,
            endAt: endAt,
            totalAgntCap: totalAgntCap,
            walletAgntCap: walletAgntCap
        });

        emit LimitedWindowConfigured(
            nextWindowId,
            startAt,
            endAt,
            totalAgntCap,
            walletAgntCap
        );
    }

    function currentPhase()
        public
        view
        returns (uint8 phaseId, uint256 agntPerUsd18, uint256 secondsRemaining)
    {
        if (block.timestamp < saleStart) {
            return (0, 0, saleEnd - block.timestamp);
        }
        if (block.timestamp >= saleEnd) {
            return (0, 0, 0);
        }

        secondsRemaining = saleEnd - block.timestamp;
        if (secondsRemaining > PHASE_ONE_CUTOFF) {
            return (1, PHASE_ONE_RATE, secondsRemaining);
        }
        if (secondsRemaining > PHASE_TWO_CUTOFF) {
            return (2, PHASE_TWO_RATE, secondsRemaining);
        }
        return (3, PHASE_THREE_RATE, secondsRemaining);
    }

    function purchaseTerms()
        public
        view
        returns (PurchaseTerms memory terms)
    {
        (terms.phaseId, terms.agntPerUsd18, ) = currentPhase();
        terms.mode = mode;
        terms.configVersion = configVersion;
        terms.phaseEndsAt = _phaseEndsAt(terms.phaseId);

        if (
            terms.phaseId == 0 ||
            block.timestamp < saleStart ||
            !_isCompatibleEndpoint(authorizedSwap, SWAP_ENDPOINT_KIND) ||
            !_isCompatibleEndpoint(
                redemptionContract,
                REDEMPTION_ENDPOINT_KIND
            )
        ) {
            return terms;
        }

        if (mode == MarketMode.OPEN) {
            terms.enabled = true;
            return terms;
        }

        if (mode != MarketMode.LIMITED_WINDOW) {
            return terms;
        }

        LimitedWindow memory window = limitedWindow;
        terms.windowId = window.id;
        terms.windowStartAt = window.startAt;
        terms.windowEndAt = window.endAt;
        terms.windowTotalAgntCap = window.totalAgntCap;
        terms.windowWalletAgntCap = window.walletAgntCap;
        terms.enabled =
            window.id != 0 &&
            block.timestamp >= window.startAt &&
            block.timestamp < window.endAt;
    }

    function isPurchaseEnabled() external view returns (bool) {
        return purchaseTerms().enabled;
    }

    function redemptionTerms()
        public
        view
        returns (RedemptionTerms memory terms)
    {
        terms.mode = mode;
        terms.configVersion = configVersion;
        if (
            !_isCompatibleEndpoint(
                redemptionContract,
                REDEMPTION_ENDPOINT_KIND
            )
        ) {
            return terms;
        }

        if (
            mode == MarketMode.REDEMPTION_ONLY &&
            block.timestamp >= saleStart &&
            block.timestamp < saleEnd
        ) {
            // Phase remains a quote-boundary/version signal only. Presale
            // refunds are settled by the redemption endpoint against the
            // caller's wallet-bound purchase cost basis, never the current
            // 10/7/3 sale rate.
            (terms.phaseId, , ) = currentPhase();
            terms.phaseEndsAt = _phaseEndsAt(terms.phaseId);
            try
                IAegentRedemptionEndpoint(redemptionContract)
                    .isOperational()
            returns (bool operational) {
                terms.enabled = operational;
            } catch {}
            return terms;
        }

        if (
            mode == MarketMode.POST_LAUNCH_REDEMPTION &&
            block.timestamp >= saleEnd
        ) {
            // Post-launch settlement price is intentionally not inherited from
            // the presale. A separately verified redemption contract/config
            // must provide it; zero here is the fail-closed sentinel.
            terms.phaseEndsAt = type(uint64).max;
            try
                IAegentRedemptionEndpoint(redemptionContract)
                    .isOperational()
            returns (bool operational) {
                terms.enabled = operational;
            } catch {}
        }
    }

    function isRedemptionEnabled() external view returns (bool) {
        return redemptionTerms().enabled;
    }

    function endpointBindingsReady()
        external
        view
        returns (bool swapReady, bool redemptionReady)
    {
        swapReady = _isCompatibleEndpoint(
            authorizedSwap,
            SWAP_ENDPOINT_KIND
        );
        redemptionReady = _isCompatibleEndpoint(
            redemptionContract,
            REDEMPTION_ENDPOINT_KIND
        );
    }

    function renounceOwnership() public view override onlyOwner {
        revert OwnershipRenunciationDisabled();
    }

    function _phaseEndsAt(uint8 phaseId) internal view returns (uint64) {
        if (phaseId == 1) {
            return saleEnd - uint64(PHASE_ONE_CUTOFF);
        }
        if (phaseId == 2) {
            return saleEnd - uint64(PHASE_TWO_CUTOFF);
        }
        return saleEnd;
    }

    function _isCompatibleEndpoint(
        address candidate,
        bytes32 expectedKind
    )
        internal
        view
        returns (bool)
    {
        if (candidate.code.length == 0) {
            return false;
        }
        try IAegentRegistryBound(candidate).marketRegistry() returns (
            address candidateRegistry
        ) {
            if (candidateRegistry != address(this)) {
                return false;
            }
        } catch {
            return false;
        }
        try IAegentRegistryBound(candidate).endpointKind() returns (
            bytes32 candidateKind
        ) {
            return candidateKind == expectedKind;
        } catch {
            return false;
        }
    }
}
