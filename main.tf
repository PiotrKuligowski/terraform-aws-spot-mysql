data "aws_region" "current" {}

resource "random_password" "this" {
  length  = 8
  special = false
}

resource "aws_ebs_volume" "this" {
  count             = var.ebs_id == null ? 1 : 0
  availability_zone = var.availability_zone
  size              = var.database_size
  snapshot_id       = var.ebs_snapshot_id
  tags              = var.tags
}

module "this" {
  depends_on                  = [aws_ebs_volume.this]
  source                      = "git::https://github.com/PiotrKuligowski/terraform-aws-spot-asg.git"
  ami_id                      = var.ami_id
  ssh_key_name                = var.ssh_key_name
  subnet_ids                  = var.subnet_ids
  vpc_id                      = var.vpc_id
  user_data                   = local.user_data
  policy_statements           = local.user_data_required_policy
  project                     = var.project
  component                   = var.component
  tags                        = var.tags
  instance_type               = var.instance_type
  private_domain              = var.private_domain
  record_name                 = var.record_name
  record_ttl                  = var.record_ttl
  security_groups             = var.security_groups
  create_sg                   = var.create_sg
  associate_public_ip_address = var.associate_public_ip_address
}

# LOCALS ----------------------------------------------------------------------

locals {
  ebs_id = var.ebs_id == null ? aws_ebs_volume.this[0].id : var.ebs_id

  user_data = <<-CONF
# Attach existing EBS volume
instance_id=$(curl http://169.254.169.254/latest/meta-data/instance-id)
aws ec2 attach-volume --device /dev/sdh --instance-id $instance_id --volume-id ${local.ebs_id}
sleep 5

# Mount EBS volume on reboot
echo "/dev/nvme1n1 /vol xfs noatime 0 0" | tee -a /etc/fstab

# Mount EBS volume
mkdir -m 000 /vol
mount /vol

# Extend EBS volume
xfs_growfs -d /vol

# Make sure files are owned by mysql
find /vol/{lib,log}/mysql/ ! -user  root -print0 | xargs -0 -r chown mysql
find /vol/{lib,log}/mysql/ ! -group root -a ! -group adm -print0 | xargs -0 -r chgrp mysql

# Mount directories and enable mounting on reboot
/etc/init.d/mysql stop
echo "/vol/etc/mysql /etc/mysql     none bind" | tee -a /etc/fstab
mount /etc/mysql
echo "/vol/lib/mysql /var/lib/mysql none bind" | tee -a /etc/fstab
mount /var/lib/mysql
echo "/vol/log/mysql /var/log/mysql none bind" | tee -a /etc/fstab
mount /var/log/mysql
/etc/init.d/mysql start

# Apply security (mysql_secure_installation)
is_mysql_root_password_set() {
  ! mysqladmin --user=root status > /dev/null 2>&1
}
if is_mysql_root_password_set; then
  echo "Database root password already set"
else
  echo "Securing mysql installation"
  mysql --user=root <<EOF
ALTER USER 'root'@'localhost' IDENTIFIED WITH mysql_native_password by '${random_password.this.result}';
UPDATE mysql.user SET Host='%' WHERE Host='localhost' AND User='root';
UPDATE mysql.db SET Host='%' WHERE Host='localhost' AND User='root';
DELETE FROM mysql.user WHERE User='';
DROP DATABASE IF EXISTS test;
DELETE FROM mysql.db WHERE Db='test' OR Db='test\\_%';
FLUSH PRIVILEGES;
%{for db in var.init_databases~}
CREATE DATABASE ${db};
%{endfor~}
EOF
fi
CONF

  user_data_required_policy = {
    allow1 = {
      effect = "Allow",
      actions = [
        "ec2:AttachVolume",
        "route53:ChangeResourceRecordSets"
      ]
      resources = ["*"]
    }
  }
}