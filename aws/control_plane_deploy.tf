# The admin server historically deployed only DP. A Kandor single-cluster
# workload also creates the CP-owned cluster and its RDS/EFS/SSM resources.
# Keep these additional deploy permissions opt-in for existing admin servers.
locals {
  cp_deploy_enabled = !local.byo_admin_role && var.control_plane_deployment_id != ""
  cp_deploy_name    = var.control_plane_deployment_id
  cp_deploy_account = data.aws_caller_identity.current.account_id
}

resource "aws_iam_policy" "cp_deploy" {
  count  = local.cp_deploy_enabled ? 1 : 0
  name   = "${var.policy_name_prefix}project-n-admin-cp-${random_id.random_suffix.hex}"
  path   = var.policy_path
  policy = data.aws_iam_policy_document.cp_deploy[0].json
}

resource "aws_iam_role_policy_attachment" "admin_cp_deploy" {
  count      = local.cp_deploy_enabled ? 1 : 0
  role       = aws_iam_role.admin[0].name
  policy_arn = aws_iam_policy.cp_deploy[0].arn
}

data "aws_iam_policy_document" "cp_deploy" {
  count = local.cp_deploy_enabled ? 1 : 0

  statement {
    sid       = "ReadDeploymentResources"
    actions   = ["iam:ListRoles", "rds:Describe*", "rds:ListTagsForResource"]
    resources = ["*"]
  }

  statement {
    sid     = "ControlPlaneCluster"
    actions = ["eks:*", "logs:CreateLogGroup", "logs:DeleteLogGroup", "logs:ListTagsForResource", "logs:ListTagsLogGroup", "logs:TagResource", "logs:UntagResource", "logs:TagLogGroup", "logs:UntagLogGroup", "logs:PutRetentionPolicy"]
    resources = [
      "arn:aws:eks:${var.aws_region}:${local.cp_deploy_account}:cluster/${local.cp_deploy_name}-eks",
      "arn:aws:eks:${var.aws_region}:${local.cp_deploy_account}:nodegroup/${local.cp_deploy_name}-eks/*/*",
      "arn:aws:eks:${var.aws_region}:${local.cp_deploy_account}:addon/${local.cp_deploy_name}-eks/*/*",
      "arn:aws:eks:${var.aws_region}:${local.cp_deploy_account}:access-entry/${local.cp_deploy_name}-eks/*/*/*/*",
      "arn:aws:logs:${var.aws_region}:${local.cp_deploy_account}:log-group:/aws/eks/${local.cp_deploy_name}-eks/*",
    ]
  }

  statement {
    sid     = "ControlPlaneDatabase"
    actions = ["rds:*"]
    resources = [
      "arn:aws:rds:${var.aws_region}:${local.cp_deploy_account}:db:${local.cp_deploy_name}-app",
      "arn:aws:rds:${var.aws_region}:${local.cp_deploy_account}:subgrp:${local.cp_deploy_name}-app-db",
      "arn:aws:rds:${var.aws_region}:${local.cp_deploy_account}:pg:${local.cp_deploy_name}-app-pg17",
    ]
  }

  statement {
    sid     = "ControlPlaneParameters"
    actions = ["ssm:PutParameter", "ssm:GetParameter", "ssm:DeleteParameter", "ssm:AddTagsToResource", "ssm:RemoveTagsFromResource", "ssm:ListTagsForResource"]
    resources = [
      "arn:aws:ssm:${var.aws_region}:${local.cp_deploy_account}:parameter/granica-control-plane/${local.cp_deploy_name}/*",
    ]
  }

  statement {
    sid     = "ControlPlaneEncryptionAlias"
    actions = ["kms:CreateAlias", "kms:DeleteAlias", "kms:UpdateAlias"]
    resources = [
      "arn:aws:kms:${var.aws_region}:${local.cp_deploy_account}:alias/${local.cp_deploy_name}-eks-secrets",
      "arn:aws:kms:${var.aws_region}:${local.cp_deploy_account}:key/*",
    ]
  }

  statement {
    sid     = "ControlPlaneImagePolicy"
    actions = ["iam:CreatePolicy", "iam:DeletePolicy", "iam:GetPolicy", "iam:GetPolicyVersion", "iam:CreatePolicyVersion", "iam:DeletePolicyVersion", "iam:ListPolicyVersions", "iam:TagPolicy", "iam:UntagPolicy"]
    resources = [
      "arn:aws:iam::${local.cp_deploy_account}:policy/${local.cp_deploy_name}-granica-ecr-pull",
    ]
  }
}
