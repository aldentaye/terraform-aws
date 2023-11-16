# --- root/main.tf ---

module "networking" {
  source          = "./networking"
  vpc_cidr        = local.vpc_cidr
  access_ip       = var.access_ip
  security_groups = local.security_groups
  # for subnets
  public_count    = 2
  private_count   = 3
  max_subnets     = 20
  public_cidrs    = [for i in range(2, 255, 2) : cidrsubnet(local.vpc_cidr, 8, i)] # even
  private_cidrs   = [for i in range(1, 255, 2) : cidrsubnet(local.vpc_cidr, 8, i)] # odd 
  db_subnet_group = true
}

module "database" {
  source                 = "./database"
  db_name                = var.db_name
  db_engine_version      = "8.0.35"
  db_instance_class      = "db.t3.micro"
  dbuser                 = var.dbuser
  dbpassword             = var.dbpassword
  db_identifier          = "alex-db"
  skip_db_snapshot       = true
  db_subnet_group_name   = module.networking.db_subnet_group_name[0]
  vpc_security_group_ids = module.networking.vpc_security_group
}

module "loadbalancing" {
  source                 = "./loadbalancing"
  public_sg              = module.networking.public_sg
  public_subnets         = module.networking.public_subnets
  tg_port                = 8000
  tg_protocol            = "HTTP"
  vpc_id                 = module.networking.vpc_id
  lb_healthy_threshold   = 2
  lb_unhealthy_threshold = 2
  lb_timeout             = 3
  lb_interval            = 30
  listener_port          = 80
  listener_protocol      = "HTTP"
}

module "compute" {
  source              = "./compute"
  public_sg           = module.networking.public_sg
  public_subnets      = module.networking.public_subnets
  instance_count      = 1
  instance_type       = "t3.micro"
  vol_size            = "20"
  key_name            = "alex-key"
  public_key_path     = "/home/ubuntu/.ssh/id_rsa.pub"
  user_data_path      = "${path.root}/userdata.tpl"
  dbuser              = var.dbuser
  dbpassword          = var.dbpassword
  db_endpoint         = module.database.db_endpoint
  db_name             = var.db_name
  lb_target_group_arn = module.loadbalancing.lb_target_group_arn
  tg_port             = 8000
  private_key_path    = "/home/ubuntu/.ssh/id_rsa"
}


