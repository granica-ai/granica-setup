# Create IAM policies
resource "aws_iam_policy" "operation_fde_read" {
  name        = "granica-fde-operations"
  description = "Granica FDE operations"
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        "Sid" : "AllowEC2InstanceConnectEndpoint",
        "Effect" : "Allow",
        "Action" : "ec2-instance-connect:*",
        "Resource" : "arn:aws:ec2:*:*:instance-connect-endpoint*"
      },
      {
        "Sid" : "AllowDescribeAlarmsAllRegionsAllAccounts",
        "Effect" : "Allow",
        "Action" : "cloudwatch:DescribeAlarms",
        "Resource" : "arn:aws:cloudwatch:*:*:alarm:*"
      },
      {
        "Sid" : "AllowDescribeReport",
        "Effect" : "Allow",
        "Action" : "ce:DescribeReport",
        "Resource" : "*"
      },
      {
        "Sid" : "AllowViewBilling",
        "Effect" : "Allow",
        "Action" : "aws-portal:ViewBilling",
        "Resource" : "*"
      },
      {
        "Action" : [
          "kms:ListResourceTags",
          "kms:GetKeyRotationStatus",
          "kms:GetKeyPolicy",
          "kms:DescribeKey",
          "kms:CreateKey",
          "kms:CreateGrant",
        ],
        "Effect" : "Allow",
        "Resource" : "arn:aws:kms:*:*:*",
        "Sid" : "ReadKMSPermissions"
      },
      {
        "Action" : [
          "ec2:RunInstances",
          "ec2:GetLaunchTemplateData",
          "ec2:DeleteTags",
          "ec2:CreateTags",
        ],
        "Effect" : "Allow",
        "Resource" : "arn:aws:ec2:*:*:*",
        "Sid" : "ReadEC2Permissions"
      },
      {
        "Action" : [
          "iam:UntagRole",
          "iam:UntagPolicy",
          "iam:UntagOpenIDConnectProvider",
          "iam:UntagInstanceProfile",
          "iam:TagRole",
          "iam:TagPolicy",
          "iam:TagOpenIDConnectProvider",
          "iam:TagInstanceProfile",
          "iam:ListRoleTags",
          "iam:ListRolePolicies",
          "iam:ListPolicyVersions",
          "iam:ListInstanceProfilesForRole",
          "iam:ListInstanceProfiles",
          "iam:ListEntitiesForPolicy",
          "iam:ListAttachedRolePolicies",
          "iam:GetRolePolicy",
          "iam:GetRole",
          "iam:GetPolicyVersion",
          "iam:GetPolicy",
          "iam:GetOpenIDConnectProvider",
          "iam:GetInstanceProfile",
        ],
        "Effect" : "Allow",
        "Resource" : [
          "arn:aws:iam::*:role/project-n-*",
          "arn:aws:iam::*:role/granica-*",
          "arn:aws:iam::*:role/aws-service-role/elasticloadbalancing.amazonaws.com/AWSServiceRoleForElasticLoadBalancing",
          "arn:aws:iam::*:role/aws-service-role/eks.amazonaws.com/AWSServiceRoleForAmazonEKS",
          "arn:aws:iam::*:role/aws-service-role/autoscaling.amazonaws.com/AWSServiceRoleForAutoScaling",
          "arn:aws:iam::*:policy/project-n-*",
          "arn:aws:iam::*:oidc-provider/oidc.eks.*.amazonaws.com/id/*",
          "arn:aws:iam::*:oidc-provider/oidc.eks.*.amazonaws.com",
          "arn:aws:iam::*:instance-profile/project-n-*"
        ],
        "Sid" : "GranicaIAM"
      },
      {
        "Action" : "s3:*",
        "Effect" : "Allow",
        "Resource" : [
          "arn:aws:s3:::project-n-*",
          "arn:aws:s3:::n-*",
          "arn:aws:s3:::granica-*"
        ],
        "Sid" : "GranicaS3"
      },
      {
        "Action" : "s3:ListAllMyBuckets",
        "Effect" : "Allow",
        "Resource" : "arn:aws:s3::*:*",
        "Sid" : "ListAllBuckets"
      },
      {
        "Action" : [
          "eks:UntagResource",
          "eks:TagResource",
          "eks:DescribeUpdate",
          "eks:DescribeCluster",
          "eks:ListClusters",
        ],
        "Effect" : "Allow",
        "Resource" : "arn:aws:eks:*:*:cluster/project-n-*",
        "Sid" : "GranicaEKS"
      },
      {
        "Action" : [
          "eks:UntagResource",
          "eks:TagResource",
          "eks:ListUpdates",
          "eks:ListTagsForResource",
          "eks:ListAddons",
        ],
        "Effect" : "Allow",
        "Resource" : [
          "arn:aws:eks:*:*:cluster/project-n-*",
          "arn:aws:eks:*:*:addon/project-n-*/*/*"
        ],
        "Sid" : "GranicaEKSAddons"
      },
      {
        "Action" : "eks:Describe*",
        "Effect" : "Allow",
        "Resource" : "arn:aws:eks:*:*:*",
        "Sid" : "EKSDescribe"
      },
      {
        "Action" : [
          "logs:UntagLogGroup",
          "logs:TagLogGroup",
          "logs:ListTagsLogGroup",
          "logs:DescribeLogGroups",
        ],
        "Effect" : "Allow",
        "Resource" : [
          "arn:aws:logs:*:*:log-group::log-stream*",
          "arn:aws:logs:*:*:log-group:/aws/eks/project-n*"
        ],
        "Sid" : "GranicaLogs"
      },
    ]
  })
}

# Create users
resource "aws_iam_user" "operations-users" {
  count = length(var.operations_user_names)
  name  = var.operations_user_names[count.index]
}

# Attach policies to users
resource "aws_iam_user_policy_attachment" "operation_cloudshell" {
  count      = length(var.operations_user_names)
  user       = aws_iam_user.operations-users[count.index].name
  policy_arn = "arn:aws:iam::aws:policy/AWSCloudShellFullAccess"
}

resource "aws_iam_user_policy_attachment" "operation_fde_read" {
  count      = length(var.operations_user_names)
  user       = aws_iam_user.operations-users[count.index].name
  policy_arn = aws_iam_policy.operation_fde_read.arn
}

resource "aws_iam_user_policy_attachment" "operation-ec2-readonly" {
  count      = length(var.operations_user_names)
  user       = aws_iam_user.operations-users[count.index].name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ReadOnlyAccess"
}

resource "aws_iam_user_policy_attachment" "operation-ec2-instance-connect" {
  count      = length(var.operations_user_names)
  user       = aws_iam_user.operations-users[count.index].name
  policy_arn = "arn:aws:iam::aws:policy/EC2InstanceConnect"
}

resource "aws_iam_user_policy_attachment" "operation-autoscaling-readonly" {
  count      = length(var.operations_user_names)
  user       = aws_iam_user.operations-users[count.index].name
  policy_arn = "arn:aws:iam::aws:policy/AutoScalingReadOnlyAccess"
}

resource "aws_iam_user_policy_attachment" "operation-acm-readonly" {
  count      = length(var.operations_user_names)
  user       = aws_iam_user.operations-users[count.index].name
  policy_arn = "arn:aws:iam::aws:policy/AWSCertificateManagerReadOnly"
}

resource "aws_iam_user_policy_attachment" "operation-sqs-readonly" {
  count      = length(var.operations_user_names)
  user       = aws_iam_user.operations-users[count.index].name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSQSReadOnlyAccess"
}