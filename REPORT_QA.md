# AEGENT Security Assessment Publication QA

**QA date:** 2026-07-29  
**Release decision:** Pass  
**Assessed set:** three AEGENT-authored Markdown/DOCX/PDF reports

## Document set

| Report | PDF pages | Visual result | DOCX accessibility | PDF text |
| --- | ---: | --- | --- | --- |
| `AEGENT-Security-Assessment-Core-2026-07` | 11 | Pass | 0 High / 0 Medium / 0 Low | Pass |
| `AEGENT-Security-Assessment-Assurance-Matrix-2026-07` | 12 | Pass | 0 High / 0 Medium / 0 Low | Pass |
| `AEGENT-Security-Assessment-Threat-Model-2026-07` | 15 | Pass | 0 High / 0 Medium / 0 Low | Pass |

All **38 PDF pages** were rendered at 144 DPI and visually inspected. No blank page, clipped table, truncated paragraph, overlapping element, edge collision, missing page number, broken header/footer, replacement character, or unreadable report page was found.

## Automated checks

- DOCX headings use Heading 1/2 styles for report-body navigation.
- DOCX table geometry: all tables have matching exact `tblW`, `tblInd`, `tblGrid`, and `tcW`.
- DOCX accessibility: all three reports return 0 High / 0 Medium / 0 Low findings.
- PDF extraction: all three PDFs are unencrypted, contain the final disposition, contain all seven accepted finding IDs, and contain zero Unicode replacement characters.
- Hyperlinks: final Markdown and DOCX report links resolve to public GitHub source/test evidence under `https://github.com/yxmail888-boop/aegent-security-reports`.
- Content safety: all reports identify the author and issuer as the AEGENT Security Review Team and explicitly state that no OpenZeppelin, CertiK, SlowMist, Binance, or other third party authored, reviewed, endorsed, signed, certified, numbered, or issued the reports.
- Numbered lists preserve the source Markdown numbering and reset correctly by section.

## Rendering path

DOCX files were generated with `python-docx`. PDF files were exported through a local Word-compatible office-suite automation interface, then normalized by the AEGENT document pipeline. PDFs were independently rendered with Poppler at 144 DPI for visual inspection and parsed with `pypdf` for text-level validation.

## Release hashes

| File | SHA-256 | Bytes |
| --- | --- | ---: |
| `reports/AEGENT-Security-Assessment-Core-2026-07.docx` | `c9db396a9365a315a3d09e33dca61ff56db1cb26da05853ca33dbefa260cc7ce` | 94,667 |
| `reports/AEGENT-Security-Assessment-Core-2026-07.md` | `dfbd0ca16648500513298f888a371d61d48628d4005f85f20e9d972ab93c3561` | 23,926 |
| `reports/AEGENT-Security-Assessment-Core-2026-07.pdf` | `1aa373a1efd16b21e2168fb94d0cfe94267853dca7df80d58a72d0cafd802d29` | 172,040 |
| `reports/AEGENT-Security-Assessment-Assurance-Matrix-2026-07.docx` | `41dc9aec22ccb4b90c8d36d6643580e79456f20f7fea83548f879be1034e314d` | 96,548 |
| `reports/AEGENT-Security-Assessment-Assurance-Matrix-2026-07.md` | `a777ce00f4d77d5e18a1d8fe329fa16b2fff3a2be15471003091f950c9fc40c1` | 25,303 |
| `reports/AEGENT-Security-Assessment-Assurance-Matrix-2026-07.pdf` | `4854fa56df7884647ba7c63160d9f23a147b2f28c269d302fdd823e2d064ab08` | 179,770 |
| `reports/AEGENT-Security-Assessment-Threat-Model-2026-07.docx` | `458cf3f1ffd19b64b00d93bd8e7dd518157272e3e45c5b3f96403dee1804cc7f` | 98,977 |
| `reports/AEGENT-Security-Assessment-Threat-Model-2026-07.md` | `278503636b9592f027147a236b4743e7f45e4b25df591cb8c51e5082033d30fa` | 29,698 |
| `reports/AEGENT-Security-Assessment-Threat-Model-2026-07.pdf` | `7e3d91d3dcf48631ed3652210f2534d9aa2ba7ea222a336b21e67ae8170e0b36` | 197,539 |

## Final release boundary

The package passes document-production QA. This is a first-party point-in-time assessment of a frozen source snapshot. The final technical disposition remains **remediation required before mainnet**.
