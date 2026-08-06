# Identity attack chain detections

Six Microsoft Sentinel KQL detections mapped one-to-one to an Entra-focused identity attack chain, from a malicious phishing-link click to a critical directory-role assignment.

The detections are behavioral signals. They do not prove that every stage occurred, and they should be correlated through shared users, IP addresses, applications, sessions and time windows during triage.

## The six-stage chain

| Stage | Activity | ATT&CK | Detection | Primary data |
| --- | --- | --- | --- | --- |
| 1 | Malicious phishing-link click | T1566.002 | `01-malicious-phishing-link-click.kql` | `UrlClickEvents` |
| 2 | Credential use after a malicious click | T1056.003, T1078.004 | `02-credential-use-after-phish.kql` | `UrlClickEvents`, `SigninLogs` |
| 3 | Possible AiTM session-cookie replay | T1539, T1550.004 | `03-possible-aitm-session-replay.kql` | `SigninLogs` |
| 4 | Suspicious OAuth consent grant | T1671 | `04-suspicious-oauth-consent.kql` | `AuditLogs` |
| 5 | Account, group and role discovery | T1069.003, T1087.004 | `05-entra-privileged-discovery.kql` | `MicrosoftGraphActivityLogs`, `SigninLogs` |
| 6 | Critical Entra role added | T1098.003 | `06-critical-entra-role-added.kql` | `AuditLogs` |

The title deliberately uses **Entra tenant compromise**, not *domain compromise*. This repository does not claim to cover an on-premises Active Directory domain or hybrid identity attack path.

## Prerequisites

- Microsoft Sentinel connected to a Log Analytics workspace.
- Microsoft Entra `SigninLogs` and `AuditLogs` routed to the workspace.
- Microsoft Graph activity logs routed to the workspace for Stage 5.
- Microsoft Defender for Office 365 Safe Links telemetry for `UrlClickEvents` in Stages 1 and 2.
- Appropriate licensing for each data source.

Stages 1 and 2 will not run where `UrlClickEvents` is unavailable. Do not silently replace that table with unrelated mail-flow telemetry; document the coverage gap instead.

## Recommended deployment model

Create one scheduled analytics rule per query and map the relevant account, IP and application entities. Use consistent naming such as `Identity chain - 01 - Malicious phishing-link click`.

Suggested initial severities:

| Stage | Initial severity | Rationale |
| --- | --- | --- |
| 1 | Low | Malicious-link classification and user interaction need investigation context. |
| 2 | Medium | Successful account use shortly after a malicious click is materially stronger. |
| 3 | Medium | Country changes and VPN switching can create false positives. |
| 4 | Medium | Legitimate application consent is common, but sensitive scopes increase risk. |
| 5 | Medium | Inventory, IAM and administration tools may enumerate the directory legitimately. |
| 6 | High | Unexpected assignment of a critical role requires immediate investigation. |

Sentinel incident grouping can group alerts produced by an analytics rule. Correlation across all six independent rules is not automatic: use matching entity mappings, automation rules, a correlation analytics rule, or Microsoft incident correlation capabilities appropriate to the environment. Do not claim that six independent rules will always become one incident without configuring that behavior.

## Tuning notes

### Stage 1 — malicious phishing-link click

- Requires Microsoft Defender for Office 365 Safe Links data.
- Review `ActionType` and `IsClickedThrough`; blocked clicks and click-through events carry different risk.
- Consider excluding sanctioned security-awareness simulations by campaign identifiers or URLs.
- Preserve `NetworkMessageId` for email investigation.

### Stage 2 — credential use after phish

- The default click-to-sign-in window is 30 minutes.
- This rule observes a successful sign-in after a suspicious click. It cannot observe a password being typed into an attacker-controlled page.
- Exclude approved phishing simulations and expected sign-in infrastructure.
- Increase severity when the sign-in has an unfamiliar device, unusual geography, risky sign-in signal or failed Conditional Access evaluation.

### Stage 3 — possible AiTM session replay

- Impossible travel is a proxy for session replay, not proof of token theft.
- Add expected country transitions to `AllowedCountryPairs` using lowercase ISO-style values returned by your tenant, for example `gb|ie`.
- Corporate VPN egress and mobile carrier routing are common false-positive sources.
- Increase confidence when browser, device ID or user agent also changes and the second session does not show a fresh MFA challenge.
- Microsoft Entra ID Protection detections such as anomalous token signals should be incorporated where licensed.

### Stage 4 — suspicious OAuth consent

- Populate `ApprovedApplications` with exact lowercase names only after owner and permission review.
- Extend `HighRiskScopes` with permissions relevant to the tenant's applications and data.
- Separate delegated user consent from tenant-wide admin consent during triage.
- Investigate the service principal, publisher verification, redirect URIs, credentials and all activity performed with issued tokens.

### Stage 5 — privileged discovery

- The initial threshold is 20 successful GET requests across at least three sensitive target classes inside 15 minutes.
- Lower thresholds may suit a small tenant; large tenants may require higher thresholds or behavioral baselines.
- Populate `ApprovedAppIds` for sanctioned IAM, backup, inventory and security tools.
- User and application identifiers should be resolved and reviewed together. Application-only Graph activity may have no `UserId`.
- This rule detects discovery that may prepare lateral movement; it does not independently prove lateral movement.

### Stage 6 — critical role addition

- Treat every unexpected true positive as high priority.
- Compare the assignment with approved change records and PIM activation history.
- Review both direct and eligible assignments.
- Display names can be localized. Production deployments should consider matching immutable role template IDs where the tenant's audit schema exposes them reliably.
- Investigate the initiating user or application, target principal, source IP and all preceding activity.

## Validation approach

Validate each rule in the target tenant before describing it as tested:

1. Confirm that every required table exists.
2. Run each query in Sentinel Logs and confirm it parses without an error.
3. Record whether the query returned real, benign test or zero results.
4. Test exclusions with approved applications, VPN paths and administrative tools.
5. Convert to scheduled rules only after the hunting queries behave as expected.

An empty result is a valid syntax-validation outcome. It is not evidence that the detection has been validated against a true attack.

## Investigation sequence

When Stage 6 fires unexpectedly:

1. Confirm whether the change was approved and whether PIM was involved.
2. Preserve the audit and sign-in evidence.
3. Disable or contain the affected identity according to the incident-response process.
4. Revoke relevant sessions and application grants.
5. Review the previous seven days for the same user, application, IP and correlation identifiers.
6. Hunt backward through Stages 1–5.
7. Review authentication methods, Conditional Access changes, application credentials, inbox rules and other persistence paths.

## ATT&CK Navigator

Import `attack-navigator-layer.json` into ATT&CK Navigator to display every technique referenced by the six stages. Navigator shows technique coverage; the numbered comments preserve the narrative order because an ATT&CK matrix is not a chronological attack-chain diagram.

## Known limitations

- This is an Entra-focused model, not a complete identity compromise playbook.
- Stages 1 and 2 depend on Defender for Office 365 telemetry.
- Stage 3 uses behavioral indicators and can be noisy.
- Stage 5 requires Microsoft Graph activity logs and may generate ingestion cost.
- OAuth consent, role assignment and authentication-event schemas can vary by operation and tenant behavior. Validate against representative events.
- Detection coverage is not prevention. Phishing-resistant authentication, Conditional Access, least privilege, PIM and consent governance remain essential controls.

## Author

[Oluwole Ajayi](https://github.com/oluwole-ajayi)
