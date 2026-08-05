terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0" # or your preferred version
    }
  }

  required_version = ">= 1.3.0"
}

provider "aws" {
  region = var.aws_region
}

# -----------------------------------------------------------------------------
# 1. Create the IAM Policy from JSON file
# -----------------------------------------------------------------------------
resource "aws_iam_policy" "fde_policy" {
  name        = "FDEPolicy"
  policy      = file("${path.module}/policy.json")
}

# -----------------------------------------------------------------------------
# 2. Create the IAM Role with trust policy
#    Example: trust policy allows ec2.amazonaws.com to assume the role
## -----------------------------------------------------------------------------
data "aws_iam_policy_document" "assume_ec2_role" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "fde_role" {
  name               = "granica_fde_role"
  assume_role_policy = data.aws_iam_policy_document.assume_ec2_role.json
  description        = "FDE role "
}

# -----------------------------------------------------------------------------
# 3. Attach the policy to the role
# -----------------------------------------------------------------------------
resource "aws_iam_role_policy_attachment" "attach_fde_policy_role" {
  role       = aws_iam_role.fde_role.name
  policy_arn = aws_iam_policy.fde_policy.arn
}

# -----------------------------------------------------------------------------
# (Optional) For demonstration: an output that shows the role ARN
# -----------------------------------------------------------------------------
output "fde_role_arn" {
  description = "The ARN of the FDE IAM role"
  value       = aws_iam_role.fde_role.arn
}
