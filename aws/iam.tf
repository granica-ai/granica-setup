resource "random_id" "random_suffix" {
  byte_length = 4
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

resource "aws_iam_policy" "emr" {
  count = var.deploy_emr ? 1 : 0

  name   = "project-n-admin-emr-permissions-${random_id.random_suffix.hex}"
  policy = data.aws_iam_policy_document.emr.json
}

resource "aws_iam_role_policy_attachment" "admin-deploy" {
  policy_arn = aws_iam_policy.deploy.arn
  role       = aws_iam_role.admin.id
}

resource "aws_iam_role_policy_attachment" "admin-emr" {
  count = var.deploy_emr ? 1 : 0

  policy_arn = aws_iam_policy.emr[0].arn
  role       = aws_iam_role.admin.name
}

resource "aws_iam_role_policy_attachment" "admin-ssm" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
  role       = aws_iam_role.admin.name
}

# EC2 admin server is used for EMR, S3, and infra only (no EKS). No KMS/ACM. Scoping via managed-by tags where possible.
data "aws_iam_policy_document" "deploy" {
  # EC2 describe/read only; scoped to one region (list/describe do not support resource tags).
  statement {
    sid    = "EC2DescribeRead"
    effect = "Allow"
    actions = [
      "autoscaling:Describe*",
      "ec2:Describe*",
      "ec2:GetLaunchTemplateData"
    ]
    resources = ["*"]
    condition {
      test     = "StringEquals"
      variable = "aws:RequestedRegion"
      values   = [var.aws_region]
    }
  }

  # EC2 create/mutate: only when the request includes the managed-resource tag (RunInstances, CreateSecurityGroup, etc. support request tags).
  statement {
    sid    = "EC2CreateMutateScopedByTag"
    effect = "Allow"
    actions = [
      "ec2:AssociateIamInstanceProfile",
      "ec2:CreateLaunchTemplate",
      "ec2:CreateLaunchTemplateVersion",
      "ec2:CreateSecurityGroup",
      "ec2:RevokeSecurityGroupIngress",
      "ec2:RevokeSecurityGroupEgress",
      "ec2:RunInstances"
    ]
    resources = ["*"]
    condition {
      test     = "StringEquals"
      variable = "aws:RequestTag/${var.ec2_resource_tag_key}"
      values   = [var.ec2_resource_tag_value]
    }
  }

  # EC2 CreateTags: only when the request includes the managed-resource tag.
  statement {
    sid    = "EC2CreateTagsScoped"
    effect = "Allow"
    actions = [
      "ec2:CreateTags"
    ]
    resources = ["*"]
    condition {
      test     = "StringEquals"
      variable = "aws:RequestTag/${var.ec2_resource_tag_key}"
      values   = [var.ec2_resource_tag_value]
    }
  }

  # EC2 DeleteTags: only on resources that already have the managed-resource tag.
  statement {
    sid    = "EC2DeleteTagsScoped"
    effect = "Allow"
    actions = [
      "ec2:DeleteTags"
    ]
    resources = ["*"]
    condition {
      test     = "StringEquals"
      variable = "ec2:ResourceTag/${var.ec2_resource_tag_key}"
      values   = [var.ec2_resource_tag_value]
    }
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
    resources = [
      "arn:aws:iam::*:instance-profile/project-n-*",
      "arn:aws:iam::*:instance-profile/granica-*",
      "arn:aws:iam::*:policy/project-n-*",
      "arn:aws:iam::*:policy/granica-*",
      "arn:aws:iam::*:role/project-n-*",
      "arn:aws:iam::*:role/granica-*",
      "arn:aws:iam::*:role/aws-service-role/autoscaling.amazonaws.com/AWSServiceRoleForAutoScaling"
    ]
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

  # s3:ListAllMyBuckets does not support resource-level permissions; must use "*" per AWS.
  statement {
    sid       = "ListAllBuckets"
    effect    = "Allow"
    actions   = ["s3:ListAllMyBuckets"]
    resources = ["*"]
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
      "arn:aws:logs:*:*:log-group:/aws/emr/*",
      "arn:aws:logs:*:*:log-group:/aws/granica-*",
      "arn:aws:logs:*:*:log-group:/aws/project-n*"
    ]
  }
}

# EMR permissions for EC2 admin (launch/manage EMR from admin server). Scoped to account and cluster name pattern.
data "aws_iam_policy_document" "emr" {
  statement {
    sid    = "EMRClusters"
    effect = "Allow"
    actions = [
      "elasticmapreduce:*"
    ]
    resources = [
      "arn:aws:elasticmapreduce:${var.aws_region}:${data.aws_caller_identity.current.account_id}:cluster/granica-*",
      "arn:aws:elasticmapreduce:${var.aws_region}:${data.aws_caller_identity.current.account_id}:cluster/project-n-*",
      "arn:aws:elasticmapreduce:${var.aws_region}:${data.aws_caller_identity.current.account_id}:cluster/j-*"
    ]
  }
  # ListClusters, ListReleaseLabels, etc. are account/region-level; scope to one region (no resource ARN for list APIs).
  statement {
    sid    = "EMRListAndAccount"
    effect = "Allow"
    actions = [
      "elasticmapreduce:ListClusters",
      "elasticmapreduce:ListReleaseLabels",
      "elasticmapreduce:GetBlockPublicAccessConfiguration",
      "elasticmapreduce:DescribeReleaseLabel"
    ]
    resources = ["*"]
    condition {
      test     = "StringEquals"
      variable = "aws:RequestedRegion"
      values   = [var.aws_region]
    }
  }
}

# VPC create/mutate is not granted to the admin server: VPC is created by AccountAdmin (e.g. CloudShell) or by Terraform apply (runner's credentials), not from the EC2 instance.

# EFS policy removed: EMR does not use EFS. EFS was only used for Airflow (airflow_enabled); for EMR-only deployments it is not needed.
