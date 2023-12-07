provider "aws" {
  region = "ap-northeast-1"
  shared_config_files = ["~/.aws/config"]
  shared_credentials_files = ["~/.aws/credentials"]
  profile = "default"
}

resource "aws_instance" "test" {
  ami = "ami-035d55281a86f9439"
  instance_type = "t2.micro"
  availability_zone = "ap-northeast-1c"
}