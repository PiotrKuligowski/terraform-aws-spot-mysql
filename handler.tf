module "k3s-mysql-interruption-handler" {
  source              = "git::https://github.com/PiotrKuligowski/terraform-aws-spot-mysql-interruption-handler.git"
  function_name       = "${var.project}-mysql-interruption-handler"
  component           = "mysql-interruption-handler"
  project             = var.project
  environment_vars    = local.mysql_interruption_handler_env_variables
  policy_statements   = local.mysql_interruption_handler_policy_statements
  eventbridge_trigger = local.spot_interruption_event_pattern
  tags                = var.tags
}

locals {
  mysql_interruption_handler_env_variables = {
    REGION                 = data.aws_region.current.name
    MYSQL_USER             = "root"
    MYSQL_PASSWORD         = random_password.this.result
    VOLUME_ID              = local.ebs_id
    AUTOSCALING_GROUP_NAME = module.this.asg_name
  }

  spot_interruption_event_pattern = <<PATTERN
{
  "detail-type": ["EC2 Spot Instance Interruption Warning"],
  "source": ["aws.ec2"]
}
  PATTERN

  mysql_interruption_handler_policy_statements = {
    AllowAttachAndDescribe = {
      effect = "Allow",
      actions = [
        "autoscaling:DescribeAutoScalingGroups",
        "autoscaling:DetachInstances",
        "ssm:ListCommandInvocations",
        "ec2:DescribeInstances",
        "ec2:TerminateInstances"
      ]
      resources = ["*"]
    }
    AllowAttachAndDescribe2 = {
      sid    = "AllowAttachAndDescribe2"
      effect = "Allow"
      actions = [
        "ec2:DetachVolume",
        "ec2:DescribeVolumes",
        "ec2:DescribeInstances",
        "ec2:TerminateInstances",
        "autoscaling:DescribeAutoScalingGroups",
        "autoscaling:DetachInstances"
      ]
      resources = ["*"]
    }
    AllowLogs = {
      effect    = "Allow",
      actions   = ["logs:*"]
      resources = ["arn:aws:logs:*:*:*"]
    }
  }
}