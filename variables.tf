// main.tf
variable "profile" {}
variable "region" {}
variable "bucket" {}
variable "instance_count" {
  default = "3"
}
variable "zone_id"{}
// instance
variable "base_ami" {}
variable "instance_type" {}
// bastion
variable "vpc_name" {}
variable "provision_key" {}
variable "public_subnet_bastion" {}
variable "private_subnet_checkmarx_instance" {}
// created subnet
variable "checkmarx-subnet-cidr-block" {}
variable "availability_zone" {
  type = "list"
  default = ["us-east-1a"]
}
// certificate
variable "domain_name" {}
variable "host_name" {}
// rds
variable "rds_instance_type" {}
variable "private_availability_zone" {}
variable "checkmarx_database_password" {}
// vpc variables
variable "vpc_cidr" {}
variable "linux_base_ami_id" {}
variable "bastion_instance_type" {}
variable "key_name" {}
variable "vpc_public_key" {}
variable "public_subnet_cidrs-vpc" {
  type = "list"
  default = [""]
}
variable "vpc-availability-zones" {
  type = "list"
  default = [""]
}
variable "private_subnet_cidrs-vpc" {
  type = "list"
  default = [""]
}
variable "rds_private_subnet" {
  type = "list"
  default = [""]
}
