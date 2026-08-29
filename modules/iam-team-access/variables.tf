variable "team_name" {
  type        = string
  description = "Short identifier for the team, e.g. 'data-engineering'"
}

variable "environment" {
  type        = string
  description = "AWS account/environment this access applies to"

  validation {
    condition     = contains(["dev", "prod"], var.environment)
    error_message = "environment must be one of: dev, prod."
  }
}

variable "usernames" {
  type        = list(string)
  description = "IAM usernames to create and add to this team's group"
  default     = []
}

variable "policy_statements" {
  description = "Permission statements this team needs, beyond MFA self-service"
  type = list(object({
    sid       = string
    effect    = string
    actions   = list(string)
    resources = list(string)
  }))
}

variable "tags" {
  type    = map(string)
  default = {}
}