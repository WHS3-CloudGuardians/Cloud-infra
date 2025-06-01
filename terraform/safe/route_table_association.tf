resource "aws_route_table_association" "tfer--subnet-00bc8b30808787684" {
  route_table_id = "${data.terraform_remote_state.route_table.outputs.aws_route_table_tfer--rtb-0c0a4965a97188ca7_id}"
  subnet_id      = "${data.terraform_remote_state.subnet.outputs.aws_subnet_tfer--subnet-00bc8b30808787684_id}"
}

resource "aws_route_table_association" "tfer--subnet-019456250fd652143" {
  route_table_id = "${data.terraform_remote_state.route_table.outputs.aws_route_table_tfer--rtb-0c0a4965a97188ca7_id}"
  subnet_id      = "${data.terraform_remote_state.subnet.outputs.aws_subnet_tfer--subnet-019456250fd652143_id}"
}

resource "aws_route_table_association" "tfer--subnet-0236bb1ee7936c687" {
  route_table_id = "${data.terraform_remote_state.route_table.outputs.aws_route_table_tfer--rtb-055a01e5c58c1d2ff_id}"
  subnet_id      = "${data.terraform_remote_state.subnet.outputs.aws_subnet_tfer--subnet-0236bb1ee7936c687_id}"
}

resource "aws_route_table_association" "tfer--subnet-03fa150113938c7bc" {
  route_table_id = "${data.terraform_remote_state.route_table.outputs.aws_route_table_tfer--rtb-0c0a4965a97188ca7_id}"
  subnet_id      = "${data.terraform_remote_state.subnet.outputs.aws_subnet_tfer--subnet-03fa150113938c7bc_id}"
}

resource "aws_route_table_association" "tfer--subnet-054d8670936fc772c" {
  route_table_id = "${data.terraform_remote_state.route_table.outputs.aws_route_table_tfer--rtb-0c0a4965a97188ca7_id}"
  subnet_id      = "${data.terraform_remote_state.subnet.outputs.aws_subnet_tfer--subnet-054d8670936fc772c_id}"
}

resource "aws_route_table_association" "tfer--subnet-070505871848b1dd7" {
  route_table_id = "${data.terraform_remote_state.route_table.outputs.aws_route_table_tfer--rtb-0c0a4965a97188ca7_id}"
  subnet_id      = "${data.terraform_remote_state.subnet.outputs.aws_subnet_tfer--subnet-070505871848b1dd7_id}"
}

resource "aws_route_table_association" "tfer--subnet-074be48a9adc00b66" {
  route_table_id = "${data.terraform_remote_state.route_table.outputs.aws_route_table_tfer--rtb-055a01e5c58c1d2ff_id}"
  subnet_id      = "${data.terraform_remote_state.subnet.outputs.aws_subnet_tfer--subnet-074be48a9adc00b66_id}"
}

resource "aws_route_table_association" "tfer--subnet-081585b9e7f7b9e7b" {
  route_table_id = "${data.terraform_remote_state.route_table.outputs.aws_route_table_tfer--rtb-0c0a4965a97188ca7_id}"
  subnet_id      = "${data.terraform_remote_state.subnet.outputs.aws_subnet_tfer--subnet-081585b9e7f7b9e7b_id}"
}
