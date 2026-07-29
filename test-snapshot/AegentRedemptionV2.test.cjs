const { expect } = require("chai");
const { ethers } = require("hardhat");
const { loadFixture, time } = require("@nomicfoundation/hardhat-network-helpers");

const DAY = 24 * 60 * 60;

describe("AegentRedemptionV2", function () {
  async function deployFixture(options = {}) {
    const { fundEscrow = true } = options;
    const [owner, alice, bob] = await ethers.getSigners();
    const now = await time.latest();
    const saleStart = now + 60;
    const saleEnd = saleStart + 90 * DAY;

    const Token = await ethers.getContractFactory("MockERC20");
    const agnt = await Token.deploy("Aegent", "AGNT", 18);
    const usdt = await Token.deploy("Tether USD", "USDT", 6);

    const Registry = await ethers.getContractFactory("AegentMarketRegistry");
    const nonce = await ethers.provider.getTransactionCount(owner.address);
    const expectedSwap = ethers.getCreateAddress({
      from: owner.address,
      nonce: nonce + 1,
    });
    const expectedRedemption = ethers.getCreateAddress({
      from: owner.address,
      nonce: nonce + 2,
    });
    const registry = await Registry.deploy(
      saleStart,
      saleEnd,
      expectedSwap,
      expectedRedemption,
      owner.address
    );
    const Endpoint = await ethers.getContractFactory("MockSwapEndpoint");
    const swapEndpoint = await Endpoint.deploy(await registry.getAddress());
    expect(await swapEndpoint.getAddress()).to.equal(expectedSwap);

    const Redemption = await ethers.getContractFactory("AegentRedemptionV2");
    const redemption = await Redemption.deploy(
      await agnt.getAddress(),
      await usdt.getAddress(),
      await registry.getAddress(),
      owner.address,
      ethers.parseUnits("1000", 6),
      ethers.parseUnits("400", 6),
      ethers.parseUnits("200", 6),
      100
    );
    await redemption.waitForDeployment();
    await redemption.endpointKind();
    const RedemptionKind = await registry.REDEMPTION_ENDPOINT_KIND();
    expect(await redemption.endpointKind()).to.equal(RedemptionKind);
    expect(await redemption.getAddress()).to.equal(expectedRedemption);

    await usdt.mint(await redemption.getAddress(), ethers.parseUnits("10000", 6));
    for (const user of [alice, bob]) {
      await agnt.mint(user.address, ethers.parseUnits("10000", 18));
      await agnt.connect(user).approve(await redemption.getAddress(), ethers.MaxUint256);
    }
    await swapEndpoint.setPurchaseReceipt(
      alice.address,
      ethers.parseUnits("1000", 18),
      ethers.parseUnits("100", 18)
    );
    await swapEndpoint.setPurchaseReceipt(
      bob.address,
      ethers.parseUnits("10000", 18),
      ethers.parseUnits("1000", 18)
    );
    if (fundEscrow) {
      await agnt.mint(
        await redemption.getAddress(),
        ethers.parseUnits("11000", 18)
      );
    }

    await time.increaseTo(saleStart);
    await registry.setMode(2); // REDEMPTION_ONLY

    return {
      owner,
      alice,
      bob,
      saleStart,
      saleEnd,
      agnt,
      usdt,
      registry,
      swapEndpoint,
      redemption
    };
  }

  async function deadlineIn(seconds = 300) {
    return (await time.latest()) + seconds;
  }

  async function deployPostLaunchFixture() {
    const fixture = await deployFixture();
    await time.increaseTo(fixture.saleEnd);
    await fixture.registry.setMode(3); // PAUSED while configuring
    await fixture.redemption.proposePostLaunchRate(ethers.parseUnits("5", 18));
    await time.increase(DAY);
    await fixture.redemption.activatePostLaunchRate();
    await fixture.registry.setMode(4); // POST_LAUNCH_REDEMPTION
    return fixture;
  }

  async function deployUnderfundedEscrowFixture() {
    return deployFixture({ fundEscrow: false });
  }

  it("refunds presale purchases at the wallet's actual cost basis", async function () {
    const { alice, agnt, registry, redemption, usdt } =
      await loadFixture(deployFixture);
    expect(await registry.isPurchaseEnabled()).to.equal(false);
    expect(await registry.isRedemptionEnabled()).to.equal(true);
    const walletAgntBefore = await agnt.balanceOf(alice.address);
    await agnt.connect(alice).approve(await redemption.getAddress(), 0);

    await redemption.connect(alice).redeem(
      ethers.parseUnits("1000", 18),
      1,
      2,
      1,
      0,
      ethers.parseUnits("99", 6),
      await deadlineIn(),
      await redemption.nextRedemptionNonce(alice.address)
    );

    expect(await usdt.balanceOf(alice.address)).to.equal(ethers.parseUnits("99", 6));
    expect(await agnt.balanceOf(alice.address)).to.equal(walletAgntBefore);
    const account = await redemption.presaleRefundAccounts(alice.address);
    expect(account.refundableAgnt).to.equal(0n);
    expect(account.refundableUsd18).to.equal(0n);
  });

  it("does not create 10/7/3 cross-phase redemption arbitrage", async function () {
    const { alice, saleEnd, registry, redemption, usdt } =
      await loadFixture(deployFixture);

    await time.increaseTo(saleEnd - 30 * DAY);
    expect((await registry.currentPhase())[1]).to.equal(
      ethers.parseUnits("3", 18)
    );
    const terms = await registry.redemptionTerms();
    expect(terms.agntPerUsd18).to.equal(0n);

    const preview = await redemption.previewRedemption(
      alice.address,
      ethers.parseUnits("1000", 18)
    );
    expect(preview.grossUsdt).to.equal(ethers.parseUnits("100", 6));
    expect(preview.netUsdt).to.equal(ethers.parseUnits("99", 6));

    await redemption.connect(alice).redeem(
      ethers.parseUnits("1000", 18),
      3,
      2,
      1,
      0,
      ethers.parseUnits("99", 6),
      await deadlineIn(),
      await redemption.nextRedemptionNonce(alice.address)
    );
    expect(await usdt.balanceOf(alice.address)).to.equal(
      ethers.parseUnits("99", 6)
    );

    await expect(
      redemption.connect(alice).redeem(
        ethers.parseUnits("1", 18),
        3,
        2,
        1,
        0,
        1,
        await deadlineIn(),
        await redemption.nextRedemptionNonce(alice.address)
      )
    ).to.be.revertedWithCustomError(
      redemption,
      "PresaleRefundExceedsEntitlement"
    );
  });

  it("keeps cost-basis accounting sound across partial refunds and later purchases", async function () {
    const { alice, agnt, swapEndpoint, redemption, usdt } =
      await loadFixture(deployFixture);

    await redemption.connect(alice).redeem(
      ethers.parseUnits("500", 18),
      1,
      2,
      1,
      0,
      ethers.parseUnits("49.5", 6),
      await deadlineIn(),
      await redemption.nextRedemptionNonce(alice.address)
    );
    await swapEndpoint.setPurchaseReceipt(
      alice.address,
      ethers.parseUnits("1700", 18),
      ethers.parseUnits("200", 18)
    );
    await agnt.mint(
      await redemption.getAddress(),
      ethers.parseUnits("700", 18)
    );

    const preview = await redemption.previewRedemption(
      alice.address,
      ethers.parseUnits("1200", 18)
    );
    expect(preview.grossUsdt).to.equal(ethers.parseUnits("150", 6));
    expect(preview.nextRefundableAgnt).to.equal(0n);
    expect(preview.nextRefundableUsd18).to.equal(0n);

    await redemption.connect(alice).redeem(
      ethers.parseUnits("1200", 18),
      1,
      2,
      1,
      0,
      ethers.parseUnits("148.5", 6),
      await deadlineIn(),
      await redemption.nextRedemptionNonce(alice.address)
    );
    expect(await usdt.balanceOf(alice.address)).to.equal(
      ethers.parseUnits("198", 6)
    );
    expect(await redemption.totalPresaleGrossUsdtRefunded()).to.equal(
      ethers.parseUnits("200", 6)
    );
  });

  it("keeps presale redemption closed unless reserve covers all outstanding cost basis", async function () {
    const { owner, alice, agnt, registry, redemption, swapEndpoint } =
      await loadFixture(deployFixture);
    await registry.setMode(3); // PAUSED
    await redemption.connect(owner).withdrawReserve(
      owner.address,
      ethers.parseUnits("8900", 6)
    );
    await agnt.mint(
      await redemption.getAddress(),
      ethers.parseUnits("1000", 18)
    );
    await swapEndpoint.setPurchaseReceipt(
      alice.address,
      ethers.parseUnits("2000", 18),
      ethers.parseUnits("300", 18)
    );
    await registry.setMode(2); // REDEMPTION_ONLY

    expect(await redemption.presaleOutstandingLiabilityUsdt()).to.equal(
      ethers.parseUnits("1300", 6)
    );
    expect(await registry.isRedemptionEnabled()).to.equal(false);
    await expect(
      redemption.connect(alice).redeem(
        ethers.parseUnits("1", 18),
        1,
        2,
        3,
        0,
        1,
        await deadlineIn(),
        await redemption.nextRedemptionNonce(alice.address)
      )
    ).to.be.revertedWithCustomError(redemption, "RedemptionUnavailable");
  });

  it("locks presale refund liability and permits only excess reserve withdrawals", async function () {
    const { owner, redemption, registry, usdt } =
      await loadFixture(deployFixture);
    const liability = ethers.parseUnits("1100", 6);
    const excess = ethers.parseUnits("8900", 6);
    await registry.setMode(3); // PAUSED

    await expect(
      redemption.connect(owner).withdrawReserve(
        owner.address,
        excess + 1n
      )
    )
      .to.be.revertedWithCustomError(
        redemption,
        "InsufficientUnlockedReserve"
      )
      .withArgs(excess + 1n, excess);

    await redemption.connect(owner).withdrawReserve(owner.address, excess);
    expect(await usdt.balanceOf(await redemption.getAddress())).to.equal(
      liability
    );
    await expect(
      redemption.connect(owner).withdrawReserve(owner.address, 1)
    )
      .to.be.revertedWithCustomError(
        redemption,
        "InsufficientUnlockedReserve"
      )
      .withArgs(1, 0);
  });

  it("fails reserve withdrawals closed when aggregate purchase receipts cannot be read", async function () {
    const { owner, redemption, swapEndpoint } =
      await loadFixture(deployFixture);
    await swapEndpoint.setAggregateReadFailure(true);

    expect(await redemption.presaleOutstandingLiabilityUsdt()).to.equal(
      ethers.MaxUint256
    );
    await expect(
      redemption.connect(owner).withdrawReserve(owner.address, 1)
    )
      .to.be.revertedWithCustomError(
        redemption,
        "InsufficientUnlockedReserve"
      )
      .withArgs(1, 0);
  });

  it("releases the refund reserve lock at saleEnd while preserving AGNT claims", async function () {
    const { owner, alice, agnt, saleEnd, redemption, usdt } =
      await loadFixture(deployFixture);
    await time.increaseTo(saleEnd);

    const reserve = await usdt.balanceOf(await redemption.getAddress());
    await redemption.connect(owner).withdrawReserve(owner.address, reserve);
    expect(await usdt.balanceOf(await redemption.getAddress())).to.equal(0n);

    const walletBefore = await agnt.balanceOf(alice.address);
    await redemption.connect(alice).claimPurchasedAgnt();
    expect(await agnt.balanceOf(alice.address)).to.equal(
      walletBefore + ethers.parseUnits("1000", 18)
    );
  });

  it("fails presale redemption closed when escrow AGNT does not cover claims", async function () {
    const { alice, registry, redemption } =
      await loadFixture(deployUnderfundedEscrowFixture);

    expect(await registry.isRedemptionEnabled()).to.equal(false);
    await expect(
      redemption.connect(alice).redeem(
        ethers.parseUnits("1000", 18),
        1,
        2,
        1,
        0,
        ethers.parseUnits("99", 6),
        await deadlineIn(),
        await redemption.nextRedemptionNonce(alice.address)
      )
    ).to.be.revertedWithCustomError(redemption, "RedemptionUnavailable");
  });

  it("opens purchased-AGNT claims exactly at saleEnd and rejects repeat claims", async function () {
    const { alice, agnt, saleEnd, redemption } =
      await loadFixture(deployFixture);

    await expect(redemption.connect(alice).claimPurchasedAgnt())
      .to.be.revertedWithCustomError(redemption, "PresaleClaimNotReady");

    await time.increaseTo(saleEnd);
    const walletBefore = await agnt.balanceOf(alice.address);
    await expect(redemption.connect(alice).claimPurchasedAgnt())
      .to.emit(redemption, "PurchasedAgntClaimed")
      .withArgs(
        alice.address,
        ethers.parseUnits("1000", 18),
        ethers.parseUnits("100", 18)
      );
    expect(await agnt.balanceOf(alice.address)).to.equal(
      walletBefore + ethers.parseUnits("1000", 18)
    );
    expect(await redemption.claimablePurchasedAgnt(alice.address)).to.deep.equal(
      [0n, 0n]
    );
    await expect(redemption.connect(alice).claimPurchasedAgnt())
      .to.be.revertedWithCustomError(redemption, "NothingToClaim")
      .withArgs(alice.address);
  });

  it("never lets the owner withdraw AGNT reserved for unclaimed purchases", async function () {
    const { owner, alice, agnt, saleEnd, redemption } =
      await loadFixture(deployFixture);

    await time.increaseTo(saleEnd);
    await expect(
      redemption.connect(owner).withdrawRedeemedAgnt(
        owner.address,
        ethers.parseUnits("1", 18)
      )
    )
      .to.be.revertedWithCustomError(
        redemption,
        "InsufficientUnlockedAgnt"
      )
      .withArgs(ethers.parseUnits("1", 18), 0);

    await redemption.connect(alice).claimPurchasedAgnt();
    expect(await agnt.balanceOf(await redemption.getAddress())).to.equal(
      ethers.parseUnits("10000", 18)
    );
  });

  it("keeps post-launch redemption closed until an independent delayed rate is activated", async function () {
    const { alice, saleEnd, registry, redemption, usdt } =
      await loadFixture(deployFixture);

    await time.increaseTo(saleEnd);
    await registry.setMode(4); // POST_LAUNCH_REDEMPTION
    expect(await registry.isRedemptionEnabled()).to.equal(false);
    await expect(
      redemption.connect(alice).redeem(
        ethers.parseUnits("500", 18),
        0,
        4,
        2,
        0,
        ethers.parseUnits("99", 6),
        await deadlineIn(),
        await redemption.nextRedemptionNonce(alice.address)
      )
    ).to.be.revertedWithCustomError(redemption, "RedemptionUnavailable");

    await registry.setMode(3); // PAUSED while configuring
    await redemption.proposePostLaunchRate(ethers.parseUnits("5", 18));
    await time.increase(24 * 60 * 60);
    await redemption.activatePostLaunchRate();
    await registry.setMode(4);
    expect(await registry.isRedemptionEnabled()).to.equal(true);

    await redemption.connect(alice).redeem(
      ethers.parseUnits("500", 18),
      0,
      4,
      4,
      1,
      ethers.parseUnits("99", 6),
      await deadlineIn(),
      await redemption.nextRedemptionNonce(alice.address)
    );

    expect(await usdt.balanceOf(alice.address)).to.equal(ethers.parseUnits("99", 6));
  });

  it("enforces the manual-review threshold and daily wallet limit", async function () {
    const { alice, redemption } = await loadFixture(deployPostLaunchFixture);

    await expect(
      redemption.connect(alice).redeem(
        ethers.parseUnits("1005", 18),
        0,
        4,
        3,
        1,
        1,
        await deadlineIn(),
        await redemption.nextRedemptionNonce(alice.address)
      )
    ).to.be.revertedWithCustomError(redemption, "ManualReviewRequired");

    for (let i = 0; i < 2; i += 1) {
      await redemption.connect(alice).redeem(
        ethers.parseUnits("1000", 18),
        0,
        4,
        3,
        1,
        ethers.parseUnits("198", 6),
        await deadlineIn(),
        await redemption.nextRedemptionNonce(alice.address)
      );
    }

    await expect(
      redemption.connect(alice).redeem(
        ethers.parseUnits("5", 18),
        0,
        4,
        3,
        1,
        ethers.parseUnits("0.99", 6),
        await deadlineIn(),
        await redemption.nextRedemptionNonce(alice.address)
      )
    ).to.be.revertedWithCustomError(redemption, "WalletDailyLimitExceeded");
  });

  it("fails closed outside redemption modes and when reserve is insufficient", async function () {
    const { owner, alice, registry, redemption } =
      await loadFixture(deployPostLaunchFixture);

    await registry.setMode(3); // PAUSED
    await expect(
      redemption.connect(alice).redeem(
        ethers.parseUnits("10", 18),
        0,
        3,
        4,
        1,
        1,
        await deadlineIn(),
        await redemption.nextRedemptionNonce(alice.address)
      )
    ).to.be.revertedWithCustomError(redemption, "RedemptionUnavailable");

    await redemption.connect(owner).withdrawReserve(
      owner.address,
      ethers.parseUnits("9999", 6)
    );
    await registry.setMode(4);
    await expect(
      redemption.connect(alice).redeem(
        ethers.parseUnits("10", 18),
        0,
        4,
        5,
        1,
        ethers.parseUnits("1.98", 6),
        await deadlineIn(),
        await redemption.nextRedemptionNonce(alice.address)
      )
    ).to.be.revertedWithCustomError(redemption, "RedemptionUnavailable");
  });

  it("rejects redemption requests with a deadline beyond five minutes", async function () {
    const { alice, redemption } = await loadFixture(deployPostLaunchFixture);
    await expect(
      redemption.connect(alice).redeem(
        ethers.parseUnits("5", 18),
        0,
        4,
        3,
        1,
        ethers.parseUnits("0.99", 6),
        await deadlineIn(302),
        await redemption.nextRedemptionNonce(alice.address)
      )
    ).to.be.revertedWithCustomError(redemption, "QuoteLifetimeExceeded");
  });

  it("consumes one wallet execution nonce and rejects replayed redemption calldata", async function () {
    const { alice, redemption } = await loadFixture(deployFixture);
    const amount = ethers.parseUnits("100", 18);
    const grossUsdt = ethers.parseUnits("10", 6);
    const feeUsdt = ethers.parseUnits("0.1", 6);
    const netUsdt = ethers.parseUnits("9.9", 6);
    const deadline = await deadlineIn();
    const redeem = redemption
      .connect(alice)
      ["redeem(uint256,uint8,uint8,uint64,uint64,uint256,uint256,uint256)"];

    expect(await redemption.nextRedemptionNonce(alice.address)).to.equal(0n);
    await expect(
      redeem(amount, 1, 2, 1, 0, netUsdt + 1n, deadline, 0)
    ).to.be.revertedWithCustomError(redemption, "SlippageExceeded");
    expect(await redemption.nextRedemptionNonce(alice.address)).to.equal(0n);

    await expect(
      redeem(amount, 1, 2, 1, 0, netUsdt, deadline, 0)
    )
      .to.emit(redemption, "RedemptionSettled")
      .withArgs(
        alice.address,
        0,
        amount,
        grossUsdt,
        feeUsdt,
        netUsdt,
        1,
        2,
        ethers.parseUnits("10", 18),
        100
      );
    expect(await redemption.nextRedemptionNonce(alice.address)).to.equal(1n);

    await expect(
      redeem(amount, 1, 2, 1, 0, netUsdt, deadline, 0)
    )
      .to.be.revertedWithCustomError(redemption, "UnexpectedRedemptionNonce")
      .withArgs(0, 1);
  });
});
