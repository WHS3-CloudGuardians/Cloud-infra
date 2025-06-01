resource "aws_vpc" "tfer--vpc-011560c021711bb7f" {
  assign_generated_ipv6_cidr_block     = "false"
  cidr_block                           = "172.31.0.0/16"
  enable_classiclink                   = "false"
  enable_classiclink_dns_support       = "false"
  enable_dns_hostnames                 = "true"
  enable_dns_support                   = "true"
  enable_network_address_usage_metrics = "false"
  instance_tenancy                     = "default"

  tags = {
    Name = "safe-vpc"
  }

  tags_all = {
    Name = "safe-vpc"
  }
}

resource "aws_vpc" "tfer--vpc-0a9aecf63a7f6d99d" {
  assign_generated_ipv6_cidr_block     = "false"
  cidr_block                           = "10.0.0.0/16"
  enable_classiclink                   = "false"
  enable_classiclink_dns_support       = "false"
  enable_dns_hostnames                 = "true"
  enable_dns_support                   = "true"
  enable_network_address_usage_metrics = "false"

  instance_tenancy                     = "default"


  tags = {
    Name = "safe-vpc-main"
  }

  tags_all = {
    Name = "safe-vpc-main"
  }
}
