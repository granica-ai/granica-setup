# Add this data source to get all AZs in the region
data "aws_availability_zones" "available" {
  state = "available"
}

module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "5.7.1"

  name = "granica-vpc-${var.server_name}"
  cidr = var.vpc_cidr
  azs  = data.aws_availability_zones.available.names

  # Derive private subnets
  # cidrsubnet(base_cidr, new_bits, net_num)
  # /16 with 4 new bits creates /20 subnets. net_num indexes which /20 segment is chosen.
  private_subnets = [
    for i in range(length(data.aws_availability_zones.available.names)) :
    cidrsubnet(var.vpc_cidr, 4, i)
  ]

  # Derive public subnets (starting after the private ones to avoid overlap)
  public_subnets = [
    for i in range(length(data.aws_availability_zones.available.names)) :
    cidrsubnet(var.vpc_cidr, 4, i + length(data.aws_availability_zones.available.names))
  ]

  enable_nat_gateway      = true
  single_nat_gateway      = true
  one_nat_gateway_per_az  = false
  map_public_ip_on_launch = false

  public_subnet_tags = {
    "Name" = "granica-vpc-${var.server_name}-public-subnet"
  }

  private_subnet_tags = {
    "kubernetes.io/role/internal-elb" = "1"
    "Name"                            = "granica-vpc-${var.server_name}-private-subnet"
  }
}

locals {
  target_subnet_id = var.public_ip_enabled ? module.vpc.public_subnets[0] : module.vpc.private_subnets[0]
}

resource "aws_security_group" "ec2_instance_connect" {
  vpc_id = module.vpc.vpc_id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"] // TODO: lock this down to the VPC CIDR
  }
}

resource "aws_ec2_instance_connect_endpoint" "main" {
  # for_each = {
  #   for subnet_id in local.private_subnet_ids : subnet_id => subnet_id
  # }
  # https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/connect-using-eice.html#ec2-instance-connect-endpoint-limitations
  # this allows the instance we're connecting to be in the different VPC than the ec2 instance connect endpoint
  preserve_client_ip = false
  subnet_id          = local.target_subnet_id
  security_group_ids = [aws_security_group.ec2_instance_connect.id]
}

# Add an S3 VPC endpoint
resource "aws_vpc_endpoint" "s3" {
  vpc_id            = module.vpc.vpc_id
  service_name      = "com.amazonaws.${var.aws_region}.s3"
  vpc_endpoint_type = "Gateway"

  route_table_ids = concat(
    module.vpc.public_route_table_ids,
    module.vpc.private_route_table_ids
  )
  tags = {
    Name = "granica-vpc-s3-endpoint"
  }
}

resource "aws_security_group" "admin_server" {
  vpc_id = module.vpc.vpc_id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port       = 0
    to_port         = 0
    protocol        = "-1"
    security_groups = [aws_security_group.ec2_instance_connect.id]
  }

  ingress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = [module.vpc.vpc_cidr_block]
  }


  dynamic "ingress" {
    for_each = var.public_ip_enabled ? [1] : []
    content {
      from_port   = 22
      to_port     = 22
      protocol    = "tcp"
      cidr_blocks = ["0.0.0.0/0"]
    }
  }
}

# TODO: Specify the exact AMI to use for now, as the latest AMI (al2023-ami-2023.6.20241121.0-kernel-6.1-x86_64) is not working for python ensurepip
data "aws_ami" "al2023" {
  most_recent = true

  filter {
    name = "name"
    #values = ["al2023-ami-2023*-kernel-*-x86_64"]
    values = ["al2023-ami-2023.6.20241121.0-kernel-6.1-x86_64"]
  }

  filter {
    name   = "owner-alias"
    values = ["amazon"] # The official owner of Amazon Linux AMIs
  }

  filter {
    name   = "state"
    values = ["available"]
  }
}

resource "aws_instance" "admin_server" {
  depends_on = [
    aws_ec2_instance_connect_endpoint.main,
    module.vpc
  ]
  ami           = data.aws_ami.al2023.id
  instance_type = "t2.small"
  subnet_id     = local.target_subnet_id

  iam_instance_profile = aws_iam_instance_profile.admin.name

  vpc_security_group_ids = [aws_security_group.admin_server.id]

  associate_public_ip_address = var.public_ip_enabled

  user_data = <<EOF
#!/bin/bash
echo "Enter Granica user-data script"

echo "Checking if Google DNS is reachable..."
until ping -c 1 8.8.8.8; do
    echo "Waiting for 8.8.8.8 to become reachable..."
    sleep 1
done
echo "8.8.8.8 is reachable!"

while [ -f /var/run/yum.pid ] || pgrep -x yum > /dev/null; do
  echo "Waiting for other yum operations to complete..."
  sleep 5  # waits 30 seconds before checking again
done

# Install pip for root and ec2-user
cd /tmp && curl -O https://bootstrap.pypa.io/get-pip.py && chmod +x get-pip.py && python3 /tmp/get-pip.py
su ec2-user -c 'python3 /tmp/get-pip.py'

max_attempts=5
attempt_num=1
success=false
while [ $success = false ] && [ $attempt_num -le $max_attempts ]; do
  echo "Trying yum install of dependencies"
  yum update -y
  yum -y install jq git libxcrypt-compat cronie cronie-anacron wget openssl-devel readline-devel ncurses-c++-libs ncurses-devel sqlite sqlite-devel tk tk-devel gcc glib2-devel glibc-devel glibc-headers
  # Check the exit code of the command
  if [ $? -eq 0 ]; then
    echo "Yum update and install of dependencies succeeded"
    success=true
  else
    echo "Attempt $attempt_num failed. Sleeping for 5 seconds and trying again..."
    sleep 5
    ((attempt_num++))
  fi
done

echo "Place resource ids at /home/ec2-user/config.tfvars"
echo "vpc_id             = \"${module.vpc.vpc_id}\"" > /home/ec2-user/config.tfvars
echo 'private_subnet_ids = ${jsonencode(module.vpc.private_subnets)}' >> /home/ec2-user/config.tfvars
echo 'public_subnet_ids  = ${jsonencode(module.vpc.public_subnets)}' >> /home/ec2-user/config.tfvars
echo 'subnet_az_ids      = ${jsonencode(data.aws_availability_zones.available.zone_ids)}' >> /home/ec2-user/config.tfvars
echo 'multi_az           = true' >> /home/ec2-user/config.tfvars
chown ec2-user:ec2-user /home/ec2-user/config.tfvars

max_attempts=5
attempt_num=1
success=false
while [ $success = false ] && [ $attempt_num -le $max_attempts ]; do
  echo "Trying download of Granica rpm"
  wget --directory-prefix=/home/ec2-user ${var.package_url}
  yum -y install ${var.package_url}
  # Check the exit code of the command
  if [ $? -eq 0 ]; then
    echo "Yum install succeeded"
    success=true
  else
    echo "Attempt $attempt_num failed. Sleeping for 5 seconds and trying again..."
    sleep 5
    ((attempt_num++))
  fi
done

echo 'export PATH=~/.local/bin:$PATH' >> /home/ec2-user/.bash_profile && chown ec2-user /home/ec2-user/.bash_profile
su ec2-user -c 'source ~/.bash_profile && aws configure set region ${var.aws_region}'

mkdir -p /home/ec2-user/.project-n/aws/default/infrastructure
echo '{"default_platform":"aws"}' > /home/ec2-user/.project-n/config
chmod -R 755 /home/ec2-user/.project-n
chown -R ec2-user /home/ec2-user/.project-n
echo "Finish Granica user-data script"
EOF

  tags = {
    Name = "granica-admin-server-${var.server_name}"
    imds = "secure"
  }
}

output "admin_server_ec2_instance_connect_endpoint_connect_command" {
  value = "aws ec2-instance-connect ssh --instance-id ${aws_instance.admin_server.id} --connection-type eice --region ${var.aws_region}"
}
