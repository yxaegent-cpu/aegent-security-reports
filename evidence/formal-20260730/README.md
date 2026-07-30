# AEGENT formal assessment evidence

This directory contains the compact public evidence set for document
`AEG-SAR-2026-0730-01`.

- Evidence run: `20260730T020710Z`
- Scope root SHA-256: `5c51c8e5df9126e3b0a5ce15e98869f6130e43bb13e4caaebf30853286763f0c`
- Frozen evidence inputs: 35
- Production Solidity scope: 5 core contracts and 6 interfaces
- Compilation: 34 Solidity files, 0 errors
- Tests: 74 passing / 1 intentional pending on chain 56
- Wrong-chain guard: 1/1 passing on chain 97
- Production-contract coverage: 96.02% statements, 59.30% branches, 97.09% functions, 86.25% lines
- All-instrumented-file coverage: 96.18% statements, 59.91% branches, 97.66% functions, 87.01% lines
- Slither 0.11.5: success, 71 raw detector records manually triaged
- Production npm advisory count: 0
- Disposition: **remediation required before mainnet**

## Files

- `snapshot-manifest.json` — frozen input paths, per-file hashes, scope-root algorithm, and correction record.
- `slither-summary.json` — tool version, success state, and raw detector counts.
- `npm-audit-production.json` — production dependency advisory result.

The evidence supports only the exact frozen scope. It does not establish deployed
bytecode equivalence, live ownership, reserves, oracle bindings, third-party
approval, or permission to enable mainnet.
