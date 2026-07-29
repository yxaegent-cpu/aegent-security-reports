# AEGENT V2 Security Assessment Evidence Manifest

**Evidence owner:** AEGENT Security Review Team  
**Evidence capture date:** 2026-07-29  
**Target:** BNB Chain mainnet deployment candidate  
**Snapshot type:** uncommitted working-tree snapshot  
**Final disposition:** **remediation required before mainnet**

> This manifest binds three AEGENT-authored first-party assessments to the frozen source and published evidence. It is not authored, reviewed, endorsed, signed, certified, numbered, or issued by OpenZeppelin, CertiK, SlowMist, Binance, or another third party.

## Source identity

The files under `source-snapshot/` are the controlling assessed source. A conclusion remains applicable only to byte-identical files. At publication time, **10 of 10** live files matched the frozen snapshot.

| Source file | Live source SHA-256 | Frozen snapshot SHA-256 | Result |
| --- | --- | --- | --- |
| `contracts/AegentMarketRegistry.sol` | `1e0fc93396402b19d085bbfc25d03be53540e847039dd768c6d47bf379f49aa9` | `1e0fc93396402b19d085bbfc25d03be53540e847039dd768c6d47bf379f49aa9` | Match |
| `contracts/AegentSaleProceedsVault.sol` | `983af93be4bb1fcbe2809c9fb01baea34a7bae0ddf12caf05933c5450842cc34` | `983af93be4bb1fcbe2809c9fb01baea34a7bae0ddf12caf05933c5450842cc34` | Match |
| `contracts/AegentSwapV2.sol` | `2b53552a367b757cc31721d31cb2e889dc9391afc293a4cac0b2590332fb515f` | `2b53552a367b757cc31721d31cb2e889dc9391afc293a4cac0b2590332fb515f` | Match |
| `contracts/AegentRedemptionV2.sol` | `2424be9e3141b055d0a27a7b12ab6fc3918d758ddbedc9201ebc454dd467fcc6` | `2424be9e3141b055d0a27a7b12ab6fc3918d758ddbedc9201ebc454dd467fcc6` | Match |
| `contracts/interfaces/IAegentMarketRegistry.sol` | `fb7b9a35bef353c3c0a5e882da595294b9dadb8d81cedada1207bbfe7bb02309` | `fb7b9a35bef353c3c0a5e882da595294b9dadb8d81cedada1207bbfe7bb02309` | Match |
| `contracts/interfaces/IAegentPurchaseReceiptSource.sol` | `52abd846c87734040bfb375177186bff6d8b56f9b23ddbeeb8a7a4f4c3d5badb` | `52abd846c87734040bfb375177186bff6d8b56f9b23ddbeeb8a7a4f4c3d5badb` | Match |
| `contracts/interfaces/IAegentRedemptionEndpoint.sol` | `92620d9cc1fec26c42b4d4d293447d4faf9d83aab05a065d7484eff299d89eab` | `92620d9cc1fec26c42b4d4d293447d4faf9d83aab05a065d7484eff299d89eab` | Match |
| `contracts/interfaces/IAegentRegistryBound.sol` | `bf53c7606cbc5853a74710c9fa31dfd256a31283eedaf7ede01e213b0f12bc84` | `bf53c7606cbc5853a74710c9fa31dfd256a31283eedaf7ede01e213b0f12bc84` | Match |
| `contracts/interfaces/IAegentSaleProceedsVault.sol` | `eb1005d38941efc7dfd9e8c961eb5a4df10f9a43f630330495dd82b73854c974` | `eb1005d38941efc7dfd9e8c961eb5a4df10f9a43f630330495dd82b73854c974` | Match |
| `contracts/interfaces/IAggregatorV3.sol` | `2dc0d69856b9cf3579d866c1da3bb9baff2fe505d9702001fcddc47e319a2b7e` | `2dc0d69856b9cf3579d866c1da3bb9baff2fe505d9702001fcddc47e319a2b7e` | Match |

The workspace commit recorded during assessment was `cae20adbf0497c46906e36cb98bcd3d19232c98b`; it is context only and is not asserted to contain the uncommitted snapshot.

## Verification result

- Hardhat tests: **42 passing, 0 failing**
- Coverage, four core contracts: **89.67% statements / 56.40% branches / 85.07% functions / 79.72% lines**
- Slither 0.11.5: `success: true`, **55 raw detector entries**
- Accepted findings: **0 Critical, 0 High, 3 Medium, 1 Low, 3 Informational**
- Accepted finding state: **Open; no remediation retest**

## Accepted finding register

| ID | Severity | Title | Status |
| --- | --- | --- | --- |
| MED-01 | Medium | Manual-review threshold can be bypassed by splitting redemptions | Open; no remediation retest |
| MED-02 | Medium | Purchases can increase refund liability without enforced reserve collateral | Open; no remediation retest |
| MED-03 | Medium | Freshness-only oracle validation lacks bounds and deviation circuit breakers | Open; no remediation retest |
| LOW-01 | Low | Fixed UTC daily buckets permit near-two-times throughput at a boundary | Open; no remediation retest |
| INFO-01 | Informational | Privileged controls do not enforce a multisig or general timelock | Open; no remediation retest |
| INFO-02 | Informational | Immutable recipients and narrow recovery paths create asset-liveness risk | Open; no remediation retest |
| INFO-03 | Informational | Settlement events omit configuration evidence needed for complete reconstruction | Open; no remediation retest |

## Public artifact hashes

All hashes use SHA-256. Byte counts are decimal bytes.

| File | SHA-256 | Bytes |
| --- | --- | ---: |
| `evidence/README.md` | `54dad087d67f03e185f7ea1131a53fbf75c65abf9a156b8955f51db9fe8f6e42` | 488 |
| `evidence/coverage-summary.json` | `976b241817592cc02cba1561dd1d9770f04a34fc7c60c87fbd3b786a2cbad951` | 568 |
| `evidence/coverage.json` | `5434801da276660647b48aabc128416d3ed484b028d3706df306a41602deceb5` | 82,900 |
| `evidence/slither-0.11.5.json` | `df9f104578d446418d44b92c7969dd5264f4b11e0f5a0e9cb41b15add967e9c7` | 594,637 |
| `evidence/slither-summary.json` | `a854873f2d536852c7319641f9c94246f07a735c650abf825ce373c903a54f69` | 441 |
| `evidence/test-summary.json` | `b33bb1bcd3157abc22ce70af0bda75af242cf35468b8a9e671c8c06196ef07b7` | 331 |
| `reports/AEGENT-Security-Assessment-Assurance-Matrix-2026-07.docx` | `41dc9aec22ccb4b90c8d36d6643580e79456f20f7fea83548f879be1034e314d` | 96,548 |
| `reports/AEGENT-Security-Assessment-Assurance-Matrix-2026-07.md` | `a777ce00f4d77d5e18a1d8fe329fa16b2fff3a2be15471003091f950c9fc40c1` | 25,303 |
| `reports/AEGENT-Security-Assessment-Assurance-Matrix-2026-07.pdf` | `4854fa56df7884647ba7c63160d9f23a147b2f28c269d302fdd823e2d064ab08` | 179,770 |
| `reports/AEGENT-Security-Assessment-Core-2026-07.docx` | `c9db396a9365a315a3d09e33dca61ff56db1cb26da05853ca33dbefa260cc7ce` | 94,667 |
| `reports/AEGENT-Security-Assessment-Core-2026-07.md` | `dfbd0ca16648500513298f888a371d61d48628d4005f85f20e9d972ab93c3561` | 23,926 |
| `reports/AEGENT-Security-Assessment-Core-2026-07.pdf` | `1aa373a1efd16b21e2168fb94d0cfe94267853dca7df80d58a72d0cafd802d29` | 172,040 |
| `reports/AEGENT-Security-Assessment-Threat-Model-2026-07.docx` | `458cf3f1ffd19b64b00d93bd8e7dd518157272e3e45c5b3f96403dee1804cc7f` | 98,977 |
| `reports/AEGENT-Security-Assessment-Threat-Model-2026-07.md` | `278503636b9592f027147a236b4743e7f45e4b25df591cb8c51e5082033d30fa` | 29,698 |
| `reports/AEGENT-Security-Assessment-Threat-Model-2026-07.pdf` | `7e3d91d3dcf48631ed3652210f2534d9aa2ba7ea222a336b21e67ae8170e0b36` | 197,539 |
| `source-snapshot/contracts/AegentMarketRegistry.sol` | `1e0fc93396402b19d085bbfc25d03be53540e847039dd768c6d47bf379f49aa9` | 10,900 |
| `source-snapshot/contracts/AegentRedemptionV2.sol` | `2424be9e3141b055d0a27a7b12ab6fc3918d758ddbedc9201ebc454dd467fcc6` | 31,853 |
| `source-snapshot/contracts/AegentSaleProceedsVault.sol` | `983af93be4bb1fcbe2809c9fb01baea34a7bae0ddf12caf05933c5450842cc34` | 3,559 |
| `source-snapshot/contracts/AegentSwapV2.sol` | `2b53552a367b757cc31721d31cb2e889dc9391afc293a4cac0b2590332fb515f` | 22,616 |
| `source-snapshot/contracts/interfaces/IAegentMarketRegistry.sol` | `fb7b9a35bef353c3c0a5e882da595294b9dadb8d81cedada1207bbfe7bb02309` | 1,600 |
| `source-snapshot/contracts/interfaces/IAegentPurchaseReceiptSource.sol` | `52abd846c87734040bfb375177186bff6d8b56f9b23ddbeeb8a7a4f4c3d5badb` | 774 |
| `source-snapshot/contracts/interfaces/IAegentRedemptionEndpoint.sol` | `92620d9cc1fec26c42b4d4d293447d4faf9d83aab05a065d7484eff299d89eab` | 246 |
| `source-snapshot/contracts/interfaces/IAegentRegistryBound.sol` | `bf53c7606cbc5853a74710c9fa31dfd256a31283eedaf7ede01e213b0f12bc84` | 217 |
| `source-snapshot/contracts/interfaces/IAegentSaleProceedsVault.sol` | `eb1005d38941efc7dfd9e8c961eb5a4df10f9a43f630330495dd82b73854c974` | 328 |
| `source-snapshot/contracts/interfaces/IAggregatorV3.sol` | `2dc0d69856b9cf3579d866c1da3bb9baff2fe505d9702001fcddc47e319a2b7e` | 383 |
| `test-snapshot/AegentRedemptionV2.test.cjs` | `19c8e17cd4adedc4b4921f0e405c2a3406c90d21a3f70b31cc05cc6e5ee72a80` | 18,989 |
| `test-snapshot/AegentSwapV2.test.cjs` | `c198255319a50cac30fef64fdf60160f77c10231938258a766109f377314ac09` | 15,076 |
| `test-snapshot/AegentV2Integration.test.cjs` | `2208ae5ffde48d79b23d3f9864941f0a0f3e9a2664135c3bfeada94ffe4de576` | 8,548 |
| `REPORT_QA.md` | `dde267046859490303de0a450640e79a8f83ba072b7aa990c5c08442816df7b3` | 3,772 |

The manifest does not hash itself because embedding its own digest would be recursive. The Git publication commit binds this file and all listed artifacts.

## Evidence path sanitation

Raw local coverage and Slither JSON contained machine-specific absolute paths. The public copies replace those prefixes with stable `review-workspace/` labels while preserving the evidence structure, detector records, counters, and coverage measurements.

| Evidence | Local raw SHA-256 | Public sanitized SHA-256 |
| --- | --- | --- |
| `evidence/coverage.json` | `a18cacd3a805d01df8659479f7c01740877cddd3e88d7c47fece1d2607446120` | `5434801da276660647b48aabc128416d3ed484b028d3706df306a41602deceb5` |
| `evidence/slither-0.11.5.json` | `738c891b384e06fe9dd1d59efb7dd03618ef9be2dd44386251b6fc4178d37ebb` | `df9f104578d446418d44b92c7969dd5264f4b11e0f5a0e9cb41b15add967e9c7` |

## Toolchain

| Tool or dependency | Version / setting |
| --- | --- |
| Node.js | `v24.18.0` |
| npm | `11.16.0` |
| Hardhat | `2.29.0` |
| ethers | `6.17.0` |
| Solidity compiler | `0.8.24+commit.e11b9ed9` |
| Optimizer | enabled, 500 runs |
| EVM target | `paris` |
| OpenZeppelin Contracts dependency | `5.1.0` |
| solidity-coverage | `0.8.17` |
| Slither | `0.11.5` |
| crytic-compile | `0.3.11` |

OpenZeppelin Contracts is a source-code dependency; it is not an OpenZeppelin audit or endorsement.

## Scope limitations

- This is a first-party point-in-time assessment, not an independent certification.
- Deployed addresses, bytecode equivalence, constructor arguments, live roles, reserves, oracle addresses, pause state, and mainnet receipts were not assessed.
- No stateful fuzzing, invariant campaign, symbolic execution, formal proof, economic simulation, or production key-compromise exercise was performed.
- Test and coverage evidence reflects local execution, not BNB Chain mainnet behavior.
- Static-analysis classifications are heuristic and were manually triaged.
- The published evidence is verifiable assessment output, not a turnkey reproduction environment.

## Conclusion

The evidence supports the accepted result only for the exact frozen snapshot. It does not support mainnet activation while the three Medium findings remain open.

**Final disposition: remediation required before mainnet.**
