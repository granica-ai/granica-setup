variable "aws_region" {
  description = "AWS region"
  type        = string
}

variable "user_names" {
  description = "Names of the IAM users to create"
  type        = list(string)
  default     = ["FDE1_granica", "FDE2_granica"]
}
