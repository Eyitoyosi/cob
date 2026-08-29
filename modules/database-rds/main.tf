locals {
  identifier = "cob-${var.environment}-${var.name}"
  is_prod    = var.environment == "prod"
  multi_az   = coalesce(var.multi_az, local.is_prod)

  common_tags = merge(
    { Platform = "COB", Environment = var.environment, ManagedBy = "Terraform" },
    var.tags
  )
}

resource "aws_security_group" "this" {
  name_prefix = "${local.identifier}-"
  vpc_id      = var.vpc_id
  tags        = local.common_tags

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  lifecycle {
    create_before_destroy = true
  }
}

# SG-to-SG references, not CIDR blocks . This is the actual access control.
resource "aws_security_group_rule" "ingress" {
  for_each = toset(var.allowed_security_group_ids)

  type                     = "ingress"
  from_port                = 5432
  to_port                  = 5432
  protocol                 = "tcp"
  security_group_id        = aws_security_group.this.id
  source_security_group_id = each.value
  description               = "Allow database access from ${each.value}"
}

resource "random_password" "master" {
  length  = 24
  special = true
  override_special = "!#$%^&*()-_=+"
}

resource "aws_db_instance" "this" {
  identifier     = local.identifier
  engine         = var.engine
  engine_version = var.engine_version
  instance_class = var.instance_class

  allocated_storage     = var.allocated_storage
  storage_encrypted     = true
  kms_key_id            = var.kms_key_arn
  db_subnet_group_name  = var.database_subnet_group_name
  vpc_security_group_ids = [aws_security_group.this.id]

  username = "cobadmin"
  password = random_password.master.result

  multi_az                = local.multi_az
  backup_retention_period = local.is_prod ? 14 : 3
  deletion_protection     = local.is_prod
  skip_final_snapshot     = !local.is_prod
  final_snapshot_identifier = local.is_prod ? "${local.identifier}-final" : null

  tags = local.common_tags
}

# Credentials live here — never in a Terraform output or .tfvars file.
resource "aws_secretsmanager_secret" "this" {
  name = "${local.identifier}-credentials"
  tags = local.common_tags
}

resource "aws_secretsmanager_secret_version" "this" {
  secret_id = aws_secretsmanager_secret.this.id
  secret_string = jsonencode({
    username = aws_db_instance.this.username
    password = random_password.master.result
    host     = aws_db_instance.this.address
    port     = aws_db_instance.this.port
    dbname   = aws_db_instance.this.db_name
  })
}