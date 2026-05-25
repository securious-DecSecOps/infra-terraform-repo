variable "name_prefix" {
  type = string
}

variable "subnet_id" {
  type = string
}

variable "ci_security_group_id" {
  type = string
}

variable "runtime_security_group_id" {
  type = string
}

variable "instance_profile_name" {
  type = string
}

variable "ci_instance_type" {
  type = string
}

variable "runtime_instance_type" {
  type = string
}

variable "ci_user_data" {
  type = string
}

variable "runtime_user_data" {
  type = string
}

variable "common_tags" {
  type = map(string)
}