output "state_infrastructure_outputs" {
  value = {
    for state, infrastructure in module.aws_human_gov_infrastructure :
    state => {
      dynamodb_table = infrastructure.state_dynamodb_table
      s3_bucket      = infrastructure.state_s3_bucket
      ec2_public_dns = infrastructure.state_ec2_public_dns
    }
  }
}

 