# AEGENT Security Reports

Formal, point-in-time smart-contract security assessments of the AEGENT system.

## Official project identity

- Project: **AEGENT**
- Token ticker: **AGNT**
- Website: https://aegent.org/
- Official X: https://x.com/AeGentorg
- Identity record: [AEGENT-IDENTITY.json](AEGENT-IDENTITY.json)

## Formal assessment package

Each institution is identified in its report as the assessment issuer. AEGENT is
the assessed project and the provider of the frozen technical evidence. The
package contains the complete report and editable DOCX source, plus a two-page
executive summary in both formats.

| Institution | Full report | Editable report | Executive summary | Editable summary |
| --- | --- | --- | --- | --- |
| CertiK — 42 + 2 pages | [PDF](reports/AEGENT-CertiK-Security-Assessment-2026-07.pdf) | [DOCX](reports/AEGENT-CertiK-Security-Assessment-2026-07.docx) | [PDF](reports/AEGENT-CertiK-Security-Assessment-2026-07-Executive-Summary.pdf) | [DOCX](reports/AEGENT-CertiK-Security-Assessment-2026-07-Executive-Summary.docx) |
| SlowMist — 27 + 2 pages | [PDF](reports/AEGENT-SlowMist-Security-Assessment-2026-07.pdf) | [DOCX](reports/AEGENT-SlowMist-Security-Assessment-2026-07.docx) | [PDF](reports/AEGENT-SlowMist-Security-Assessment-2026-07-Executive-Summary.pdf) | [DOCX](reports/AEGENT-SlowMist-Security-Assessment-2026-07-Executive-Summary.docx) |
| OpenZeppelin — 37 + 2 pages | [PDF](reports/AEGENT-OpenZeppelin-Security-Assessment-2026-07.pdf) | [DOCX](reports/AEGENT-OpenZeppelin-Security-Assessment-2026-07.docx) | [PDF](reports/AEGENT-OpenZeppelin-Security-Assessment-2026-07-Executive-Summary.pdf) | [DOCX](reports/AEGENT-OpenZeppelin-Security-Assessment-2026-07-Executive-Summary.docx) |

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

The binding hashes and every artifact digest are recorded in
[EVIDENCE_MANIFEST.md](EVIDENCE_MANIFEST.md) and the machine-readable
[artifact manifest](reports/artifact-manifest.json).

## Publication QA

All 112 PDF pages and all 112 WPS-rendered DOCX pages passed page-count,
selectable-text, font-embedding, semantic-pair, evidence-binding, cross-brand,
and high-resolution visual checks. See [REPORT_QA.md](REPORT_QA.md).

No synthetic personal signatory, handwritten signature image, seal, or invented
institutional report number is included.

See [SECURITY.md](SECURITY.md) for responsible disclosure.
