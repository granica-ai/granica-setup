resource "random_id" "random_suffix" {
  byte_length = 4
}

locals {
  # The admin (deployer) role runs deployments and must create IAM roles/policies.
  # Most boundaries (e.g. ones excluding iam:* from their broad allow) would block
  # those create actions, so the boundary is applied to it only when explicitly
  # opted in via permission_boundary_on_admin_role.
  admin_permissions_boundary = var.permission_boundary_on_admin_role && var.permission_boundary_arn != "" ? var.permission_boundary_arn : null

  # BYO: when a custom admin role ARN is supplied, the admin (deployer) role and
  # everything that defines it — instance profile, policies, attachments — are not
  # created. The customer-supplied role is expected to already carry equivalent
  # permissions, and the admin server EC2 instance uses custom_admin_instance_profile_name.
  byo_admin_role = var.custom_admin_role_arn != ""

  # When this deployment uses a custom IAM role/policy prefix or path (matching
  # krypton's role_name_prefix / role_path / policy_name_prefix / policy_path), the
  # deployer must also be allowed to manage IAM resources in that namespace. Derived
  # from the same vars so the scope stays in sync with how krypton names things,
  # instead of a hand-maintained ARN list. Empty when prefix/path are at their
  # defaults (the project-n-*/granica-* patterns already cover those).
  custom_role_namespace   = var.role_path != "/" || var.role_name_prefix != ""
  custom_policy_namespace = var.policy_path != "/" || var.policy_name_prefix != ""
  derived_iam_resource_arns = concat(
    local.custom_role_namespace ? [
      "arn:aws:iam::*:role${var.role_path}${var.role_name_prefix}*",
      "arn:aws:iam::*:instance-profile${var.role_path}${var.role_name_prefix}*",
    ] : [],
    local.custom_policy_namespace ? [
      "arn:aws:iam::*:policy${var.policy_path}${var.policy_name_prefix}*",
    ] : [],
  )
}

resource "aws_iam_role" "admin" {
  count                = local.byo_admin_role ? 0 : 1
  name                 = substr("${var.role_name_prefix}project-n-admin-${random_id.random_suffix.hex}", 0, 64)
  path                 = var.role_path
  permissions_boundary = local.admin_permissions_boundary
  assume_role_policy   = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "ec2.amazonaws.com"
      },
    "Action": "sts:AssumeRole"
    }
  ]
}
EOF
}

resource "aws_iam_instance_profile" "admin" {
  count = local.byo_admin_role ? 0 : 1
  name  = aws_iam_role.admin[0].name
  path  = var.role_path
  role  = aws_iam_role.admin[0].name
}

resource "aws_iam_policy" "deploy" {
  count = local.byo_admin_role ? 0 : 1

  name   = "${var.policy_name_prefix}project-n-admin-deploy-${random_id.random_suffix.hex}"
  path   = var.policy_path
  policy = data.aws_iam_policy_document.deploy.json
}

resource "aws_iam_policy" "vpc" {
  count = !local.byo_admin_role && var.manage_vpc && length(var.existing_vpc_id) == 0 ? 1 : 0

  name   = "${var.policy_name_prefix}project-n-admin-vpc-permissions-${random_id.random_suffix.hex}"
  path   = var.policy_path
  policy = data.aws_iam_policy_document.vpc.json
}

resource "aws_iam_policy" "emr" {
  count = !local.byo_admin_role && var.deploy_emr ? 1 : 0

  name   = "${var.policy_name_prefix}project-n-admin-emr-permissions-${random_id.random_suffix.hex}"
  path   = var.policy_path
  policy = data.aws_iam_policy_document.emr.json
}

resource "aws_iam_policy" "efs" {
  count = !local.byo_admin_role && var.airflow_enabled ? 1 : 0

  name   = "${var.policy_name_prefix}project-n-admin-efs-permissions-${random_id.random_suffix.hex}"
  path   = var.policy_path
  policy = data.aws_iam_policy_document.efs.json
}

resource "aws_iam_role_policy_attachment" "admin-deploy" {
  count = local.byo_admin_role ? 0 : 1

  policy_arn = aws_iam_policy.deploy[0].arn
  role       = aws_iam_role.admin[0].id
}

resource "aws_iam_role_policy_attachment" "admin-vpc" {
  count = !local.byo_admin_role && var.manage_vpc && length(var.existing_vpc_id) == 0 ? 1 : 0

  policy_arn = aws_iam_policy.vpc[0].arn
  role       = aws_iam_role.admin[0].name
}

resource "aws_iam_role_policy_attachment" "admin-emr" {
  count = !local.byo_admin_role && var.deploy_emr ? 1 : 0

  policy_arn = aws_iam_policy.emr[0].arn
  role       = aws_iam_role.admin[0].name
}

resource "aws_iam_role_policy_attachment" "admin-efs" {
  count = !local.byo_admin_role && var.airflow_enabled ? 1 : 0

  policy_arn = aws_iam_policy.efs[0].arn
  role       = aws_iam_role.admin[0].name
}

resource "aws_iam_role_policy_attachment" "admin-ssm" {
  count = local.byo_admin_role ? 0 : 1

  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
  role       = aws_iam_role.admin[0].name
}

data "aws_iam_policy_document" "deploy" {
  statement {
    sid    = "UnrestrictedResourcePermissions"
    effect = "Allow"
    actions = [
      "acm:DescribeCertificate",
      "acm:ListTagsForCertificate",
      "acm:RequestCertificate",
      "acm:ImportCertificate",
      "acm:AddTagsToCertificate",
      "autoscaling:Describe*",
      "ec2:AssociateIamInstanceProfile",
      "ec2:CreateLaunchTemplate",
      "ec2:CreateLaunchTemplateVersion",
      "ec2:DeleteLaunchTemplate",
      "ec2:CreateSecurityGroup",
      "ec2:AuthorizeSecurityGroupEgress",
      "ec2:RevokeSecurityGroupEgress",
      "ec2:AuthorizeSecurityGroupIngress",
      "ec2:RevokeSecurityGroupIngress",
      "ec2:CreateTags",
      "ec2:DeleteTags",
      "ec2:Describe*",
      "ec2:GetLaunchTemplateData",
      "ec2:RunInstances",
      "ec2:TerminateInstances",
      "eks:CreateCluster",
      "eks:DeleteCluster",
      "eks:ListClusters",
      "kms:CreateKey",
      "kms:EnableKeyRotation",
      "kms:DescribeKey",
      "kms:GetKeyPolicy",
      "kms:GetKeyRotationStatus",
      "kms:ListResourceTags",
      "kms:CreateGrant",
      "kms:TagResource",
      "kms:UntagResource",
      "kms:ScheduleKeyDeletion"
    ]
    resources = ["*"]
  }

  statement {
    sid    = "IAM"
    effect = "Allow"
    actions = [
      "iam:DeleteRolePolicy",
      "iam:AddClientIDToOpenIDConnectProvider",
      "iam:AddRoleToInstanceProfile",
      "iam:AttachRolePolicy",
      "iam:CreateInstanceProfile",
      "iam:CreateOpenIDConnectProvider",
      "iam:CreatePolicy",
      "iam:CreatePolicyVersion",
      "iam:CreateRole",
      "iam:CreateServiceLinkedRole",
      "iam:DeleteInstanceProfile",
      "iam:DeletePolicy",
      "iam:DeletePolicyVersion",
      "iam:DeleteRole",
      "iam:DetachRolePolicy",
      "iam:DeleteOpenIDConnectProvider",
      "iam:GetInstanceProfile",
      "iam:GetOpenIDConnectProvider",
      "iam:GetPolicy",
      "iam:GetPolicyVersion",
      "iam:GetRole",
      "iam:GetRolePolicy",
      "iam:ListAttachedRolePolicies",
      "iam:ListEntitiesForPolicy",
      "iam:ListInstanceProfiles",
      "iam:ListInstanceProfilesForRole",
      "iam:ListPolicyVersions",
      "iam:ListRolePolicies",
      "iam:ListRoleTags",
      "iam:PassRole",
      "iam:PutRolePermissionsBoundary",
      "iam:PutRolePolicy",
      "iam:RemoveRoleFromInstanceProfile",
      "iam:SimulatePrincipalPolicy",
      "iam:TagRole",
      "iam:UntagRole",
      "iam:TagPolicy",
      "iam:UntagPolicy",
      "iam:TagInstanceProfile",
      "iam:UntagInstanceProfile",
      "iam:TagOpenIDConnectProvider",
      "iam:UntagOpenIDConnectProvider",
      "iam:UpdateAssumeRolePolicy",
      "iam:UpdateOpenIDConnectProviderThumbprint"
    ]
    # Extra ARNs cover IAM resources placed outside the default project-n-*/granica-*
    # namespaces when this deployment sets role_path / role_name_prefix /
    # policy_path / policy_name_prefix (e.g. role/OneCloud/CustomerManaged-*,
    # policy/CustomerManaged_*). Derived in locals; empty when those are at defaults.
    resources = concat([
      "arn:aws:iam::*:instance-profile/project-n-*",
      "arn:aws:iam::*:instance-profile/granica-*",
      "arn:aws:iam::*:policy/project-n-*",
      "arn:aws:iam::*:policy/granica-*",
      "arn:aws:iam::*:role/project-n-*",
      "arn:aws:iam::*:role/granica-*",
      "arn:aws:iam::*:oidc-provider/oidc.eks.*.amazonaws.com",
      "arn:aws:iam::*:oidc-provider/oidc.eks.*.amazonaws.com/id/*",
      "arn:aws:iam::*:role/aws-service-role/eks.amazonaws.com/AWSServiceRoleForAmazonEKS",
      "arn:aws:iam::*:role/aws-service-role/autoscaling.amazonaws.com/AWSServiceRoleForAutoScaling",
      "arn:aws:iam::*:role/aws-service-role/elasticloadbalancing.amazonaws.com/AWSServiceRoleForElasticLoadBalancing"
    ], local.derived_iam_resource_arns)
  }

  statement {
    sid    = "Autoscaling"
    effect = "Allow"
    actions = [
      "autoscaling:AttachInstances",
      "autoscaling:CreateOrUpdateTags",
      "autoscaling:CreateAutoScalingGroup",
      "autoscaling:DeleteAutoScalingGroup",
      "autoscaling:SetDesiredCapacity",
      "autoscaling:SuspendProcesses",
      "autoscaling:UpdateAutoScalingGroup"
    ]
    resources = [
      "arn:aws:autoscaling:*:*:autoScalingGroup:*:autoScalingGroupName/project-n-*"
    ]
  }

  statement {
    sid    = "S3"
    effect = "Allow"
    actions = [
      "s3:*"
    ]
    resources = [
      "arn:aws:s3:::n-*",
      "arn:aws:s3:::project-n-*",
      "arn:aws:s3:::granica-*"
    ]
  }

  statement {
    sid       = "ListAllBuckets"
    effect    = "Allow"
    actions   = ["s3:ListAllMyBuckets"]
    resources = ["*"]
  }

  statement {
    sid    = "EKS"
    effect = "Allow"
    actions = [
      "eks:DescribeUpdate",
      "eks:DescribeCluster",
      "eks:UpdateClusterConfig",
      "eks:UpdateClusterVersion",
      "eks:AssociateEncryptionConfig",
      "eks:TagResource",
      "eks:UntagResource"
    ]
    resources = [
      "arn:aws:eks:*:*:cluster/project-n-*"
    ]
  }

  statement {
    sid    = "EKSAddons"
    effect = "Allow"
    actions = [
      "eks:CreateAddon",
      "eks:DeleteAddon",
      "eks:ListAddons",
      "eks:ListTagsForResource",
      "eks:ListUpdates",
      "eks:UpdateAddon",
      "eks:TagResource",
      "eks:UntagResource"
    ]
    resources = [
      "arn:aws:eks:*:*:addon/project-n-*/*/*",
      "arn:aws:eks:*:*:cluster/project-n-*"
    ]
  }

  statement {
    sid       = "EKSDescribe"
    effect    = "Allow"
    actions   = ["eks:Describe*"]
    resources = ["*"]
  }

  statement {
    sid    = "SQS"
    effect = "Allow"
    actions = [
      "sqs:AddPermission",
      "sqs:CreateQueue",
      "sqs:DeleteQueue",
      "sqs:GetQueueAttributes",
      "sqs:GetQueueUrl",
      "sqs:ListQueues",
      "sqs:ListQueueTags",
      "sqs:SetQueueAttributes",
      "sqs:TagQueue",
      "sqs:UntagQueue"
    ]
    resources = [
      "arn:aws:sqs:*:*:project-n-*"
    ]
  }

  # Required by Karpenter: manages EventBridge rules for spot interruption and
  # EC2 rebalance notifications routed to the Karpenter SQS interruption queue.
  statement {
    sid    = "EventBridge"
    effect = "Allow"
    actions = [
      "events:DeleteRule",
      "events:DescribeRule",
      "events:ListTagsForResource",
      "events:ListTargetsByRule",
      "events:PutRule",
      "events:PutTargets",
      "events:RemoveTargets",
      "events:TagResource",
      "events:UntagResource",
    ]
    resources = [
      "arn:aws:events:*:*:rule/project-n-*"
    ]
  }

  statement {
    sid    = "logs"
    effect = "Allow"
    actions = [
      "logs:CreateLogGroup",
      "logs:DescribeLogGroups",
      "logs:ListTagsLogGroup",
      "logs:PutRetentionPolicy",
      "logs:TagLogGroup",
      "logs:UntagLogGroup",
      "logs:DeleteLogGroup"
    ]
    resources = [
      "arn:aws:logs:*:*:log-group:/aws/eks/project-n*",
      "arn:aws:logs:*:*:log-group::log-stream*"
    ]
  }
}

data "aws_iam_policy_document" "emr" {
  statement {
    sid    = "EMR"
    effect = "Allow"
    actions = [
      "elasticmapreduce:*"
    ]
    resources = ["*"]
  }
}

data "aws_iam_policy_document" "vpc" {
  statement {
    sid    = "VPC"
    effect = "Allow"
    actions = [
      // Nat Gateways
      "ec2:CreateNatGateway",
      "ec2:DeleteNatGateway",
      // Internet Gateways
      "ec2:CreateInternetGateway",
      "ec2:AttachInternetGateway",
      "ec2:DetachInternetGateway",
      "ec2:DeleteInternetGateway",
      // Network Interfaces
      "ec2:CreateNetworkInterface",
      "ec2:AttachNetworkInterface",
      "ec2:DetachNetworkInterface",
      "ec2:DeleteNetworkInterface",
      // Addresses
      "ec2:AllocateAddress",
      "ec2:AssociateAddress",
      "ec2:DisassociateAddress",
      "ec2:ReleaseAddress",
      // Routes/Route Tables
      "ec2:CreateRoute",
      "ec2:DeleteRoute",
      "ec2:CreateRouteTable",
      "ec2:DeleteRouteTable",
      "ec2:AssociateRouteTable",
      "ec2:DisassociateRouteTable",
      // VPC
      "ec2:CreateVpc",
      "ec2:AssociateVpcCidrBlock",
      "ec2:DisassociateVpcCidrBlock",
      "ec2:ModifyVpcAttribute",
      "ec2:DeleteVpc",
      // Subnets
      "ec2:CreateSubnet",
      "ec2:AssociateSubnetCidrBlock",
      "ec2:DisassociateSubnetCidrBlock",
      "ec2:ModifySubnetAttribute",
      "ec2:DeleteSubnet",
      "ec2:DescribeSubnets",
      // VPC Endpoints
      "ec2:CreateVpcEndpoint",
      "ec2:ModifyVpcEndpoint",
      "ec2:DeleteVpcEndpoints",
      // Security Groups
      "ec2:CreateSecurityGroup",
      "ec2:AuthorizeSecurityGroupIngress",
      "ec2:AuthorizeSecurityGroupEgress",
      "ec2:RevokeSecurityGroupIngress",
      "ec2:RevokeSecurityGroupEgress",
      "ec2:DeleteSecurityGroup",
      "ec2:CreateTags",
      "ec2:DeleteTags",
      // VPC Peering
      "ec2:CreateVpcPeeringConnection",
      "ec2:DeleteVpcPeeringConnection",
      "ec2:AcceptVpcPeeringConnection",
    ]
    resources = ["*"]
  }
}

data "aws_iam_policy_document" "efs" {
  statement {
    sid    = "EFS"
    effect = "Allow"
    actions = [
      "elasticfilesystem:CreateFileSystem",
      "elasticfilesystem:CreateMountTarget",
      "elasticfilesystem:CreateTags",
      "elasticfilesystem:DeleteFileSystem",
      "elasticfilesystem:DeleteMountTarget",
      "elasticfilesystem:DeleteTags",
      "elasticfilesystem:DescribeFileSystems",
      "elasticfilesystem:DescribeLifecycleConfiguration",
      "elasticfilesystem:DescribeMountTargets",
      "elasticfilesystem:DescribeMountTargetSecurityGroups",
      "elasticfilesystem:ModifyMountTargetSecurityGroups",
      "elasticfilesystem:PutLifecycleConfiguration",
      "elasticfilesystem:TagResource",
      "elasticfilesystem:UntagResource",
      "elasticfilesystem:UpdateFileSystem"
    ]
    resources = [
      "arn:aws:elasticfilesystem:*:*:file-system/*"
    ]
  }
}
