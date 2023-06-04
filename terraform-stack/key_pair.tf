resource "aws_key_pair" "deployer" {
  key_name   = var.ssh_key_name
  public_key = file("${path.module}/.ssh/${var.project_name}.pub")
}
