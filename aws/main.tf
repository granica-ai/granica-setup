# Can we try this today?
# Bring up Cluster in a private network:
# Create an instance in default private subnet.
# Connect to that instance using "EC2 Instance Connect Endpoint"
# From that EC2 instance create admin server.
# From this admin server create Crunch
# As Chetan mentioned:
# All instances are running in private subnet, no public IP
# All instances have tags imds=secure Worst case hard code the tag name. Value can be input
# Ability to change mem allocated to pods from KRY
# Private dashboards...how do we do that?
# EKS 1.29

# data "aws_vpc" "default" {
#   # default = true
#   id = "vpc-0241943159d4073e8"
# }


# data "aws_subnet_ids" "private" {
#   vpc_id = data.aws_vpc.default.id

#   # Assuming private subnets are tagged as such; adjust tag as necessary
#   tags = {
#     "Tier" = "Private"
#   }
# }

# data "aws_subnet" "private_subnets" {
#   for_each = data.aws_subnet_ids.private.ids

#   id = each.value
# }

# output "default_vpc_id" {
#   value = data.aws_vpc.default.id
# }

# output "private_subnet_ids" {
#   value = data.aws_subnet.private_subnets[*].id
# }

# output "private_subnet_cidr_blocks" {
#   value = data.aws_subnet.private_subnets[*].cidr_block
# }

module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "5.7.1"

  name = "granica-vpc"
  cidr = "${var.vpc_cidr_prefix}.0.0/16"

  azs             = ["${var.aws_region}a", "${var.aws_region}b", "${var.aws_region}c"]
  private_subnets = ["${var.vpc_cidr_prefix}.0.0/20", "${var.vpc_cidr_prefix}.16.0/20", "${var.vpc_cidr_prefix}.32.0/20"]
  public_subnets  = ["${var.vpc_cidr_prefix}.48.0/20", "${var.vpc_cidr_prefix}.64.0/20", "${var.vpc_cidr_prefix}.80.0/20"]

  enable_nat_gateway      = true
  single_nat_gateway      = true
  one_nat_gateway_per_az  = false
  map_public_ip_on_launch = false

  public_subnet_tags = {
    "Name" = "granica-vpc-public-subnet"
  }

  private_subnet_tags = {
    "kubernetes.io/role/internal-elb" = "1"
    "Name"                            = "granica-vpc-private-subnet"
  }
}

locals {
  private_subnet_ids       = module.vpc.private_subnets
  target_private_subnet_id = local.private_subnet_ids[0]
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
  subnet_id          = local.target_private_subnet_id
  security_group_ids = [aws_security_group.ec2_instance_connect.id]
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
}

data "aws_ami" "al2023" {
  most_recent = true

  filter {
    name   = "name"
    values = ["al2023-ami-2023*-kernel-*-x86_64"]
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

data "aws_ami" "amazon_linux_2" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["amzn2-ami-hvm*"]
  }

  filter {
    name   = "architecture"
    values = ["x86_64"]
  }
}

resource "aws_instance" "admin_server" {
  depends_on = [
    aws_ec2_instance_connect_endpoint.main,
    module.vpc
  ]
  ami           = data.aws_ami.al2023.id
  instance_type = "t2.small"
  subnet_id     = local.target_private_subnet_id

  iam_instance_profile = aws_iam_instance_profile.admin.name

  vpc_security_group_ids = [aws_security_group.admin_server.id]

  associate_public_ip_address = false

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
  yum -y install jq git libxcrypt-compat cronie cronie-anacron wget
  # Check the exit code of the command
  if [ $? -eq 0 ]; then
    echo "Yum update and instal of dependencies succeeded"
    success=true
  else
    echo "Attempt $attempt_num failed. Sleeping for 5 seconds and trying again..."
    sleep 5
    ((attempt_num++))
  fi
done

echo "Place resource ids at /home/ec2-user/config.tfvars"
echo "vpc_id = \"${module.vpc.vpc_id}\"" > /home/ec2-user/config.tfvars
echo "private_subnet_ids = ${jsonencode(module.vpc.private_subnets)}" >> /home/ec2-user/config.tfvars
echo "public_subnet_ids = ${jsonencode(module.vpc.public_subnets)}" >> /home/ec2-user/config.tfvars
chown ec2-user:ec2-user /home/ec2-user/config.tfvars


max_attempts=5
attempt_num=1
success=false
while [ $success = false ] && [ $attempt_num -le $max_attempts ]; do
  echo "Trying download of Granica rpm"
  wget --directory-prefix=/home/ec2-user ${var.package_url}
  # yum -y install ${var.package_url}
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

sudo git clone https://github.com/ahmetb/kubectx /opt/kubectx
sudo ln -s /opt/kubectx/kubectx /usr/local/bin/kubectx
sudo ln -s /opt/kubectx/kubens /usr/local/bin/kubens

echo 'export PATH=~/.local/bin:$PATH' >> /home/ec2-user/.bash_profile && chown ec2-user /home/ec2-user/.bash_profile
su ec2-user -c 'source ~/.bash_profile && aws configure set region ${var.aws_region}'

mkdir -p /home/ec2-user/.project-n/aws/default/infrastructure
echo '{"default_platform":"aws"}' > /home/ec2-user/.project-n/config
chmod -R 755 /home/ec2-user/.project-n
chown -R ec2-user /home/ec2-user/.project-n
echo "Finish Granica user-data script"
EOF

  tags = {
    Name = "granica-admin-server"
    imds = "secure"
  }
}

output "admin_server_ec2_instance_connect_endpoint_connect_command" {
  value = "aws ec2-instance-connect ssh --instance-id ${aws_instance.admin_server.id} --connection-type eice --region ${var.aws_region}"
}
