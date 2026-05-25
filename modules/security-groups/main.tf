resource "aws_security_group" "ci" {
  name        = "${var.name_prefix}-ci-sg"
  description = "Security group for CI and Supply Chain server"
  vpc_id      = var.vpc_id

  tags = merge(var.common_tags, {
    Name = "${var.name_prefix}-ci-sg"
  })
}

resource "aws_security_group" "runtime" {
  name        = "${var.name_prefix}-runtime-sg"
  description = "Security group for Runtime and k3s server"
  vpc_id      = var.vpc_id

  tags = merge(var.common_tags, {
    Name = "${var.name_prefix}-runtime-sg"
  })
}

resource "aws_security_group_rule" "ci_jenkins_admin" {
  type              = "ingress"
  security_group_id = aws_security_group.ci.id

  from_port   = 8083
  to_port     = 8083
  protocol    = "tcp"
  cidr_blocks = [var.allowed_admin_cidr]

  description = "Admin access to Jenkins UI"
}

resource "aws_security_group_rule" "ci_harbor_admin" {
  type              = "ingress"
  security_group_id = aws_security_group.ci.id

  from_port   = 8082
  to_port     = 8082
  protocol    = "tcp"
  cidr_blocks = [var.allowed_admin_cidr]

  description = "Admin access to Harbor UI"
}

resource "aws_security_group_rule" "ci_harbor_from_runtime" {
  type                     = "ingress"
  security_group_id        = aws_security_group.ci.id
  source_security_group_id = aws_security_group.runtime.id

  from_port   = 8082
  to_port     = 8082
  protocol    = "tcp"

  description = "Runtime server pulls images from Harbor"
}

resource "aws_security_group_rule" "runtime_k3s_from_ci" {
  type                     = "ingress"
  security_group_id        = aws_security_group.runtime.id
  source_security_group_id = aws_security_group.ci.id

  from_port   = 6443
  to_port     = 6443
  protocol    = "tcp"

  description = "CI server accesses k3s API"
}

resource "aws_security_group_rule" "runtime_nodeport_admin" {
  type              = "ingress"
  security_group_id = aws_security_group.runtime.id

  from_port   = 30080
  to_port     = 30080
  protocol    = "tcp"
  cidr_blocks = [var.allowed_admin_cidr]

  description = "Admin access to VulnBank NodePort"
}

resource "aws_security_group_rule" "ci_egress_all" {
  type              = "egress"
  security_group_id = aws_security_group.ci.id

  from_port   = 0
  to_port     = 0
  protocol    = "-1"
  cidr_blocks = ["0.0.0.0/0"]

  description = "Allow all outbound traffic from CI server"
}

resource "aws_security_group_rule" "runtime_egress_all" {
  type              = "egress"
  security_group_id = aws_security_group.runtime.id

  from_port   = 0
  to_port     = 0
  protocol    = "-1"
  cidr_blocks = ["0.0.0.0/0"]

  description = "Allow all outbound traffic from Runtime server"
}