resource "aws_route_table" "tfer--rtb-055a01e5c58c1d2ff" {
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = "igw-0bac91e2fa59443d6"
  }

  tags = {
    Name = "safe-vpc-main-public"
  }

  tags_all = {
    Name = "safe-vpc-main-public"
  }

  vpc_id = "${data.terraform_remote_state.vpc.outputs.aws_vpc_tfer--vpc-0a9aecf63a7f6d99d_id}"
}

resource "aws_route_table" "tfer--rtb-07ed886e75fc6429c" {
  tags = {
    Name = "safe-vpc-main-default"
  }

  tags_all = {
    Name = "safe-vpc-main-default"
  }

  vpc_id = "${data.terraform_remote_state.vpc.outputs.aws_vpc_tfer--vpc-0a9aecf63a7f6d99d_id}"
}

resource "aws_route_table" "tfer--rtb-093e8333f01736653" {
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = "igw-0b2154f1c4ab7e6f9"
  }

  tags = {
    Name = "-"
  }

  tags_all = {
    Name = "-"
  }

  vpc_id = "${data.terraform_remote_state.vpc.outputs.aws_vpc_tfer--vpc-011560c021711bb7f_id}"
}

resource "aws_route_table" "tfer--rtb-0c0a4965a97188ca7" {
  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = "nat-0c22ab4d33c206e0f"
  }

  tags = {
    Name = "safe-vpc-main-private"
  }

  tags_all = {
    Name = "safe-vpc-main-private"
  }

  vpc_id = "${data.terraform_remote_state.vpc.outputs.aws_vpc_tfer--vpc-0a9aecf63a7f6d99d_id}"
}

resource "aws_route_table_association" "websubnet_association" {
  subnet_id      = aws_subnet.tfer--subnet-00bc8b30808787684.id
  route_table_id = aws_route_table.tfer--rtb-055a01e5c58c1d2ff.id
}
