# terraform-aws-wordpress

This repository contains Terraform scripts for provisioning a highly available Wordpress environment on AWS. It leverages a variety of AWS services such as Elastic Compute Cloud (EC2), Relational Database Service (RDS), Elastic File System (EFS), Virtual Private Cloud (VPC), Security Group, Auto Scaling Group (ASG), Elastic Load Balancer (ALB), S3 bucket for Terraform remote state, and DynamoDB for state lock.

## Project Structure:
#### terraform-stack:
This directory holds the main Terraform scripts for the infrastructure setup.

* `variables.tf`: Contains all the variable definitions used across the Terraform scripts.
* `provider.tf`: Specifies the required provider, AWS in this case, and sets up the S3 backend for Terraform state file storage.
* `output.tf`: Defines output variables that return values after Terraform has completed execution.
* `locals.tf`: Defines local values, used for assigning names to expressions for reuse within a module.
* `security_group.tf`: Creates Security Groups for RDS, EFS, and EC2 instances, defining inbound and outbound traffic rules.
* `vpc.tf`: Defines the VPC, Subnets (Public, Private, and Database), and enables DNS hostnames.
* `efs.tf`: Provisions an Elastic File System (EFS) and includes mount targets.
* `key-pair.tf`: Creates an AWS Key Pair, for secure connections to instances.
* `rds.tf`: Defines an AWS RDS instance, including configurations like engine, version, instance class, username, password.
* `alb.tf`: Provisions an AWS Application Load Balancer (ALB), distributing incoming application traffic across multiple EC2 instances.
* `asg.tf`: Defines an AWS Auto Scaling Group (ASG), ensuring the number of Amazon EC2 instances scales up during demand spikes and scales down during lulls to minimize costs.
* `data.tf`: Fetches data from pre-defined data sources required to configure resources or outputs.

#### terraform-remote-state:
This directory contains Terraform scripts managing the remote state.

* `dynamodb.tf`: Creates a DynamoDB table used by Terraform to lock the state file, preventing concurrent writes and potential state corruption.
* `provider.tf`: Sets up the AWS provider for the Terraform scripts in this directory.
* `s3.tf`: Creates an S3 bucket storing the Terraform's remote state file, enables versioning and sets up server-side encryption.
* `variables.tf`: Defines variables used within this directory.

## Usage:
```bash
cat > .env << EOF
TF_VAR_project_name=terraform-aws-wordpress
TF_VAR_wp_admin_username=administrator
TF_VAR_wp_admin_password=passw0rd
TF_VAR_state_region=us-east-1
TF_VAR_installation_region=us-east-1
TF_VAR_rds_name=wordpress_db
TF_VAR_rds_username=dbuser
TF_VAR_rds_password=p4ssw0rd777
AWS_ACCESS_KEY_ID=<REPLACE>
AWS_SECRET_ACCESS_KEY=<REPLACE>
AWS_DEFAULT_REGION=us-east-1
EOF
chmod +x ./scripts/*.sh
./scripts/initialize.sh # to initialize
./scripts/destroy.sh # to destroy
```

