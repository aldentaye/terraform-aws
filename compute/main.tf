# --- compute/main.tf ---

data "aws_ami" "server_ami" {
  most_recent = true

  owners = ["099720109477"] # note, plural usually means in a list

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }
}

resource "random_id" "node_id" {
  byte_length = 2
  count       = var.instance_count
  # arbitrary map of values that, when changed, will trigger recreation of resource
  keepers = {
    key_name = var.key_name
  }
}

resource "aws_key_pair" "auth" {
  key_name   = var.key_name
  public_key = file(var.public_key_path)
}

resource "aws_instance" "node" {
  count         = var.instance_count
  instance_type = var.instance_type
  ami           = data.aws_ami.server_ami.id

  tags = {
    # elb, k8's, etc do not like underscores in hostnames
    Name = "node-${random_id.node_id[count.index].dec}" # decimal of random_id
  }

  key_name               = aws_key_pair.auth.id
  vpc_security_group_ids = var.public_sg
  subnet_id              = var.public_subnets[count.index]
  user_data = templatefile(var.user_data_path,
    {
      nodename    = "node-${random_id.node_id[count.index].dec}"
      dbuser      = var.dbuser
      dbpass      = var.dbpassword
      db_endpoint = var.db_endpoint
      dbname      = var.db_name
    }
  )
  root_block_device {
    volume_size = var.vol_size
  }
  # below not recommended, prefer to use ansible 
  # verifies kube config exists
  provisioner "remote-exec" {
    connection {
      type        = "ssh"
      user        = "ubuntu"
      host        = self.public_ip
      private_key = file(var.private_key_path)
    }
    script = "${path.root}/delay.sh"
  }
  # pulls kube config to local
  provisioner "local-exec" {
    command = templatefile("${path.cwd}/scp_script.tpl",
      {
        nodeip           = self.public_ip
        k3s_path         = "${path.cwd}/../" # so we do not commit kube config to repo
        nodename         = self.tags.Name
        private_key_path = var.private_key_path
      }
    )
  }
  # for cleaning up old kube config
  provisioner "local-exec" {
    when    = destroy
    command = "rm -rf ${path.cwd}/../k3s-${self.tags.Name}.yaml"
  }
}

# provides the ability to register instances and containers with a load balancer
resource "aws_lb_target_group_attachment" "tg_attach" {
  count            = var.instance_count
  target_group_arn = var.lb_target_group_arn
  target_id        = aws_instance.node[count.index].id
  port             = var.tg_port
}

