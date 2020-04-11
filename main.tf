// declare provider
provider "aws" {
  profile = "${var.profile}"
  region  = "${var.region}"
}

// initialize terraform
terraform {
  backend "s3" {}
  required_version = "> 0.9.0"
}

// create s3 bucket
resource "aws_s3_bucket" "checkmarx-bucket" {
  bucket = "${var.bucket}"
  acl    = "private" // declares the permissions, only owner gets full control
  tags {
    name = "checkmarx-s3"
  }
}
// end s3

resource "aws_key_pair" "bastion-key" {
  key_name   = "${var.vpc_name}-checkmarx-provision-key"
  public_key = "${var.provision_key}"
}

// public instance
resource "aws_instance" "bastion" {
  ami                    = "${var.base_ami}"
  instance_type          = "${var.instance_type}"
  security_groups        = ["${aws_security_group.bastion-sg.id}"]
  key_name               = "${aws_key_pair.bastion-key.key_name}"
  subnet_id              = "${var.public_subnet_bastion}"
  tags {
    Name = "${var.vpc_name}-checkmarx-bastion"
  }
}

// private instance
resource "aws_instance" "checkmarx-private"{
  ami                = "${var.base_ami}"
  instance_type      = "${var.instance_type}"
  key_name           = "${aws_key_pair.bastion-key.key_name}"
  subnet_id          = "${var.private_subnet_checkmarx_instance}"
  security_groups    = [
    "${aws_security_group.ssh-in.id}",
    "${aws_security_group.health-check-in.id}",
    "${aws_security_group.checkmarx-outbound-all.id}"
  ]
  tags {
    Name = "${var.vpc_name}-checkmarx-private"
  }
}
// end private instance

resource "aws_elb" "checkmarx" {
  name               = "checkmarx-elb"
  availability_zones = ["us-east-1a", "us-east-1b"]
  subnets = ["${var.public_subnet_cidrs-vpc}"]
  security_groups = [
    "${aws_security_group.checkmarx-alb-in.id}",
    "${aws_security_group.checkmarx-outbound-all.id}"
  ]

  listener {
    instance_port      = 443
    instance_protocol  = "https"
    lb_port            = 443
    lb_protocol        = "https"
    ssl_certificate_id = "${aws_acm_certificate.checkmarx-cert.id}"
  }

  health_check {
    healthy_threshold   = 2
    unhealthy_threshold = 2
    timeout             = 3
    target              = "HTTPS:443/"
    interval            = 30
  }

  instances                   = ["${aws_instance.checkmarx-private.id}"]
  cross_zone_load_balancing   = true
  idle_timeout                = 400
  connection_draining         = true
  connection_draining_timeout = 400

  tags = {
    Name = "checkmarx-elb"
  }
}

resource "aws_db_instance" "checkmarx" {
  db_subnet_group_name = "${aws_db_subnet_group.rds_subnet_group.name}"
  allocated_storage    = 100
  storage_type         = "gp2"
  engine               = "mysql"
  engine_version       = "5.7.26"
  instance_class       = "${var.rds_instance_type}"
  name                 = "checkmarx"
  username             = "checkmarx"
  password             = "${var.checkmarx_database_password}"
  skip_final_snapshot  = true
  port = 1433

  vpc_security_group_ids = [
    "${aws_security_group.mysql.id}"
  ]

  tags {
    name = "checkmarx-rds"
  }
}

// new subnet for rds instance
resource "aws_db_subnet_group" "rds_subnet_group" {
  name = "${var.vpc_name}-checkmarx-rds"

  subnet_ids = [
    "${var.private_subnet_cidrs-vpc}",
    "${var.rds_private_subnet}"
  ]
}


resource "aws_route53_zone" "db_internal" {
  name = "domain.db"
}

resource "aws_route53_zone" "domain-digital" {
  name = "domain-digital"
}

resource "aws_route53_record" "checkmarx-db" {
  zone_id = "${aws_route53_zone.db_internal.id}"
  name    = "checkmarx.domain.db"
  type    = "CNAME"
  ttl     = "300"
  records = ["${aws_db_instance.checkmarx.address}"]
}

resource "aws_acm_certificate" "checkmarx-cert" {
  domain_name       = "checkmarx.${var.domain_name}"
  validation_method = "DNS"
}

resource "aws_route53_record" "checkmarx" {
  zone_id = "${var.zone_id}"
  name    = "checkmarx.${var.domain_name}"
  type    = "CNAME"
  ttl     = "300"
  records = ["${aws_elb.checkmarx.dns_name}"]
}

resource "aws_route53_record" "cert_validation-checkmarx" {
  name = "${aws_acm_certificate.checkmarx-cert.domain_validation_options.0.resource_record_name}"
  type = "${aws_acm_certificate.checkmarx-cert.domain_validation_options.0.resource_record_type}"
  zone_id = "${var.zone_id}"
  records = ["${aws_acm_certificate.checkmarx-cert.domain_validation_options.0.resource_record_value}"]
  ttl = 60
}

resource "aws_acm_certificate_validation" "checkmarx-cert" {
  certificate_arn         = "${aws_acm_certificate.checkmarx-cert.arn}"
  validation_record_fqdns = ["${aws_route53_record.cert_validation-checkmarx.fqdn}"] // reference cert_validation
}
