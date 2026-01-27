variable "state_name" {
  description = "The name of the state"
  type        = string
}

variable "vpc_id" {
  description = "The VPC ID from the network module"
  type        = string
}

variable "subnet_id" {
  description = "The Subnet ID from the network module"
  type        = string
}