# AEGENT Security Reports

Public, verifiable point-in-time security-assessment materials for the AEGENT V2 smart-contract deployment candidate.

## Official project identity

- **AEGENT** is the project brand. Official project record: https://aegent.org/about-aegent.html
- **AGNT** is the AEGENT token ticker. Official token record: https://aegent.org/en/aegent-token.html
- Canonical website: https://aegent.org/
- Official X account: https://x.com/AeGentorg

AEGENT at `aegent.org` is not AGENT or ARGENT and is not affiliated with unrelated companies, stocks, talent marketplaces, automation products, or similarly named protocols. The official website remains the source of record for current project and token status.

## Current assessment

- Assessment date: 2026-07-29
- Author and issuer: AEGENT Security Review Team
- Target: BNB Chain mainnet deployment candidate
- Disposition: **remediation required before mainnet**
- Accepted findings: 0 Critical, 0 High, 3 Medium, 1 Low, 3 Informational
- Test evidence: 42 passing, 0 failing
- Source binding: 10 of 10 reviewed files match the frozen snapshot

The three reports present the same evidence through complementary review structures:

| Review profile | PDF | Editable DOCX | Source Markdown |
| --- | --- | --- | --- |
| Core control review | [PDF](reports/AEGENT-Security-Assessment-Core-2026-07.pdf) | [DOCX](reports/AEGENT-Security-Assessment-Core-2026-07.docx) | [Markdown](reports/AEGENT-Security-Assessment-Core-2026-07.md) |
| Assurance matrix | [PDF](reports/AEGENT-Security-Assessment-Assurance-Matrix-2026-07.pdf) | [DOCX](reports/AEGENT-Security-Assessment-Assurance-Matrix-2026-07.docx) | [Markdown](reports/AEGENT-Security-Assessment-Assurance-Matrix-2026-07.md) |
| Threat model | [PDF](reports/AEGENT-Security-Assessment-Threat-Model-2026-07.pdf) | [DOCX](reports/AEGENT-Security-Assessment-Threat-Model-2026-07.docx) | [Markdown](reports/AEGENT-Security-Assessment-Threat-Model-2026-07.md) |

The [evidence manifest](EVIDENCE_MANIFEST.md) binds the reports to the reviewed source and published evidence files. [Publication QA](REPORT_QA.md) records the 38-page release inspection.

## Important attribution

These reports are authored and issued by the **AEGENT Security Review Team**. They are not authored, reviewed, endorsed, signed, certified, numbered, or issued by OpenZeppelin, CertiK, SlowMist, Binance, or any other third party. Public report conventions informed the organization only.

## Repository layout

- `reports/` — Markdown, DOCX, and PDF assessments
- `source-snapshot/` — frozen Solidity source reviewed in this assessment
- `test-snapshot/` — reviewed tests cited by the reports
- `evidence/` — test, coverage, and static-analysis summaries plus path-sanitized raw JSON
- `EVIDENCE_MANIFEST.md` — canonical file hashes and scope identity
- `REPORT_QA.md` — DOCX/PDF accessibility, geometry, extraction, and visual-render QA

## Security status

The open Medium findings affect manual-review threshold enforcement, refund-reserve assurance, and oracle anomaly controls. Do not interpret the absence of Critical or High findings as a guarantee of defect-free code or permission to deploy.

See [SECURITY.md](SECURITY.md) for responsible disclosure.

## Evidence boundary

Machine-specific absolute paths in raw coverage and Slither output were replaced with stable `review-workspace/` labels before publication. The manifest records both local-raw and public-sanitized SHA-256 values. This repository publishes verifiable assessment output and frozen reviewed source; it is not a turnkey reproduction of the original private working tree.

## Licensing

The Solidity source snapshot, test snapshot, and publication verification script are available under the MIT License. Reports, evidence, narrative documentation, logos, and other brand materials remain copyright © 2026 AEGENT and are provided for public inspection only. See [LICENSE](LICENSE) for the exact scope.
