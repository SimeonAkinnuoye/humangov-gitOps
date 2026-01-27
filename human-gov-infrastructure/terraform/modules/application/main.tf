# 1. Security Group (Needs VPC ID from Variable)
resource "aws_security_group" "state_ec2_sg" {
  name        = "humangov-${var.state_name}-ec2-sg"
  description = "Allow traffic for ${var.state_name}"
  vpc_id      = var.vpc_id  

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  
  tags = { Name = "humangov-${var.state_name}-ec2-sg" }
}

# 2. Key Pair 
resource "aws_key_pair" "humangov_key" {
  key_name   = "humangov-${var.state_name}-key"
  public_key = file("${path.module}/humangov10-ec2-key.pub")
}

# 3. EC2 Instance 
resource "aws_instance" "state_ec2" {
  ami           = "ami-068c0051b15cdb816" 
  instance_type = "t2.micro"
  
  key_name               = aws_key_pair.humangov_key.key_name
  subnet_id              = var.subnet_id  
  vpc_security_group_ids = [aws_security_group.state_ec2_sg.id]

  tags = { Name = "humangov-${var.state_name}-ec2" }
}

# 4. DynamoDB
resource "aws_dynamodb_table" "state_dynamodb" {
  name         = "humangov-${var.state_name}-dynamodb"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "id"
  attribute {
    name = "id"
    type = "S"
  }
  tags = { Name = "humangov-${var.state_name}-dynamodb" }
}

# 5. S3 Bucket
resource "random_string" "bucket_suffix" {
  length  = 4
  special = false
  upper   = false
}

resource "aws_s3_bucket" "state_s3" {
  bucket = "humangov-${var.state_name}-s3-${random_string.bucket_suffix.result}"
  tags = { Name = "humangov-${var.state_name}-s3" }
}