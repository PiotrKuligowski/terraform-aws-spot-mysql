output "mysql_root_password" {
  value = random_password.this.result
}

output "ebs_volume_id" {
  value = local.ebs_id
}

output "asg_name" {
  value = module.this.asg_name
}