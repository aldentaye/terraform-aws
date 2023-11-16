# --- compute/outputs.tf ---

output "instance" {
  value     = aws_instance.node[*]
  sensitive = true # marks output as sensitive to prevent error
}

output "instance_port" {
  value = aws_lb_target_group_attachment.tg_attach[0].port # pull first bc it's the same for all
}