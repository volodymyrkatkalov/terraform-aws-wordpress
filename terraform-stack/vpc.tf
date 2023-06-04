module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "5.0.0"

  name                         = "${var.project_name}-${var.environment}-vpc"
  cidr                         = var.vpc_cidr
  azs                          = slice(data.aws_availability_zones.this.names, 0, 2)
  create_database_subnet_group = "true"
  public_subnets               = var.public_subnet_cidrs
  private_subnets              = var.private_subnet_cidrs
  database_subnets             = var.database_subnets_cidrs
  enable_dns_hostnames         = "true"

  tags = local.tags
}
