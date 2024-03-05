variable "app_name" {
  type = string
}

variable "vpc_id" {
  type = string
}

variable "vpc_cidr_blocks" {
  type = string
}

variable "public_subnets" {
  type = list(string)
}

variable "private_subnets" {
  type = list(string)
}

variable "db_host" {
  type = string
}

variable "db_port" {
  type = number
}

variable "dbname" {
  type = string
}

variable "db_username" {
  type = string
}

variable "db_user_secret_arn" {
  type = string
}

