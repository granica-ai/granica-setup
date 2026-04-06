resource "random_id" "random_suffix" {
  byte_length = 4
}

################################################################################
# Permission Boundary — caps what any role created by the admin EC2 can do.
# Blocks IAM/STS escalation so a compromised EC2 cannot create or modify roles
# to gain broader access in the customer account.
################################################################################

resource "aws_iam_policy" "permission_boundary" {
  count = var.enable_permission_boundary ? 1 : 0

  name   = "granica-role-boundary-${random_id.random_suffix.hex}"
  policy = data.aws_iam_policy_document.permission_boundary.json
}

data "aws_iam_policy_document" "permission_boundary" {
  # Allow all non-escalation actions — workload roles need S3, EC2, EKS, ELB,
  # ECR, SQS, SSM, RDS, EFS, CloudWatch, Autoscaling, Pricing, etc.
  statement {
    sid       = "AllowWorkloadActions"
    effect    = "Allow"
    actions   = ["*"]
    resources = ["*"]
  }

  # Deny IAM write actions that enable privilege escalation.
  # A role bounded by this policy cannot create/modify/delete other roles or
  # policies, even if AdministratorAccess is attached to it.
  statement {
    sid    = "DenyIAMEscalation"
    effect = "Deny"
    actions = [
      "iam:CreateRole",
      "iam:DeleteRole",
      "iam:AttachRolePolicy",
      "iam:DetachRolePolicy",
      "iam:PutRolePolicy",
      "iam:DeleteRolePolicy",
      "iam:PutRolePermissionsBoundary",
      "iam:DeleteRolePermissionsBoundary",
      "iam:UpdateAssumeRolePolicy",
      "iam:CreatePolicy",
      "iam:CreatePolicyVersion",
      "iam:DeletePolicy",
      "iam:DeletePolicyVersion",
      "iam:CreateUser",
      "iam:DeleteUser",
      "iam:AttachUserPolicy",
      "iam:DetachUserPolicy",
      "iam:PutUserPolicy",
      "iam:DeleteUserPolicy",
      "iam:CreateAccessKey",
      "iam:CreateLoginProfile",
      "iam:UpdateLoginProfile",
      "iam:CreateOpenIDConnectProvider",
      "iam:DeleteOpenIDConnectProvider",
    ]
    resources = ["*"]
  }
}

locals {
  permission_boundary_arn = var.enable_permission_boundary ? aws_iam_policy.permission_boundary[0].arn : ""
}

resource "aws_iam_role" "admin" {
  name               = "project-n-admin-${random_id.random_suffix.hex}"
  assume_role_policy = <<EOF
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
  name = aws_iam_role.admin.name
  role = aws_iam_role.admin.name
}

resource "aws_iam_policy" "deploy" {
  name   = "project-n-admin-deploy-${random_id.random_suffix.hex}"
  policy = data.aws_iam_policy_document.deploy.json
}

resource "aws_iam_policy" "vpc" {
  count = var.manage_vpc && length(var.existing_vpc_id) == 0 ? 1 : 0

  name   = "project-n-admin-vpc-permissions-${random_id.random_suffix.hex}"
  policy = data.aws_iam_policy_document.vpc.json
}

resource "aws_iam_policy" "emr" {
  count = var.deploy_emr ? 1 : 0

  name   = "project-n-admin-emr-permissions-${random_id.random_suffix.hex}"
  policy = data.aws_iam_policy_document.emr.json
}

resource "aws_iam_policy" "efs" {
  count = var.airflow_enabled ? 1 : 0

  name   = "project-n-admin-efs-permissions-${random_id.random_suffix.hex}"
  policy = data.aws_iam_policy_document.efs.json
}

resource "aws_iam_role_policy_attachment" "admin-deploy" {
  policy_arn = aws_iam_policy.deploy.arn
  role       = aws_iam_role.admin.id
}

resource "aws_iam_role_policy_attachment" "admin-vpc" {
  count = var.manage_vpc && length(var.existing_vpc_id) == 0 ? 1 : 0

  policy_arn = aws_iam_policy.vpc[0].arn
  role       = aws_iam_role.admin.name
}

resource "aws_iam_role_policy_attachment" "admin-emr" {
  count = var.deploy_emr ? 1 : 0

  policy_arn = aws_iam_policy.emr[0].arn
  role       = aws_iam_role.admin.name
}

resource "aws_iam_role_policy_attachment" "admin-efs" {
  count = var.airflow_enabled ? 1 : 0

  policy_arn = aws_iam_policy.efs[0].arn
  role       = aws_iam_role.admin.name
}

resource "aws_iam_role_policy_attachment" "admin-ssm" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
  role       = aws_iam_role.admin.name
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

  # IAM read-only and tagging actions on Granica-namespaced resources.
  # Write actions (CreateRole, AttachRolePolicy, etc.) are in separate
  # statements below with tighter conditions.
  statement {
    sid    = "IAMReadAndTag"
    effect = "Allow"
    actions = [
      "iam:AddClientIDToOpenIDConnectProvider",
      "iam:AddRoleToInstanceProfile",
      "iam:CreateInstanceProfile",
      "iam:CreateOpenIDConnectProvider",
      "iam:CreateServiceLinkedRole",
      "iam:DeleteInstanceProfile",
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
      "iam:UpdateOpenIDConnectProviderThumbprint",
    ]
    resources = [
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
      "arn:aws:iam::*:role/aws-service-role/elasticloadbalancing.amazonaws.com/AWSServiceRoleForElasticLoadBalancing",
    ]
  }

  # CreateRole — only allowed when the permission boundary is attached.
  # This prevents the EC2 from creating roles that exceed the boundary ceiling.
  statement {
    sid    = "IAMCreateRoleWithBoundary"
    effect = "Allow"
    actions = [
      "iam:CreateRole",
    ]
    resources = [
      "arn:aws:iam::*:role/project-n-*",
      "arn:aws:iam::*:role/granica-*",
    ]
    dynamic "condition" {
      for_each = var.enable_permission_boundary ? [1] : []
      content {
        test     = "StringEquals"
        variable = "iam:PermissionsBoundary"
        values   = [aws_iam_policy.permission_boundary[0].arn]
      }
    }
  }

  # Role policy management — scoped to Granica-namespaced roles/policies only.
  statement {
    sid    = "IAMRolePolicyManagement"
    effect = "Allow"
    actions = [
      "iam:AttachRolePolicy",
      "iam:DetachRolePolicy",
      "iam:PutRolePolicy",
      "iam:DeleteRolePolicy",
      "iam:DeleteRole",
      "iam:UpdateAssumeRolePolicy",
      "iam:CreatePolicy",
      "iam:CreatePolicyVersion",
      "iam:DeletePolicy",
      "iam:DeletePolicyVersion",
    ]
    resources = [
      "arn:aws:iam::*:policy/project-n-*",
      "arn:aws:iam::*:policy/granica-*",
      "arn:aws:iam::*:role/project-n-*",
      "arn:aws:iam::*:role/granica-*",
    ]
  }

  # AttachRolePolicy — restrict which managed policies can be attached.
  # Only Granica-namespaced policies and specific AWS managed policies are allowed.
  statement {
    sid    = "IAMAttachRolePolicyRestricted"
    effect = "Allow"
    actions = [
      "iam:AttachRolePolicy",
    ]
    resources = [
      "arn:aws:iam::*:role/project-n-*",
      "arn:aws:iam::*:role/granica-*",
    ]
    condition {
      test     = "ArnLike"
      variable = "iam:PolicyARN"
      values = [
        "arn:aws:iam::*:policy/project-n-*",
        "arn:aws:iam::*:policy/granica-*",
        "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy",
        "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy",
        "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore",
        "arn:aws:iam::aws:policy/service-role/AmazonEBSCSIDriverPolicy",
        "arn:aws:iam::aws:policy/service-role/AmazonEFSCSIDriverPolicy",
      ]
    }
  }

  # PassRole — only for cluster and worker roles, only to EKS and EC2 services.
  # IRSA roles use OIDC trust and do NOT require PassRole.
  statement {
    sid     = "IAMPassRoleRestricted"
    effect  = "Allow"
    actions = ["iam:PassRole"]
    resources = [
      "arn:aws:iam::*:role/project-n-*-cluster",
      "arn:aws:iam::*:role/project-n-*-workers",
    ]
    condition {
      test     = "StringEquals"
      variable = "iam:PassedToService"
      values   = ["eks.amazonaws.com", "ec2.amazonaws.com"]
    }
  }

  # PutRolePermissionsBoundary — only allow setting the Granica boundary.
  # This lets Terraform manage boundaries on roles it creates, but prevents
  # the EC2 from attaching a more permissive boundary or removing one.
  dynamic "statement" {
    for_each = var.enable_permission_boundary ? [1] : []
    content {
      sid     = "IAMBoundaryManagement"
      effect  = "Allow"
      actions = ["iam:PutRolePermissionsBoundary"]
      resources = [
        "arn:aws:iam::*:role/project-n-*",
        "arn:aws:iam::*:role/granica-*",
      ]
      condition {
        test     = "StringEquals"
        variable = "iam:PermissionsBoundary"
        values   = [aws_iam_policy.permission_boundary[0].arn]
      }
    }
  }

  # Deny removing permission boundaries — prevents escape from the ceiling.
  dynamic "statement" {
    for_each = var.enable_permission_boundary ? [1] : []
    content {
      sid    = "DenyBoundaryRemoval"
      effect = "Deny"
      actions = [
        "iam:DeleteRolePermissionsBoundary",
      ]
      resources = [
        "arn:aws:iam::*:role/project-n-*",
        "arn:aws:iam::*:role/granica-*",
      ]
    }
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
