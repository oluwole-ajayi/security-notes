# Suspicious Inbox Forwarding Rules

Detects successful creation or modification of Microsoft Exchange inbox rules that forward, redirect, or forward messages as attachments to an external email address.

External forwarding can provide persistence and email collection after a mailbox compromise, including during business email compromise (BEC).

## Detection file

* `inbox-forwarding-rules.kql`

## What the query detects

The query examines Exchange events in the Microsoft Sentinel `OfficeActivity` table and detects these forwarding actions:

* `ForwardTo`
* `RedirectTo`
* `ForwardAsAttachmentTo`

It parses the Exchange audit parameters, extracts each forwarding destination, compares its domain with the organisation's internal domains, applies narrowly scoped allowlists, and normalizes the source IP address and port.

The query covers these operations when their audit records contain forwarding parameters:

* `New-InboxRule`
* `Set-InboxRule`
* `UpdateInboxRules`

## Data requirements

* Microsoft Sentinel enabled on a Log Analytics workspace.
* Microsoft 365 solution installed from the Sentinel Content hub.
* Microsoft 365 data connector connected for Exchange activity.
* Microsoft 365 unified auditing enabled.
* Exchange events available in the `OfficeActivity` table.

Confirm that Exchange data is arriving:

```kusto
OfficeActivity
| where TimeGenerated > ago(24h)
| where OfficeWorkload =~ "Exchange"
| summarize EventCount=count(), LatestEvent=max(TimeGenerated)
```

## Configuration

Before operational use, replace the example values in `InternalDomains`:

```kusto
let InternalDomains = dynamic([
    "contoso.com",
    "contoso.onmicrosoft.com"
]);
```

Include every accepted email domain that should be treated as internal. Keep all entries lowercase.

If an internal domain is omitted, forwarding to that domain will be reported as external.

## Tuning guidance

Investigate initial results before adding exclusions. Prefer the narrowest possible exception.

### Mailbox-to-destination pair

This is the preferred option for a legitimate shared or delegated mailbox workflow:

```kusto
let AllowedMailboxTargetPairs = dynamic([
    "shared-mailbox@contoso.com|approved-archive@example.net"
]);
```

This suppresses only the documented mailbox and destination relationship.

### Exact forwarding destination

Use this only when the destination is approved for every applicable mailbox:

```kusto
let AllowedForwardingAddresses = dynamic([
    "approved-archive@example.net"
]);
```

### Stable rule name

Use this only for a centrally managed rule with controlled ownership:

```kusto
let AllowedRuleNames = dynamic([
    "approved crm forwarding"
]);
```

Rule-name exclusions are easier to imitate. Prefer a mailbox-to-destination pair whenever possible.

Avoid broadly excluding every administrator-created rule, every shared mailbox, or an entire external domain without a documented requirement.

## Suggested Microsoft Sentinel analytic rule

| Setting           | Suggested value                           |
| ----------------- | ----------------------------------------- |
| Name              | Suspicious external inbox forwarding rule |
| Severity          | Medium                                    |
| Query frequency   | 15 minutes                                |
| Query period      | 1 hour                                    |
| Trigger threshold | Greater than 0                            |
| Tactics           | Collection, Persistence                   |
| Technique         | T1114.003 – Email Forwarding Rule         |

For scheduled use, change `QueryPeriod` in the KQL file to `1h`.

Recommended entity mappings:

| Entity  | Identifier | Query column       |
| ------- | ---------- | ------------------ |
| Account | FullName   | `UserId`           |
| Account | Name       | `AccountName`      |
| Account | UPNSuffix  | `AccountUPNSuffix` |
| IP      | Address    | `SourceIPAddress`  |

Consider grouping alerts by mailbox, rule name, and forwarding destination to reduce duplicate incidents caused by overlapping query windows.

## Investigation guidance

When the query returns a result:

1. Confirm whether the inbox rule still exists and whether it is enabled.
2. Verify the forwarding destination and documented business purpose.
3. Identify who created or modified the rule.
4. Review sign-in activity around the event time.
5. Check for unfamiliar IP addresses, locations, devices, or user agents.
6. Review recent MFA changes, consent grants, and mailbox delegation.
7. Search for additional inbox rules or mailbox-level forwarding.
8. Review message trace and related email activity.
9. Preserve relevant evidence before disabling or removing the rule.
10. Reset credentials and revoke sessions if compromise is suspected.

A detection result is an investigation signal, not proof that an account has been compromised.

## Validation performed

The query was validated in an isolated Microsoft 365 and Sentinel lab:

* A benign subject-only inbox rule was excluded.
* A rule forwarding to a controlled external destination was detected.
* The forwarding rule was immediately disabled before any test message was sent.
* The `New-InboxRule` event was detected in `OfficeActivity`.
* The forwarding action, destination address, and external domain were extracted.
* An exact-address allowlist suppressed the expected result.
* A successful `Set-InboxRule` event was confirmed in the Microsoft 365 unified audit log.
* The source IP address and port were normalized into separate fields.

Tenant identifiers, mailbox addresses, subscription identifiers, IP addresses, and raw audit evidence are not included in this repository.

## Known limitations

* Audit and connector ingestion can be delayed.
* The audit event must expose a recognizable forwarding parameter and SMTP address.
* Some `UpdateInboxRules` events may not contain enough detail to identify the forwarding destination.
* The query does not detect mailbox-level forwarding configured through `Set-Mailbox`.
* The query does not detect Exchange transport rules.
* Broad or inaccurate allowlists can hide malicious activity.
* The internal-domain list must be maintained as accepted domains change.

Mailbox-level forwarding and transport-rule forwarding should be covered by separate detections.

## References

* [OfficeActivity table reference](https://learn.microsoft.com/azure/azure-monitor/reference/tables/officeactivity)
* [New-InboxRule reference](https://learn.microsoft.com/powershell/module/exchangepowershell/new-inboxrule)
* [Search-UnifiedAuditLog reference](https://learn.microsoft.com/powershell/module/exchangepowershell/search-unifiedauditlog)
* [Create Microsoft Sentinel scheduled analytics rules](https://learn.microsoft.com/azure/sentinel/create-analytics-rules)
* [Microsoft Sentinel Microsoft 365 reference detection](https://github.com/Azure/Azure-Sentinel/blob/master/Solutions/Microsoft%20365/Analytic%20Rules/Office_MailForwarding.yaml)
* [MITRE ATT&CK T1114.003: Email Forwarding Rule](https://attack.mitre.org/techniques/T1114/003/)

## License

This detection is provided under the repository's MIT License.
