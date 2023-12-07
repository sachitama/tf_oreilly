provider "aws" {
  region                   = "ap-northeast-1"
  shared_config_files      = ["~/.aws/config"]
  shared_credentials_files = ["~/.aws/credentials"]
  profile                  = "default"
}

#resource "aws_instance" "test-userdata" {
#  ami = "ami-0f7b55661ecbbe44c"
#  instance_type = "t2.micro"
#  availability_zone = "ap-northeast-1c"
#  vpc_security_group_ids = [aws_security_group.instance.id]
#
#  user_data = <<-EOF
#  #!/bin/bash
#  echo "Hello World" > index.html
#  nohup busybox httpd -f -p 8080 &
#  EOF
#
#  user_data_replace_on_change = true
#
#  tags = {
#    name="terraform-test"
#  }
#}

resource "aws_launch_configuration" "test-userdata" {
  image_id        = "ami-0f7b55661ecbbe44c"
  instance_type   = "t2.micro"
  security_groups = [aws_security_group.instance.id]

  user_data = <<-EOF
  #!/bin/bash
  echo "Hello World" > index.html
  nohup busybox httpd -f -p ${var.server_port} &
  EOF

  # AutoScaling Groupを使う場合必須
  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_autoscaling_group" "test-ag" {
  launch_configuration = aws_launch_configuration.test-userdata.name
  vpc_zone_identifier  = data.aws_subnets.default.ids

  target_group_arns = [aws_lb_target_group.alb-tg.arn]
  health_check_type = "ELB"

  min_size = 2
  max_size = 10

  tag {
    key                 = "Name"
    value               = "test-ag"
    propagate_at_launch = true

  }
}

data "aws_vpc" "default" {
  default = true
}

data "aws_subnets" "default" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }
}

resource "aws_security_group" "instance" {
  name = "test-userdata-secgp"

  ingress {
    from_port   = var.server_port
    to_port     = var.server_port
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

variable "server_port" {
  description = "The port the server will use for HTTP requests"
  type        = number
  default     = 8080
}

resource "aws_lb" "test" {
  name               = "test-alb"
  load_balancer_type = "application"
  subnets            = data.aws_subnets.default.ids
  security_groups    = [aws_security_group.alb.id]
}

resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.test.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type = "fixed-response"

    fixed_response {
      content_type = "text/plain"
      message_body = "404: page not found"
      status_code  = 404
    }
  }
}

resource "aws_security_group" "alb" {
  name = "test-alb-secgp"

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_lb_target_group" "alb-tg" {
  name     = "test-alb-tg"
  port     = 8080
  protocol = "HTTP"
  vpc_id   = data.aws_vpc.default.id

  health_check {
    path                = "/"
    protocol            = "HTTP"
    matcher             = "200"
    interval            = 15
    timeout             = 3
    healthy_threshold   = 2
    unhealthy_threshold = 2
  }
}

resource "aws_lb_listener_rule" "alb-tg-rule" {
  listener_arn = aws_lb_listener.http.arn
  priority     = 100

  condition {
    path_pattern {
      values = ["*"]
    }
  }

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.alb-tg.arn
  }
}
output "alb_dns_name" {
  value       = aws_lb.test.dns_name
  description = "The domain name of the load balancer"
}