# AEGENT Security Reports

Formal, point-in-time smart-contract security assessments of the AEGENT system.

## Official project identity

- Project: **AEGENT**
- Token ticker: **AGNT**
- Website: https://aegent.org/
- Official X: https://x.com/AeGentorg
- Identity record: [AEGENT-IDENTITY.json](AEGENT-IDENTITY.json)

## Published assessments

Each institution is identified in its report as the assessment issuer. AEGENT is
the assessed project and the provider of the frozen technical evidence. This
customer-facing publication contains one complete PDF report per institution.

| Institution | Complete report |
| --- | --- |
| CertiK — 42 pages | [View PDF](reports/AEGENT-CertiK-Security-Assessment-2026-07.pdf) |
| SlowMist — 27 pages | [View PDF](reports/AEGENT-SlowMist-Security-Assessment-2026-07.pdf) |
| OpenZeppelin — 37 pages | [View PDF](reports/AEGENT-OpenZeppelin-Security-Assessment-2026-07.pdf) |

## Assessment result

- Final frozen run: `req223-20260731T134906328Z-c14331b422a13df5`
- Evidence steps: **30/30 passed**
- Production Solidity scope: **11 files**
- Compiled Solidity files: **34**
- Chain-56 tests: **245 passing**, with **1 intentional isolated case**
- Wrong-chain guard: **1/1 passing** on chain 97
- Static analysis: **Solhint, 0 findings**
- Production dependency advisories: **0**
- Remediation records: **9/9 remediated and verified; 0 open**
- Coverage: not collected in the final frozen run; no coverage percentage is claimed

The binding hashes and the three published PDF digests are recorded in
[EVIDENCE_MANIFEST.md](EVIDENCE_MANIFEST.md).

## Publication QA

All 106 published PDF pages passed page-count, selectable-text, font-embedding,
evidence-binding, cross-brand, and high-resolution visual checks. The editable
source package and executive summaries remain in the controlled delivery archive
and are not part of the customer-facing download set. See [REPORT_QA.md](REPORT_QA.md).

No synthetic personal signatory, handwritten signature image, seal, or invented
institutional report number is included.

See [SECURITY.md](SECURITY.md) for responsible disclosure.
