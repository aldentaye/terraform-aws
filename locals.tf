locals {
  vpc_cidr = "10.123.0.0/16"
}

locals {
  security_groups = {
    public = {
      name        = "public_sg"
      description = "Security group for _public_ access"
      ingress = {
        # ssh = {
        #   from_port   = 22
        #   to_port     = 22
        #   protocol    = "tcp"
        #   cidr_blocks = [var.access_ip]
        # }
        open = {
          from_port   = 0
          to_port     = 0
          protocol    = -1
          cidr_blocks = [var.access_ip]
        }
         tg = {
          from_port        = 8000
          to_port          = 8000
          protocol    = "tcp"
          cidr_blocks = ["0.0.0.0/0"]
        }
        http = {
          from_port   = 80
          to_port     = 80
          protocol    = "tcp"
          cidr_blocks = ["0.0.0.0/0"]
        }
      }
    }
    rds = {
      name        = "rds_sg"
      description = "Security group for _rds_ access"
      ingress = {
        mysql = {
          from_port   = 3306
          to_port     = 3306
          protocol    = "tcp"
          cidr_blocks = [var.access_ip]
        }
      }
    }
  }
}


