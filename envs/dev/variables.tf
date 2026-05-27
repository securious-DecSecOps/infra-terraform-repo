variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "ap-northeast-2"
}

variable "project_name" {
  description = "Project name used for resource naming"
  type        = string
  default     = "secubank"
}

variable "environment" {
  description = "Environment name"
  type        = string
  default     = "dev"
}

variable "vpc_cidr" {
  description = "VPC CIDR block"
  type        = string
  default     = "10.0.0.0/16"
}

variable "public_subnet_cidr" {
  description = "Public subnet CIDR block"
  type        = string
  default     = "10.0.1.0/24"
}

variable "allowed_admin_cidr" {
  description = "Admin public IP CIDR allowed to access Jenkins, Harbor, and NodePort"
  type        = string
  default     = "0.0.0.0/0"
}

variable "ci_instance_type" {
  description = "EC2 instance type for CI/Supply Chain server"
  type        = string
  default     = "t3.medium"
}

variable "runtime_instance_type" {
  description = "EC2 instance type for Runtime server"
  type        = string
  default     = "t3.medium"
}

variable "defectdojo_instance_type" {
  description = "EC2 instance type for DefectDojo server"
  type        = string
  default     = "t3.medium"
}

variable "aws_profile" {
  description = "AWS CLI profile name"
  type        = string
  default     = "secubank"
}