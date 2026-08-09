# aws-hardened-s3

A reusable Terraform module for an S3 bucket with explicit security guardrails. It is paired with [`azure-hardened-blob`](../azure-hardened-blob/) to compare the same security intent through each cloud's native controls.

## What the module configures

1. All four bucket-level S3 Block Public Access settings enabled.
2. `BucketOwnerEnforced` object ownership, which disables ACLs.
3. A bucket policy that denies non-service requests over HTTP or TLS below 1.2.
4. Explicit default encryption: SSE-S3, or SSE-KMS when a KMS key ARN is supplied.
5. Versioning enabled.
6. Optional server access logging to a pre-existing destination bucket.

AWS has enabled Block Public Access and disabled ACLs by default for new buckets since April 2023. The module still declares these controls so the security posture is versioned and reviewable rather than dependent on a platform default.

## Prerequisites

- Terraform 1.8 or later.
- AWS provider 6.x.
- AWS CLI credentials for a personal lab account or an approved sandbox.
- A configured AWS region; the basic example defaults to `eu-west-2`.

Do not use a client or employer account for this lab unless you have explicit authorisation.

## Deploy the basic example

```powershell
Set-Location "./examples/basic"

terraform init
terraform fmt -check -recursive
terraform validate

terraform plan `
    -var "bucket_name=<globally-unique-bucket-name>" `
    -out "hardened-s3.tfplan"

terraform apply "hardened-s3.tfplan"
```

The example sets `force_destroy = true` only to make lab cleanup reliable. The module default is `false`.

## Verify the deployed bucket

```powershell
$bucketName = "<globally-unique-bucket-name>"

aws s3api get-public-access-block `
    --bucket $bucketName

aws s3api get-bucket-ownership-controls `
    --bucket $bucketName

aws s3api get-bucket-versioning `
    --bucket $bucketName

aws s3api get-bucket-encryption `
    --bucket $bucketName
```

For the transport-policy evidence:

```powershell
aws s3api get-bucket-policy `
    --bucket $bucketName `
    --query Policy `
    --output text |
    ConvertFrom-Json |
    Select-Object -ExpandProperty Statement |
    Select-Object Sid, Effect, Action, Condition |
    Format-List
```

## Safe comparison example

[`examples/relaxed-guardrails`](./examples/relaxed-guardrails/) turns off the four bucket-level Public Access Block settings for `terraform plan`. It deliberately adds no public policy, ACL or object.

Turning off S3 Block Public Access does **not** by itself make the bucket public. It removes a preventive guardrail that would otherwise reject public policies or ACLs. Account-level Block Public Access may still override the bucket setting.

## Cross-cloud comparison

| Security intent | AWS S3 | Azure Blob Storage |
| --- | --- | --- |
| Prevent anonymous/public authorisation | Four S3 Block Public Access settings plus IAM and bucket policies | `allowBlobPublicAccess: false` |
| Remove the public network path | Restrict access with a VPC endpoint and bucket/access-point policies; Public Access Block alone does not remove the public S3 endpoint | `publicNetworkAccess: 'Disabled'` |
| Enforce HTTPS | Bucket-policy deny using `aws:SecureTransport` | `supportsHttpsTrafficOnly: true` |
| Enforce TLS 1.2 minimum | Bucket-policy deny using `s3:TlsVersion` | `minimumTlsVersion: 'TLS1_2'` |
| Disable legacy ACL authorisation | `BucketOwnerEnforced` | Blob authorisation does not use the S3 ACL model |
| Prefer identity-based access | IAM roles, policies, SCPs and resource policies | Entra ID/RBAC plus `allowSharedKeyAccess: false` |
| Recover changed/deleted objects | S3 Versioning | Blob versioning and soft delete |

## Important authentication difference

Azure has a first-class property that disables Shared Key authorisation. AWS S3 does not have a Shared Key mode that maps directly to that Azure feature. AWS long-term access keys, temporary STS credentials, roles, IAM policies and resource policies are parts of a different authorisation model.

Do not describe a SigV4 or `AssumedRole` bucket-policy condition as an exact equivalent to Azure's `allowSharedKeyAccess: false`. For AWS, prefer workload roles and control long-term credentials through IAM, organisations policies and credential governance.

## Encryption note

S3 automatically encrypts new objects with SSE-S3. This module declares the default explicitly and lets callers select SSE-KMS when they need customer-managed key control. KMS permissions and key policy design remain the caller's responsibility.

## Access logging note

When `access_log_bucket` is supplied, the destination bucket must already exist and must allow the S3 logging service to write objects. This module does not manage the destination bucket or its policy.

## Cleanup

From `examples/basic`:

```powershell
terraform destroy `
    -var "bucket_name=<globally-unique-bucket-name>"
```

## References

- [AWS S3 security best practices](https://docs.aws.amazon.com/AmazonS3/latest/userguide/security-best-practices.html)
- [S3 Block Public Access](https://docs.aws.amazon.com/AmazonS3/latest/userguide/access-control-block-public-access.html)
- [S3 bucket policy condition keys](https://docs.aws.amazon.com/AmazonS3/latest/userguide/amazon-s3-policy-keys.html)
- [S3 default encryption](https://docs.aws.amazon.com/AmazonS3/latest/userguide/default-bucket-encryption.html)
- [Terraform AWS provider](https://registry.terraform.io/providers/hashicorp/aws/latest)


## Deployment validation

- Successfully deploy-tested on 9 August 2026 in `eu-west-2` with Terraform 1.15.8 and AWS provider 6.58.0.
- Apply result: six resources added, zero changed and zero destroyed.
- Verified all four Block Public Access controls, non-public policy status, `BucketOwnerEnforced`, versioning, SSE-S3 and the HTTP/TLS deny statements.

## Author

[Oluwole Ajayi](https://github.com/oluwole-ajayi)
