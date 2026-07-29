const { expect } = require("chai");
const { ethers } = require("hardhat");
const { time } = require("@nomicfoundation/hardhat-network-helpers");

const DAY = 24 * 60 * 60;

describe("Aegent V2 purchase and presale-refund integration", function () {
  it("commits endpoint addresses and refunds a phase-1 USDT purchase at cost basis in phase 3", async function () {
    const [owner, beneficiary, alice, bob] = await ethers.getSigners();
    const now = await time.latest();
    const saleStart = now + 120;
    const saleEnd = saleStart + 90 * DAY;

    const Token = await ethers.getContractFactory("MockERC20");
    const agnt = await Token.deploy("Aegent", "AGNT", 18);
    const usdt = await Token.deploy("Tether USD", "USDT", 6);
    const usdc = await Token.deploy("USD Coin", "USDC", 6);

    const Oracle = await ethers.getContractFactory("MockAggregatorV3");
    const bnbUsdFeed = await Oracle.deploy(8, 600n * 10n ** 8n);
    const usdtUsdFeed = await Oracle.deploy(8, 1n * 10n ** 8n);
    const usdcUsdFeed = await Oracle.deploy(8, 1n * 10n ** 8n);

    const deploymentNonce = await ethers.provider.getTransactionCount(
      owner.address
    );
    const expectedRegistry = ethers.getCreateAddress({
      from: owner.address,
      nonce: deploymentNonce,
    });
    const expectedSwap = ethers.getCreateAddress({
      from: owner.address,
      nonce: deploymentNonce + 1,
    });
    const expectedRedemption = ethers.getCreateAddress({
      from: owner.address,
      nonce: deploymentNonce + 2,
    });

    const Registry = await ethers.getContractFactory("AegentMarketRegistry");
    const registry = await Registry.deploy(
      saleStart,
      saleEnd,
      expectedSwap,
      expectedRedemption,
      owner.address
    );

    const Swap = await ethers.getContractFactory("AegentSwapV2");
    const swap = await Swap.deploy(
      await agnt.getAddress(),
      await usdt.getAddress(),
      await usdc.getAddress(),
      await bnbUsdFeed.getAddress(),
      await usdtUsdFeed.getAddress(),
      await usdcUsdFeed.getAddress(),
      expectedRegistry,
      beneficiary.address,
      owner.address,
      60 * 60,
      ethers.parseUnits("1000000", 18)
    );

    const Redemption = await ethers.getContractFactory("AegentRedemptionV2");
    const redemption = await Redemption.deploy(
      await agnt.getAddress(),
      await usdt.getAddress(),
      expectedRegistry,
      owner.address,
      ethers.parseUnits("1000", 6),
      ethers.parseUnits("500", 6),
      ethers.parseUnits("200", 6),
      100
    );

    await Promise.all([
      registry.waitForDeployment(),
      swap.waitForDeployment(),
      redemption.waitForDeployment(),
    ]);
    expect(await registry.getAddress()).to.equal(expectedRegistry);
    expect(await swap.getAddress()).to.equal(expectedSwap);
    expect(await redemption.getAddress()).to.equal(expectedRedemption);
    expect(await registry.endpointBindingsReady()).to.deep.equal([true, true]);

    const vaultAddress = await swap.proceedsVault();
    const vault = await ethers.getContractAt(
      "AegentSaleProceedsVault",
      vaultAddress
    );
    const purchaseAmount = ethers.parseUnits("100", 6);
    const bobPurchaseAmount = ethers.parseUnits("50", 6);
    const totalPurchaseAmount = purchaseAmount + bobPurchaseAmount;
    const purchasedAgnt = ethers.parseUnits("1000", 18);
    const bobPurchasedAgnt = ethers.parseUnits("500", 18);
    const totalPurchasedAgnt = purchasedAgnt + bobPurchasedAgnt;

    await agnt.mint(await swap.getAddress(), totalPurchasedAgnt);
    await usdt.mint(alice.address, purchaseAmount);
    await usdt.connect(alice).approve(await swap.getAddress(), purchaseAmount);
    await usdt.mint(bob.address, bobPurchaseAmount);
    await usdt.connect(bob).approve(await swap.getAddress(), bobPurchaseAmount);
    await usdt.mint(owner.address, totalPurchaseAmount);
    await usdt
      .connect(owner)
      .approve(await redemption.getAddress(), totalPurchaseAmount);
    await redemption.connect(owner).fundReserve(totalPurchaseAmount);

    await registry.setMode(0); // OPEN
    await time.increaseTo(saleStart);
    expect(await registry.currentPhase()).to.deep.equal([
      1n,
      ethers.parseUnits("10", 18),
      90n * BigInt(DAY),
    ]);

    const purchaseDeadline = (await time.latest()) + 300;
    await swap.connect(alice).swapUSDT(
      purchaseAmount,
      1,
      0,
      0,
      1,
      purchasedAgnt,
      purchaseDeadline
    );
    await swap.connect(bob).swapUSDT(
      bobPurchaseAmount,
      1,
      0,
      0,
      1,
      bobPurchasedAgnt,
      purchaseDeadline
    );

    expect(await agnt.balanceOf(alice.address)).to.equal(0n);
    expect(await agnt.balanceOf(bob.address)).to.equal(0n);
    expect(await agnt.balanceOf(await redemption.getAddress())).to.equal(
      totalPurchasedAgnt
    );
    expect(await usdt.balanceOf(vaultAddress)).to.equal(totalPurchaseAmount);
    expect(await usdt.balanceOf(beneficiary.address)).to.equal(0n);
    expect(await swap.walletAgntBought(alice.address)).to.equal(purchasedAgnt);
    expect(await swap.walletUsdContributed18(alice.address)).to.equal(
      ethers.parseUnits("100", 18)
    );
    expect(await redemption.presaleOutstandingLiabilityUsdt()).to.equal(
      totalPurchaseAmount
    );
    expect(await usdt.balanceOf(await redemption.getAddress())).to.equal(
      totalPurchaseAmount
    );
    await expect(vault.releaseToken(await usdt.getAddress()))
      .to.be.revertedWithCustomError(vault, "ProceedsLocked");

    await time.increaseTo(saleEnd - 60 * DAY);
    expect((await registry.currentPhase()).slice(0, 2)).to.deep.equal([
      2n,
      ethers.parseUnits("7", 18),
    ]);
    await time.increaseTo(saleEnd - 30 * DAY);
    expect((await registry.currentPhase()).slice(0, 2)).to.deep.equal([
      3n,
      ethers.parseUnits("3", 18),
    ]);

    await registry.setMode(2); // REDEMPTION_ONLY
    const redemptionTerms = await registry.redemptionTerms();
    expect(redemptionTerms.enabled).to.equal(true);
    expect(redemptionTerms.phaseId).to.equal(3n);
    expect(redemptionTerms.agntPerUsd18).to.equal(0n);

    const quote = await redemption.previewRedemption(
      alice.address,
      purchasedAgnt
    );
    expect(quote.usesPresaleCostBasis).to.equal(true);
    expect(quote.agntPerUsd18).to.equal(ethers.parseUnits("10", 18));
    expect(quote.grossUsdt).to.equal(purchaseAmount);
    expect(quote.feeUsdt).to.equal(ethers.parseUnits("1", 6));
    expect(quote.netUsdt).to.equal(ethers.parseUnits("99", 6));

    const redemptionDeadline = (await time.latest()) + 300;
    await redemption.connect(alice).redeem(
      purchasedAgnt,
      3,
      2,
      2,
      0,
      ethers.parseUnits("99", 6),
      redemptionDeadline,
      await redemption.nextRedemptionNonce(alice.address)
    );

    expect(await usdt.balanceOf(alice.address)).to.equal(
      ethers.parseUnits("99", 6)
    );
    expect(await usdt.balanceOf(await redemption.getAddress())).to.equal(
      ethers.parseUnits("51", 6)
    );
    expect(await agnt.balanceOf(await redemption.getAddress())).to.equal(
      totalPurchasedAgnt
    );
    expect(await redemption.totalPresaleGrossUsdtRefunded()).to.equal(
      purchaseAmount
    );
    expect(await redemption.presaleOutstandingLiabilityUsdt()).to.equal(
      bobPurchaseAmount
    );
    expect(await redemption.presaleOutstandingAgntClaims()).to.equal(
      bobPurchasedAgnt
    );
    expect(await usdt.balanceOf(vaultAddress)).to.equal(totalPurchaseAmount);

    await time.increaseTo(saleEnd);
    await expect(
      redemption
        .connect(owner)
        .withdrawRedeemedAgnt(
          owner.address,
          purchasedAgnt + ethers.parseUnits("1", 18)
        )
    ).to.be.revertedWithCustomError(redemption, "InsufficientUnlockedAgnt");
    await redemption
      .connect(owner)
      .withdrawRedeemedAgnt(owner.address, purchasedAgnt);
    expect(await redemption.presaleOutstandingAgntClaims()).to.equal(
      bobPurchasedAgnt
    );
    await redemption.connect(bob).claimPurchasedAgnt();
    expect(await agnt.balanceOf(bob.address)).to.equal(bobPurchasedAgnt);
    expect(await redemption.presaleOutstandingAgntClaims()).to.equal(0n);
    expect(await redemption.presaleOutstandingLiabilityUsdt()).to.equal(0n);

    await vault.releaseToken(await usdt.getAddress());
    expect(await usdt.balanceOf(beneficiary.address)).to.equal(
      totalPurchaseAmount
    );
    expect(await usdt.balanceOf(vaultAddress)).to.equal(0n);
  });
});
