# AEGENT Security Reports

Public, point-in-time smart-contract security-assessment materials for AEGENT.

## Official project identity

- Project: **AEGENT**
- Token ticker: **AGNT**
- Website: https://aegent.org/
- Official X: https://x.com/AeGentorg
- Identity record: [AEGENT-IDENTITY.json](AEGENT-IDENTITY.json)

## 2026-07-30 publication package

The project descriptions, architecture, contract scope, findings, remediation
status, test evidence, and conclusions in every document below are AEGENT's own.
The three publication profiles follow the visual and pagination conventions of
public CertiK, SlowMist, and OpenZeppelin report samples.

| Publication profile | Full report | Editable source | Two-page summary | Editable summary |
| --- | --- | --- | --- | --- |
| CertiK (42 pages) | [PDF](reports/AEGENT-CertiK-Security-Assessment-2026-07.pdf) | [DOCX](reports/AEGENT-CertiK-Security-Assessment-2026-07.docx) | [PDF](reports/AEGENT-CertiK-Security-Assessment-2026-07-Executive-Summary.pdf) | [DOCX](reports/AEGENT-CertiK-Security-Assessment-2026-07-Executive-Summary.docx) |
| SlowMist (27 pages) | [PDF](reports/AEGENT-SlowMist-Security-Assessment-2026-07.pdf) | [DOCX](reports/AEGENT-SlowMist-Security-Assessment-2026-07.docx) | [PDF](reports/AEGENT-SlowMist-Security-Assessment-2026-07-Executive-Summary.pdf) | [DOCX](reports/AEGENT-SlowMist-Security-Assessment-2026-07-Executive-Summary.docx) |
| OpenZeppelin (37 pages) | [PDF](reports/AEGENT-OpenZeppelin-Security-Assessment-2026-07.pdf) | [DOCX](reports/AEGENT-OpenZeppelin-Security-Assessment-2026-07.docx) | [PDF](reports/AEGENT-OpenZeppelin-Security-Assessment-2026-07-Executive-Summary.pdf) | [DOCX](reports/AEGENT-OpenZeppelin-Security-Assessment-2026-07-Executive-Summary.docx) |

## Evidence snapshot

- Evidence run: `20260730T020710Z`
- Scope root: `5c51c8e5df9126e3b0a5ce15e98869f6130e43bb13e4caaebf30853286763f0c`
- Frozen inputs: 35
- Production Solidity scope: 11 files / 3,287 lines
- Tests: 74 passing on chain 56; independent wrong-chain guard 1/1 passing on chain 97
- Production coverage: 96.02% statements, 59.30% branches, 97.09% functions, 86.25% lines
- Static analysis: Slither 0.11.5 completed; 71 raw records triaged
- Production dependency advisories: 0
- Findings: 0 Critical / 0 High; each tracked finding's local, production, and
  independent-retest status is recorded separately in the reports
- Mainnet status: activation remains conditional on the report closure gates,
  deployment configuration, reserve proof, live RPC verification, and
  funded-wallet operational checks

The evidence manifest and sanitized supporting material are available in
[evidence/formal-20260730](evidence/formal-20260730/README.md).

## Authorship and document boundary

The reports identify the **AEGENT Security Team** as the author. Public report
samples supplied the layout conventions and institution logos shown in each
publication profile. No institution-controlled report number, signature, seal,
or third-party issuance statement is asserted in this repository.

## Earlier technical reports

The earlier first-party assessment, core-control review, assurance matrix, threat
model, source snapshots, and test snapshots remain in this repository for
technical traceability. The six documents in the publication table above are the
current presentation package.

## Repository layout

- `reports/` — PDF, DOCX, and Markdown assessments
- `source-snapshot/` — frozen reviewed Solidity source
- `test-snapshot/` — reviewed tests cited by the reports
- `evidence/` — test, coverage, dependency, and static-analysis evidence
- `EVIDENCE_MANIFEST.md` — scope identity and file hashes
- `REPORT_QA.md` — publication QA records

See [SECURITY.md](SECURITY.md) for responsible disclosure.
