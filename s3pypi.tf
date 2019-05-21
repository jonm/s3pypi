variable "region" {
  default = "us-east-1"
}
variable "aws_access_key" {}
variable "aws_secret_key" {}

terraform {
  backend "s3" {
    key = "s3pypi.tfstate"
  }
}

provider "aws" {
  region = "${var.region}"
  version = "~> 2.11"
  access_key = "${var.aws_access_key}"
  secret_key = "${var.aws_secret_key}"
}

resource "aws_s3_bucket" "artifact_bucket" {
  bucket = "s3pypi-artifacts"
}
