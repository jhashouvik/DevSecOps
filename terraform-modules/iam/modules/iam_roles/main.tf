
# --- PERSONA 1: THE PLATFORM TEAM (Infrastructure Owners) ---
# Build the VPCs, EKS, and Databases. Manage KMS Keys and RDS Ops
# Admin access for VPCs/EKS but explicitly CANNOT view raw customer data(PII).
module "platform_team_setup" {
  create_role = var.enable_platform_role 

  source  = "terraform-aws-modules/iam/aws//modules/iam-assumable-role"
  version = "~> 5.0"

  role_name   = "Fintech-Platform-Admin"

  # 1. Manage the Networking and EKS "Pipes"
  custom_role_policy_arns = [
    "arn:aws:iam::aws:policy/AmazonVPCFullAccess",
    "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy",
    "arn:aws:iam::aws:policy/AmazonRDSFullAccess" # Manage DB instances/backups
  ]

  inline_policy_statements = [
    {
      sid    = "ManageKMSAndEncryption"
      effect = "Allow"
      actions = [
        "kms:Create*",
        "kms:Describe*",
        "kms:Enable*",
        "kms:List*",
        "kms:PutKeyPolicy",
        "kms:UpdateKeyDescription"
      ]
      resources = ["*"]
    },
    {
      sid    = "DenyPIIDataAccess"
      effect = "Deny"
      # Compliance Guardrail: They can manage the DB/Keys, but not use them to see data.
      actions = [
        "s3:GetObject",
        "dynamodb:GetItem",
        "rds-db:connect", # Cannot log into the DB data layer
        "kms:Decrypt"     # Cannot use keys to decrypt sensitive files manually
      ]
      resources = ["*"]
    }
  ]

  trusted_role_arns = ["arn:aws:iam::${var.account_id}:root"]
}

# --- PERSONA 2: THE PRODUCT TEAM (Application Developers) ---
# Troubleshoot EKS (Read-only) and view data from DB, but CANNOT delete Network.
module "product_team_setup" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-assumable-role"
  version = "~> 5.0"

  create_role = var.enable_product_role
  role_name   = "AppTeam-${var.env_type}-Role"

  inline_policy_statements = [
  {
    sid    = "EKSAndRDSLogic"
    effect = "Allow"
    # Logic: If Prod/UAT, give Read-Only. If QA/Dev, give Full Access.
    actions = (var.env_type == "prod" || var.env_type == "uat") ? [
        "eks:Describe*", 
        "eks:List*", 
        "eks:AccessKubernetesApi",
        "rds:Describe*",
        "ecr:BatchGetImage",
        "ecr:GetDownloadUrlForLayer"
      ] : [
        "eks:*", 
        "rds:*", 
        "ecr:*"
      ]
    resources = ["*"]
  },
  {
    sid    = "DatabaseConnect"
    effect = "Allow"
    actions   = ["rds-db:connect"]
    # In Fintech, even in QA, we usually restrict DB connection to a specific user
    resources = ["arn:aws:rds-db:*:*:dbuser:*/${var.env_type}_user"]
  },
  {
    sid    = "FintechGuardrail"
    effect = "Deny"
    # Strict Deny: Networking is always off-limits for the App Team
    actions   = ["ec2:DeleteVpc", "ec2:DeleteSubnet", "ec2:DeleteTransitGateway", "ec2:TerminateInstances"]
    resources = ["*"]
  }
  ]

  trusted_role_arns = ["arn:aws:iam::${var.account_id}:root"]
}

# --- PERSONA 3: THE CI/CD PIPELINE (Automation Robot) ---
# Machine-to-machine access via OIDC to update ECR and EKS code.
module "cicd_pipeline_setup" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-assumable-role-with-oidc"
  version = "~> 5.0"

  create_role = var.enable_cicd_role
  
  # Dynamic naming helps distinguish which account this role belongs to
  role_name   = "Fintech-CI-CD-Deployer-${var.env_type}"

  provider_url = "token.actions.githubusercontent.com" # Example for GitHub Actions

  oidc_subjects_with_wildcards = [
    "repo:scmlearningcentre/capstone-II:*"
  ]

  inline_policy_statements = [
    {
      sid    = "ContainerRegistryPush"
      effect = "Allow"
      actions = [
        "ecr:GetAuthorizationToken",
        "ecr:BatchCheckLayerAvailability",
        "ecr:GetDownloadUrlForLayer",
        "ecr:BatchGetImage",
        "ecr:PutImage",
        "ecr:InitiateLayerUpload",
        "ecr:UploadPart",
        "ecr:CompleteLayerUpload"
      ]
      resources = ["*"]
    },
    {
      sid    = "UpdateRunningApplication"
      effect = "Allow"
      # In Prod/UAT, the pipeline only updates the image. 
      # In Dev/QA, we might let it modify cluster configs.
      actions = (var.env_type == "prod" || var.env_type == "uat") ? [
        "eks:DescribeCluster",
        "eks:UpdateClusterConfig"
      ] : [
        "eks:*" # Full EKS control for Dev/QA automation
      ]
      resources = ["*"]
    },
    {
      sid    = "SecretsAccess"
      effect = "Allow"
      # Pipeline needs to read secrets to inject into the app during deployment
      actions = [
        "secretsmanager:GetSecretValue",
        "kms:Decrypt"
      ]
      resources = ["*"]
    }
  ]
}
