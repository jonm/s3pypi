variable "region" {
  default = "us-east-1"
}
variable "name_prefix" {}
variable "aws_access_key" {}
variable "aws_secret_key" {}

provider "aws" {
  region = var.region
  version = "~> 2.11"
  access_key = var.aws_access_key
  secret_key = var.aws_secret_key
}

resource "aws_s3_bucket" "artifact_bucket" {
  bucket = "${var.name_prefix}-artifacts"
}

resource "aws_s3_bucket" "index_bucket" {
  bucket = "${var.name_prefix}-index"
}
