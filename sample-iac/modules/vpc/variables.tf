variable "app_name" {
  type = string
}

variable "vpc_cidr" {
  type = string
  description = "The CIDR block for the VPC"
  default = "10.100.0.0/16"

  validation {
    condition = can(regex("^([0-9]{1,3}\\.){3}[0-9]{1,3}($|/(16|24))$",var.vpc_cidr))
    error_message = "Please ensure a valid CIDR has been entered with range /16 or /24."
  }
}

variable "use_existing_vpc" {
  type = bool
  default = false
  description = "If this value is true, vpc is not created"
}

variable "vpc_id" {
  type = string
  default = ""
  description = "ID of existing vpc. If use_existing_vpc value is true, this value should be required"
}

variable "public_subnets" {
  type = list(string)
  default = []
}

variable "private_subnets" {
  type = list(string)
  default = []
}

variable "database_subnets" {
  type = list(string)
  default = []
}