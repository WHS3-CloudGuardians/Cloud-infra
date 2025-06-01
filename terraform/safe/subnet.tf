resource "aws_subnet" "tfer--subnet-00bc8b30808787684" {
  assign_ipv6_address_on_creation                = "false"
  cidr_block                                     = "10.0.11.0/24"
  enable_dns64                                   = "false"
  enable_resource_name_dns_a_record_on_launch    = "false"
  enable_resource_name_dns_aaaa_record_on_launch = "false"
  ipv6_native                                    = "false"
  map_public_ip_on_launch                        = "true"
  private_dns_hostname_type_on_launch            = "ip-name"

  tags = {
    Name = "safe-subnet-web-01"
  }

  tags_all = {
    Name = "safe-subnet-web-01"
  }

  vpc_id = "${data.terraform_remote_state.vpc.outputs.aws_vpc_tfer--vpc-0a9aecf63a7f6d99d_id}"
}

resource "aws_subnet" "tfer--subnet-019456250fd652143" {
  assign_ipv6_address_on_creation                = "false"
  cidr_block                                     = "10.0.31.0/24"
  enable_dns64                                   = "false"
  enable_resource_name_dns_a_record_on_launch    = "false"
  enable_resource_name_dns_aaaa_record_on_launch = "false"
  ipv6_native                                    = "false"
  map_public_ip_on_launch                        = "false"
  private_dns_hostname_type_on_launch            = "ip-name"

  tags = {
    Name = "safe-subnet-db-01"
  }

  tags_all = {
    Name = "safe-subnet-db-01"
  }

  vpc_id = "${data.terraform_remote_state.vpc.outputs.aws_vpc_tfer--vpc-0a9aecf63a7f6d99d_id}"
}

resource "aws_subnet" "tfer--subnet-020cd4075bc3fa7c7" {
  assign_ipv6_address_on_creation                = "false"
  cidr_block                                     = "172.31.0.0/25"
  enable_dns64                                   = "false"
  enable_resource_name_dns_a_record_on_launch    = "false"
  enable_resource_name_dns_aaaa_record_on_launch = "false"
  ipv6_native                                    = "false"
  map_public_ip_on_launch                        = "false"
  private_dns_hostname_type_on_launch            = "ip-name"

  tags = {
    Name = "safe-vpc-app-subnet-2a"
  }

  tags_all = {
    Name = "safe-vpc-app-subnet-2a"
  }

  vpc_id = "${data.terraform_remote_state.vpc.outputs.aws_vpc_tfer--vpc-011560c021711bb7f_id}"
}

resource "aws_subnet" "tfer--subnet-0236bb1ee7936c687" {
  assign_ipv6_address_on_creation                = "false"
  cidr_block                                     = "10.0.2.0/24"
  enable_dns64                                   = "false"
  enable_resource_name_dns_a_record_on_launch    = "false"
  enable_resource_name_dns_aaaa_record_on_launch = "false"
  ipv6_native                                    = "false"
  map_public_ip_on_launch                        = "false"
  private_dns_hostname_type_on_launch            = "ip-name"

  tags = {
    Name = "safe-subnet-public-02"
  }

  tags_all = {
    Name = "safe-subnet-public-02"
  }

  vpc_id = "${data.terraform_remote_state.vpc.outputs.aws_vpc_tfer--vpc-0a9aecf63a7f6d99d_id}"
}

resource "aws_subnet" "tfer--subnet-03fa150113938c7bc" {
  assign_ipv6_address_on_creation                = "false"
  cidr_block                                     = "10.0.32.0/24"
  enable_dns64                                   = "false"
  enable_resource_name_dns_a_record_on_launch    = "false"
  enable_resource_name_dns_aaaa_record_on_launch = "false"
  ipv6_native                                    = "false"
  map_public_ip_on_launch                        = "false"
  private_dns_hostname_type_on_launch            = "ip-name"

  tags = {
    Name = "safe-subnet-db-02"
  }

  tags_all = {
    Name = "safe-subnet-db-02"
  }

  vpc_id = "${data.terraform_remote_state.vpc.outputs.aws_vpc_tfer--vpc-0a9aecf63a7f6d99d_id}"
}

resource "aws_subnet" "tfer--subnet-054d8670936fc772c" {
  assign_ipv6_address_on_creation                = "false"
  cidr_block                                     = "10.0.12.0/24"
  enable_dns64                                   = "false"
  enable_resource_name_dns_a_record_on_launch    = "false"
  enable_resource_name_dns_aaaa_record_on_launch = "false"
  ipv6_native                                    = "false"
  map_public_ip_on_launch                        = "false"
  private_dns_hostname_type_on_launch            = "ip-name"

  tags = {
    Name = "safe-subnet-web-02"
  }

  tags_all = {
    Name = "safe-subnet-web-02"
  }

  vpc_id = "${data.terraform_remote_state.vpc.outputs.aws_vpc_tfer--vpc-0a9aecf63a7f6d99d_id}"
}

resource "aws_subnet" "tfer--subnet-070505871848b1dd7" {
  assign_ipv6_address_on_creation                = "false"
  cidr_block                                     = "10.0.22.0/24"
  enable_dns64                                   = "false"
  enable_resource_name_dns_a_record_on_launch    = "false"
  enable_resource_name_dns_aaaa_record_on_launch = "false"
  ipv6_native                                    = "false"
  map_public_ip_on_launch                        = "false"
  private_dns_hostname_type_on_launch            = "ip-name"

  tags = {
    Name = "safe-subnet-app-02"
  }

  tags_all = {
    Name = "safe-subnet-app-02"
  }

  vpc_id = "${data.terraform_remote_state.vpc.outputs.aws_vpc_tfer--vpc-0a9aecf63a7f6d99d_id}"
}

resource "aws_subnet" "tfer--subnet-074be48a9adc00b66" {
  assign_ipv6_address_on_creation                = "false"
  cidr_block                                     = "10.0.1.0/24"
  enable_dns64                                   = "false"
  enable_resource_name_dns_a_record_on_launch    = "false"
  enable_resource_name_dns_aaaa_record_on_launch = "false"
  ipv6_native                                    = "false"
  map_public_ip_on_launch                        = "false"
  private_dns_hostname_type_on_launch            = "ip-name"

  tags = {
    Name = "safe-subnet-public-01"
  }

  tags_all = {
    Name = "safe-subnet-public-01"
  }

  vpc_id = "${data.terraform_remote_state.vpc.outputs.aws_vpc_tfer--vpc-0a9aecf63a7f6d99d_id}"
}

resource "aws_subnet" "tfer--subnet-07b4751c75a5a3309" {
  assign_ipv6_address_on_creation                = "false"
  cidr_block                                     = "172.31.11.0/24"
  enable_dns64                                   = "false"
  enable_resource_name_dns_a_record_on_launch    = "false"
  enable_resource_name_dns_aaaa_record_on_launch = "false"
  ipv6_native                                    = "false"
  map_public_ip_on_launch                        = "false"
  private_dns_hostname_type_on_launch            = "ip-name"

  tags = {
    Name = "safe-rds-2a"
  }

  tags_all = {
    Name = "safe-rds-2a"
  }

  vpc_id = "${data.terraform_remote_state.vpc.outputs.aws_vpc_tfer--vpc-011560c021711bb7f_id}"
}

resource "aws_subnet" "tfer--subnet-07da39db7798452a3" {
  assign_ipv6_address_on_creation                = "false"
  cidr_block                                     = "172.31.1.0/24"
  enable_dns64                                   = "false"
  enable_resource_name_dns_a_record_on_launch    = "false"
  enable_resource_name_dns_aaaa_record_on_launch = "false"
  ipv6_native                                    = "false"
  map_public_ip_on_launch                        = "false"
  private_dns_hostname_type_on_launch            = "ip-name"

  tags = {
    Name = "safe-vpc-web-subnet-2a"
  }

  tags_all = {
    Name = "safe-vpc-web-subnet-2a"
  }

  vpc_id = "${data.terraform_remote_state.vpc.outputs.aws_vpc_tfer--vpc-011560c021711bb7f_id}"
}

resource "aws_subnet" "tfer--subnet-081585b9e7f7b9e7b" {
  assign_ipv6_address_on_creation                = "false"
  cidr_block                                     = "10.0.21.0/24"

  enable_resource_name_dns_a_record_on_launch    = "false"
  enable_resource_name_dns_aaaa_record_on_launch = "false"
  ipv6_native                                    = "false"
  map_public_ip_on_launch                        = "false"
  private_dns_hostname_type_on_launch            = "ip-name"

  tags = {
    Name = "safe-subnet-app-01"
  }

  tags_all = {
    Name = "safe-subnet-app-01"
  }

  vpc_id = "${data.terraform_remote_state.vpc.outputs.aws_vpc_tfer--vpc-0a9aecf63a7f6d99d_id}"
}

resource "aws_subnet" "tfer--subnet-09f651da01a48af1a" {
  assign_ipv6_address_on_creation                = "false"
  cidr_block                                     = "172.31.0.128/25"
  enable_dns64                                   = "false"
  enable_resource_name_dns_a_record_on_launch    = "false"
  enable_resource_name_dns_aaaa_record_on_launch = "false"
  ipv6_native                                    = "false"
  map_public_ip_on_launch                        = "false"
  private_dns_hostname_type_on_launch            = "ip-name"

  tags = {
    Name = "safe-rds-2c"
  }

  tags_all = {
    Name = "safe-rds-2c"
  }

  vpc_id = "${data.terraform_remote_state.vpc.outputs.aws_vpc_tfer--vpc-011560c021711bb7f_id}"
}

resource "aws_subnet" "tfer--subnet-0e2518770bc1923dc" {
  assign_ipv6_address_on_creation                = "false"
  cidr_block                                     = "172.31.12.0/24"
  enable_dns64                                   = "false"
  enable_resource_name_dns_a_record_on_launch    = "false"
  enable_resource_name_dns_aaaa_record_on_launch = "false"
  ipv6_native                                    = "false"
  map_public_ip_on_launch                        = "false"
  private_dns_hostname_type_on_launch            = "ip-name"

  tags = {
    Name = "safe-vpc-app-subnet-2c"
  }

  tags_all = {
    Name = "safe-vpc-app-subnet-2c"
  }

  vpc_id = "${data.terraform_remote_state.vpc.outputs.aws_vpc_tfer--vpc-011560c021711bb7f_id}"
}

resource "aws_subnet" "tfer--subnet-0f77e80199d15780b" {
  assign_ipv6_address_on_creation                = "false"
  cidr_block                                     = "172.31.2.0/24"
  enable_dns64                                   = "false"
  enable_resource_name_dns_a_record_on_launch    = "false"
  enable_resource_name_dns_aaaa_record_on_launch = "false"
  ipv6_native                                    = "false"
  map_public_ip_on_launch                        = "false"
  private_dns_hostname_type_on_launch            = "ip-name"

  tags = {
    Name = "safe-vpc-web-subnet-2c"
  }

  tags_all = {
    Name = "safe-vpc-web-subnet-2c"
  }

  vpc_id = "${data.terraform_remote_state.vpc.outputs.aws_vpc_tfer--vpc-011560c021711bb7f_id}"
}
