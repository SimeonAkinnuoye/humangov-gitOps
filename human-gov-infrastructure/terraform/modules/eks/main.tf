data "aws_caller_identity" "current" {}

module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 20.0"

  cluster_name    = "humangov-cluster" 
  cluster_version = "1.29"             

  # Networking
  vpc_id                   = var.vpc_id
  subnet_ids               = var.subnet_ids
  control_plane_subnet_ids = var.subnet_ids

  # Security: Allow you to access it from the internet (public endpoint)
  cluster_endpoint_public_access = true


  # Grant Admin permissions to the user running Terraform
  enable_cluster_creator_admin_permissions = true

   /* access_entries = {
    ci_cd_pipeline = {
      # Constructs ARN using the Account ID data source
      principal_arn = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/humangov-codebuild-role"

      policy_associations = {
        admin = {
          policy_arn = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"
          access_scope = { type = "cluster" }
        }
      }
    }
  } */

 
  # Node Groups (The "t3.medium" workers)
  eks_managed_node_groups = {
    standard_workers = {      # Matches your --nodegroup-name
      min_size     = 1
      max_size     = 2
      desired_size = 2             # Matches your --nodes 1

      instance_types = ["t3.medium"] # Matches your --node-type
      capacity_type  = "ON_DEMAND"
    }
  }

  tags = {
    Environment = "dev"
    Project     = "humangov"
  }
}

# 1. Fetch the LATEST official policy from AWS GitHub
data "http" "lb_controller_iam_policy" {
  url = "https://raw.githubusercontent.com/kubernetes-sigs/aws-load-balancer-controller/main/docs/install/iam_policy.json"
}

# 2. Create the IAM Policy resource using that JSON
resource "aws_iam_policy" "lb_controller_policy" {
  name        = "AWSLoadBalancerControllerIAMPolicy_HumanGov"
  path        = "/"
  description = "Official AWS Load Balancer Controller IAM Policy"
  policy      = data.http.lb_controller_iam_policy.response_body
}

# 3. Create the Role and attach OUR policy (Disable the default one)
module "lb_role" {
  source    = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"
  version   = "~> 5.0"

  role_name = "humangov-eks-lb-role"

  # CRITICAL: Turn OFF the default policy (It was missing permissions)
  attach_load_balancer_controller_policy = false

  # CRITICAL: Attach OUR fresh official policy
  role_policy_arns = {
    additional = aws_iam_policy.lb_controller_policy.arn
  }

  oidc_providers = {
    main = {
      provider_arn               = module.eks.oidc_provider_arn
      namespace_service_accounts = ["kube-system:aws-load-balancer-controller"]
    }
  }

  tags = {
    Name = "humangov-eks-lb-role"
  }
}


module "irsa_humangov_app" {
  source = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"
  version = "5.30"
  role_name = "humangov-pod-execution-role"

  oidc_providers = {
    main = {
      provider_arn = module.eks.oidc_provider_arn
      namespace_service_accounts = ["default:humangov-pod-execution-role"]
    }
  }

# Attach permissions
  role_policy_arns = {
    AmazonS3FullAccess       = "arn:aws:iam::aws:policy/AmazonS3FullAccess"
    AmazonDynamoDBFullAccess = "arn:aws:iam::aws:policy/AmazonDynamoDBFullAccess"
  }

  tags = {
    Name = "humangov-pod-execution-role"
  }

}

