// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {Ownable2Step} from "@openzeppelin/contracts/access/Ownable2Step.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";
import {AegentSaleProceedsVault} from "./AegentSaleProceedsVault.sol";
import {IAegentMarketRegistry} from "./interfaces/IAegentMarketRegistry.sol";
import {IAegentSaleProceedsVault} from "./interfaces/IAegentSaleProceedsVault.sol";
import {IAggregatorV3} from "./interfaces/IAggregatorV3.sol";

/// @title AegentSwapV2
/// @notice Inventory-backed AGNT purchases using BNB, USDT or USDC.
/// @dev Price, phase, market mode and limited-window terms come from one immutable
///      registry. The contract has no arbitrary price setter or upgrade proxy.
contract AegentSwapV2 is Ownable2Step, ReentrancyGuard {
    using SafeERC20 for IERC20;

    uint256 private constant ONE = 1e18;
    bytes32 public constant ENDPOINT_KIND = keccak256("AEGENT_SWAP_V2");
    uint48 public constant MAX_ORACLE_AGE = 6 hours;
    uint256 public constant MAX_QUOTE_LIFETIME = 5 minutes;

    struct PurchaseRequest {
        uint8 expectedPhaseId;
        IAegentMarketRegistry.MarketMode expectedMode;
        uint64 expectedWindowId;
        uint64 expectedConfigVersion;
        uint256 minAgntOut;
        uint256 deadline;
    }

    error ZeroAddress();
    error ZeroAmount();
    error InvalidAssetConfiguration();
    error AddressHasNoCode(address candidate);
    error UnsupportedDecimals(address asset, uint8 decimals);
    error InvalidOracleAge(uint48 supplied);
    error PurchaseUnavailable();
    error UnauthorizedSwap(address authorizedSwap);
    error QuoteExpired(uint256 deadline, uint256 currentTimestamp);
    error QuoteLifetimeExceeded(uint256 deadline, uint256 maximumDeadline);
    error DeadlineBeyondMarketBoundary(uint256 deadline, uint256 boundary);
    error UnexpectedPhase(uint8 expectedPhaseId, uint8 actualPhaseId);
    error UnexpectedMode(uint8 expectedMode, uint8 actualMode);
    error UnexpectedWindow(uint64 expectedWindowId, uint64 actualWindowId);
    error UnexpectedConfigVersion(
        uint64 expectedVersion,
        uint64 actualVersion
    );
    error MinimumOutputRequired();
    error SlippageExceeded(uint256 minimumOutput, uint256 actualOutput);
    error GlobalSaleCapExceeded(uint256 limit, uint256 attemptedTotal);
    error WindowTotalLimitExceeded(
        uint64 windowId,
        uint256 limit,
        uint256 attemptedTotal
    );
    error WindowWalletLimitExceeded(
        uint64 windowId,
        address wallet,
        uint256 limit,
        uint256 attemptedTotal
    );
    error InsufficientInventory(uint256 required, uint256 available);
    error InvalidOracleAnswer(address feed);
    error StaleOraclePrice(address feed, uint256 updatedAt);
    error FeeOnTransferUnsupported(address asset);
    error NativeTransferFailed();
    error DirectNativeTransferDisabled();
    error PurchaseMustBeDisabled();
    error OwnershipRenunciationDisabled();

    /// @notice Records the paid purchase and its escrow entitlement.
    /// @dev `PurchaseEscrowed` identifies where AGNT is held; this event does
    ///      not represent a direct AGNT delivery to the buyer wallet.
    event PurchaseSettled(
        address indexed buyer,
        address indexed paymentAsset,
        uint256 paymentAmount,
        uint256 usdValue18,
        uint256 agntOut,
        uint8 phaseId,
        uint256 agntPerUsd18,
        uint64 indexed windowId
    );
    event PurchaseEscrowed(
        address indexed buyer,
        address indexed escrow,
        uint256 agntAmount
    );
    event UnsoldInventoryWithdrawn(address indexed recipient, uint256 amount);

    IERC20Metadata public immutable agnt;
    IERC20Metadata public immutable usdt;
    IERC20Metadata public immutable usdc;
    IAggregatorV3 public immutable bnbUsdFeed;
    IAggregatorV3 public immutable usdtUsdFeed;
    IAggregatorV3 public immutable usdcUsdFeed;
    IAegentMarketRegistry public immutable marketRegistry;
    IAegentSaleProceedsVault public immutable proceedsVault;
    uint48 public immutable maxOracleAge;
    uint256 public immutable maxTotalAgntSold;
    uint256 public immutable usdtScale;
    uint256 public immutable usdcScale;
    uint256 public immutable bnbUsdFeedScale;
    uint256 public immutable usdtUsdFeedScale;
    uint256 public immutable usdcUsdFeedScale;

    uint256 public totalAgntSold;
    uint256 public totalUsdContributed18;
    mapping(address wallet => uint256 amount) public walletAgntBought;
    mapping(address wallet => uint256 amount) public walletUsdContributed18;
    mapping(uint64 windowId => uint256 amount) public windowAgntSold;
    mapping(uint64 windowId => mapping(address wallet => uint256 amount))
        public windowWalletAgntBought;

    constructor(
        address agnt_,
        address usdt_,
        address usdc_,
        address bnbUsdFeed_,
        address usdtUsdFeed_,
        address usdcUsdFeed_,
        address marketRegistry_,
        address payable beneficiary_,
        address initialOwner,
        uint48 maxOracleAge_,
        uint256 maxTotalAgntSold_
    ) Ownable(initialOwner) {
        if (
            agnt_ == address(0) ||
            usdt_ == address(0) ||
            usdc_ == address(0) ||
            bnbUsdFeed_ == address(0) ||
            usdtUsdFeed_ == address(0) ||
            usdcUsdFeed_ == address(0) ||
            marketRegistry_ == address(0) ||
            beneficiary_ == address(0)
        ) {
            revert ZeroAddress();
        }
        if (
            agnt_ == usdt_ ||
            agnt_ == usdc_ ||
            usdt_ == usdc_ ||
            bnbUsdFeed_ == usdtUsdFeed_ ||
            bnbUsdFeed_ == usdcUsdFeed_ ||
            usdtUsdFeed_ == usdcUsdFeed_
        ) {
            revert InvalidAssetConfiguration();
        }
        _requireCode(agnt_);
        _requireCode(usdt_);
        _requireCode(usdc_);
        _requireCode(bnbUsdFeed_);
        _requireCode(usdtUsdFeed_);
        _requireCode(usdcUsdFeed_);
        _requireCode(marketRegistry_);

        if (maxOracleAge_ == 0 || maxOracleAge_ > MAX_ORACLE_AGE) {
            revert InvalidOracleAge(maxOracleAge_);
        }
        if (maxTotalAgntSold_ == 0) {
            revert ZeroAmount();
        }

        agnt = IERC20Metadata(agnt_);
        usdt = IERC20Metadata(usdt_);
        usdc = IERC20Metadata(usdc_);
        bnbUsdFeed = IAggregatorV3(bnbUsdFeed_);
        usdtUsdFeed = IAggregatorV3(usdtUsdFeed_);
        usdcUsdFeed = IAggregatorV3(usdcUsdFeed_);
        marketRegistry = IAegentMarketRegistry(marketRegistry_);
        maxOracleAge = maxOracleAge_;
        maxTotalAgntSold = maxTotalAgntSold_;

        uint8 agntDecimals = IERC20Metadata(agnt_).decimals();
        if (agntDecimals != 18) {
            revert UnsupportedDecimals(agnt_, agntDecimals);
        }
        usdtScale = _tokenScale(usdt_);
        usdcScale = _tokenScale(usdc_);
        bnbUsdFeedScale = _feedScale(bnbUsdFeed_);
        usdtUsdFeedScale = _feedScale(usdtUsdFeed_);
        usdcUsdFeedScale = _feedScale(usdcUsdFeed_);
        proceedsVault = IAegentSaleProceedsVault(
            address(
                new AegentSaleProceedsVault(
                    marketRegistry_,
                    usdt_,
                    usdc_,
                    beneficiary_
                )
            )
        );
    }

    function endpointKind() external pure returns (bytes32) {
        return ENDPOINT_KIND;
    }

    function quoteBNB(address buyer, uint256 amount)
        external
        view
        returns (
            uint256 usdValue18,
            uint256 agntOut,
            uint8 phaseId,
            uint256 agntPerUsd18
        )
    {
        if (buyer == address(0)) {
            revert ZeroAddress();
        }
        IAegentMarketRegistry.PurchaseTerms memory terms = _activeTerms();
        usdValue18 = _nativeUsdValue(amount);
        phaseId = terms.phaseId;
        agntPerUsd18 = terms.agntPerUsd18;
        agntOut = Math.mulDiv(usdValue18, agntPerUsd18, ONE);
        _ensureCapacity(buyer, agntOut, terms);
    }

    function quoteStable(address buyer, address asset, uint256 amount)
        external
        view
        returns (
            uint256 usdValue18,
            uint256 agntOut,
            uint8 phaseId,
            uint256 agntPerUsd18
        )
    {
        if (buyer == address(0)) {
            revert ZeroAddress();
        }
        IAegentMarketRegistry.PurchaseTerms memory terms = _activeTerms();
        usdValue18 = _stableUsdValue(asset, amount);
        phaseId = terms.phaseId;
        agntPerUsd18 = terms.agntPerUsd18;
        agntOut = Math.mulDiv(usdValue18, agntPerUsd18, ONE);
        _ensureCapacity(buyer, agntOut, terms);
    }

    function swapBNB(
        uint8 expectedPhaseId,
        IAegentMarketRegistry.MarketMode expectedMode,
        uint64 expectedWindowId,
        uint64 expectedConfigVersion,
        uint256 minAgntOut,
        uint256 deadline
    ) external payable nonReentrant returns (uint256 agntOut) {
        if (msg.value == 0) {
            revert ZeroAmount();
        }

        PurchaseRequest memory request = PurchaseRequest({
            expectedPhaseId: expectedPhaseId,
            expectedMode: expectedMode,
            expectedWindowId: expectedWindowId,
            expectedConfigVersion: expectedConfigVersion,
            minAgntOut: minAgntOut,
            deadline: deadline
        });
        IAegentMarketRegistry.PurchaseTerms memory terms = _activeTerms();
        uint256 usdValue18 = _nativeUsdValue(msg.value);
        agntOut = _validateQuote(usdValue18, request, terms);
        _recordPurchase(msg.sender, agntOut, usdValue18, terms);

        _escrowAgnt(msg.sender, agntOut);
        (bool sent, ) = payable(address(proceedsVault)).call{
            value: msg.value
        }("");
        if (!sent) {
            revert NativeTransferFailed();
        }

        _emitPurchase(
            address(0),
            msg.value,
            usdValue18,
            agntOut,
            terms
        );
    }

    function swapUSDT(
        uint256 amount,
        uint8 expectedPhaseId,
        IAegentMarketRegistry.MarketMode expectedMode,
        uint64 expectedWindowId,
        uint64 expectedConfigVersion,
        uint256 minAgntOut,
        uint256 deadline
    ) external nonReentrant returns (uint256 agntOut) {
        return
            _swapStable(
                true,
                amount,
                PurchaseRequest({
                    expectedPhaseId: expectedPhaseId,
                    expectedMode: expectedMode,
                    expectedWindowId: expectedWindowId,
                    expectedConfigVersion: expectedConfigVersion,
                    minAgntOut: minAgntOut,
                    deadline: deadline
                })
            );
    }

    function swapUSDC(
        uint256 amount,
        uint8 expectedPhaseId,
        IAegentMarketRegistry.MarketMode expectedMode,
        uint64 expectedWindowId,
        uint64 expectedConfigVersion,
        uint256 minAgntOut,
        uint256 deadline
    ) external nonReentrant returns (uint256 agntOut) {
        return
            _swapStable(
                false,
                amount,
                PurchaseRequest({
                    expectedPhaseId: expectedPhaseId,
                    expectedMode: expectedMode,
                    expectedWindowId: expectedWindowId,
                    expectedConfigVersion: expectedConfigVersion,
                    minAgntOut: minAgntOut,
                    deadline: deadline
                })
            );
    }

    function withdrawUnsoldAgnt(address recipient, uint256 amount)
        external
        onlyOwner
    {
        _requirePurchasesDisabled();
        if (recipient == address(0)) {
            revert ZeroAddress();
        }
        if (amount == 0) {
            revert ZeroAmount();
        }
        IERC20(address(agnt)).safeTransfer(recipient, amount);
        emit UnsoldInventoryWithdrawn(recipient, amount);
    }

    function renounceOwnership() public view override onlyOwner {
        revert OwnershipRenunciationDisabled();
    }

    function _swapStable(
        bool useUsdt,
        uint256 amount,
        PurchaseRequest memory request
    ) internal returns (uint256 agntOut) {
        IERC20Metadata paymentToken = useUsdt ? usdt : usdc;
        IAegentMarketRegistry.PurchaseTerms memory terms = _activeTerms();
        uint256 usdValue18 = _stableUsdValue(
            address(paymentToken),
            amount
        );
        agntOut = _validateQuote(usdValue18, request, terms);
        _recordPurchase(msg.sender, agntOut, usdValue18, terms);
        _collectStable(paymentToken, amount);
        _escrowAgnt(msg.sender, agntOut);
        _emitPurchase(
            address(paymentToken),
            amount,
            usdValue18,
            agntOut,
            terms
        );
    }

    function _collectStable(IERC20Metadata paymentToken, uint256 amount)
        internal
    {
        address vault = address(proceedsVault);
        uint256 vaultBalanceBefore = paymentToken.balanceOf(vault);
        IERC20(address(paymentToken)).safeTransferFrom(
            msg.sender,
            vault,
            amount
        );
        uint256 vaultBalanceAfter = paymentToken.balanceOf(vault);
        if (vaultBalanceAfter - vaultBalanceBefore != amount) {
            revert FeeOnTransferUnsupported(address(paymentToken));
        }
    }

    function _escrowAgnt(address buyer, uint256 amount) internal {
        address escrow = marketRegistry.redemptionContract();
        uint256 escrowBalanceBefore = agnt.balanceOf(escrow);
        IERC20(address(agnt)).safeTransfer(escrow, amount);
        uint256 escrowBalanceAfter = agnt.balanceOf(escrow);
        if (escrowBalanceAfter - escrowBalanceBefore != amount) {
            revert FeeOnTransferUnsupported(address(agnt));
        }
        emit PurchaseEscrowed(buyer, escrow, amount);
    }

    function _validateQuote(
        uint256 usdValue18,
        PurchaseRequest memory request,
        IAegentMarketRegistry.PurchaseTerms memory terms
    )
        internal
        view
        returns (uint256 agntOut)
    {
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
        if (terms.phaseId != request.expectedPhaseId) {
            revert UnexpectedPhase(request.expectedPhaseId, terms.phaseId);
        }
        if (terms.mode != request.expectedMode) {
            revert UnexpectedMode(
                uint8(request.expectedMode),
                uint8(terms.mode)
            );
        }
        if (terms.windowId != request.expectedWindowId) {
            revert UnexpectedWindow(
                request.expectedWindowId,
                terms.windowId
            );
        }
        if (terms.configVersion != request.expectedConfigVersion) {
            revert UnexpectedConfigVersion(
                request.expectedConfigVersion,
                terms.configVersion
            );
        }
        if (request.minAgntOut == 0) {
            revert MinimumOutputRequired();
        }

        uint256 boundary = terms.phaseEndsAt;
        if (
            terms.mode ==
            IAegentMarketRegistry.MarketMode.LIMITED_WINDOW &&
            terms.windowEndAt < boundary
        ) {
            boundary = terms.windowEndAt;
        }
        if (request.deadline > boundary) {
            revert DeadlineBeyondMarketBoundary(request.deadline, boundary);
        }

        agntOut = Math.mulDiv(usdValue18, terms.agntPerUsd18, ONE);
        if (agntOut < request.minAgntOut) {
            revert SlippageExceeded(request.minAgntOut, agntOut);
        }
        _ensureCapacity(msg.sender, agntOut, terms);
    }

    function _activeTerms()
        internal
        view
        returns (IAegentMarketRegistry.PurchaseTerms memory terms)
    {
        address authorizedSwap = marketRegistry.authorizedSwap();
        if (authorizedSwap != address(this)) {
            revert UnauthorizedSwap(authorizedSwap);
        }
        terms = marketRegistry.purchaseTerms();
        if (!terms.enabled) {
            revert PurchaseUnavailable();
        }
    }

    function _ensureCapacity(
        address buyer,
        uint256 agntOut,
        IAegentMarketRegistry.PurchaseTerms memory terms
    ) internal view {
        uint256 nextGlobalTotal = totalAgntSold + agntOut;
        if (nextGlobalTotal > maxTotalAgntSold) {
            revert GlobalSaleCapExceeded(
                maxTotalAgntSold,
                nextGlobalTotal
            );
        }

        uint256 inventory = agnt.balanceOf(address(this));
        if (inventory < agntOut) {
            revert InsufficientInventory(agntOut, inventory);
        }

        if (
            terms.mode !=
            IAegentMarketRegistry.MarketMode.LIMITED_WINDOW
        ) {
            return;
        }

        uint256 nextWindowTotal = windowAgntSold[terms.windowId] + agntOut;
        if (nextWindowTotal > terms.windowTotalAgntCap) {
            revert WindowTotalLimitExceeded(
                terms.windowId,
                terms.windowTotalAgntCap,
                nextWindowTotal
            );
        }

        uint256 nextWalletTotal = windowWalletAgntBought[terms.windowId][buyer] +
            agntOut;
        if (nextWalletTotal > terms.windowWalletAgntCap) {
            revert WindowWalletLimitExceeded(
                terms.windowId,
                buyer,
                terms.windowWalletAgntCap,
                nextWalletTotal
            );
        }
    }

    function _recordPurchase(
        address buyer,
        uint256 agntOut,
        uint256 usdValue18,
        IAegentMarketRegistry.PurchaseTerms memory terms
    ) internal {
        totalAgntSold += agntOut;
        totalUsdContributed18 += usdValue18;
        walletAgntBought[buyer] += agntOut;
        walletUsdContributed18[buyer] += usdValue18;
        if (
            terms.mode ==
            IAegentMarketRegistry.MarketMode.LIMITED_WINDOW
        ) {
            windowAgntSold[terms.windowId] += agntOut;
            windowWalletAgntBought[terms.windowId][buyer] += agntOut;
        }
    }

    function _stableUsdValue(address asset, uint256 amount)
        internal
        view
        returns (uint256 usdValue18)
    {
        if (amount == 0) {
            revert ZeroAmount();
        }

        uint256 normalizedAmount;
        uint256 price18;
        if (asset == address(usdt)) {
            normalizedAmount = amount * usdtScale;
            price18 = _oraclePrice18(usdtUsdFeed, usdtUsdFeedScale);
        } else if (asset == address(usdc)) {
            normalizedAmount = amount * usdcScale;
            price18 = _oraclePrice18(usdcUsdFeed, usdcUsdFeedScale);
        } else {
            revert InvalidAssetConfiguration();
        }

        // A downward depeg reduces AGNT output. An upward deviation never grants
        // more than the advertised one-dollar stablecoin reference.
        price18 = Math.min(price18, ONE);
        usdValue18 = Math.mulDiv(normalizedAmount, price18, ONE);
    }

    function _nativeUsdValue(uint256 amount)
        internal
        view
        returns (uint256 usdValue18)
    {
        if (amount == 0) {
            revert ZeroAmount();
        }
        uint256 price18 = _oraclePrice18(
            bnbUsdFeed,
            bnbUsdFeedScale
        );
        usdValue18 = Math.mulDiv(amount, price18, ONE);
    }

    function _oraclePrice18(IAggregatorV3 feed, uint256 feedScale)
        internal
        view
        returns (uint256 price18)
    {
        (
            uint80 roundId,
            int256 answer,
            ,
            uint256 updatedAt,
            uint80 answeredInRound
        ) = feed.latestRoundData();
        if (
            answer <= 0 ||
            updatedAt == 0 ||
            updatedAt > block.timestamp ||
            answeredInRound < roundId
        ) {
            revert InvalidOracleAnswer(address(feed));
        }
        if (block.timestamp - updatedAt > maxOracleAge) {
            revert StaleOraclePrice(address(feed), updatedAt);
        }
        price18 = uint256(answer) * feedScale;
    }

    function _requirePurchasesDisabled() internal view {
        if (
            block.timestamp < marketRegistry.saleEnd() &&
            marketRegistry.mode() !=
            IAegentMarketRegistry.MarketMode.PAUSED
        ) {
            revert PurchaseMustBeDisabled();
        }
    }

    function _tokenScale(address token) internal view returns (uint256 scale) {
        uint8 decimals = IERC20Metadata(token).decimals();
        if (decimals > 18) {
            revert UnsupportedDecimals(token, decimals);
        }
        scale = 10 ** (18 - decimals);
    }

    function _feedScale(address feed) internal view returns (uint256 scale) {
        uint8 decimals = IAggregatorV3(feed).decimals();
        if (decimals > 18) {
            revert UnsupportedDecimals(feed, decimals);
        }
        scale = 10 ** (18 - decimals);
    }

    function _requireCode(address candidate) internal view {
        if (candidate.code.length == 0) {
            revert AddressHasNoCode(candidate);
        }
    }

    function _emitPurchase(
        address paymentAsset,
        uint256 paymentAmount,
        uint256 usdValue18,
        uint256 agntOut,
        IAegentMarketRegistry.PurchaseTerms memory terms
    ) internal {
        emit PurchaseSettled(
            msg.sender,
            paymentAsset,
            paymentAmount,
            usdValue18,
            agntOut,
            terms.phaseId,
            terms.agntPerUsd18,
            terms.windowId
        );
    }

    receive() external payable {
        revert DirectNativeTransferDisabled();
    }
}
