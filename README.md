# GitHub Repository Aggregator

This project synchronizes repositories from a configured GitHub organization into a single destination repository.

Example:

My_Repo/
├── checkout-ui/
├── payment-deployment/
├── repo-3/
└── repo-4/

A GitHub Actions workflow runs every 30 minutes and discovers repositories automatically.

## Important authorization note

Use this only for repositories and source code that you are explicitly authorized to copy or mirror into the destination repository. Repository access does not automatically grant permission to reproduce company/institution source code in a personal repository.

## What this version does

- Discovers all repositories in the configured source organization that the token can read.
- Automatically detects newly available repositories.
- Synchronizes repository files into `My_Repo/<repository-name>/`.
- Removes `.git` from the copied source repository so nested repositories are not created.
- Keeps the destination repository's own Git history.
- Skips the destination repository if it happens to be in the source organization.
- Supports an allow-list and exclude-list.
- Runs manually or every 30 minutes through GitHub Actions.

## What it does NOT do

This version copies repository contents, not the original Git history/branches/tags of each source repository.

If you need original Git history preserved for every source repository, use a Git subtree/history-preserving implementation instead.

## 1. Configure the source organization

Edit `config/config.json`:

```json
{
  "source_org": "wezva-fintech",
  "include_archived": false,
  "include_forks": true,
  "allow_repositories": [],
  "exclude_repositories": []
}
```

Empty `allow_repositories` means all readable repositories in the organization are considered.

Example restricted list:

```json
{
  "source_org": "wezva-fintech",
  "allow_repositories": [
    "checkout-ui",
    "payment-deployment"
  ]
}
```

## 2. Create a GitHub token

The token used by the workflow must be able to read the source private repositories.

For a fine-grained token, grant the minimum permissions required, normally:

- Metadata: Read
- Contents: Read

Restrict the token to the authorized source repositories/organization.

Do NOT put the token in this repository.

## 3. Add the token as a repository secret

In the destination `My_Repo`:

Settings -> Secrets and variables -> Actions -> New repository secret

Name:

```text
SOURCE_GITHUB_TOKEN
```

Value:

```text
<your GitHub token>
```

## 4. Configure destination workflow

The workflow uses:

```yaml
SOURCE_ORG: wezva-fintech
```

You can instead change it to your organization.

The destination repository is automatically detected using:

```text
github.repository
```

## 5. Run locally

Set the environment variables.

Linux/macOS:

```bash
export SOURCE_GITHUB_TOKEN="YOUR_TOKEN"
export SOURCE_ORG="wezva-fintech"
python scripts/sync_repositories.py
```

PowerShell:

```powershell
$env:SOURCE_GITHUB_TOKEN="YOUR_TOKEN"
$env:SOURCE_ORG="wezva-fintech"
python scripts/sync_repositories.py
```

The script needs:

```bash
pip install requests
```

## 6. Workflow schedule

The included workflow runs:

- manually using `workflow_dispatch`
- every 30 minutes using cron

GitHub Actions scheduled workflows use UTC. GitHub may delay scheduled workflow execution during periods of high load.

## 7. Expected result

Initial run:

```text
Discovered: checkout-ui
Discovered: payment-deployment

My_Repo/
├── checkout-ui/
└── payment-deployment/
```

Later, if a new repository becomes available:

```text
Discovered: checkout-ui
Discovered: payment-deployment
Discovered: payment-gateway

My_Repo/
├── checkout-ui/
├── payment-deployment/
└── payment-gateway/
```

## 8. Security recommendations

- Prefer a fine-grained GitHub token.
- Give read-only access to source repositories.
- Do not commit tokens.
- Do not print tokens in logs.
- Prefer an organization-owned destination for company code.
- Use an allow-list when possible.
- Review your organization's policies before copying private source code.

## 9. Files

```text
.github/workflows/repository-sync.yml
config/config.json
scripts/sync_repositories.py
.gitignore
README.md
```
