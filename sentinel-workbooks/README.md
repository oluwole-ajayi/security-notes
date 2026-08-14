# Identity Risk Dashboard

A portable Microsoft Sentinel workbook for reviewing identity-related security activity from Microsoft Entra ID logs.

The dashboard provides four focused views:

1. Sign-in outcomes and access-control interruptions
2. Potential repeated MFA-failure patterns
3. Sensitive identity administration
4. OAuth consent activity

The workbook is designed for Microsoft 365 Business Premium and Microsoft Entra ID P1 environments. It deliberately avoids dependence on Microsoft Entra ID Protection risk-level fields, which might not be available without Entra ID P2.

## Repository contents

| File | Purpose |
|---|---|
| `identity-risk-dashboard.json` | Importable Microsoft Sentinel workbook gallery template |
| `README.md` | Deployment, interpretation and validation guidance |

## Dashboard panes

### 1. Sign-in outcomes and access-control interruptions

Summarises successful sign-ins and common unsuccessful or interrupted outcomes.

The query provides plain-English labels for selected Microsoft Entra result codes:

| Result code | Dashboard label |
|---|---|
| `0` | Successful sign-in |
| `65001` | Application consent required |
| `50097` | Device authentication required |
| `50140` | Keep me signed in interruption |
| `500121` | MFA authentication failed |

An unsuccessful sign-in is not automatically malicious. Analysts should review the user, application, IP address, device, Conditional Access result and authentication context before reaching a conclusion.

### 2. Potential repeated MFA-failure patterns

Identifies five-minute windows containing at least three distinct MFA-failure correlations for the same user and IP address.

The pane displays the number of matching patterns.

A positive result is an investigation indicator, not proof of an MFA-fatigue attack. Error `500121` represents a strong-authentication failure and can occur for several legitimate or malicious reasons.

A value of zero is a valid healthy-state result.

### 3. Sensitive identity administration

Summarises successful identity-administration operations, including:

- Role membership changes
- Application role assignment changes
- Password resets
- Authentication-method changes
- User deletion
- Conditional Access policy changes
- Security-relevant user updates

Results are aggregated by operation name. This avoids exposing user principal names, targets and correlation identifiers in the dashboard while preserving useful activity counts.

### 4. OAuth consent activity

Summarises successful `Consent to application` events by application.

The pane displays:

- Application name
- Number of consent events
- Latest event time
- Observed delegated scopes

Consent activity is not automatically malicious. Applications and permissions should be assessed against business purpose, publisher information, user context and approved application inventory.

## Requirements

- A Microsoft Sentinel environment in the Microsoft Defender portal
- Access to a Log Analytics workspace
- Microsoft Entra ID diagnostic logs sent to that workspace
- `SigninLogs` populated for the sign-in panes
- `AuditLogs` populated for the administration and consent panes
- Permission to query the selected workspace
- Appropriate permission to create or edit Microsoft Sentinel workbooks

The workbook does not require Entra ID P2 risk scoring for its core queries.

## Import

1. Download `identity-risk-dashboard.json`.
2. Open the Microsoft Defender portal.
3. Go to **Microsoft Sentinel > Threat management > Workbooks**.
4. Open **My workbooks**.
5. Create a new workbook.
6. Select **Edit > Advanced editor**.
7. Open the **Gallery Template** tab.
8. Replace the existing JSON with the contents of `identity-risk-dashboard.json`.
9. Apply the template.
10. Select the Log Analytics workspace containing `SigninLogs` and `AuditLogs`.
11. Select the required time range.
12. Save the workbook to a Microsoft Sentinel-enabled workspace.

## Parameters

### Workspace

A required resource selector used by all four queries.

The published JSON does not contain a fixed subscription, resource group, tenant or workspace identifier.

### TimeRange

A required time-range selector with a default of 30 days.

Changing this parameter updates all four panes.

## Data interpretation

This workbook is intended for triage and investigation support.

It does not:

- Assign a risk score to users
- Confirm that an MFA-fatigue attack occurred
- Determine whether an OAuth application is malicious
- Replace incident investigation
- Replace Conditional Access, identity governance or detection rules

Low-volume environments might show zero or limited results. That is not a workbook failure if the required tables are present and the queries complete successfully.

## Tuning guidance

### Repeated MFA failures

The default threshold is:

- At least three distinct correlation identifiers
- Same user
- Same IP address
- Within five minutes

Adjust this threshold only after reviewing normal authentication behaviour in the environment.

### Sensitive administration

Review the operation allowlist against the tenant's administrative processes.

Additional operation names can be added where necessary, but broad keyword matching can introduce unrelated user-management events.

### OAuth consent

Compare applications and delegated scopes with:

- Approved application inventory
- Publisher verification
- Application ownership
- Expected business use
- User-consent policy
- Admin-consent workflow

## Privacy and portability

The published workbook:

- Contains no tenant ID
- Contains no subscription ID
- Contains no fixed resource group
- Contains no fixed workspace name
- Contains no user principal name
- Uses a required Workspace parameter
- Aggregates administration and consent results for safer demonstration

Query results remain in the selected Log Analytics workspace and are not embedded in the JSON file.

## Validation

The workbook was validated against Microsoft Entra `SigninLogs` and `AuditLogs` in a controlled lab.

Validation included:

- Successful execution of all four queries
- A valid zero-result state for repeated MFA failures
- Elimination of row multiplication from expanded audit targets
- Aggregation of sensitive administration activity
- Positive and benign OAuth-consent observations
- Removal of tenant-specific resource identifiers
- Fresh import of the sanitised gallery template
- Successful workspace selection after import
- Successful reproduction of all four dashboard panes

## Limitations

- Available results depend on log ingestion and retention.
- Microsoft audit schemas and operation names can change.
- Some tenants might use different result descriptions or administrative operations.
- Native Entra risk-level fields are intentionally not required.
- Analysts must validate findings using the underlying sign-in and audit records.

## References

- [Microsoft Sentinel workbooks](https://learn.microsoft.com/en-us/azure/sentinel/monitor-your-data)
- [Azure Workbook parameters](https://learn.microsoft.com/en-us/azure/azure-monitor/visualize/workbooks-parameters)
- [SigninLogs table reference](https://learn.microsoft.com/en-us/azure/azure-monitor/reference/tables/signinlogs)
- [AuditLogs table reference](https://learn.microsoft.com/en-us/azure/azure-monitor/reference/tables/auditlogs)
- [Microsoft Entra diagnostic settings](https://learn.microsoft.com/en-us/entra/identity/monitoring-health/howto-configure-diagnostic-settings)

## Author

Oluwole Ajayi
Cybersecurity professional and founder of Techlync Solutions

GitHub: [oluwole-ajayi](https://github.com/oluwole-ajayi)
