# Relaxed guardrails comparison

This example exists only to make the insecure **configuration posture** visible in `terraform plan`.

It turns off all four bucket-level S3 Block Public Access settings but does not add a public bucket policy, an ACL or any object. Turning off these settings does **not** by itself make the bucket anonymously readable. Account-level S3 Block Public Access may also continue to override the bucket configuration.

Use `terraform plan` for the video comparison. Do not apply this example.
