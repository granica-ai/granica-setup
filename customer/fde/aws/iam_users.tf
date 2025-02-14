# Create IAM policies
resource "aws_iam_policy" "cloudshell_access" {
  name        = "AWSCloudShellFullAccess"
  description = "Allows full access to AWS CloudShell"
  policy      = jsonencode({
    Version = "2012-10-17"
    Statement = [
        {
            Action   = ["cloudshell:*"]
            Effect   = "Allow"
            Resource = "*"
        }
    ]
  })
}

resource "aws_iam_policy" "granica_lb" {
  name        = "granica-lb"
  description = "Granica Load Balancer policy"
  policy      = jsonencode({
    Version = "2012-10-17"
    Statement = [
        {
            Sid       = "VisualEditor0"
            Effect    = "Allow"
            Action    = "elasticloadbalancing:Describe*"
            Resource  = "*"
        },
        {
            "Sid": "AllowEC2InstanceConnectForAllInstances",
            "Effect": "Allow",
            "Action": "ec2-instance-connect:*",
            "Resource": "*"
        },
        {
            "Sid": "AllowDescribeAlarmsAllRegionsAllAccounts",
            "Effect": "Allow",
            "Action": "cloudwatch:DescribeAlarms",
            "Resource": "arn:aws:cloudwatch:*:*:alarm:*"
        },
        {
            "Sid": "deleteEc2entry",
            "Effect": "Allow",
            "Action": [
                "ec2:DeleteNetworkAclEntry",
                "ec2:CreateNetworkAclEntry"
            ],
            "Resource": "arn:aws:ec2:*:*:network-acl*"
        },
        {
            "Sid": "deleteLaunchTemplate",
            "Effect": "Allow",
            "Action": ["ec2:DeleteLaunchTemplate"],
            "Resource": "arn:aws:ec2:*:*:launch-template*"
        },
        {
            "Sid": "InstanceConnect",
            "Effect": "Allow",
            "Action": "ec2:CreateInstanceConnectEndpoint",
            "Resource": [
                "arn:aws:ec2:*:*:subnet*",
                "arn:aws:ec2:*:*:security-group*",
                "arn:aws:ec2:*:*:instance-connect-endpoint*"
            ]
        },
        {
            "Sid": "AllowDescribeReport",
            "Effect": "Allow",
            "Action": "ce:DescribeReport",
            "Resource": "*"
        },
        {
            "Sid": "AllowViewBilling",
            "Effect": "Allow",
            "Action": "aws-portal:ViewBilling",
            "Resource": "*"
        }
    ]
  })
}

# Create remaining policies similarly
resource "aws_iam_policy" "project_n_admin_deploy" {
  name        = "project-n-admin-deploy"
  description = "Project N Admin Deploy policy"
  policy      = jsonencode({
    Version = "2012-10-17"
    Statement = [
        {
            "Action": [
                "route53:*",
                "kms:UntagResource",
                "kms:TagResource",
                "kms:ScheduleKeyDeletion",
                "kms:ListResourceTags",
                "kms:GetKeyRotationStatus",
                "kms:GetKeyPolicy",
                "kms:EnableKeyRotation",
                "kms:DescribeKey",
                "kms:CreateKey",
                "kms:CreateGrant",
                "eks:ListClusters",
                "eks:DeleteCluster",
                "eks:CreateCluster",
                "ec2:RunInstances",
                "ec2:GetLaunchTemplateData",
                "ec2:Describe*",
                "ec2:DeleteTags",
                "ec2:CreateTags",
                "ec2:CreateSecurityGroup",
                "ec2:CreateLaunchTemplateVersion",
                "ec2:CreateLaunchTemplate",
                "ec2:AssociateIamInstanceProfile",
                "autoscaling:Describe*",
                "acm:RequestCertificate",
                "acm:ListTagsForCertificate",
                "acm:ImportCertificate",
                "acm:DescribeCertificate",
                "acm:AddTagsToCertificate"
            ],
            "Effect": "Allow",
            "Resource": "*",
            "Sid": "UnrestrictedResourcePermissions"
        },
        {
            "Sid": "ListInstanceProfilesGlobal",
            "Effect": "Allow",
            "Action": [
                "iam:ListInstanceProfilesForRole",
                "iam:ListInstanceProfiles"
            ],
            "Resource": "*"
        },
        {
            "Action": [
                "iam:UpdateOpenIDConnectProviderThumbprint",
                "iam:UpdateAssumeRolePolicy",
                "iam:UntagRole",
                "iam:UntagPolicy",
                "iam:UntagOpenIDConnectProvider",
                "iam:UntagInstanceProfile",
                "iam:TagRole",
                "iam:TagPolicy",
                "iam:TagOpenIDConnectProvider",
                "iam:TagInstanceProfile",
                "iam:RemoveRoleFromInstanceProfile",
                "iam:PutRolePolicy",
                "iam:PutRolePermissionsBoundary",
                "iam:PassRole",
                "iam:ListRoleTags",
                "iam:ListRolePolicies",
                "iam:ListPolicyVersions",
                "iam:ListEntitiesForPolicy",
                "iam:ListAttachedRolePolicies",
                "iam:GetRolePolicy",
                "iam:GetRole",
                "iam:GetPolicyVersion",
                "iam:GetPolicy",
                "iam:GetOpenIDConnectProvider",
                "iam:GetInstanceProfile",
                "iam:DetachRolePolicy",
                "iam:DeleteRole",
                "iam:DeletePolicy",
                "iam:DeleteOpenIDConnectProvider",
                "iam:DeleteInstanceProfile",
                "iam:CreateServiceLinkedRole",
                "iam:CreateRole",
                "iam:CreatePolicyVersion",
                "iam:CreatePolicy",
                "iam:CreateOpenIDConnectProvider",
                "iam:CreateInstanceProfile",
                "iam:AttachRolePolicy",
                "iam:AddRoleToInstanceProfile",
                "iam:AddClientIDToOpenIDConnectProvider"
            ],
            "Effect": "Allow",
            "Resource": [
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
            "Sid": "IAM"
        },
        {
            "Action": [
                "autoscaling:UpdateAutoScalingGroup",
                "autoscaling:SuspendProcesses",
                "autoscaling:SetDesiredCapacity",
                "autoscaling:DeleteAutoScalingGroup",
                "autoscaling:CreateOrUpdateTags",
                "autoscaling:CreateAutoScalingGroup",
                "autoscaling:AttachInstances"
            ],
            "Effect": "Allow",
            "Resource": "arn:aws:autoscaling:*:*:autoScalingGroup:*:autoScalingGroupName/project-n-*",
            "Sid": "Autoscaling"
        },
        {
            "Action": "s3:*",
            "Effect": "Allow",
            "Resource": [
                "arn:aws:s3:::project-n-*",
                "arn:aws:s3:::n-*",
                "arn:aws:s3:::granica-*"
            ],
            "Sid": "S3"
        },
        {
            "Action": "s3:ListAllMyBuckets",
            "Effect": "Allow",
            "Resource": "*",
            "Sid": "ListAllBuckets"
        },
        {
            "Action": [
                "eks:UpdateClusterVersion",
                "eks:UpdateClusterConfig",
                "eks:UntagResource",
                "eks:TagResource",
                "eks:DescribeUpdate",
                "eks:DescribeCluster",
                "eks:AssociateEncryptionConfig"
            ],
            "Effect": "Allow",
            "Resource": "arn:aws:eks:*:*:cluster/project-n-*",
            "Sid": "EKS"
        },
        {
            "Action": [
                "eks:UpdateAddon",
                "eks:UntagResource",
                "eks:TagResource",
                "eks:ListUpdates",
                "eks:ListTagsForResource",
                "eks:ListAddons",
                "eks:DeleteAddon",
                "eks:CreateAddon"
            ],
            "Effect": "Allow",
            "Resource": [
                "arn:aws:eks:*:*:cluster/project-n-*",
                "arn:aws:eks:*:*:addon/project-n-*/*/*"
            ],
            "Sid": "EKSAddons"
        },
        {
            "Action": "eks:Describe*",
            "Effect": "Allow",
            "Resource": "*",
            "Sid": "EKSDescribe"
        },
        {
            "Action": [
                "sqs:UntagQueue",
                "sqs:TagQueue",
                "sqs:SetQueueAttributes",
                "sqs:ListQueues",
                "sqs:ListQueueTags",
                "sqs:GetQueueUrl",
                "sqs:GetQueueAttributes",
                "sqs:CreateQueue",
                "sqs:AddPermission"
            ],
            "Effect": "Allow",
            "Resource": "arn:aws:sqs:*:*:project-n-*",
            "Sid": "SQS"
        },
        {
            "Action": [
                "logs:UntagLogGroup",
                "logs:TagLogGroup",
                "logs:PutRetentionPolicy",
                "logs:ListTagsLogGroup",
                "logs:DescribeLogGroups",
                "logs:DeleteLogGroup",
                "logs:CreateLogGroup"
            ],
            "Effect": "Allow",
            "Resource": [
                "arn:aws:logs:*:*:log-group::log-stream*",
                "arn:aws:logs:*:*:log-group:/aws/eks/project-n*"
            ],
            "Sid": "logs"
        }
    ]
  })
}

resource "aws_iam_policy" "project-n-admin-vpc-permissions" {
  name        = "project-n-admin-vpc-permissions"
  description = "Project N Admin VPC Permissions"
  policy      = jsonencode({
    Version = "2012-10-17"
    Statement = [
        {
            "Action": [
                "ec2:RevokeSecurityGroupIngress",
                "ec2:RevokeSecurityGroupEgress",
                "ec2:ReleaseAddress",
                "ec2:ModifyVpcEndpoint",
                "ec2:ModifyVpcAttribute",
                "ec2:ModifySubnetAttribute",
                "ec2:DisassociateVpcCidrBlock",
                "ec2:DisassociateSubnetCidrBlock",
                "ec2:DisassociateRouteTable",
                "ec2:DisassociateAddress",
                "ec2:DetachNetworkInterface",
                "ec2:DetachInternetGateway",
                "ec2:DescribeSubnets",
                "ec2:DeleteVpcPeeringConnection",
                "ec2:DeleteVpcEndpoints",
                "ec2:DeleteVpc",
                "ec2:DeleteTags",
                "ec2:DeleteSubnet",
                "ec2:DeleteSecurityGroup",
                "ec2:DeleteRouteTable",
                "ec2:DeleteRoute",
                "ec2:DeleteNetworkInterface",
                "ec2:DeleteNatGateway",
                "ec2:DeleteInternetGateway",
                "ec2:CreateVpcPeeringConnection",
                "ec2:CreateVpcEndpoint",
                "ec2:CreateVpc",
                "ec2:CreateTags",
                "ec2:CreateSubnet",
                "ec2:CreateSecurityGroup",
                "ec2:CreateRouteTable",
                "ec2:CreateRoute",
                "ec2:CreateNetworkInterface",
                "ec2:CreateNatGateway",
                "ec2:CreateInternetGateway",
                "ec2:AuthorizeSecurityGroupIngress",
                "ec2:AuthorizeSecurityGroupEgress",
                "ec2:AttachNetworkInterface",
                "ec2:AttachInternetGateway",
                "ec2:AssociateVpcCidrBlock",
                "ec2:AssociateSubnetCidrBlock",
                "ec2:AssociateRouteTable",
                "ec2:AssociateAddress",
                "ec2:AllocateAddress",
                "ec2:AcceptVpcPeeringConnection"
            ],
            "Effect": "Allow",
            "Resource": "*",
            "Sid": "VPC"
        }
    ]
  })
}

resource "aws_iam_policy" "project-n-eks-addons-terraform" {
  name        = "project-n-eks-addons-terraform"
  description = "Project N EKS Addons Terraform"
  policy      = jsonencode({
    Version = "2012-10-17"
    Statement = [
        {
            "Action": [
                "eks:UpdateAddon",
                "eks:UntagResource",
                "eks:TagResource",
                "eks:ListUpdates",
                "eks:ListTagsForResource",
                "eks:ListAddons",
                "eks:DeleteAddon",
                "eks:CreateAddon"
            ],
            "Effect": "Allow",
            "Resource": [
                "arn:aws:eks:*:*:cluster/project-n-*",
                "arn:aws:eks:*:*:addon/project-n-*/*/*"
            ],
            "Sid": "EKSAddons"
        },
        {
            "Action": "eks:Describe*",
            "Effect": "Allow",
            "Resource": "*",
            "Sid": "EKSDescribe"
        }
    ]
  })
}

resource "aws_iam_policy" "project-n-oidc-additional-terraform" {
  name        = "project-n-oidc-additional-terraform"
  description = "Project N OIDC Additional Terraform"
  policy      = jsonencode({
    Version = "2012-10-17"
    Statement = [
        {
            "Action": "iam:UpdateOpenIDConnectProviderThumbprint",
            "Effect": "Allow",
            "Resource": [
                "arn:aws:iam::*:role/project-n-*",
                "arn:aws:iam::*:role/aws-service-role/elasticloadbalancing.amazonaws.com/AWSServiceRoleForElasticLoadBalancing",
                "arn:aws:iam::*:role/aws-service-role/eks.amazonaws.com/AWSServiceRoleForAmazonEKS",
                "arn:aws:iam::*:role/aws-service-role/autoscaling.amazonaws.com/AWSServiceRoleForAutoScaling",
                "arn:aws:iam::*:policy/project-n-*",
                "arn:aws:iam::*:oidc-provider/oidc.eks.*.amazonaws.com/id/*",
                "arn:aws:iam::*:oidc-provider/oidc.eks.*.amazonaws.com",
                "arn:aws:iam::*:instance-profile/project-n-*"
            ],
            "Sid": "OIDCAdditional"
        }
    ]
  })
}


# Create users
resource "aws_iam_user" "users" {
  count = length(var.user_names)
  name  = var.user_names[count.index]
}

# Attach policies to users
resource "aws_iam_user_policy_attachment" "cloudshell" {
  count      = length(var.user_names)
  user       = aws_iam_user.users[count.index].name
  policy_arn = aws_iam_policy.cloudshell_access.arn
}

resource "aws_iam_user_policy_attachment" "granica_lb" {
  count      = length(var.user_names)
  user       = aws_iam_user.users[count.index].name
  policy_arn = aws_iam_policy.granica_lb.arn
}

resource "aws_iam_user_policy_attachment" "project_n_admin_deploy" {
  count      = length(var.user_names)
  user       = aws_iam_user.users[count.index].name
  policy_arn = aws_iam_policy.project_n_admin_deploy.arn
}

resource "aws_iam_user_policy_attachment" "project-n-admin-vpc-permissions" {
  count      = length(var.user_names)
  user       = aws_iam_user.users[count.index].name
  policy_arn = aws_iam_policy.project-n-admin-vpc-permissions.arn
}

resource "aws_iam_user_policy_attachment" "project-n-eks-addons-terraform" {
  count      = length(var.user_names)
  user       = aws_iam_user.users[count.index].name
  policy_arn = aws_iam_policy.project-n-eks-addons-terraform.arn
}

resource "aws_iam_user_policy_attachment" "project-n-oidc-additional-terraform" {
  count      = length(var.user_names)
  user       = aws_iam_user.users[count.index].name
  policy_arn = aws_iam_policy.project-n-oidc-additional-terraform.arn
}
