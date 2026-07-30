# AEGENT Smart-Contract Security Assessment

**Document ID:** `AEG-SAR-2026-0730-01`  
**Version:** `1.0`  
**Issue date:** 30 July 2026  
**Author / issuer:** AEGENT Security Review Team  
**Status:** REMEDIATION REQUIRED BEFORE MAINNET  
**Evidence run:** `20260730T020710Z`  
**Scope root SHA-256:** `5c51c8e5df9126e3b0a5ce15e98869f6130e43bb13e4caaebf30853286763f0c`

> This is a formal AEGENT-authored point-in-time first-party assessment. It is not a third-party certificate, warranty or independent audit.

## Executive summary

During the procedures described and within the frozen scope, no Critical or High finding was identified. One open Medium issue remains in Staking oracle validation, together with one open Low and four open Informational findings. Mainnet enablement should remain blocked until MED-04 and the deployment gates are closed or explicitly risk-accepted.

| Metric | Verified result |
|---|---|
| Production Solidity scope | 5 core contracts + 6 interfaces; 3,287 LOC |
| Frozen package | 35 files |
| Compilation | 34 Solidity files; 0 errors |
| Tests | 74 passing / 1 pending on chain 56; wrong-chain guard 1/1 passing on chain 97 |
| Coverage | 96.18% statements; 59.91% branches; 97.66% functions; 87.01% lines |
| Static analysis | Slither 0.11.5; 71 raw records manually triaged |
| Production dependency audit | 0 known npm advisories |

## Scope

| Relative path | LOC | SHA-256 |
|---|---|---|
| contracts/AegentMarketRegistry.sol | 406 | 7bb6cf38a0b59e52564f8fa83be1a24ad33456286f712eb239ad681f83dbfb32 |
| contracts/AegentRedemptionV2.sol | 925 | 1353e6b2ef4382cd544bd321141e071d3b50e7a3704e31387847ce1ceebfcf13 |
| contracts/AegentSaleProceedsVault.sol | 109 | 983af93be4bb1fcbe2809c9fb01baea34a7bae0ddf12caf05933c5450842cc34 |
| contracts/AegentStakingV1.sol | 557 | 789b1839a17e021b5e9cca679b8332e53ea6615644ef422ec30349e4c3b0abde |
| contracts/AegentSwapV2.sol | 1142 | c93726e35beb4d5bbdbfe37353f03c8418dc9be1add5d333c9aaedb0620d2334 |
| contracts/interfaces/IAegentMarketRegistry.sol | 70 | 20f86c9d6927aec67a51bdf5fbf7fa2ce8fbbeaa76ea577ca410c42f6f382b76 |
| contracts/interfaces/IAegentPurchaseReceiptSource.sol | 28 | 52abd846c87734040bfb375177186bff6d8b56f9b23ddbeeb8a7a4f4c3d5badb |
| contracts/interfaces/IAegentRedemptionEndpoint.sol | 13 | b78ac12e384e2c71bdf33eb44a899c417c30eb4a9376fb28351d85c50bcf369d |
| contracts/interfaces/IAegentRegistryBound.sol | 8 | bf53c7606cbc5853a74710c9fa31dfd256a31283eedaf7ede01e213b0f12bc84 |
| contracts/interfaces/IAegentSaleProceedsVault.sol | 12 | eb1005d38941efc7dfd9e8c961eb5a4df10f9a43f630330495dd82b73854c974 |
| contracts/interfaces/IAggregatorV3.sol | 17 | 2dc0d69856b9cf3579d866c1da3bb9baff2fe505d9702001fcddc47e319a2b7e |

## Findings summary

| ID | Severity | Status | Title |
|---|---|---|---|
| MED-01 | Medium | Resolved | Manual-review threshold could be bypassed by splitting redemptions |
| MED-02 | Medium | Resolved | Purchases could create redemption liabilities without enforced reserve coverage |
| MED-03 | Medium | Partially Resolved | Oracle validation previously relied primarily on freshness |
| MED-04 | Medium | Open | Staking oracle controls are materially weaker than purchase controls |
| LOW-01 | Low | Open | UTC day buckets permit a short-window boundary burst |
| INFO-01 | Informational | Open | Privileged operations are not constrained by protocol-level multisig or timelock |
| INFO-02 | Informational | Open | Immutable beneficiaries and narrow recovery paths create liveness risk |
| INFO-03 | Informational | Open | Settlement events omit configuration evidence needed for independent reconstruction |
| INFO-04 | Informational | Open | Staking proceeds depend indefinitely on a user-triggered claim |

## MED-01 — Manual-review threshold could be bypassed by splitting redemptions

| Field | Value |
|---|---|
| Severity | Medium |
| Status | Resolved |
| Affected | AegentRedemptionV2 |
| Likelihood | Low after remediation |
| Evidence | AegentRedemptionV2.sol:734–757; AegentRedemptionV2.test.cjs cumulative-threshold tests |

### Description

The earlier implementation evaluated the manual-review threshold at request level. The reviewed snapshot now computes the wallet's next cumulative UTC-day redemption total before applying both the hard wallet limit and the manual-review threshold.

### Impact and exploit conditions

Control bypass and excessive wallet-level redemption throughput.

The previous weakness required a wallet to submit multiple individually sub-threshold transactions. The cumulative accounting in this snapshot removes that path.

### Recommendation

Retain cumulative accounting and monitoring. If the business policy is intended to mean any rolling 24-hour period, also address LOW-01.

### Validation

Fresh chain-56 tests passed: “applies the manual-review threshold to the cumulative wallet total” and “retains the hard daily wallet limit when the review threshold equals it.”

## MED-02 — Purchases could create redemption liabilities without enforced reserve coverage

| Field | Value |
|---|---|
| Severity | Medium |
| Status | Resolved |
| Affected | AegentSwapV2; AegentRedemptionV2 |
| Likelihood | Low after remediation |
| Evidence | AegentRedemptionV2.sol:588–610; AegentSwapV2.sol:299–340, 630–687, 770–799 |

### Description

The reviewed contracts now expose the projected reserve requirement for an incremental purchase and require every BNB, USDT and USDC execution path to fail closed when the redemption reserve cannot cover the resulting liability.

### Impact and exploit conditions

Insolvent presale refunds or inability to honor cost-basis liabilities.

The previous condition required additional purchases to be accepted while refund reserves were insufficient or unreadable. The current quote and execution paths reject that state.

### Recommendation

Preserve the fail-closed reserve check in every future purchase path and monitor both reserve assets and outstanding cost-basis liabilities.

### Validation

Fresh tests passed for reserve coverage on BNB, USDT and USDC purchases, unreadable reserve state, locked liability and excess-only withdrawals.

## MED-03 — Oracle validation previously relied primarily on freshness

| Field | Value |
|---|---|
| Severity | Medium |
| Status | Partially Resolved |
| Affected | AegentSwapV2; AegentMarketRegistry; oracle-breaker keeper |
| Likelihood | Low to Medium |
| Evidence | AegentSwapV2.sol:38–53, 346–463, 843–879, 970–1055; AegentMarketRegistry.sol:143–181 |

### Description

The snapshot adds per-feed maximum age, absolute bounds, deviation limits, reference prices and a permissionless circuit breaker that persistently pauses purchase-capable modes. Registry logic rejects breaker calls after sale end and from uncommitted endpoints.

### Impact and exploit conditions

Incorrect purchase valuation if a valid-looking feed value is materially wrong.

Residual exposure remains if the single upstream source is compromised within configured bounds, if the owner sets an unsafe reference while paused, or if operational monitoring, RPC access and gas are unavailable.

### Recommendation

Control oracle-risk configuration through a multisig and timelock, monitor reference-price changes, document per-feed heartbeats, and consider a secondary source or TWAP for high-value execution.

### Validation

Fresh tests passed for per-feed ages, bounds, deviation checks, breaker classification, permissionless trip behavior, post-sale rejection and post-launch redemption continuity. Residual operational assumptions were not eliminated.

## MED-04 — Staking oracle controls are materially weaker than purchase controls

| Field | Value |
|---|---|
| Severity | Medium |
| Status | Open |
| Affected | AegentStakingV1 |
| Likelihood | Medium |
| Evidence | AegentStakingV1.sol:113, 133–190, 240–261, 493–517 |

### Description

Staking uses one immutable maxOracleAge for both feeds and accepts any positive, non-future, round-complete value within that age. It has no per-feed heartbeat cap, absolute price bounds, deviation limit, reference price or circuit breaker. BNB valuation is not capped; a fresh extreme value can create an excessive AGNT entitlement. USDT valuation caps prices above one dollar but still relies on user minOut for low-price protection.

### Impact and exploit conditions

Inflated AGNT entitlement and reserve depletion from a fresh but anomalous BNB price.

An oracle, upstream data path or feed configuration returns a fresh, positive but materially incorrect value. A user executes before operators can close deposits.

### Recommendation

Reuse the Swap oracle-risk model: bounded per-feed maximum age, min/max price, reference/deviation validation, permissionless persistent breaker, and explicit tests at the first representable boundary breach. Enforce a safe upper bound on configured heartbeat.

### Validation

No remediation for this issue exists in the reviewed snapshot. Existing tests cover stale, future, incomplete and non-positive rounds but do not provide the missing bounds/deviation controls.

## LOW-01 — UTC day buckets permit a short-window boundary burst

| Field | Value |
|---|---|
| Severity | Low |
| Status | Open |
| Affected | AegentRedemptionV2 |
| Likelihood | Medium |
| Evidence | AegentRedemptionV2.sol:734–757 |

### Description

Daily global and wallet counters use block.timestamp / 1 days. A wallet can consume the full limit immediately before UTC midnight and the next full limit immediately after the bucket changes.

### Impact and exploit conditions

A wallet can approach twice the nominal daily amount across UTC midnight.

The user has available entitlement and reserve on both sides of a UTC-day boundary. This is a rate-limit design issue, not a timestamp manipulation by a block producer.

### Recommendation

Use a rolling-window, token-bucket or decaying accumulator if the intended policy is a true 24-hour limit. Otherwise document the UTC-bucket behavior as an accepted business rule and monitor boundary utilization.

### Validation

The snapshot retains the UTC bucket; no rolling-window retest is available.

## INFO-01 — Privileged operations are not constrained by protocol-level multisig or timelock

| Field | Value |
|---|---|
| Severity | Informational |
| Status | Open |
| Affected | Registry; Swap; Redemption; Staking |
| Likelihood | Operational |
| Evidence | Registry setMode/configureLimitedWindow; Swap setOracleRiskConfig/withdrawUnsoldAgnt; Redemption rate and withdrawal functions; Staking deposit and surplus controls |

### Description

The contracts use Ownable2Step, which protects ownership transfer but does not enforce multisig approval, delay high-impact changes or separate duties.

### Impact and exploit conditions

Single-key compromise or error can change modes, oracle policy or withdrawals.

The deployed owner is an externally owned account, a weakly configured Safe, or an operational process with insufficient review.

### Recommendation

Assign ownership to a verified multisig, apply a timelock to high-impact configuration, separate keeper and treasury duties, and publish an on-chain role matrix before enabling production modes.

### Validation

Deployment addresses and live ownership were not provided; no on-chain retest was possible.

## INFO-02 — Immutable beneficiaries and narrow recovery paths create liveness risk

| Field | Value |
|---|---|
| Severity | Informational |
| Status | Open |
| Affected | AegentSaleProceedsVault; AegentStakingV1 |
| Likelihood | Operational |
| Evidence | AegentSaleProceedsVault.sol:30–92; AegentStakingV1.sol:108–199, 334–361 |

### Description

Vault and Staking proceeds are bound to immutable beneficiaries. Native release reverts if the recipient rejects BNB, while token recovery is limited to expected assets. A lost or unusable beneficiary cannot be rotated in the reviewed bytecode.

### Impact and exploit conditions

Proceeds or accidental assets can remain locked if the recipient cannot receive them.

The beneficiary contract rejects native transfers, loses signing access, is misconfigured, or an unsupported asset is sent to the contract.

### Recommendation

Use a tested Safe-compatible beneficiary, add delayed two-step beneficiary rotation or a narrowly scoped recovery path, and test native/token release against the exact production recipient.

### Validation

No production beneficiary or funded release transaction was supplied.

## INFO-03 — Settlement events omit configuration evidence needed for independent reconstruction

| Field | Value |
|---|---|
| Severity | Informational |
| Status | Open |
| Affected | AegentSwapV2; AegentRedemptionV2 |
| Likelihood | Operational |
| Evidence | AegentSwapV2.sol:129–138, 1127–1136; AegentRedemptionV2.sol:122–133, 349–360 |

### Description

PurchaseSettled does not emit market mode or configVersion. RedemptionSettled does not emit configVersion, rateVersion or whether the presale cost-basis path was used. Off-chain systems must join historical state to reconstruct settlement context.

### Impact and exploit conditions

Reduced auditability and more difficult incident reconstruction.

An investigator or reconciler must prove which configuration governed a historical settlement.

### Recommendation

Add the governing mode/config/rate identifiers and settlement-basis flag to events. Version the event schema and update indexers before deployment.

### Validation

The reviewed snapshot retains the current event schemas.

## INFO-04 — Staking proceeds depend indefinitely on a user-triggered claim

| Field | Value |
|---|---|
| Severity | Informational |
| Status | Open |
| Affected | AegentStakingV1 |
| Likelihood | Operational |
| Evidence | AegentStakingV1.sol:312–361 |

### Description

Only the position owner can call claim. The beneficiary can release the corresponding deposited asset only after claimed becomes true. There is no third-party claim-for path or post-maturity fallback.

### Impact and exploit conditions

Deposited USDT or BNB can remain locked indefinitely when a user never claims.

A position matures but its owner loses access, abandons the wallet or never submits the claim.

### Recommendation

Consider a permissionless claim-for function that always delivers AGNT to the recorded owner, or a carefully specified post-maturity fallback that does not reduce the user's entitlement. Document long-tail liabilities.

### Validation

Existing tests verify the designed owner-only claim and release sequence; they do not remove the liveness dependency.

## Automated verification

- Hardhat chain-56 suite: 74 passing, 1 intentional pending.
- Hardhat chain-97 wrong-chain guard: 1 passing.
- Coverage: 96.18% statements, 59.91% branches, 97.66% functions, 87.01% lines.
- Slither: 71 raw detector records; 30 Medium, 34 Low, 7 Informational tool labels.
- Production npm audit: 0 known advisories.

## Deployment status

No deployment addresses, runtime bytecode, explorer verification, funded receipts, live ownership, beneficiary, reserve or oracle binding evidence was assessed.

## Conclusion

REMEDIATION REQUIRED BEFORE MAINNET.

This conclusion is valid only for evidence run `20260730T020710Z` and scope root `5c51c8e5df9126e3b0a5ce15e98869f6130e43bb13e4caaebf30853286763f0c`.
