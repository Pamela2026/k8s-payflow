locals {
  broker_subnet_ids = var.deployment_mode == "SINGLE_INSTANCE" ? [var.subnet_ids[0]] : var.subnet_ids
}

## Security group for RabbitMQ. ##
resource "aws_security_group" "this" {
  name        = "${var.name_prefix}-mq-sg"
  description = "RabbitMQ access from EKS nodes only"
  vpc_id      = var.vpc_id

  dynamic "ingress" {
    for_each = var.allowed_sg_ids
    content {
      description     = "RabbitMQ AMQPS from EKS nodes"
      from_port       = 5671
      to_port         = 5671
      protocol        = "tcp"
      security_groups = [ingress.value]
    }
  }

  dynamic "ingress" {
    for_each = var.allowed_sg_ids
    content {
      description     = "RabbitMQ management from EKS nodes"
      from_port       = 15672
      to_port         = 15672
      protocol        = "tcp"
      security_groups = [ingress.value]
    }
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = var.tags
}

## Amazon MQ RabbitMQ broker. ##
resource "aws_mq_broker" "this" {
  broker_name                = "${var.name_prefix}-rabbitmq"
  engine_type                = "RabbitMQ"
  engine_version             = var.engine_version
  host_instance_type         = var.host_instance_type
  deployment_mode            = var.deployment_mode
  auto_minor_version_upgrade = var.auto_minor_version_upgrade
  publicly_accessible        = false

  subnet_ids      = local.broker_subnet_ids
  security_groups = [aws_security_group.this.id]

  user {
    username = var.username
    password = var.password
  }

  tags = var.tags
}
