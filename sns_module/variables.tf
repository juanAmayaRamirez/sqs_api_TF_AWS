variable "monthly_spend_limit" {
  description = "The maximum amount to spend on SMS messages each month. If you send a message that exceeds your limit, Amazon SNS stops sending messages within minutes."
  type        = number
  default     = 1
}

variable "policy_name" {
  description = "Name of policy to publish to Group SMS topic."
  type        = string
  default     = "group-sms-publish"
}

variable "policy_path" {
  description = "Path of policy to publish to Group SMS topic"
  type        = string
  default     = "/"
}

variable "role_name" {
  description = "The IAM role that allows Amazon SNS to write logs for SMS deliveries in CloudWatch Logs."
  type        = string
  default     = "SNSSuccessFeedback"
}

variable "subscriptions" {
  description = "List of telephone numbers to subscribe to SNS."
  type        = list(string)
  default     = []
}

variable "topic_display_name" {
  description = "Display name of the AWS SNS topic."
  type        = string
  default     = ""
}

variable "topic_name" {
  description = "Name of the AWS SNS topic."
  type        = string
}
