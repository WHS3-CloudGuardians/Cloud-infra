resource "aws_main_route_table_association" "tfer--vpc-011560c021711bb7f" {
  route_table_id = "${data.terraform_remote_state.route_table.outputs.aws_route_table_tfer--rtb-093e8333f01736653_id}"
  vpc_id         = "${data.terraform_remote_state.vpc.outputs.aws_vpc_tfer--vpc-011560c021711bb7f_id}"
}

resource "aws_main_route_table_association" "tfer--vpc-0a9aecf63a7f6d99d" {
  route_table_id = "${data.terraform_remote_state.route_table.outputs.aws_route_table_tfer--rtb-07ed886e75fc6429c_id}"
  vpc_id         = "${data.terraform_remote_state.vpc.outputs.aws_vpc_tfer--vpc-0a9aecf63a7f6d99d_id}"
}
