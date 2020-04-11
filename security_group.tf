resource "aws_security_group" "bastion-sg" {
  name   = "checkmarx-bastion-sg"
  vpc_id = "${var.vpc_name}"

  ingress { // sets incoming traffic ports
    from_port   = 22
    to_port     = 22
    protocol    = "TCP"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress { // sets outbound traffic
    from_port   = 0
    to_port     = 65535
    protocol    = "TCP"
    cidr_blocks = ["0.0.0.0/0"]
  }
} // end bastion sg

resource "aws_security_group" "ssh-in" {
  name   = "checkmarx-ssh-in"
  vpc_id = "${var.vpc_name}"

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "TCP"
    cidr_blocks = ["${aws_instance.bastion.private_ip}/32"]
  }

  egress {
    from_port   = 0
    to_port     = 65535
    protocol    = "TCP"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_security_group" "health-check-in" {
  name   = "checkmarx-health-check-in"
  vpc_id = "${var.vpc_name}"

  ingress {
    from_port       = 443
    to_port         = 443
    protocol        = "TCP"
    security_groups = ["${aws_security_group.checkmarx-alb-in.id}"]
  }
}

// load balancer security groups
resource "aws_security_group" "checkmarx-alb-in" {
  name   = "checkmarx-alb-in"
  vpc_id = "${var.vpc_name}"

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "TCP"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_security_group" "checkmarx-outbound-all" {
  name   = "checkmarx-outbound-all"
  vpc_id = "${var.vpc_name}"

  egress {
    from_port   = 0
    to_port     = 65535
    protocol    = "TCP"
    cidr_blocks = ["0.0.0.0/0"]
  }
}
// end of load balancer security groups

// RDS security groups
resource "aws_security_group" "mysql" {
  name   = "mysql"
  vpc_id = "${var.vpc_name}"

  ingress {
    from_port   = 1433
    to_port     = 1433
    protocol    = "TCP"
    cidr_blocks = ["0.0.0.0/0"]
  }
}
