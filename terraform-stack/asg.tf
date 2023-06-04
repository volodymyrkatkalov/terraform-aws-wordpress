module "wp-asg" {
  source  = "terraform-aws-modules/autoscaling/aws"
  version = "6.10.0"

  name                      = "${var.project_name}-${var.environment}-asg"
  instance_name             = "${var.project_name}-${var.environment}-web"
  min_size                  = var.asg_exact_size
  max_size                  = var.asg_exact_size
  desired_capacity          = var.asg_exact_size
  wait_for_capacity_timeout = 0
  health_check_type         = "ELB"
  vpc_zone_identifier       = module.vpc.public_subnets

  # Launch Template
  launch_template_name        = "${var.project_name}-${var.environment}-lt"
  launch_template_description = var.asg_launch_template_description
  update_default_version      = true
  image_id                    = data.aws_ami.amazon_linux.id
  instance_type               = var.asg_instance_type
  target_group_arns           = module.alb.target_group_arns
  key_name                    = var.ssh_key_name
  user_data = base64encode(templatefile("${path.module}/wordpress-init.sh",
    {
      vars = {
        project_name      = var.project_name
        alb_dns_name      = module.alb.lb_dns_name
        efs_dns_name      = "${resource.aws_efs_file_system.efs.dns_name}"
        db_name           = module.db.db_instance_name
        db_user           = module.db.db_instance_username
        db_password       = module.db.db_instance_password
        db_host           = module.db.db_instance_endpoint
        wp_admin_username = var.wp_admin_username
        wp_admin_email    = var.wp_admin_email
        wp_admin_password = var.wp_admin_password
      }
  }))
  tag_specifications = [
    {
      resource_type = "instance"
      tags          = local.tags
    }
  ]

  network_interfaces = [
    {
      delete_on_termination       = true
      description                 = "eth0"
      device_index                = 0
      security_groups             = [module.ssh_sg.security_group_id]
      associate_public_ip_address = true
    }
  ]

  tags = local.tags

  depends_on = [resource.aws_efs_mount_target.efs_target]
}

## Delay to allow time to initialize EC2
resource "time_sleep" "wait_180_seconds" {
  create_duration = "180s"
}
