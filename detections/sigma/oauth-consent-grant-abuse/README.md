# OAuth consent grant with offline access and sensitive scopes

This detection identifies successful Microsoft Entra ID application-consent
events where `offline_access` is granted together with a sensitive delegated
permission.

The combination matters because `offline_access` allows an application to
request refresh tokens, while the accompanying delegated permission determines
which user data or service the application can access.

`offline_access` alone is not treated as suspicious.

## Detection logic

The detection requires all the following:

1. A successful `Consent to application` operation.
2. A `ConsentAction.Permissions` modified property.
3. The `offline_access` scope.
4. At least one sensitive delegated permission.
5. No matching approved application-to-scope exclusion.

The sensitive permission families follow Microsoft incident-response guidance:

- `Mail.*`, excluding `Mail.ReadBasic*`
- `Contacts.*`
- `MailboxSettings.*`
- `People.*`
- `Files.*`
- `Notes.*`
- `Directory.AccessAsUser.All`
- `user_impersonation`

## Files

- `oauth-consent-grant-abuse.yml` — portable Sigma detection logic.
- `sentinel.kql` — deploy-tested Sentinel and Log Analytics query.
- `README.md` — implementation, tuning and validation guidance.

## Required telemetry

Microsoft Entra audit logs must be routed to the target SIEM.

The relevant event contains:

- Operation: `Consent to application`
- Result: `success`
- Modified-property name: `ConsentAction.Permissions`
- Modified-property value containing the consent type and scopes

In Sentinel, the permission data is nested inside:

    TargetResources[].modifiedProperties[]

The KQL expands these arrays and extracts the property whose `displayName`
equals `ConsentAction.Permissions`.

## Sigma field normalisation

| Sigma field | Meaning |
| --- | --- |
| `OperationName` | Entra audit operation name |
| `Result` | Operation result |
| `ConsentAction.Permissions` | New value of the matching modified property |

A processing pipeline or SIEM-side extraction must populate
`ConsentAction.Permissions` before applying the portable Sigma logic.

## Microsoft Sentinel

Use `sentinel.kql`.

The query:

- Expands `TargetResources` and `modifiedProperties`.
- Extracts the client ID, consent type and granted scopes.
- Requires exact `offline_access` membership.
- Matches Microsoft’s documented sensitive permission families.
- Excludes `Mail.ReadBasic*`.
- Supports exact client-ID-to-scope allowlisting.
- Returns the initiating identity and correlation ID.

For an analytics rule, align `Lookback` with the rule’s query period and
execution frequency.

## Elastic Security

Elastic’s Azure integration commonly maps Entra events to the
`azure.auditlogs` dataset.

Relevant fields include:

- `azure.auditlogs.operation_name`
- `azure.auditlogs.properties.result`
- `azure.auditlogs.properties.target_resources.*.display_name`
- `azure.auditlogs.properties.target_resources.*.modified_properties.*.display_name`
- `azure.auditlogs.properties.target_resources.*.modified_properties.*.new_value`

Create an ingest pipeline, runtime field or detection-specific extraction that
copies the matching `new_value` into the normalised
`ConsentAction.Permissions` field.

Review generated Lucene, EQL or ES|QL against the field structure produced by
your installed Elastic Azure integration before deployment.

## Splunk

Collect Microsoft Entra directory-audit events through an appropriate
Microsoft Cloud Services, Microsoft Azure or Microsoft 365 input.

Use `spath` and `mvexpand`, or equivalent index-time extraction, to:

1. Expand `targetResources`.
2. Expand `modifiedProperties`.
3. Select `displayName="ConsentAction.Permissions"`.
4. Expose its `newValue` as `ConsentAction.Permissions`.

Index, source type and field naming vary by collection method. Map those fields
before using Sigma-generated SPL.

The Sigma Splunk backend confirms query portability, but its output is not
automatically production-ready without an environment-specific processing
pipeline and field mapping.

## Tuning

Prefer an exact application-ID-to-sensitive-scope exclusion:

    approved-client-id|mail.read

This is narrower than excluding an entire application name, permission family,
publisher or tenant.

Review each exclusion against:

- Business owner and purpose
- Publisher verification
- Application age and registration tenant
- Redirect URIs
- Consent type: `Principal` or `AllPrincipals`
- Expected users and groups
- Approved permission set
- Permission changes over time

## Investigation guidance

When the detection fires:

1. Confirm who granted consent and whether it was expected.
2. Review the application, service principal, publisher and redirect URIs.
3. Examine the complete delegated permission grant.
4. Determine whether consent was user-specific or tenant-wide.
5. Review sign-in and Microsoft Graph activity for the application.
6. Look for access to mail, files, contacts, notes or directory data.
7. If malicious, disable the enterprise application, revoke consent and revoke
   affected user sessions and refresh tokens.

## Validation

Validated on 11 August 2026 in an isolated Microsoft 365 Business Premium
tenant with Microsoft Entra ID P1 audit logs routed to Log Analytics.

Controlled positive case:

    openid profile offline_access Mail.Read

Result: detected successfully.

Controlled benign case:

    openid profile offline_access

Result: zero detection matches.

The initial Sentinel implementation preserved the benign row with an empty
matched-scope array. Explicit non-empty array checks corrected this behaviour.

Final validation results:

- Detection rows: 4
- Positive application rows: 4
- Benign application rows: 0

Multiple records were produced by repeated consent processing. Use correlation,
time grouping or alert suppression to manage duplicate alerts.

No authorisation code was redeemed. No access token or refresh token was
obtained during testing.

The Sigma YAML parsed successfully and converted through the Kusto backend with
exit code `0`. The generated expression validates the portable rule structure;
`sentinel.kql` remains the deploy-tested Sentinel implementation.

Only `Mail.Read` and the `offline_access`-only control were exercised in the
live test. The remaining permission families come from Microsoft’s published
incident-response guidance and should be validated against each organisation’s
telemetry.

## ATT&CK mapping

This rule maps to:

- Credential Access
- T1528 — Steal Application Access Token

The consent event is an enabling or precursor signal. It does not, by itself,
prove that an access token was issued, stolen or used.

## References

- [Microsoft: App consent grant investigation](https://learn.microsoft.com/en-us/security/operations/incident-response-playbook-app-consent)
- [Microsoft: OAuth 2.0 authorisation-code flow](https://learn.microsoft.com/en-us/entra/identity-platform/v2-oauth2-auth-code-flow)
- [MITRE ATT&CK T1528](https://attack.mitre.org/techniques/T1528/)
- [Elastic Azure audit-log fields](https://www.elastic.co/docs/reference/beats/filebeat/exported-fields-azure)
- [Sigma CLI](https://github.com/SigmaHQ/sigma-cli)
