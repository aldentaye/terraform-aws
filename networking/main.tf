# --- networking/main.tf --- 

# resource "random_integer" "random" {
#   min = 1
#   max = 100
# }

data "aws_availability_zones" "available" {}

resource "random_shuffle" "az" {
  input        = data.aws_availability_zones.available.names
  result_count = var.max_subnets
}

# Create a VPC
resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true

  tags = {
    # Name = "main-${random_integer.random.id}"
    Name = "main"
  }
  # lifecycle policy to have a new replacement object is created first, and the prior object is destroyed after the replacement is created
  # to prevent terraform from hanging if there is no vpc available 
  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_subnet" "main_public" {
  count                   = var.public_count
  vpc_id                  = aws_vpc.main.id
  cidr_block              = var.public_cidrs[count.index]
  map_public_ip_on_launch = true
  # availability_zone = ["us-west-2a", "us-west-2b", "us-west-2c", "us-west-2d"][count.index]
  availability_zone = random_shuffle.az.result[count.index]

  tags = {
    Name = "public-main-${count.index + 1}"
  }
}

# Shows what subnets are associated with what route table (or internet gateways)
resource "aws_route_table_association" "public_assoc" {
  count          = var.public_count
  subnet_id      = aws_subnet.main_public.*.id[count.index] # access each subnet
  route_table_id = aws_route_table.public_rt.id
}

resource "aws_subnet" "main_private" {
  count                   = var.private_count
  vpc_id                  = aws_vpc.main.id
  cidr_block              = var.private_cidrs[count.index]
  map_public_ip_on_launch = false
  availability_zone       = random_shuffle.az.result[count.index]

  tags = {
    Name = "private-main-${count.index + 1}"
  }
}

# Provides details about a specific Internet Gateway.
resource "aws_internet_gateway" "internet_gateway" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "main-igw"
  }
}

# Provides details about a specific Route Table
resource "aws_route_table" "public_rt" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "public"
  }
}

# This resource can prove useful when finding the resource associated with a CIDR. For example, finding the peering connection associated with a CIDR value
resource "aws_route" "default_route" {
  route_table_id         = aws_route_table.public_rt.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.internet_gateway.id
}

resource "aws_default_route_table" "private_rt" {
  default_route_table_id = aws_vpc.main.default_route_table_id # every vpc gets a default route table

  tags = {
    Name = "private"
  }
}

resource "aws_security_group" "sg" {
  for_each    = var.security_groups
  name        = each.value.name
  description = each.value.description
  vpc_id      = aws_vpc.main.id

  dynamic "ingress" {
    for_each = each.value.ingress
    content {
      from_port   = ingress.value.from_port
      to_port     = ingress.value.to_port
      protocol    = ingress.value.protocol
      cidr_blocks = ingress.value.cidr_blocks
    }

  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_db_subnet_group" "rds_subnet_group" {
  count      = var.db_subnet_group == true ? 1 : 0
  name       = "rds_subnet_group"
  subnet_ids = aws_subnet.main_private.*.id

  tags = {
    Name = "rds_subnet_group"
  }
}