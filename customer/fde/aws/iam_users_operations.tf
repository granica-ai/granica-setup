# Create IAM policies

resource "aws_iam_policy" "operation_granica_fde_access" {
  name        = "granica-operations-fde-access"
  description = "Granica Load Balancer policy"
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid      = "AllowDescribeELBs"
        Effect   = "Allow"
        Action   = "elasticloadbalancing:Describe*"
        Resource = "arn:aws:elasticloadbalancing:*:*:loadbalancer*"
      },
      {
        "Sid" : "AllowEC2InstanceConnectForAllInstances",
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
      }
    ]
  })
}

# Create remaining policies similarly
resource "aws_iam_policy" "operation_fde_read" {
  name        = "granica-operations-admin-read"
  description = "Project N Admin Deploy policy"
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
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
        "Resource" : "arn:aws:kms:*",
        "Sid" : "ReadKMSPermissions"
      },
      {
        "Action" : [
          "ec2:RunInstances",
          "ec2:GetLaunchTemplateData",
          "ec2:Describe*",
          "ec2:DeleteTags",
          "ec2:CreateTags",
          ],
        "Effect" : "Allow",
        "Resource" : "arn:aws:ec2:*",
        "Sid" : "ReadEC2Permissions"
      },
      {
        "Action" : [
          "autoscaling:Describe*",
          ],
        "Effect" : "Allow",
        "Resource" : "arn:aws:autoscaling:*",
        "Sid" : "ReadAutoScalingPermissions"
      },
      {
        "Action" : [
          "acm:ListTagsForCertificate",
          "acm:DescribeCertificate",
          "acm:AddTagsToCertificate"
        ],
        "Effect" : "Allow",
        "Resource" : "arn:aws:acm:*",
        "Sid" : "ReadACMPermissions"
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
        "Sid" : "IAM"
      },
      {
        "Action" : "s3:*",
        "Effect" : "Allow",
        "Resource" : [
          "arn:aws:s3:::project-n-*",
          "arn:aws:s3:::n-*",
          "arn:aws:s3:::granica-*"
        ],
        "Sid" : "S3"
      },
      {
        "Action" : "s3:ListAllMyBuckets",
        "Effect" : "Allow",
        "Resource" : "arn:aws:s3*",
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
        "Sid" : "EKS"
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
        "Sid" : "EKSAddons"
      },
      {
        "Action" : "eks:Describe*",
        "Effect" : "Allow",
        "Resource" : "arn:aws:eks:*",
        "Sid" : "EKSDescribe"
      },
      {
        "Action" : [
          "sqs:UntagQueue",
          "sqs:TagQueue",
          "sqs:ListQueues",
          "sqs:ListQueueTags",
          "sqs:GetQueueUrl",
          "sqs:GetQueueAttributes",
        ],
        "Effect" : "Allow",
        "Resource" : "arn:aws:sqs:*:*:project-n-*",
        "Sid" : "SQS"
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
        "Sid" : "logs"
      }
    ]
  })
}

resource "aws_iam_policy" "operation-admin-vpc-permissions" {
  name        = "granica-operations-vpc-read"
  description = "Project N Operations VPC Permissions"
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        "Action" : [
          "ec2:DescribeSubnets",
          "ec2:CreateTags",
        ],
        "Effect" : "Allow",
        "Resource" : "arn:aws:ec2:*",
        "Sid" : "VPC"
      }
    ]
  })
}

resource "aws_iam_policy" "operation-eks-addons-terraform" {
  name        = "granica-operations-eks-addons-terraform-read"
  description = "Project N EKS Addons Terraform"
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
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
        "Sid" : "EKSAddons"
      },
      {
        "Action" : "eks:Describe*",
        "Effect" : "Allow",
        "Resource" : "arn:aws:eks:*",
        "Sid" : "EKSDescribe"
      }
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
  policy_arn = aws_iam_policy.cloudshell_access.arn
}

resource "aws_iam_user_policy_attachment" "operation_granica_fde_access" {
  count      = length(var.operations_user_names)
  user       = aws_iam_user.operations-users[count.index].name
  policy_arn = aws_iam_policy.operation_granica_fde_access.arn
}

resource "aws_iam_user_policy_attachment" "operation_fde_read" {
  count      = length(var.operations_user_names)
  user       = aws_iam_user.operations-users[count.index].name
  policy_arn = aws_iam_policy.operation_fde_read.arn
}

resource "aws_iam_user_policy_attachment" "operation-admin-vpc-permissions" {
  count      = length(var.operations_user_names)
  user       = aws_iam_user.operations-users[count.index].name
  policy_arn = aws_iam_policy.operation-admin-vpc-permissions.arn
}

resource "aws_iam_user_policy_attachment" "operation-eks-addons-terraform" {
  count      = length(var.operations_user_names)
  user       = aws_iam_user.operations-users[count.index].name
  policy_arn = aws_iam_policy.operation-eks-addons-terraform.arn
}
