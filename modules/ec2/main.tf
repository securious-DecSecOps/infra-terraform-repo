data "aws_ami" "amazon_linux_2023" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-2023*-x86_64"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

resource "aws_instance" "ci" {
  ami                         = data.aws_ami.amazon_linux_2023.id
  instance_type               = var.ci_instance_type
  subnet_id                   = var.subnet_id
  vpc_security_group_ids      = [var.ci_security_group_id]
  iam_instance_profile        = var.instance_profile_name
  associate_public_ip_address = true

  user_data                   = var.ci_user_data
  user_data_replace_on_change = true

  root_block_device {
    volume_size           = 30
    volume_type           = "gp3"
    delete_on_termination = true
  }

  tags = merge(var.common_tags, {
    Name = "${var.name_prefix}-ec2-ci-supply-chain"
    Role = "ci-supply-chain"
  })
}

resource "aws_instance" "runtime" {
  ami                         = data.aws_ami.amazon_linux_2023.id
  instance_type               = var.runtime_instance_type
  subnet_id                   = var.subnet_id
  vpc_security_group_ids      = [var.runtime_security_group_id]
  iam_instance_profile        = var.instance_profile_name
  associate_public_ip_address = true

  user_data                   = var.runtime_user_data
  user_data_replace_on_change = true

  root_block_device {
    volume_size           = 30
    volume_type           = "gp3"
    delete_on_termination = true
  }

  tags = merge(var.common_tags, {
    Name = "${var.name_prefix}-ec2-runtime"
    Role = "runtime"
  })
}