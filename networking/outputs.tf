# --- networking/outputs.tf --- 

output "vpc_id" {
  value = aws_vpc.main.id
}

output "db_subnet_group_name" {
  value = aws_db_subnet_group.rds_subnet_group.*.name
}

output "vpc_security_group" {
  value = [aws_security_group.sg["rds"].id]
}

output "public_sg" {
  value = [aws_security_group.sg["public"].id]
}

output "public_subnets" {
  value = aws_subnet.main_public.*.id
}