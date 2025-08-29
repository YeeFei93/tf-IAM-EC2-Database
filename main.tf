locals {
  name_prefix = "yeefei"
}


resource "aws_iam_role" "role_example" {
  name = "${local.name_prefix}-role-example"


  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Sid    = ""
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      },
    ]
  })
}


data "aws_iam_policy_document" "policy_example" {
  statement {
    effect    = "Allow"
    actions   = ["ec2:Describe*"]
    resources = ["*"]
  }
  statement {
    effect    = "Allow"
    actions   = ["s3:ListBucket"]
    resources = ["*"]
  }
  statement {
    effect    = "Allow"
    actions   = [
      "dynamodb:ListTables",
      "dynamodb:Scan"
    ]
    resources = ["*"]
  }
  # Activity 2: Secrets Manager permissions for RDS
  # statement {
  #   effect    = "Allow"
  #   actions   = [
  #     "secretsmanager:GetSecretValue",
  #     "secretsmanager:DescribeSecret"
  #   ]
  #   resources = ["*"]
  # }
}


resource "aws_iam_policy" "policy_example" {
  name = "${local.name_prefix}-policy-example"

  ## Option 1: Attach data block policy document
  policy = data.aws_iam_policy_document.policy_example.json
}




resource "aws_iam_role_policy_attachment" "attach_example" {
  role       = aws_iam_role.role_example.name
  policy_arn = aws_iam_policy.policy_example.arn
}


resource "aws_iam_instance_profile" "profile_example" {
  name = "${local.name_prefix}-profile-example"
  role = aws_iam_role.role_example.name
}

# Data source to find the VPC with name pattern ce11-tf-vpc-*
data "aws_vpc" "shared_vpc" {
  filter {
    name   = "tag:Name"
    values = ["ce11-tf-vpc-*"]
  }
}

# Data source to find private subnets in the shared VPC for RDS
# data "aws_subnets" "private_subnets" {
#   filter {
#     name   = "vpc-id"
#     values = [data.aws_vpc.shared_vpc.id]
#   }
#   
#   filter {
#     name   = "tag:Name"
#     values = ["*private*"]
#   }
# }

# Data source to find public subnet in the shared VPC
data "aws_subnets" "public_subnets" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.shared_vpc.id]
  }
  
  filter {
    name   = "tag:Name"
    values = ["*public*"]
  }
}

# Get the latest Amazon Linux 2 AMI
data "aws_ami" "amazon_linux" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["amzn2-ami-hvm-*-x86_64-gp2"]
  }
}

# DynamoDB Table
resource "aws_dynamodb_table" "example_table" {
  name           = "${local.name_prefix}-dynamodb-table"
  billing_mode   = "PAY_PER_REQUEST"
  hash_key       = "id"

  attribute {
    name = "id"
    type = "S"
  }

  tags = {
    Name = "${local.name_prefix}-dynamodb-table"
  }
}

# EC2 Instance
resource "aws_instance" "example_instance" {
  ami                    = data.aws_ami.amazon_linux.id
  instance_type          = "t3.micro"
  subnet_id              = data.aws_subnets.public_subnets.ids[0]
  iam_instance_profile   = aws_iam_instance_profile.profile_example.name
  
  # Enable public IP for the instance
  associate_public_ip_address = true

  tags = {
    Name = "${local.name_prefix}-ec2-instance"
  }
}

# ========================================
# ACTIVITY 2 - RDS RESOURCES (COMMENTED)
# ========================================

# # Generate random password for RDS
# resource "random_password" "db_password" {
#   length  = 16
#   special = true
#   # Exclude characters that are not allowed in RDS passwords
#   override_special = "!#$%&*+-=?^_`{|}~"
# }

# # Store RDS credentials in AWS Secrets Manager
# resource "aws_secretsmanager_secret" "db_credentials" {
#   name = "${local.name_prefix}-rds-credentials"
#   description = "RDS database credentials"
# }

# resource "aws_secretsmanager_secret_version" "db_credentials" {
#   secret_id = aws_secretsmanager_secret.db_credentials.id
#   secret_string = jsonencode({
#     username = "admin"
#     password = random_password.db_password.result
#   })
# }

# # RDS Subnet Group
# resource "aws_db_subnet_group" "rds_subnet_group" {
#   name       = "${local.name_prefix}-rds-subnet-group"
#   subnet_ids = data.aws_subnets.private_subnets.ids

#   tags = {
#     Name = "${local.name_prefix}-rds-subnet-group"
#   }
# }

# # Security Group for RDS
# resource "aws_security_group" "rds_sg" {
#   name        = "${local.name_prefix}-rds-sg"
#   description = "Security group for RDS database"
#   vpc_id      = data.aws_vpc.shared_vpc.id

#   ingress {
#     from_port   = 3306
#     to_port     = 3306
#     protocol    = "tcp"
#     cidr_blocks = [data.aws_vpc.shared_vpc.cidr_block]
#   }

#   egress {
#     from_port   = 0
#     to_port     = 0
#     protocol    = "-1"
#     cidr_blocks = ["0.0.0.0/0"]
#   }

#   tags = {
#     Name = "${local.name_prefix}-rds-sg"
#   }
# }

# # RDS MySQL Instance
# resource "aws_db_instance" "mysql_db" {
#   identifier             = "${local.name_prefix}-mysql-db"
#   allocated_storage      = 20
#   max_allocated_storage  = 100
#   storage_type          = "gp2"
#   engine                = "mysql"
#   engine_version        = "8.0"
#   instance_class        = "db.t3.micro"
#   db_name               = "sampledb"
#   username              = "admin"
#   password              = random_password.db_password.result
#   parameter_group_name  = "default.mysql8.0"
#   skip_final_snapshot   = true
#   
#   vpc_security_group_ids = [aws_security_group.rds_sg.id]
#   db_subnet_group_name   = aws_db_subnet_group.rds_subnet_group.name
#   
#   backup_retention_period = 7
#   backup_window          = "03:00-04:00"
#   maintenance_window     = "sun:04:00-sun:05:00"

#   tags = {
#     Name = "${local.name_prefix}-mysql-db"
#   }
# }