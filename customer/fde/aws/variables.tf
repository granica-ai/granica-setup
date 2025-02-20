variable "aws_region" {
  description = "AWS region"
  type        = string
}

variable "operations_user_names" {
  description = "Names of the Granica operations IAM users to create"
  type        = list(string)
  default     = ["granica_fde_operations"]
}

variable "administer_user_names" {
  description = "Names of the Granica admin IAM user(s) to create"
  type        = list(string)
  default     = ["granica_fde_administer"]
}
