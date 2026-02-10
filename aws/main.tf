# Add this data source to get all AZs in the region
data "aws_availability_zones" "available" {
  state = "available"
}

# Optional: existing VPC and route tables when existing_vpc_id is set
data "aws_vpc" "existing" {
  count = length(var.existing_vpc_id) > 0 ? 1 : 0
  id    = var.existing_vpc_id
}

data "aws_route_tables" "existing" {
  count  = length(var.existing_vpc_id) > 0 ? 1 : 0
  vpc_id = var.existing_vpc_id
}

module "vpc" {
  count  = length(var.existing_vpc_id) > 0 ? 0 : 1
  source = "terraform-aws-modules/vpc/aws"
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
  use_existing_vpc         = length(var.existing_vpc_id) > 0
  create_instance_connect  = length(var.existing_eice_security_group_id) == 0
  vpc_id                   = local.use_existing_vpc ? var.existing_vpc_id : module.vpc[0].vpc_id
  vpc_cidr_block           = local.use_existing_vpc ? data.aws_vpc.existing[0].cidr_block : module.vpc[0].vpc_cidr_block
  private_subnet_ids        = local.use_existing_vpc ? var.existing_private_subnet_ids : module.vpc[0].private_subnets
  public_subnet_ids         = local.use_existing_vpc ? var.existing_public_subnet_ids : module.vpc[0].public_subnets
  route_table_ids           = local.use_existing_vpc ? data.aws_route_tables.existing[0].ids : concat(module.vpc[0].public_route_table_ids, module.vpc[0].private_route_table_ids)
  target_subnet_id          = var.public_ip_enabled ? local.public_subnet_ids[0] : local.private_subnet_ids[0]
  create_s3_vpc_endpoint    = coalesce(var.create_s3_vpc_endpoint, !local.use_existing_vpc)
}

resource "aws_security_group" "ec2_instance_connect" {
  count  = local.create_instance_connect ? 1 : 0
  vpc_id = local.vpc_id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"] // TODO: lock this down to the VPC CIDR
  }
}

resource "aws_ec2_instance_connect_endpoint" "main" {
  count = local.create_instance_connect ? 1 : 0
  # https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/connect-using-eice.html#ec2-instance-connect-endpoint-limitations
  preserve_client_ip = false
  subnet_id          = local.target_subnet_id
  security_group_ids = [aws_security_group.ec2_instance_connect[0].id]
}

# S3 Gateway VPC endpoint; skip when VPC already has one (avoids RouteAlreadyExists) or create_s3_vpc_endpoint = false
resource "aws_vpc_endpoint" "s3" {
  count = local.create_s3_vpc_endpoint ? 1 : 0

  vpc_id            = local.vpc_id
  service_name      = "com.amazonaws.${var.aws_region}.s3"
  vpc_endpoint_type = "Gateway"

  route_table_ids = local.route_table_ids
  tags = {
    Name = "granica-vpc-s3-endpoint"
  }
}

resource "aws_security_group" "admin_server" {
  vpc_id = local.vpc_id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  dynamic "ingress" {
    for_each = local.create_instance_connect ? [1] : []
    content {
      from_port       = 0
      to_port         = 0
      protocol        = "-1"
      security_groups = [aws_security_group.ec2_instance_connect[0].id]
    }
  }

  dynamic "ingress" {
    for_each = local.create_instance_connect ? [] : [1]
    content {
      from_port       = 0
      to_port         = 0
      protocol        = "-1"
      security_groups = [var.existing_eice_security_group_id]
    }
  }

  ingress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = [local.vpc_cidr_block]
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
    values = ["al2023-ami-2023*"]
  }

  filter {
    name   = "owner-alias"
    values = ["amazon"] # The official owner of Amazon Linux AMIs
  }

  filter {
    name   = "state"
    values = ["available"]
  }

  filter {
    name   = "architecture"
    values = ["x86_64"]
  }
}

resource "aws_instance" "admin_server" {
  # Only wait for EIC/S3 endpoint when we create them; no blocker when skipped
  depends_on = [
    aws_ec2_instance_connect_endpoint.main,
    aws_vpc_endpoint.s3
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

if [ "$success" = false ]; then
  echo "ERROR: Failed to install dependencies after $max_attempts attempts"
fi

# Enable and start cron service
echo "Enabling and starting cron service..."
systemctl enable crond
systemctl start crond
if systemctl is-active --quiet crond; then
  echo "Cron service started successfully"
else
  echo "ERROR: Failed to start cron service"
fi

echo "Place resource ids at /home/ec2-user/config.tfvars"
echo "vpc_id             = \"${local.vpc_id}\"" > /home/ec2-user/config.tfvars
echo 'private_subnet_ids = ${jsonencode(local.private_subnet_ids)}' >> /home/ec2-user/config.tfvars
echo 'public_subnet_ids  = ${jsonencode(local.public_subnet_ids)}' >> /home/ec2-user/config.tfvars
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

if [ "$success" = false ]; then
  echo "ERROR: Failed to install Granica package after $max_attempts attempts"
fi

# Verify cron is still running after RPM installation
echo "Verifying cron service status after RPM installation..."
if systemctl is-active --quiet crond; then
  echo "VERIFICATION: Cron service is running properly"
else
  echo "ERROR: Cron service is not running, attempting to restart..."
  systemctl restart crond
  if systemctl is-active --quiet crond; then
    echo "RECOVERY: Cron service restarted successfully"
  else
    echo "CRITICAL ERROR: Failed to restart cron service"
  fi
fi

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
