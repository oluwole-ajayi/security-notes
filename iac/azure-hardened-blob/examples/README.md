# Relaxed guardrails comparison

`relaxed-guardrails.bicep` exists only for an Azure `what-if` comparison.

It enables the public network endpoint, permits container-level anonymous access to be configured and sets the network ACL default action to `Allow`. It does not create a container or grant anonymous access to blob data. Public network reachability and anonymous data authorisation are separate controls.

Use `az deployment group what-if` for the video comparison. Do not deploy this example.
