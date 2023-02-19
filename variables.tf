# AWS Region
variable "aws_region" {
  type        = string
  nullable    = false
  description = "the aws region for the deployment"
}
# AWS Profile
variable "profile" {
  type        = string
  nullable    = false
  description = "name of the profile stored in ~/.aws/credentials"
  sensitive   = true
}