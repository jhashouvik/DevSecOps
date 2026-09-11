# Deploy S3 with GitHub Actions

The workflow `.github/workflows/s3-deploy.yml` deploys this directory into the AWS
account belonging to the configured credentials, in `ap-south-1` (Mumbai).
It runs manually and supports `plan` (preview only), `apply` (deployment), and
`destroy` (delete resources managed by this Terraform state).
Concurrent runs are serialized, and Terraform also uses S3 state locking.

## One-time setup

1. Push the workflow to the GitHub repository's default branch so that GitHub
   displays its **Run workflow** button.
2. Under **Settings > Secrets and variables > Actions**, configure repository secrets:
   - `AWS_ACCESS_KEY_ID`
   - `AWS_SECRET_ACCESS_KEY`
   These are the same credential names used by the existing IAC pipeline.
   This workflow uses access-key credentials without a session token.
   `AWS_REGION` is set to `ap-south-1` in the workflow and is not a secret.
3. Ensure `wezvatech-s3-2027-tfstate` already exists in the intended
   AWS account. Confirm its region under S3 **Properties** and set `region` in
   `backend.tf` to match (currently `ap-south-1`). The state bucket region can
   differ from the deployment region in `main.tf`.
   Terraform's backend cannot create its own state bucket during
   initialization. If using a different state bucket, update `backend.tf` and
   the workflow's `head-bucket` check together. Enable versioning on the state
   bucket to allow recovery of earlier state versions.
4. Give the credentials permission to manage the two target buckets (create/read,
   tags, versioning, lifecycle configuration, and deletion for planned replacements).
   Terraform also reads bucket configuration during refresh; the role needs the
   corresponding S3 read permissions. Scope permissions to your target bucket ARNs.
   For the backend, grant `s3:ListBucket` on the state bucket, `s3:GetObject` and
   `s3:PutObject` on `product-name/envs/prod/s3.tfstate`, and `s3:GetObject`,
   `s3:PutObject`, and `s3:DeleteObject` on
   `product-name/envs/prod/s3.tfstate.tflock`. A backend using a customer-managed
   KMS key also needs the appropriate KMS permissions.
5. Review the bucket names in `main.tf`. S3 bucket names must be globally unique.
   The names now include the authenticated AWS account ID and deployment region
   to reduce collisions, for example `wezvatech-dvc-data-lake-123456789012-ap-south-1`.
   No additional GitHub secret is needed for the account ID. These names remain
   stable across runs in the same account and region; availability is checked by
   AWS during creation. Update any IAM policies scoped to the old bucket names.
   When deploying `comprehend-PII-gateway`, pass the resulting data lake bucket name
   as `raw_ingestion_bucket_id`; its default still uses the original name.
   Existing buckets must already be tracked in this Terraform state or be imported
   before deployment. Changing the backend path creates a different state location;
   use state migration if this infrastructure is already managed elsewhere.

## Run the pipeline

1. Open **Actions > Deploy S3 > Run workflow**.
2. Select the branch containing the reviewed Terraform configuration and choose
   `plan`. Read **Show target AWS account** and **Plan S3 changes** in the run logs.
3. Run again with `apply` to deploy. This run creates a fresh plan and applies that
   exact saved plan. It does not reuse the earlier preview; intervening changes
   to code or AWS resources can change the result.
4. Read **Show deployed bucket ARNs** for the resulting bucket identifiers.

## Destroy the deployed buckets

Open **Actions > Deploy S3 > Run workflow**, select the branch with the same
backend used for deployment, and choose `destroy`. This selection authorizes
deletion: the run creates a destroy plan and immediately applies that saved plan.
There is no additional approval pause between the two steps.

Destroy targets all resources managed in this S3 Terraform state, including the
two application buckets and their versioning/lifecycle configuration. The separate
`wezvatech-s3-2027-tfstate` backend bucket is not managed by this module and remains.
The application buckets must be empty, including all object versions and delete
markers. The workflow does not empty them or enable `force_destroy`; nonempty
buckets can cause destruction to fail after some configuration resources have
already been removed. Only empty a bucket if its data is intended for permanent
deletion, then rerun `destroy`. The AWS identity needs permission to delete the
managed buckets and their configuration.

The workflow installs Terraform 1.10.5, which supports the backend's native S3
lock file. It does not automatically run on pushes or destroy resources after
deployment. An apply can still delete or replace resources if the Terraform
configuration calls for it; review the plan before deploying configuration changes.

The existing lifecycle policy archives data and eventually deletes old versions.
Current versions expire after 730 days; noncurrent versions are permanently deleted
180 days after becoming noncurrent. Review these retention settings for your data.

This repository synchronizes source repositories into subdirectories. Make the
corresponding S3 documentation/configuration changes in the source repository too
if synchronization would otherwise overwrite them.

References:
- [Terraform S3 backend permissions and locking](https://developer.hashicorp.com/terraform/language/backend/s3)
- [AWS credentials action](https://github.com/aws-actions/configure-aws-credentials)
- [Terraform setup action](https://github.com/hashicorp/setup-terraform)
