variable "stack_name" {
  type = string
  default = "terraform"
}

variable "b_nat_gateway" {
  default = "false"
}

data "aws_region" "current" {}

# "data" keyword allow you to pull existing resources from your AWS account
# In this case, we pull the list of availability zones from the current AWS region
data "aws_availability_zones" "available" {}

# Local values assign names to expressions so you can re-use them
# multiple times in the current module (here the number of AZs for the current region)
locals {
  nb_azs = length(data.aws_availability_zones.available.names)
}

# The "resource" keyword will create a new resource in our AWS account
resource "aws_vpc" "vpc" {
  cidr_block = "10.0.0.0/16"

  tags = {
    Name = "${var.stack_name}_vpc"
  }
}

resource "aws_internet_gateway" "internet_gateway" {
  vpc_id = aws_vpc.vpc.id

  tags = {
    Name = "${var.stack_name}_internet_gateway"
  }
}

// Public subnets
resource "aws_subnet" "public_subnets" {
  #The "count" parameter allows you to loop and create a resource a variable number of times
  # We create one subnet in each AZ for our current region. Since we are in eu-west-2,
  # this will effectively create 3 subnets, one in each of eu-west-2a, eu-west-2b, eu-west-2c.
  count             = local.nb_azs
  vpc_id            = aws_vpc.vpc.id
  # Note the use of the Terraform helper function "cidrsubnet" which calculates non-overlapping
  # CIDR blocks for each subnet
  cidr_block        = cidrsubnet(aws_vpc.vpc.cidr_block, 8, count.index)
  #We loop over the array of AZs initialised before
  availability_zone = data.aws_availability_zones.available.names[count.index]

  tags = {
    Name = "${var.stack_name}_public_subnet_${count.index + 1}"
  }
}

resource "aws_route_table" "public_route_table" {
  vpc_id = aws_vpc.vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.internet_gateway.id
  }

  tags = {
    Name = "${var.stack_name}_public_route_table"
  }
}

resource "aws_route_table_association" "public_rt_associations" {
  count          = local.nb_azs
  subnet_id      = aws_subnet.public_subnets.*.id[count.index]
  route_table_id = aws_route_table.public_route_table.id
}

// Private subnets
resource "aws_eip" "eips" {
  vpc     = true
  count   = var.b_nat_gateway == true ? 1 : 0

  tags = {
    Name = "${var.stack_name}_eips"
  }
}

resource "aws_nat_gateway" "nat_gateway" {
  count   = var.b_nat_gateway == true ? 1 : 0
  allocation_id= aws_eip.eips[count.index]
#  allocation_id = aws_eip.eips.id
  subnet_id     = aws_subnet.public_subnets.*.id[0]

#  depends_on = ["aws_internet_gateway.internet_gateway"]

  tags = {
    Name = "${var.stack_name}_nat_getway"
  }
}

resource "aws_subnet" "private_subnets" {
  count             = local.nb_azs
  vpc_id            = aws_vpc.vpc.id
  cidr_block        = cidrsubnet(aws_vpc.vpc.cidr_block, 8, count.index + local.nb_azs)
  availability_zone = data.aws_availability_zones.available.names[count.index]

  tags = {
    Name = "${var.stack_name}_private_subnet_${count.index + 1}"
  }
}

resource "aws_route_table" "private_route_table" {
  vpc_id = aws_vpc.vpc.id

  tags = {
    Name = "${var.stack_name}_private_route_table"
  }
}

resource "aws_route" "route" {
  count                     = var.b_nat_gateway == true ? 1 : 0
  route_table_id            = aws_route_table.private_route_table.id
  destination_cidr_block    = "0.0.0.0/0"
#  depends_on                = ["aws_route_table.private_route-table"]
#  nat_gateway_id            = aws_nat_gateway.nat_gateway.id
  nat_gateway_id            = aws_nat_gateway.nat_gateway[count.index]
}

resource "aws_route_table_association" "private_rt_associations" {
  count          = local.nb_azs
  subnet_id      = aws_subnet.private_subnets.*.id[count.index]
  route_table_id = aws_route_table.private_route_table.id
}
