module "sg_pg_db" {
  source  = "terraform-aws-modules/security-group/aws"
  version = "5.2.0"

  for_each = var.entries

  name        = "postgresql-${each.key}"
  description = "Security group for POSTGRESQL-${each.key}"
  vpc_id      = each.value.rds_vpc

  ingress_with_cidr_blocks = [
    {
      rule        = "postgresql-tcp"
      cidr_blocks = "${each.value.rds_cidr}"
    }
  ]
  computed_ingress_with_source_security_group_id = flatten([
    for security_group in each.value.access_sg_ids : [
      {
        rule                     = "postgresql-tcp"
        source_security_group_id = security_group
      }
    ]
  ])

  number_of_computed_ingress_with_source_security_group_id = length(each.value.access_sg_ids)

}

module "rds-pg" {
  source  = "terraform-aws-modules/rds/aws"
  version = "6.9.0"

  for_each = var.entries

  identifier           = "${var.name}-${var.environment}-pg-${each.key}"
  engine               = "postgres"
  engine_version       = each.value.postgresql_db_version
  family               = each.value.postgresql_db_family
  major_engine_version = each.value.postgresql_db_major
  instance_class       = each.value.postgresql_db_instance_type
  allocated_storage    = each.value.postgresql_db_size
  storage_encrypted    = false

  manage_master_user_password = false
  username = each.value.postgresql_db_user
  password = each.value.postgresql_db_password
  port     = "5432"

  snapshot_identifier = each.value.postgresql_snapshot

  maintenance_window        = "Mon:00:00-Mon:03:00"
  backup_window             = "03:00-06:00"
  backup_retention_period   = 2
  skip_final_snapshot       = true

  enabled_cloudwatch_logs_exports = ["postgresql", "upgrade"]

  vpc_security_group_ids = concat([module.sg_pg_db[each.key].security_group_id], each.value.sg_ids)
  subnet_ids             = each.value.rds_subnets

  deletion_protection = false
  publicly_accessible = each.value.postgresql_public
  apply_immediately   = true

  parameters = lookup(each.value, "parameters", [])

}
