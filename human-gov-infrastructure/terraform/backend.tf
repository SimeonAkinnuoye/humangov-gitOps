
terraform {
  backend "s3" {
    bucket         = "humangov-terraform-state-x123x"
    key            = "humangov-gitops/terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "humangov-terraform-lock"
    encrypt        = true
  }
}