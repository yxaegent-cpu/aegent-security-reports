# AEGENT Formal Assessment Evidence Manifest

This manifest binds the three formal institutional assessment families to one
final frozen evidence run. Superseded and failed runs are not part of this
publication.

## Final evidence identity

| Field | Value |
| --- | --- |
| Run ID | `req223-20260731T134906328Z-c14331b422a13df5` |
| Scope ID | `aegent-contracts:req223` |
| Scope/source snapshot SHA-256 | `cff85cbfc727272ccf234a69745299a4f73de007ee6ac7b6f9c6d6b9a31651e1` |
| Build snapshot SHA-256 | `54dda9d4ac9d0e6ce83d2bc863ae05be30e3a71dd6a8faecb8aa31a02afd2d16` |
| Toolchain SHA-256 | `89a6096feeea6b0fdc0f7ad564ccdd38e0e042382fd020a4c4d05a5c6ba910de` |
| Snapshot manifest SHA-256 | `ae20c397eec2941560d6048ec03746068d3bbf086de780e0cd2256d989c3b902` |
| Finding status SHA-256 | `b586fa2c5916ebe964d17a593d20038d40dc8c3959591f2633806c3c55a45117` |
| Triage SHA-256 | `7b4943babf25f2c9ae78be34e2563022d4a120dc88eae5b366e20379b94e4bb1` |
| Run summary SHA-256 | `112057d3eaa5f2e1c6552fb673b9f0e807406a442af666d84eb50865aba3a011` |
| Unified QA SHA-256 | `a5c1ff1f751b248ff79c40c54fc29c0b1c3ec6146fd138559cbd4f485fca4d31` |

The run completed 30/30 evidence steps. `FROZEN.json` was present,
`FAILED.json` was absent, and the production-evidence validator passed before
generation and publication.

## Verified result

- 11 production Solidity files; 34 Solidity files compiled.
- 245 passing chain-56 tests plus one intentional isolated case.
- 1/1 wrong-chain guard passing in the isolated chain-97 run.
- Solhint completed with 0 source findings.
- Production npm audit recorded 0 advisories.
- 27 development-toolchain advisories were classified and triaged as dev-only.
- 9/9 remediation records are remediated, verified and closed in the frozen source.
- 0 source findings remain open.
- Instrumentation coverage was not collected in the final run; no percentage is claimed.

## Published artifact hashes

All hashes use SHA-256. Byte counts are decimal bytes.

| File | SHA-256 | Bytes |
| --- | --- | ---: |
| `AEGENT-CertiK-Security-Assessment-2026-07.pdf` | `950409993d48e92f2a81d48f60dc11d915c24cc63fe087b12e42607e7f8b4c00` | 2,524,519 |
| `AEGENT-SlowMist-Security-Assessment-2026-07.pdf` | `265d38a09d95f200d7a8c9e3c962dd6bee6b4717bfdf7d1ecc2d8a92df6b711e` | 172,876 |
| `AEGENT-OpenZeppelin-Security-Assessment-2026-07.pdf` | `19649469abba4ba126c2b796622285f38d6720470b044b553f2af603b8afbb8a` | 243,739 |

Only these three complete PDFs are included in the customer-facing publication.
Editable source files and executive summaries remain in the controlled delivery archive.
