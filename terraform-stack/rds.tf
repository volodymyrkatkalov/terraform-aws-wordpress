module "db" {
  source  = "terraform-aws-modules/rds/aws"
  version = "5.9.0"

  identifier = "${var.project_name}-${var.environment}-db"

  engine                    = var.rds_engine
  engine_version            = var.rds_engine_version
  create_db_parameter_group = "false"
  create_db_option_group    = "false"
  skip_final_snapshot       = "true"

  instance_class        = var.rds_instance_class
  allocated_storage     = 5
  max_allocated_storage = 10

  username = var.rds_username
  password = var.rds_password
  db_name  = var.rds_db_name

  db_subnet_group_name   = module.vpc.database_subnet_group_name
  multi_az               = "true"
  subnet_ids             = module.vpc.database_subnets
  vpc_security_group_ids = [module.db_sg.security_group_id]
  tags                   = local.tags
}
