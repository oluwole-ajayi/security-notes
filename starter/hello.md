# hello

Initial commit for `security-notes`.

## About this folder

The `starter/` folder holds documentation about the repository itself — how it's organised, why it's structured the way it is, and what to expect over time. As the repository grows, this folder may also hold small template files and boilerplate used across other folders.

## Folder structure

```
security-notes/
├── README.md               — project overview
├── LICENSE                 — MIT license
├── CONTRIBUTING.md         — how to contribute
├── CODE_OF_CONDUCT.md      — expected behaviour
├── starter/                — meta files about the repo (this folder)
├── detections/             — detection rules
│   ├── sentinel/           — Microsoft Sentinel KQL detection rules
│   └── sigma/              — vendor-neutral Sigma rules
├── iac/                    — infrastructure-as-code modules
│   ├── azure-landing-zone/ — Bicep, opinionated Azure baseline
│   ├── aws-hardened-s3/    — Terraform, hardened S3 module
│   └── azure-hardened-blob/— Bicep, hardened Blob Storage module
├── scripts/                — audit and operational scripts (PowerShell / Python)
└── sentinel-workbooks/     — importable Sentinel workbook JSONs
```

## What to expect

Content lands here as it's built. This isn't a curated portfolio — it's a working notebook, with all the trade-offs that implies. Some folders will grow faster than others depending on the applied work at any given time.

## Publishing rhythm

The aim is at least one non-trivial commit per week from month 2 onward. Commits vary in scope: sometimes a new detection rule, sometimes a small documentation update, sometimes a full IaC module.

## First scheduled additions

- Early August 2026 — `iac/` gets its first Bicep module for a hardened Azure Storage account, and `scripts/` gets a PowerShell script to audit baseline Conditional Access policies against any Microsoft 365 tenant.
- Mid-August 2026 — `detections/sentinel/` gets its first KQL detection (attacker-set inbox forwarding rules), and `iac/azure-landing-zone/` receives a full opinionated landing-zone module.
- Late August 2026 — `detections/sigma/` gets its first vendor-neutral Sigma rule (OAuth consent grant abuse), and `sentinel-workbooks/` gets an identity risk dashboard workbook JSON.