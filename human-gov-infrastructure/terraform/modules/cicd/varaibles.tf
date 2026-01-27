variable "region" {
  description = "The AWS Region (e.g., us-east-1)"
  type        = string
}

variable "ecr_repo_url" {
  description = "The URL of the ECR repository"
  type        = string
}

variable "codestar_connection_arn" {
  description = "The ARN of the AWS CodeStar connection to GitHub"
  type        = string
}

variable "github_repo_id" {
  description = "The GitHub Repository ID in the format User/Repo"
  type        = string
}