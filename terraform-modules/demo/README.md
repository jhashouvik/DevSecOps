# Terraform state

This configuration stores its state in the existing S3 bucket:

`s3://state-backup-file/terraform-modules/demo/terraform.tfstate`

The bucket must be in Mumbai (`ap-south-1`). The pipeline's existing AWS
credentials are used by `terraform init` to access it. Terraform 1.10 or later
is required for S3 state locking; no DynamoDB table is needed.

Enable S3 Bucket Versioning on the bucket to retain earlier state versions.
The backend configuration does not enable bucket versioning itself.

The pipeline's IAM identity needs `s3:ListBucket` on the bucket,
`s3:GetObject` and `s3:PutObject` on the state object, and
`s3:GetObject`, `s3:PutObject`, and `s3:DeleteObject` on
`terraform-modules/demo/terraform.tfstate.tflock` in that bucket.

For a fresh pipeline checkout, the existing `terraform init` step initializes
this backend automatically. If you have local state tracking existing resources,
run `terraform init -migrate-state` from this directory with the correct AWS
credentials before running the pipeline. State lost from a previous runner
cannot be recovered by adding a backend; surviving resources must be imported.

The pipeline currently destroys infrastructure after applying it. This updates
the remote state to reflect the destruction; it does not delete the state bucket.
Earlier state snapshots are retained only if bucket versioning is enabled.
