// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {Ownable2Step} from "@openzeppelin/contracts/access/Ownable2Step.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";
import {IAegentMarketRegistry} from "./interfaces/IAegentMarketRegistry.sol";
import {IAegentPurchaseReceiptSource} from "./interfaces/IAegentPurchaseReceiptSource.sol";

/// @title AegentRedemptionV2
/// @notice Reserve-backed AGNT to USDT settlement with on-chain limits.
/// @dev Presale redemption is owner-controlled through the Registry's
///      REDEMPTION_ONLY mode and refunds only the caller's wallet-bound
///      V2 escrow entitlement at its authentic cost basis. The purchased AGNT
///      never enters the buyer wallet before refund or end-of-sale claim, so
///      substitute fungible tokens cannot exercise the refund right.
///      Post-launch redemption remains fail-closed until an independent
///      delayed settlement rate is activated.
contract AegentRedemptionV2 is Ownable2Step, ReentrancyGuard {
    using SafeERC20 for IERC20;

    uint256 private constant ONE = 1e18;
    bytes32 public constant ENDPOINT_KIND =
        keccak256("AEGENT_REDEMPTION_V2");
    uint16 private constant BPS = 10_000;
    uint16 public constant MAX_FEE_BPS = 1_000;
    uint64 public constant POST_LAUNCH_RATE_DELAY = 1 days;
    uint256 public constant MAX_QUOTE_LIFETIME = 5 minutes;

    struct RedemptionRequest {
        uint256 agntAmount;
        uint8 expectedPhaseId;
        IAegentMarketRegistry.MarketMode expectedMode;
        uint64 expectedConfigVersion;
        uint64 expectedRateVersion;
        uint256 minUsdtOut;
        uint256 deadline;
        uint256 expectedExecutionNonce;
    }

    struct RedemptionQuote {
        IAegentMarketRegistry.RedemptionTerms terms;
        uint256 agntPerUsd18;
        uint256 grossUsdt;
        uint256 feeUsdt;
        uint256 netUsdt;
        uint256 dayIndex;
        uint256 nextGlobalDaily;
        uint256 nextWalletDaily;
        bool usesPresaleCostBasis;
        uint256 nextAccountedAgntBought;
        uint256 nextAccountedUsdContributed18;
        uint256 nextRefundableAgnt;
        uint256 nextRefundableUsd18;
        uint256 executionNonce;
    }

    struct PresaleRefundAccount {
        uint256 accountedAgntBought;
        uint256 accountedUsdContributed18;
        uint256 refundableAgnt;
        uint256 refundableUsd18;
    }

    error ZeroAddress();
    error ZeroAmount();
    error AddressHasNoCode(address candidate);
    error InvalidAssetConfiguration();
    error UnsupportedDecimals(address asset, uint8 decimals);
    error InvalidLimits();
    error InvalidFee(uint16 supplied);
    error RedemptionUnavailable();
    error UnauthorizedRedemptionContract(address configuredContract);
    error QuoteExpired(uint256 deadline, uint256 currentTimestamp);
    error QuoteLifetimeExceeded(uint256 deadline, uint256 maximumDeadline);
    error DeadlineBeyondMarketBoundary(uint256 deadline, uint256 boundary);
    error UnexpectedPhase(uint8 expectedPhaseId, uint8 actualPhaseId);
    error UnexpectedMode(uint8 expectedMode, uint8 actualMode);
    error UnexpectedConfigVersion(
        uint64 expectedVersion,
        uint64 actualVersion
    );
    error UnexpectedRateVersion(uint64 expectedVersion, uint64 actualVersion);
    error UnexpectedRedemptionNonce(
        uint256 expectedNonce,
        uint256 actualNonce
    );
    error MinimumOutputRequired();
    error SlippageExceeded(uint256 minimumOutput, uint256 actualOutput);
    error ManualReviewRequired(uint256 requestedUsdt, uint256 thresholdUsdt);
    error GlobalDailyLimitExceeded(uint256 limit, uint256 attemptedTotal);
    error WalletDailyLimitExceeded(
        address wallet,
        uint256 limit,
        uint256 attemptedTotal
    );
    error InsufficientReserve(uint256 required, uint256 available);
    error FeeOnTransferUnsupported(address asset);
    error ConfigurationRequiresPausedMode();
    error PostLaunchRateUnavailable();
    error PostLaunchRateNotReady(uint64 activatesAt);
    error PurchaseReceiptUnavailable(address source);
    error InvalidPurchaseReceiptState(address account);
    error PresaleRefundExceedsEntitlement(
        address account,
        uint256 requestedAgnt,
        uint256 availableAgnt
    );
    error PresaleClaimNotReady(uint256 claimOpensAt, uint256 currentTimestamp);
    error NothingToClaim(address account);
    error InsufficientEscrowAgnt(uint256 required, uint256 available);
    error InsufficientUnlockedReserve(uint256 requested, uint256 available);
    error InsufficientUnlockedAgnt(uint256 requested, uint256 available);
    error OwnershipRenunciationDisabled();
    error DirectNativeTransferDisabled();

    event ReserveFunded(address indexed funder, uint256 amount);
    event RedemptionSettled(
        address indexed account,
        uint256 indexed executionNonce,
        uint256 agntIn,
        uint256 grossUsdt,
        uint256 feeUsdt,
        uint256 netUsdt,
        uint8 phaseId,
        IAegentMarketRegistry.MarketMode mode,
        uint256 agntPerUsd18,
        uint16 feeBps
    );
    event PostLaunchRateProposed(
        uint256 agntPerUsd18,
        uint64 activatesAt
    );
    event PostLaunchRateProposalCancelled(uint256 agntPerUsd18);
    event PostLaunchRateActivated(
        uint64 indexed version,
        uint256 agntPerUsd18
    );
    event ReserveWithdrawn(address indexed recipient, uint256 amount);
    event RedeemedAgntWithdrawn(address indexed recipient, uint256 amount);
    event PresaleRefundAccountUpdated(
        address indexed account,
        uint256 accountedAgntBought,
        uint256 accountedUsdContributed18,
        uint256 refundableAgnt,
        uint256 refundableUsd18
    );
    event PurchasedAgntClaimed(
        address indexed account,
        uint256 agntAmount,
        uint256 settledUsd18
    );

    IERC20Metadata public immutable agnt;
    IERC20Metadata public immutable usdt;
    IAegentMarketRegistry public immutable marketRegistry;
    uint256 public immutable usdtScale;
    uint256 public immutable dailyGlobalUsdtLimit;
    uint256 public immutable dailyWalletUsdtLimit;
    uint256 public immutable manualReviewThresholdUsdt;
    uint16 public immutable feeBps;

    uint256 public postLaunchAgntPerUsd18;
    uint64 public postLaunchRateVersion;
    uint256 public pendingPostLaunchAgntPerUsd18;
    uint64 public pendingPostLaunchRateActivatesAt;

    uint256 public totalAgntRedeemed;
    uint256 public totalUsdtPaid;
    uint256 public totalPresaleGrossUsdtRefunded;
    uint256 public totalPresaleAgntRefunded;
    uint256 public totalPresaleAgntClaimed;
    uint256 public totalPresaleClaimedUsd18;
    mapping(uint256 dayIndex => uint256 grossUsdt)
        public dailyGlobalUsdtRedeemed;
    mapping(uint256 dayIndex => mapping(address wallet => uint256 grossUsdt))
        public dailyWalletUsdtRedeemed;
    mapping(address wallet => PresaleRefundAccount account)
        public presaleRefundAccounts;
    mapping(address wallet => uint256 nonce) public nextRedemptionNonce;

    constructor(
        address agnt_,
        address usdt_,
        address marketRegistry_,
        address initialOwner,
        uint256 dailyGlobalUsdtLimit_,
        uint256 dailyWalletUsdtLimit_,
        uint256 manualReviewThresholdUsdt_,
        uint16 feeBps_
    ) Ownable(initialOwner) {
        if (
            agnt_ == address(0) ||
            usdt_ == address(0) ||
            marketRegistry_ == address(0)
        ) {
            revert ZeroAddress();
        }
        if (agnt_ == usdt_) {
            revert InvalidAssetConfiguration();
        }
        _requireCode(agnt_);
        _requireCode(usdt_);
        _requireCode(marketRegistry_);
        if (
            dailyGlobalUsdtLimit_ == 0 ||
            dailyWalletUsdtLimit_ == 0 ||
            manualReviewThresholdUsdt_ == 0 ||
            dailyWalletUsdtLimit_ > dailyGlobalUsdtLimit_ ||
            manualReviewThresholdUsdt_ > dailyWalletUsdtLimit_
        ) {
            revert InvalidLimits();
        }
        if (feeBps_ > MAX_FEE_BPS) {
            revert InvalidFee(feeBps_);
        }

        agnt = IERC20Metadata(agnt_);
        usdt = IERC20Metadata(usdt_);
        marketRegistry = IAegentMarketRegistry(marketRegistry_);
        dailyGlobalUsdtLimit = dailyGlobalUsdtLimit_;
        dailyWalletUsdtLimit = dailyWalletUsdtLimit_;
        manualReviewThresholdUsdt = manualReviewThresholdUsdt_;
        feeBps = feeBps_;

        uint8 agntDecimals = IERC20Metadata(agnt_).decimals();
        uint8 usdtDecimals = IERC20Metadata(usdt_).decimals();
        if (agntDecimals != 18) {
            revert UnsupportedDecimals(agnt_, agntDecimals);
        }
        if (usdtDecimals > 18) {
            revert UnsupportedDecimals(usdt_, usdtDecimals);
        }
        usdtScale = 10 ** (18 - usdtDecimals);
    }

    function endpointKind() external pure returns (bytes32) {
        return ENDPOINT_KIND;
    }

    function fundReserve(uint256 amount) external nonReentrant {
        if (amount == 0) {
            revert ZeroAmount();
        }
        uint256 balanceBefore = usdt.balanceOf(address(this));
        IERC20(address(usdt)).safeTransferFrom(
            msg.sender,
            address(this),
            amount
        );
        uint256 balanceAfter = usdt.balanceOf(address(this));
        if (balanceAfter - balanceBefore != amount) {
            revert FeeOnTransferUnsupported(address(usdt));
        }
        emit ReserveFunded(msg.sender, amount);
    }

    function previewRedemption(address account, uint256 agntAmount)
        external
        view
        returns (RedemptionQuote memory quote)
    {
        if (account == address(0)) {
            revert ZeroAddress();
        }
        IAegentMarketRegistry.RedemptionTerms memory terms = _activeTerms();
        uint64 rateVersion = terms.mode ==
            IAegentMarketRegistry.MarketMode.POST_LAUNCH_REDEMPTION
            ? postLaunchRateVersion
            : 0;
        quote = _validateRedemption(
            account,
            RedemptionRequest({
                agntAmount: agntAmount,
                expectedPhaseId: terms.phaseId,
                expectedMode: terms.mode,
                expectedConfigVersion: terms.configVersion,
                expectedRateVersion: rateVersion,
                minUsdtOut: 1,
                deadline: block.timestamp,
                expectedExecutionNonce: nextRedemptionNonce[account]
            })
        );
    }

    function redeem(
        uint256 agntAmount,
        uint8 expectedPhaseId,
        IAegentMarketRegistry.MarketMode expectedMode,
        uint64 expectedConfigVersion,
        uint64 expectedRateVersion,
        uint256 minUsdtOut,
        uint256 deadline,
        uint256 expectedExecutionNonce
    ) external nonReentrant returns (uint256 netUsdt) {
        RedemptionQuote memory quote = _validateRedemption(
            msg.sender,
            RedemptionRequest({
                agntAmount: agntAmount,
                expectedPhaseId: expectedPhaseId,
                expectedMode: expectedMode,
                expectedConfigVersion: expectedConfigVersion,
                expectedRateVersion: expectedRateVersion,
                minUsdtOut: minUsdtOut,
                deadline: deadline,
                expectedExecutionNonce: expectedExecutionNonce
            })
        );
        netUsdt = quote.netUsdt;
        uint256 reserve = usdt.balanceOf(address(this));
        if (reserve < netUsdt) {
            revert InsufficientReserve(netUsdt, reserve);
        }

        nextRedemptionNonce[msg.sender] = quote.executionNonce + 1;
        dailyGlobalUsdtRedeemed[quote.dayIndex] = quote.nextGlobalDaily;
        dailyWalletUsdtRedeemed[quote.dayIndex][
            msg.sender
        ] = quote.nextWalletDaily;
        if (quote.usesPresaleCostBasis) {
            presaleRefundAccounts[msg.sender] = PresaleRefundAccount({
                accountedAgntBought: quote.nextAccountedAgntBought,
                accountedUsdContributed18: quote
                    .nextAccountedUsdContributed18,
                refundableAgnt: quote.nextRefundableAgnt,
                refundableUsd18: quote.nextRefundableUsd18
            });
            emit PresaleRefundAccountUpdated(
                msg.sender,
                quote.nextAccountedAgntBought,
                quote.nextAccountedUsdContributed18,
                quote.nextRefundableAgnt,
                quote.nextRefundableUsd18
            );
            totalPresaleGrossUsdtRefunded += quote.grossUsdt;
            totalPresaleAgntRefunded += agntAmount;
        }
        totalAgntRedeemed += agntAmount;
        totalUsdtPaid += netUsdt;

        if (!quote.usesPresaleCostBasis) {
            _collectAgnt(msg.sender, agntAmount);
        }
        _deliverUsdt(msg.sender, netUsdt);
        emit RedemptionSettled(
            msg.sender,
            quote.executionNonce,
            agntAmount,
            quote.grossUsdt,
            quote.feeUsdt,
            netUsdt,
            quote.terms.phaseId,
            quote.terms.mode,
            quote.agntPerUsd18,
            feeBps
        );
    }

    function claimablePurchasedAgnt(address account)
        external
        view
        returns (uint256 agntAmount, uint256 settledUsd18)
    {
        if (account == address(0)) {
            revert ZeroAddress();
        }
        PresaleRefundAccount memory refundAccount =
            _syncedPresaleRefundAccount(account);
        return (
            refundAccount.refundableAgnt,
            refundAccount.refundableUsd18
        );
    }

    function claimPurchasedAgnt()
        external
        nonReentrant
        returns (uint256 agntAmount)
    {
        uint256 claimOpensAt = marketRegistry.saleEnd();
        if (block.timestamp < claimOpensAt) {
            revert PresaleClaimNotReady(claimOpensAt, block.timestamp);
        }
        address configuredContract = marketRegistry.redemptionContract();
        if (configuredContract != address(this)) {
            revert UnauthorizedRedemptionContract(configuredContract);
        }

        PresaleRefundAccount memory refundAccount =
            _syncedPresaleRefundAccount(msg.sender);
        agntAmount = refundAccount.refundableAgnt;
        uint256 settledUsd18 = refundAccount.refundableUsd18;
        if (agntAmount == 0) {
            revert NothingToClaim(msg.sender);
        }

        uint256 escrowBalance = agnt.balanceOf(address(this));
        if (escrowBalance < agntAmount) {
            revert InsufficientEscrowAgnt(agntAmount, escrowBalance);
        }
        refundAccount.refundableAgnt = 0;
        refundAccount.refundableUsd18 = 0;
        presaleRefundAccounts[msg.sender] = refundAccount;
        totalPresaleAgntClaimed += agntAmount;
        totalPresaleClaimedUsd18 += settledUsd18;

        emit PresaleRefundAccountUpdated(
            msg.sender,
            refundAccount.accountedAgntBought,
            refundAccount.accountedUsdContributed18,
            0,
            0
        );
        _deliverClaimedAgnt(msg.sender, agntAmount);
        emit PurchasedAgntClaimed(
            msg.sender,
            agntAmount,
            settledUsd18
        );
    }

    function proposePostLaunchRate(uint256 agntPerUsd18)
        external
        onlyOwner
    {
        _requirePausedPostLaunch();
        if (agntPerUsd18 == 0) {
            revert ZeroAmount();
        }
        uint64 activatesAt = uint64(
            block.timestamp + POST_LAUNCH_RATE_DELAY
        );
        pendingPostLaunchAgntPerUsd18 = agntPerUsd18;
        pendingPostLaunchRateActivatesAt = activatesAt;
        emit PostLaunchRateProposed(agntPerUsd18, activatesAt);
    }

    function cancelPostLaunchRateProposal() external onlyOwner {
        uint256 cancelledRate = pendingPostLaunchAgntPerUsd18;
        pendingPostLaunchAgntPerUsd18 = 0;
        pendingPostLaunchRateActivatesAt = 0;
        emit PostLaunchRateProposalCancelled(cancelledRate);
    }

    function activatePostLaunchRate() external onlyOwner {
        _requirePausedPostLaunch();
        uint64 activatesAt = pendingPostLaunchRateActivatesAt;
        if (
            pendingPostLaunchAgntPerUsd18 == 0 ||
            activatesAt == 0 ||
            block.timestamp < activatesAt
        ) {
            revert PostLaunchRateNotReady(activatesAt);
        }
        postLaunchAgntPerUsd18 = pendingPostLaunchAgntPerUsd18;
        postLaunchRateVersion += 1;
        pendingPostLaunchAgntPerUsd18 = 0;
        pendingPostLaunchRateActivatesAt = 0;
        emit PostLaunchRateActivated(
            postLaunchRateVersion,
            postLaunchAgntPerUsd18
        );
    }

    function withdrawReserve(address recipient, uint256 amount)
        external
        onlyOwner
    {
        _requireRedemptionDisabled();
        if (recipient == address(0)) {
            revert ZeroAddress();
        }
        if (amount == 0) {
            revert ZeroAmount();
        }
        if (block.timestamp < marketRegistry.saleEnd()) {
            uint256 reserve = usdt.balanceOf(address(this));
            uint256 lockedLiability = presaleOutstandingLiabilityUsdt();
            uint256 available = lockedLiability != type(uint256).max &&
                reserve > lockedLiability
                ? reserve - lockedLiability
                : 0;
            if (amount > available) {
                revert InsufficientUnlockedReserve(amount, available);
            }
        }
        IERC20(address(usdt)).safeTransfer(recipient, amount);
        emit ReserveWithdrawn(recipient, amount);
    }

    function withdrawRedeemedAgnt(address recipient, uint256 amount)
        external
        onlyOwner
    {
        _requireRedemptionDisabled();
        if (recipient == address(0)) {
            revert ZeroAddress();
        }
        if (amount == 0) {
            revert ZeroAmount();
        }
        uint256 escrowBalance = agnt.balanceOf(address(this));
        uint256 lockedClaims = presaleOutstandingAgntClaims();
        uint256 available = escrowBalance > lockedClaims
            ? escrowBalance - lockedClaims
            : 0;
        if (amount > available) {
            revert InsufficientUnlockedAgnt(amount, available);
        }
        IERC20(address(agnt)).safeTransfer(recipient, amount);
        emit RedeemedAgntWithdrawn(recipient, amount);
    }

    function renounceOwnership() public view override onlyOwner {
        revert OwnershipRenunciationDisabled();
    }

    function isOperational() external view returns (bool) {
        uint256 reserve = usdt.balanceOf(address(this));
        if (
            marketRegistry.redemptionContract() != address(this) ||
            reserve == 0
        ) {
            return false;
        }

        uint256 timestamp = block.timestamp;
        uint64 saleEnd_ = marketRegistry.saleEnd();
        if (
            timestamp >= marketRegistry.saleStart() &&
            timestamp < saleEnd_
        ) {
            uint256 outstandingAgnt = presaleOutstandingAgntClaims();
            return
                marketRegistry.mode() ==
                IAegentMarketRegistry.MarketMode.REDEMPTION_ONLY &&
                reserve >= presaleOutstandingLiabilityUsdt() &&
                outstandingAgnt != type(uint256).max &&
                agnt.balanceOf(address(this)) >= outstandingAgnt;
        }

        return
            timestamp >= saleEnd_ &&
            marketRegistry.mode() ==
            IAegentMarketRegistry.MarketMode.POST_LAUNCH_REDEMPTION &&
            postLaunchAgntPerUsd18 != 0 &&
            postLaunchRateVersion != 0 &&
            reserve >= dailyGlobalUsdtLimit;
    }

    function presaleOutstandingLiabilityUsdt()
        public
        view
        returns (uint256 outstanding)
    {
        address sourceAddress = marketRegistry.authorizedSwap();
        if (sourceAddress == address(0) || sourceAddress.code.length == 0) {
            return type(uint256).max;
        }
        uint256 contributedUsd18;
        try
            IAegentPurchaseReceiptSource(sourceAddress)
                .totalUsdContributed18()
        returns (uint256 value) {
            contributedUsd18 = value;
        } catch {
            return type(uint256).max;
        }
        uint256 settledUsd18 =
            totalPresaleGrossUsdtRefunded *
            usdtScale +
            totalPresaleClaimedUsd18;
        if (settledUsd18 >= contributedUsd18) {
            return 0;
        }
        uint256 outstandingUsd18 = contributedUsd18 - settledUsd18;
        return (outstandingUsd18 + usdtScale - 1) / usdtScale;
    }

    function presaleOutstandingAgntClaims()
        public
        view
        returns (uint256 outstanding)
    {
        address sourceAddress = marketRegistry.authorizedSwap();
        if (sourceAddress == address(0) || sourceAddress.code.length == 0) {
            return type(uint256).max;
        }
        uint256 sold;
        try
            IAegentPurchaseReceiptSource(sourceAddress)
                .totalAgntSold()
        returns (uint256 value) {
            sold = value;
        } catch {
            return type(uint256).max;
        }
        uint256 settled = totalPresaleAgntRefunded +
            totalPresaleAgntClaimed;
        if (settled > sold) {
            return type(uint256).max;
        }
        return sold - settled;
    }

    function _validateRedemption(
        address account,
        RedemptionRequest memory request
    ) internal view returns (RedemptionQuote memory quote) {
        if (request.agntAmount == 0) {
            revert ZeroAmount();
        }
        if (request.minUsdtOut == 0) {
            revert MinimumOutputRequired();
        }
        if (request.deadline < block.timestamp) {
            revert QuoteExpired(request.deadline, block.timestamp);
        }
        uint256 maximumDeadline = block.timestamp + MAX_QUOTE_LIFETIME;
        if (request.deadline > maximumDeadline) {
            revert QuoteLifetimeExceeded(
                request.deadline,
                maximumDeadline
            );
        }
        quote.executionNonce = nextRedemptionNonce[account];
        if (request.expectedExecutionNonce != quote.executionNonce) {
            revert UnexpectedRedemptionNonce(
                request.expectedExecutionNonce,
                quote.executionNonce
            );
        }

        quote.terms = _activeTerms();
        if (quote.terms.phaseId != request.expectedPhaseId) {
            revert UnexpectedPhase(
                request.expectedPhaseId,
                quote.terms.phaseId
            );
        }
        if (quote.terms.mode != request.expectedMode) {
            revert UnexpectedMode(
                uint8(request.expectedMode),
                uint8(quote.terms.mode)
            );
        }
        if (quote.terms.configVersion != request.expectedConfigVersion) {
            revert UnexpectedConfigVersion(
                request.expectedConfigVersion,
                quote.terms.configVersion
            );
        }
        if (request.deadline > quote.terms.phaseEndsAt) {
            revert DeadlineBeyondMarketBoundary(
                request.deadline,
                quote.terms.phaseEndsAt
            );
        }

        uint64 rateVersion;
        if (
            quote.terms.mode ==
            IAegentMarketRegistry.MarketMode.POST_LAUNCH_REDEMPTION
        ) {
            quote.agntPerUsd18 = postLaunchAgntPerUsd18;
            rateVersion = postLaunchRateVersion;
            if (quote.agntPerUsd18 == 0 || rateVersion == 0) {
                revert PostLaunchRateUnavailable();
            }
            uint256 grossUsd18 = Math.mulDiv(
                request.agntAmount,
                ONE,
                quote.agntPerUsd18
            );
            quote.grossUsdt = grossUsd18 / usdtScale;
        } else {
            quote = _presaleCostBasisQuote(
                account,
                request.agntAmount,
                quote
            );
        }
        if (request.expectedRateVersion != rateVersion) {
            revert UnexpectedRateVersion(
                request.expectedRateVersion,
                rateVersion
            );
        }

        if (quote.grossUsdt == 0) {
            revert ZeroAmount();
        }
        if (quote.grossUsdt > manualReviewThresholdUsdt) {
            revert ManualReviewRequired(
                quote.grossUsdt,
                manualReviewThresholdUsdt
            );
        }

        quote.feeUsdt = Math.mulDiv(quote.grossUsdt, feeBps, BPS);
        quote.netUsdt = quote.grossUsdt - quote.feeUsdt;
        if (quote.netUsdt < request.minUsdtOut) {
            revert SlippageExceeded(
                request.minUsdtOut,
                quote.netUsdt
            );
        }

        quote.dayIndex = block.timestamp / 1 days;
        quote.nextGlobalDaily = dailyGlobalUsdtRedeemed[quote.dayIndex] +
            quote.grossUsdt;
        if (quote.nextGlobalDaily > dailyGlobalUsdtLimit) {
            revert GlobalDailyLimitExceeded(
                dailyGlobalUsdtLimit,
                quote.nextGlobalDaily
            );
        }
        quote.nextWalletDaily = dailyWalletUsdtRedeemed[quote.dayIndex][
            account
        ] + quote.grossUsdt;
        if (quote.nextWalletDaily > dailyWalletUsdtLimit) {
            revert WalletDailyLimitExceeded(
                account,
                dailyWalletUsdtLimit,
                quote.nextWalletDaily
            );
        }
    }

    function _presaleCostBasisQuote(
        address account,
        uint256 agntAmount,
        RedemptionQuote memory quote
    ) internal view returns (RedemptionQuote memory) {
        PresaleRefundAccount memory refundAccount =
            _syncedPresaleRefundAccount(account);
        uint256 refundableAgnt = refundAccount.refundableAgnt;
        uint256 refundableUsd18 = refundAccount.refundableUsd18;
        if (agntAmount > refundableAgnt) {
            revert PresaleRefundExceedsEntitlement(
                account,
                agntAmount,
                refundableAgnt
            );
        }
        if (refundableAgnt == 0 || refundableUsd18 == 0) {
            revert PurchaseReceiptUnavailable(
                marketRegistry.authorizedSwap()
            );
        }

        uint256 grossUsd18 = agntAmount == refundableAgnt
            ? refundableUsd18
            : Math.mulDiv(
                refundableUsd18,
                agntAmount,
                refundableAgnt
            );
        quote.grossUsdt = grossUsd18 / usdtScale;
        if (quote.grossUsdt != 0) {
            quote.agntPerUsd18 = Math.mulDiv(
                agntAmount,
                ONE,
                quote.grossUsdt * usdtScale
            );
        }
        quote.usesPresaleCostBasis = true;
        quote.nextAccountedAgntBought = refundAccount.accountedAgntBought;
        quote.nextAccountedUsdContributed18 = refundAccount
            .accountedUsdContributed18;
        quote.nextRefundableAgnt = refundableAgnt - agntAmount;
        quote.nextRefundableUsd18 = agntAmount == refundableAgnt
            ? 0
            : refundableUsd18 - quote.grossUsdt * usdtScale;
        return quote;
    }

    function _syncedPresaleRefundAccount(address account)
        internal
        view
        returns (PresaleRefundAccount memory refundAccount)
    {
        address sourceAddress = marketRegistry.authorizedSwap();
        if (sourceAddress == address(0) || sourceAddress.code.length == 0) {
            revert PurchaseReceiptUnavailable(sourceAddress);
        }

        IAegentPurchaseReceiptSource source =
            IAegentPurchaseReceiptSource(sourceAddress);
        uint256 bought;
        uint256 contributedUsd18;
        try source.walletAgntBought(account) returns (uint256 value) {
            bought = value;
        } catch {
            revert PurchaseReceiptUnavailable(sourceAddress);
        }
        try source.walletUsdContributed18(account) returns (uint256 value) {
            contributedUsd18 = value;
        } catch {
            revert PurchaseReceiptUnavailable(sourceAddress);
        }

        refundAccount = presaleRefundAccounts[account];
        if (
            bought < refundAccount.accountedAgntBought ||
            contributedUsd18 <
            refundAccount.accountedUsdContributed18
        ) {
            revert InvalidPurchaseReceiptState(account);
        }

        refundAccount.refundableAgnt =
            refundAccount.refundableAgnt +
            (bought - refundAccount.accountedAgntBought);
        refundAccount.refundableUsd18 =
            refundAccount.refundableUsd18 +
            (contributedUsd18 -
                refundAccount.accountedUsdContributed18);
        refundAccount.accountedAgntBought = bought;
        refundAccount.accountedUsdContributed18 = contributedUsd18;
    }

    function _activeTerms()
        internal
        view
        returns (IAegentMarketRegistry.RedemptionTerms memory terms)
    {
        address configuredContract = marketRegistry.redemptionContract();
        if (configuredContract != address(this)) {
            revert UnauthorizedRedemptionContract(configuredContract);
        }
        terms = marketRegistry.redemptionTerms();
        if (!terms.enabled) {
            revert RedemptionUnavailable();
        }
    }

    function _collectAgnt(address account, uint256 amount) internal {
        uint256 balanceBefore = agnt.balanceOf(address(this));
        IERC20(address(agnt)).safeTransferFrom(
            account,
            address(this),
            amount
        );
        uint256 balanceAfter = agnt.balanceOf(address(this));
        if (balanceAfter - balanceBefore != amount) {
            revert FeeOnTransferUnsupported(address(agnt));
        }
    }

    function _deliverUsdt(address account, uint256 amount) internal {
        uint256 balanceBefore = usdt.balanceOf(account);
        IERC20(address(usdt)).safeTransfer(account, amount);
        uint256 balanceAfter = usdt.balanceOf(account);
        if (balanceAfter - balanceBefore != amount) {
            revert FeeOnTransferUnsupported(address(usdt));
        }
    }

    function _deliverClaimedAgnt(address account, uint256 amount) internal {
        uint256 balanceBefore = agnt.balanceOf(account);
        IERC20(address(agnt)).safeTransfer(account, amount);
        uint256 balanceAfter = agnt.balanceOf(account);
        if (balanceAfter - balanceBefore != amount) {
            revert FeeOnTransferUnsupported(address(agnt));
        }
    }

    function _requireRedemptionDisabled() internal view {
        if (marketRegistry.isRedemptionEnabled()) {
            revert ConfigurationRequiresPausedMode();
        }
    }

    function _requirePausedPostLaunch() internal view {
        if (
            block.timestamp < marketRegistry.saleEnd() ||
            marketRegistry.mode() !=
            IAegentMarketRegistry.MarketMode.PAUSED
        ) {
            revert ConfigurationRequiresPausedMode();
        }
    }

    function _requireCode(address candidate) internal view {
        if (candidate.code.length == 0) {
            revert AddressHasNoCode(candidate);
        }
    }

    receive() external payable {
        revert DirectNativeTransferDisabled();
    }
}
