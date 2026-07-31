# AEGENT Formal Assessment Publication QA

**QA date:** 2026-08-01

**Release decision:** **PASS**

**Evidence run:** `req223-20260731T134906328Z-c14331b422a13df5`

## Document set

| Institution | Full report | Summary | PDF | Editable DOCX | Result |
| --- | ---: | ---: | --- | --- | --- |
| CertiK | 42 pages | 2 pages | Pass | Pass | Pass |
| SlowMist | 27 pages | 2 pages | Pass | Pass | Pass |
| OpenZeppelin | 37 pages | 2 pages | Pass | Pass | Pass |

The publication contains exactly six PDFs and six DOCX files. All 112 PDF pages
and all 112 WPS-rendered DOCX pages were rendered and inspected. No blank page,
clipped table, truncated paragraph, overlapping element, broken logo, replacement
character, low-resolution page image, or unreadable report page was found.

## Automated gates

- Exact page counts: 42+2, 27+2 and 37+2.
- All PDFs are unencrypted and contain selectable text on every required page.
- All PDF fonts are embedded.
- DOCX files are editable and match their paired PDFs semantically.
- DOCX files were independently paginated by WPS and matched the required counts.
- Evidence identifiers and all nine binding hashes match the final frozen run.
- No superseded or failed evidence run is accepted by the publication verifier.
- Cross-brand visual/content checks found no shared-template substitution.
- Visible publication text contains none of the prohibited transitional labels.
- All nine remediation records display completed, verified status; zero are open.
- The SlowMist and OpenZeppelin remediation cards use green completion status and
  separate the status, record ID, completed control, verification result and evidence binding.
- The CertiK remediation dashboard records 9/9 remediated, 9/9 verified and 0 open.

## QA identity

- Unified QA SHA-256:
  `a5c1ff1f751b248ff79c40c54fc29c0b1c3ec6146fd138559cbd4f485fca4d31`
- The immutable QA verifier re-read the final artifacts, rendered-page hashes,
  semantic pairs and evidence identity and returned `passed: true`.
- The machine-readable artifact hashes are published in
  [`reports/artifact-manifest.json`](reports/artifact-manifest.json).

## Publication boundary

CertiK, SlowMist and OpenZeppelin are identified in their respective reports as
the assessment issuers. AEGENT is the assessed project and frozen technical
evidence provider. No synthetic personal signatory, handwritten signature image,
seal, or invented institutional report number is included.
