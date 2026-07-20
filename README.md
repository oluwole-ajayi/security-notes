# security-notes

A public working notebook - detection rules, cloud security infrastructure-as-code, and audit scripts from a UK cybersecurity practitioner.

## About

This repository is my personal working notebook. I publish things here as I build them in the course of my applied work: detection rules I tune, cloud security infrastructure-as-code I write, audit scripts I run against tenants I look after, and short notes from engagements and research.

Content is UK-context, SME-oriented, and vendor-honest - I write about what works, what doesn't, and what I'd send elsewhere.

## What lives here

- **`/detections`** — Detection rules for Microsoft Sentinel (KQL) and vendor-neutral formats (Sigma). Each rule ships with the ATT&CK technique it covers, false-positive tuning notes, and deployment guidance.
- **`/iac`** — Infrastructure-as-code modules for cloud security baselines. Bicep for Azure, Terraform for AWS. Each module is deploy-tested and includes a README explaining the security controls it enforces.
- **`/scripts`** — Audit and operational scripts. Mostly PowerShell (Microsoft Graph) and Python. Each script does one thing well.
- **`/sentinel-workbooks`** — Importable Microsoft Sentinel workbook JSONs for common defensive dashboards (identity risk, cloud posture, incident triage).

See [`starter/hello.md`](./starter/hello.md) for the current folder tree.

## Using this repository

Everything here is MIT-licensed - use it, fork it, ship it into production, no attribution required. If you find a bug or want to propose an improvement, open an issue or a PR.

If you deploy the IaC modules against a production environment, please read the module README first. The modules are opinionated - they enforce security defaults that may conflict with existing patterns in your estate.

## Contributing

See [CONTRIBUTING.md](./CONTRIBUTING.md). Detection-rule PRs are especially welcome — peer tuning improves quality, and the catalogue grows better with more eyes on it.

## About me

I'm Oluwole Isaac Ajayi - a UK-based Cybersecurity Engineer with over nine years of security practitioner experience. MSc in Applied Cybersecurity (Distinction) from the University of South Wales; my dissertation researched LLM-based detection of injection-class vulnerabilities. Certifications include CompTIA Security+, CySA+, CSAP, Microsoft SC-900, AZ-500, and SC-100, and AZ-900, with CISSP in progress. Currently a Cloud Security Engineer at [ZDL Systems].

Outside of employment I run two ventures:

- **[Techlync Solutions](https://techlynsolutions.co.uk/)** - a UK-registered cybersecurity practice (Companies House 16594063) serving SMEs across professional services, financial services, healthcare, technology, retail, and public sector supply chain.
- **[VeriLync](https://verilync.com/)** - an application security platform under development, commercialising my MSc research on LLM-augmented injection detection.

You can find me on [LinkedIn](https://www.linkedin.com/in/ajayi-isaac/), where I post regularly on cloud security, identity, detection engineering, and the SME security reality.

## License

[MIT](./LICENSE) © 2026 Oluwole Ajayi

