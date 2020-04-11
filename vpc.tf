resource "aws_vpc" "checkmarx-vpc" {
  cidr_block           = "${var.vpc_cidr}"
  enable_dns_hostnames = true

  tags {
    Name = "${var.vpc_name}"
  }
}

resource "aws_instance" "bastion-checkmarx-vpc" {
  ami           = "${var.linux_base_ami_id}"
  instance_type = "${var.bastion_instance_type}"
  key_name      = "${var.key_name}"
  subnet_id     = "${aws_subnet.public.0.id}"
  vpc_security_group_ids = [
    "${aws_security_group.bastion-login.id}",
    "${aws_security_group.outbound-all.id}"
  ]

  tags {
    Name = "${var.vpc_name}-bastion"
  }
}

// security group start

resource "aws_security_group" "bastion-login" {
  name = "${var.vpc_name}-bastion-login"

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "TCP"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_security_group" "outbound-all" {
  name = "${var.vpc_name}-outbound-all"
  egress {
    from_port = 0
    to_port = 65535
    protocol = "TCP"
    cidr_blocks = ["0.0.0.0/0"]
  }
}
// security group end

resource "aws_key_pair" "vpc_provisioner_key" {
  key_name   = "${var.key_name}"
  public_key = "${var.vpc_public_key}"
}

// public subnet start

resource "aws_subnet" "public" {
  count                   = "${length(var.public_subnet_cidrs-vpc)}"
  vpc_id                  = "${aws_vpc.checkmarx-vpc.id}"
  cidr_block              = "${element(var.public_subnet_cidrs-vpc, count.index)}"
  map_public_ip_on_launch = true
  availability_zone       = "${element(var.vpc-availability-zones, count.index)}"

  tags {
    Name = "${var.vpc_name}-public-subnet"
  }
}

resource "aws_internet_gateway" "checkmarx-igw" {
  vpc_id = "${aws_vpc.checkmarx-vpc.id}"

  tags {
    Name = "${var.vpc_name}-igw"
  }
}

resource "aws_eip" "checkmarx-nat-eip" {
  vpc = true
  depends_on = ["aws_vpc.checkmarx-vpc"]
}

resource "aws_nat_gateway" "checkmarx-nat-gateway" {
  allocation_id = "${aws_eip.checkmarx-nat-eip.id}"
  subnet_id     = "${aws_subnet.public.0.id}"
}

// end public subnet

// private subnet start

resource "aws_subnet" "private" {
  count             = "${length(var.private_subnet_cidrs-vpc)}"
  vpc_id            = "${var.vpc_name}"
  cidr_block        = "${element(var.private_subnet_cidrs-vpc, count.index)}"
  availability_zone = "${element(var.vpc-availability-zones, count.index)}"

  tags {
    Name = "${var.vpc_name}-private-vpc-subnet-${count.index}"
  }
}
// end private subnet
// public subnet routing
resource "aws_route_table" "public" {
  vpc_id = "${var.vpc_name}"

  tags {
    Name = "${var.vpc_name}-public-route-table"
  }
}

resource "aws_route" "igw-route" {
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = "${aws_internet_gateway.checkmarx-igw.id}"
  route_table_id         = "${aws_route_table.public.id}"
}

resource "aws_route_table_association" "public" {
  count          = "${length(var.public_subnet_cidrs-vpc)}"
  subnet_id      = "${element(aws_subnet.public.*.id, count.index)}"
  route_table_id = "${aws_route_table.public.id}"
}

// end public subnet routing
// start private subnet routing

resource "aws_route_table" "private" {
  count  = "${length(var.private_subnet_cidrs-vpc)}"
  vpc_id = "${var.vpc_name}"
  tags {
    Name = "${var.vpc_name}-private-${count.index}-route-table"
  }
}

resource "aws_route" "nat_route" {
  count                  = "${length(var.private_subnet_cidrs-vpc)}"
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = "${aws_nat_gateway.checkmarx-nat-gateway.id}"
  route_table_id         = "${element(aws_route_table.private.*.id, count.index)}"
}

resource "aws_route_table_association" "private" {
  count          = "${length(var.private_subnet_cidrs-vpc)}"
  subnet_id      = "${element(aws_subnet.private.*.id, count.index)}"
  route_table_id = "${element(aws_route_table.private.*.id, count.index)}"
}
