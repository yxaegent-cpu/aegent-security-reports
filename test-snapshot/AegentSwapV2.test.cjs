const { expect } = require("chai");
const { ethers } = require("hardhat");
const { loadFixture, time } = require("@nomicfoundation/hardhat-network-helpers");

const DAY = 24 * 60 * 60;
const ONE_AGNT = ethers.parseUnits("1", 18);

describe("AegentSwapV2", function () {
  async function deployFixture(advanceToSaleStart = true) {
    const [owner, treasury, alice, bob, carol] = await ethers.getSigners();
    const now = await time.latest();
    const saleStart = now + 60;
    const saleEnd = saleStart + 90 * DAY;

    const Token = await ethers.getContractFactory("MockERC20");
    const agnt = await Token.deploy("Aegent", "AGNT", 18);
    const usdt = await Token.deploy("Tether USD", "USDT", 6);
    const usdc = await Token.deploy("USD Coin", "USDC", 6);

    const Oracle = await ethers.getContractFactory("MockAggregatorV3");
    const oracle = await Oracle.deploy(8, 600n * 10n ** 8n);
    const usdtOracle = await Oracle.deploy(8, 1n * 10n ** 8n);
    const usdcOracle = await Oracle.deploy(8, 1n * 10n ** 8n);

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
    const Swap = await ethers.getContractFactory("AegentSwapV2");
    const swap = await Swap.deploy(
      await agnt.getAddress(),
      await usdt.getAddress(),
      await usdc.getAddress(),
      await oracle.getAddress(),
      await usdtOracle.getAddress(),
      await usdcOracle.getAddress(),
      await registry.getAddress(),
      treasury.address,
      owner.address,
      60 * 60,
      ethers.parseUnits("10000", 18)
    );
    const proceedsVault = await ethers.getContractAt(
      "AegentSaleProceedsVault",
      await swap.proceedsVault()
    );
    const Endpoint = await ethers.getContractFactory("MockSwapEndpoint");
    const redemptionEndpoint = await Endpoint.deploy(await registry.getAddress());
    await redemptionEndpoint.waitForDeployment();
    expect(await redemptionEndpoint.getAddress()).to.equal(expectedRedemption);
    await redemptionEndpoint.setEndpointKind(
      await registry.REDEMPTION_ENDPOINT_KIND()
    );

    expect(await swap.getAddress()).to.equal(expectedSwap);
    await agnt.mint(await swap.getAddress(), ethers.parseUnits("1000000", 18));
    for (const buyer of [alice, bob, carol]) {
      await usdt.mint(buyer.address, ethers.parseUnits("10000", 6));
      await usdc.mint(buyer.address, ethers.parseUnits("10000", 6));
      await usdt.connect(buyer).approve(await swap.getAddress(), ethers.MaxUint256);
      await usdc.connect(buyer).approve(await swap.getAddress(), ethers.MaxUint256);
    }
    await registry.setMode(0); // OPEN
    if (advanceToSaleStart) {
      await time.increaseTo(saleStart);
    }

    return {
      owner,
      treasury,
      alice,
      bob,
      carol,
      saleStart,
      saleEnd,
      agnt,
      usdt,
      usdc,
      oracle,
      usdtOracle,
      usdcOracle,
      registry,
      proceedsVault,
      redemptionEndpoint,
      swap
    };
  }

  async function deadlineIn(seconds = 300) {
    return (await time.latest()) + seconds;
  }

  async function deployPreSaleFixture() {
    return deployFixture(false);
  }

  it("settles stablecoin purchases at the current fixed phase rate", async function () {
    const {
      alice,
      agnt,
      usdt,
      usdtOracle,
      proceedsVault,
      redemptionEndpoint,
      swap,
      registry,
      saleEnd
    } =
      await loadFixture(deployFixture);
    const hundredUsdt = ethers.parseUnits("100", 6);

    await expect(
      swap.connect(alice).swapUSDT(
        hundredUsdt,
        1,
        0,
        0,
        1,
        ethers.parseUnits("1000", 18),
        await deadlineIn()
      )
    )
      .to.emit(swap, "PurchaseSettled")
      .withArgs(
        alice.address,
        await usdt.getAddress(),
        hundredUsdt,
        ethers.parseUnits("100", 18),
        ethers.parseUnits("1000", 18),
        1,
        ethers.parseUnits("10", 18),
        0
      );

    expect(await agnt.balanceOf(alice.address)).to.equal(0n);
    expect(await agnt.balanceOf(await redemptionEndpoint.getAddress())).to.equal(
      ethers.parseUnits("1000", 18)
    );
    expect(await swap.walletAgntBought(alice.address)).to.equal(
      ethers.parseUnits("1000", 18)
    );
    expect(await swap.walletUsdContributed18(alice.address)).to.equal(
      ethers.parseUnits("100", 18)
    );
    expect(await swap.totalUsdContributed18()).to.equal(
      ethers.parseUnits("100", 18)
    );
    expect(await usdt.balanceOf(await proceedsVault.getAddress())).to.equal(
      hundredUsdt
    );

    await time.increaseTo(saleEnd - 60 * DAY);
    expect((await registry.currentPhase())[0]).to.equal(2n);
    await usdtOracle.setRoundData(100_000_000n, await time.latest(), 2, 2);

    await swap.connect(alice).swapUSDT(
      hundredUsdt,
      2,
      0,
      0,
      1,
      ethers.parseUnits("700", 18),
      await deadlineIn()
    );
    expect(await agnt.balanceOf(alice.address)).to.equal(0n);
    expect(await agnt.balanceOf(await redemptionEndpoint.getAddress())).to.equal(
      ethers.parseUnits("1700", 18)
    );
    expect(await swap.walletUsdContributed18(alice.address)).to.equal(
      ethers.parseUnits("200", 18)
    );
    expect(await swap.totalUsdContributed18()).to.equal(
      ethers.parseUnits("200", 18)
    );
  });

  it("rejects stale client phases, expired quotes and insufficient minimum output", async function () {
    const { alice, swap } = await loadFixture(deployFixture);
    const amount = ethers.parseUnits("10", 6);

    await expect(
      swap.connect(alice).swapUSDT(amount, 1, 0, 0, 1, 0, await deadlineIn())
    ).to.be.revertedWithCustomError(swap, "MinimumOutputRequired");

    await expect(
      swap.connect(alice).swapUSDT(amount, 2, 0, 0, 1, 0, await deadlineIn())
    )
      .to.be.revertedWithCustomError(swap, "UnexpectedPhase")
      .withArgs(2, 1);

    await expect(
      swap.connect(alice).swapUSDT(
        amount,
        1,
        1,
        0,
        1,
        ethers.parseUnits("100", 18),
        await deadlineIn()
      )
    )
      .to.be.revertedWithCustomError(swap, "UnexpectedMode")
      .withArgs(1, 0);

    await expect(
      swap.connect(alice).swapUSDT(
        amount,
        1,
        0,
        0,
        1,
        0,
        (await time.latest()) - 1
      )
    ).to.be.revertedWithCustomError(swap, "QuoteExpired");

    await expect(
      swap.connect(alice).swapUSDT(
        amount,
        1,
        0,
        0,
        0,
        ethers.parseUnits("100", 18),
        await deadlineIn()
      )
    )
      .to.be.revertedWithCustomError(swap, "UnexpectedConfigVersion")
      .withArgs(0, 1);

    await expect(
      swap.connect(alice).swapUSDT(
        amount,
        1,
        0,
        0,
        1,
        ethers.parseUnits("101", 18),
        await deadlineIn()
      )
    )
      .to.be.revertedWithCustomError(swap, "SlippageExceeded")
      .withArgs(ethers.parseUnits("101", 18), ethers.parseUnits("100", 18));

    await expect(
      swap.connect(alice).swapUSDT(
        amount,
        1,
        0,
        0,
        1,
        ethers.parseUnits("100", 18),
        await deadlineIn(302)
      )
    ).to.be.revertedWithCustomError(swap, "QuoteLifetimeExceeded");
  });

  it("enforces limited-window total inventory and per-wallet limits on chain", async function () {
    const { alice, bob, carol, usdt, registry, swap } =
      await loadFixture(deployFixture);
    const now = await time.latest();
    const startAt = now + 60;
    const endAt = startAt + DAY;

    await registry.setMode(3); // PAUSED before reconfiguration
    await registry.configureLimitedWindow(
      startAt,
      endAt,
      ethers.parseUnits("1000", 18),
      ethers.parseUnits("400", 18)
    );
    await registry.setMode(1); // LIMITED_WINDOW
    await time.increaseTo(startAt);

    await expect(
      swap.connect(alice).swapUSDT(
        ethers.parseUnits("1", 6),
        1,
        1,
        2,
        4,
        ethers.parseUnits("10", 18),
        await deadlineIn()
      )
    )
      .to.be.revertedWithCustomError(swap, "UnexpectedWindow")
      .withArgs(2, 1);

    await swap.connect(alice).swapUSDT(
      ethers.parseUnits("40", 6),
      1,
      1,
      1,
      4,
      ethers.parseUnits("400", 18),
      await deadlineIn()
    );
    expect(await swap.windowWalletAgntBought(1, alice.address))
      .to.equal(ethers.parseUnits("400", 18));

    await expect(
      swap.connect(alice).quoteStable(
        alice.address,
        await usdt.getAddress(),
        ethers.parseUnits("1", 6)
      )
    ).to.be.revertedWithCustomError(swap, "WindowWalletLimitExceeded");

    await expect(
      swap.connect(alice).swapUSDT(
        ethers.parseUnits("1", 6),
        1,
        1,
        1,
        4,
        ONE_AGNT,
        await deadlineIn()
      )
    ).to.be.revertedWithCustomError(swap, "WindowWalletLimitExceeded");

    await swap.connect(bob).swapUSDT(
      ethers.parseUnits("40", 6),
      1,
      1,
      1,
      4,
      ethers.parseUnits("400", 18),
      await deadlineIn()
    );
    await swap.connect(carol).swapUSDT(
      ethers.parseUnits("20", 6),
      1,
      1,
      1,
      4,
      ethers.parseUnits("200", 18),
      await deadlineIn()
    );
    expect(await swap.windowAgntSold(1)).to.equal(ethers.parseUnits("1000", 18));

    await expect(
      swap.connect(carol).swapUSDT(
        ethers.parseUnits("1", 6),
        1,
        1,
        1,
        4,
        ONE_AGNT,
        await deadlineIn()
      )
    ).to.be.revertedWithCustomError(swap, "WindowTotalLimitExceeded");
  });

  it("enforces the immutable global sale cap in every market mode", async function () {
    const { alice, bob, swap } = await loadFixture(deployFixture);

    await swap.connect(alice).swapUSDT(
      ethers.parseUnits("1000", 6),
      1,
      0,
      0,
      1,
      ethers.parseUnits("10000", 18),
      await deadlineIn()
    );

    await expect(
      swap.connect(bob).swapUSDT(
        ethers.parseUnits("1", 6),
        1,
        0,
        0,
        1,
        ethers.parseUnits("10", 18),
        await deadlineIn()
      )
    )
      .to.be.revertedWithCustomError(swap, "GlobalSaleCapExceeded")
      .withArgs(
        ethers.parseUnits("10000", 18),
        ethers.parseUnits("10010", 18)
      );
  });

  it("quotes BNB from a fresh Chainlink feed and forwards the native asset", async function () {
    const { alice, agnt, proceedsVault, redemptionEndpoint, swap } =
      await loadFixture(deployFixture);
    const value = ethers.parseEther("1");
    const vaultBefore = await ethers.provider.getBalance(
      await proceedsVault.getAddress()
    );

    await swap.connect(alice).swapBNB(
      1,
      0,
      0,
      1,
      ethers.parseUnits("6000", 18),
      await deadlineIn(),
      { value }
    );

    expect(await agnt.balanceOf(alice.address)).to.equal(0n);
    expect(await agnt.balanceOf(await redemptionEndpoint.getAddress())).to.equal(
      ethers.parseUnits("6000", 18)
    );
    expect(await ethers.provider.getBalance(await proceedsVault.getAddress()))
      .to.equal(vaultBefore + value);
  });

  it("values stablecoins from fresh USD feeds instead of assuming a permanent peg", async function () {
    const { alice, agnt, usdtOracle, redemptionEndpoint, swap } =
      await loadFixture(deployFixture);
    const now = await time.latest();
    await usdtOracle.setRoundData(80_000_000n, now, 2, 2); // $0.80

    await swap.connect(alice).swapUSDT(
      ethers.parseUnits("10", 6),
      1,
      0,
      0,
      1,
      ethers.parseUnits("80", 18),
      await deadlineIn()
    );

    expect(await agnt.balanceOf(alice.address)).to.equal(0n);
    expect(await agnt.balanceOf(await redemptionEndpoint.getAddress())).to.equal(
      ethers.parseUnits("80", 18)
    );
  });

  it("fails closed when the oracle is stale or the market is not purchasable", async function () {
    const { alice, oracle, usdtOracle, registry, swap } = await loadFixture(deployFixture);
    const now = await time.latest();

    await oracle.setRoundData(600n * 10n ** 8n, now - 3601, 2, 2);
    await expect(
      swap.connect(alice).swapBNB(1, 0, 0, 1, 0, await deadlineIn(), {
        value: ethers.parseEther("0.1")
      })
    ).to.be.revertedWithCustomError(swap, "StaleOraclePrice");

    await usdtOracle.setRoundData(100_000_000n, now - 3601, 2, 2);
    await expect(
      swap.connect(alice).swapUSDT(
        ethers.parseUnits("1", 6),
        1,
        0,
        0,
        1,
        ONE_AGNT,
        await deadlineIn()
      )
    ).to.be.revertedWithCustomError(swap, "StaleOraclePrice");

    await registry.setMode(3); // PAUSED
    await expect(
      swap.connect(alice).swapUSDT(
        ethers.parseUnits("1", 6),
        1,
        0,
        0,
        2,
        0,
        await deadlineIn()
      )
    ).to.be.revertedWithCustomError(swap, "PurchaseUnavailable");
  });

  it("closes all purchases at the configured sale end", async function () {
    const { alice, saleEnd, swap } = await loadFixture(deployFixture);
    await time.increaseTo(saleEnd);

    await expect(
      swap.connect(alice).swapUSDC(
        ethers.parseUnits("1", 6),
        0,
        0,
        1,
        0,
        0,
        saleEnd + 60
      )
    ).to.be.revertedWithCustomError(swap, "PurchaseUnavailable");
  });

  it("does not let the owner remove inventory while purchases are enabled", async function () {
    const { owner, bob, registry, swap } = await loadFixture(deployFixture);

    await expect(
      swap.connect(owner).withdrawUnsoldAgnt(bob.address, ONE_AGNT)
    ).to.be.revertedWithCustomError(swap, "PurchaseMustBeDisabled");

    await registry.setMode(3); // PAUSED
    await expect(
      swap.connect(owner).withdrawUnsoldAgnt(bob.address, ONE_AGNT)
    ).to.emit(swap, "UnsoldInventoryWithdrawn");
  });

  it("does not let a scheduled sale be emptied before saleStart", async function () {
    const { owner, bob, swap } = await loadFixture(deployPreSaleFixture);
    await expect(
      swap.connect(owner).withdrawUnsoldAgnt(bob.address, ONE_AGNT)
    ).to.be.revertedWithCustomError(swap, "PurchaseMustBeDisabled");
  });

  it("requires an explicit non-zero buyer for executable quotes", async function () {
    const { usdt, swap } = await loadFixture(deployFixture);
    await expect(
      swap.quoteStable(
        ethers.ZeroAddress,
        await usdt.getAddress(),
        ethers.parseUnits("1", 6)
      )
    ).to.be.revertedWithCustomError(swap, "ZeroAddress");
  });
});
