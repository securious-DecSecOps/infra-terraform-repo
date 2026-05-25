locals {
  name_prefix = "${var.project_name}-${var.environment}"

  common_tags = {
    Project     = var.project_name
    Environment = var.environment
    ManagedBy   = "terraform"
  }
}

module "network" {
  source = "../../modules/network"

  name_prefix        = local.name_prefix
  vpc_cidr           = var.vpc_cidr
  public_subnet_cidr = var.public_subnet_cidr
  common_tags        = local.common_tags
}

module "iam" {
  source = "../../modules/iam"

  name_prefix = local.name_prefix
  common_tags = local.common_tags
}

module "security_groups" {
  source = "../../modules/security-groups"

  name_prefix        = local.name_prefix
  vpc_id             = module.network.vpc_id
  allowed_admin_cidr = var.allowed_admin_cidr
  common_tags        = local.common_tags
}

module "ec2" {
  source = "../../modules/ec2"

  name_prefix               = local.name_prefix
  subnet_id                 = module.network.public_subnet_id
  ci_security_group_id      = module.security_groups.ci_security_group_id
  runtime_security_group_id = module.security_groups.runtime_security_group_id
  instance_profile_name     = module.iam.instance_profile_name

  ci_instance_type      = var.ci_instance_type
  runtime_instance_type = var.runtime_instance_type

  ci_user_data      = file("${path.module}/../../scripts/user-data/ci-server.sh")
  runtime_user_data = file("${path.module}/../../scripts/user-data/runtime-server.sh")

  common_tags = local.common_tags
}