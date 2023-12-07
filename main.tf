provider "aws" {
  region = "ap-northeast-1"
  shared_config_files = ["~/.aws/config"]
  shared_credentials_files = ["~/.aws/credentials"]
  profile = "default"
}

resource "aws_instance" "test-userdata" {
  ami = "ami-0f7b55661ecbbe44c"
  instance_type = "t2.micro"
  availability_zone = "ap-northeast-1c"
  vpc_security_group_ids = [aws_security_group.instance.id]

  user_data = <<-EOF
  #!/bin/bash
  echo "Hello World" > index.html
  nohup busybox httpd -f -p 8080 &
  EOF

  user_data_replace_on_change = true

  tags = {
    name="terraform-test"
  }
}

resource "aws_security_group" "instance" {
  name = "test-userdata-secgp"

  ingress {
    from_port = 8080
    to_port = 8080
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
}