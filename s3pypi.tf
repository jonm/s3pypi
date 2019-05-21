variable "region" {
  default = "us-east-1"
}

terraform {
  backend "s3" {
    key = "s3pypi.tfstate"
  }
}

provider "aws" {
  region = "${var.region}"
  version = "~> 2.11"
}

resource "aws_s3_bucket" "artifact_bucket" {
  bucket = "s3pypi-artifacts"
}
