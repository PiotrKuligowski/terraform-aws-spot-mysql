# AWS Spot MySQL Terraform module

Example how to create base EBS volume image to be used by this module.

```shell
# Update system
DEBIAN_FRONTEND=noninteractive apt-get update
DEBIAN_FRONTEND=noninteractive apt-get dist-upgrade -y
DEBIAN_FRONTEND=noninteractive apt-get install -y unzip xfsprogs mysql-server

# Install aws cli
file="awscli-exe-linux-$(uname -i).zip"
curl -O https://awscli.amazonaws.com/$file && unzip -q $file && ./aws/install
rm -rf ./aws && rm -f $file
aws --version

instance_id=$(curl http://169.254.169.254/latest/meta-data/instance-id)
volume_id=$(aws ec2 describe-volumes --filter Name=tag:project,Values=k3s --query "Volumes[*].{ID:VolumeId}" --output text)
aws ec2 attach-volume --device /dev/sdh --instance-id $instance_id --volume-id $volume_id

grep -q xfs /proc/filesystems || sudo modprobe xfs
sudo mkfs.xfs /dev/nvme1n1

echo "/dev/nvme1n1 /vol xfs noatime 0 0" | sudo tee -a /etc/fstab
sudo mkdir -m 000 /vol
sudo mount /vol

sudo /etc/init.d/mysql stop

sudo mkdir /vol/etc /vol/lib /vol/log
sudo mv /etc/mysql     /vol/etc/
sudo mv /var/lib/mysql /vol/lib/
sudo mv /var/log/mysql /vol/log/

sudo mkdir /etc/mysql
sudo mkdir /var/lib/mysql
sudo mkdir /var/log/mysql

echo "/vol/etc/mysql /etc/mysql     none bind" | sudo tee -a /etc/fstab
sudo mount /etc/mysql

echo "/vol/lib/mysql /var/lib/mysql none bind" | sudo tee -a /etc/fstab
sudo mount /var/lib/mysql

echo "/vol/log/mysql /var/log/mysql none bind" | sudo tee -a /etc/fstab
sudo mount /var/log/mysql

sudo /etc/init.d/mysql start

FLUSH TABLES WITH READ LOCK;
SHOW MASTER STATUS;
SYSTEM sudo xfs_freeze -f /vol

# while keeping mysql session open, go to AWS Console and create 
# EBS snapshot while XFS system is frozen

SYSTEM sudo xfs_freeze -u /vol
UNLOCK TABLES;
```

This module is based on: https://aws.amazon.com/articles/running-mysql-on-amazon-ec2-with-ebs-elastic-block-store/