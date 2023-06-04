variable "project_name" {
  default = "terraform-aws-wp"
  type    = string
}

variable "region" {
  default = "us-east-1"
  type    = string
}

variable "tf_state_region" {
  default = "us-east-1"
  type    = string
}

variable "environment" {
  description = "Name of the application environment. e.g. dev, prod, test, staging"
  default     = "dev"
}

variable "vpc_cidr" {
  description = "The CIDR block for the VPC"
  default     = "10.0.0.0/16"
}
variable "public_subnet_cidrs" {
  description = "List of CIDR blocks for public subnets"
  default     = ["10.0.0.0/24", "10.0.1.0/24"]
}

variable "private_subnet_cidrs" {
  description = "List of CIDR blocks for private subnets"
  default     = ["10.0.100.0/24", "10.0.101.0/24"]
}

variable "database_subnets_cidrs" {
  description = "List of CIDR blocks for db subnets"
  default     = ["10.0.200.0/24", "10.0.201.0/24"]
}

variable "asg_instance_type" {
  description = "AutoScaling Group Instance type"
  default     = "t3.micro"
}
variable "asg_launch_template_description" {
  description = "AutoScaling Group launch template description"
  default     = "Wordpress Launch Template"
}

variable "asg_exact_size" {
  description = "AutoScaling Group Exact Size "
  default     = 2
}

variable "wp_admin_username" {
  description = "Wordpress administrator username"
  default     = "admin"
}

variable "wp_admin_email" {
  description = "Wordpress administrator email"
  default     = "admin@example.org"
}

variable "wp_admin_password" {
  description = "Wordpress administrator password"
  default     = "password"
}

variable "rds_username" {
  description = "RDS username"
  default     = "dbuser"
}

variable "rds_password" {
  description = "RDS password"
  default     = "p4ssw0rd777"
}

variable "rds_db_name" {
  description = "RDS database name"
  default     = "wordpressdb"
}

variable "rds_engine" {
  description = "RDS engine"
  default     = "mariadb"
}

variable "rds_engine_version" {
  description = "RDS engine version"
  default     = "10.6.12"
}

variable "rds_instance_class" {
  description = "RDS instance class"
  default     = "db.t3.micro"
}

variable "ssh_key_name" {
  description = "SSH Key name"
  default     = "deployer-key"
}
