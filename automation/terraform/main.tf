provider "aws" {
  version = "~> 2.0"
  region  = "eu-west-2"
}

data "aws_ami" "ubuntu" {
  most_recent = true

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-bionic-18.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  owners = ["099720109477"]
}

resource "aws_key_pair" "xebia-key" {
  key_name = "xebia"
  public_key = file(var.ssh_public_key_file)
}

module "staging" {
  source = "./application"

  application_key_name = aws_key_pair.xebia-key.key_name
  application_instance_type = "t2.micro"
  application_ami = data.aws_ami.ubuntu.id
  application_instance_count = 1
  application_stage = "staging"
}

module "production" {
  source = "./application"

  application_key_name = aws_key_pair.xebia-key.key_name
  application_instance_type = "t2.micro"
  application_ami = data.aws_ami.ubuntu.id
  application_instance_count = 1
  application_stage = "production"
}
