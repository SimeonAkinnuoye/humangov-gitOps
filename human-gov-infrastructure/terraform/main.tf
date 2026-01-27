terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }

    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.24.0"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.12.0"
    }
  }
}

provider "aws" {
  region = "us-east-1"
}

module "network" {
  source = "./modules/network"
}

module "eks" {
  source     = "./modules/eks"
  vpc_id     = module.network.vpc_id
  subnet_ids = module.network.private_subnets
}

module "aws_human_gov_infrastructure" {
  source     = "./modules/application"
  for_each   = toset(var.states)
  state_name = each.value
  vpc_id     = module.network.vpc_id
  subnet_id  = try(module.network.public_subnets[0], null)
}
# ✅ FIX: Only fetch cluster data if it exists
data "aws_eks_cluster" "cluster" {
  name       = module.eks.cluster_name
  depends_on = [module.eks]
}
data "aws_eks_cluster_auth" "cluster_auth" {
  name       = module.eks.cluster_name
  depends_on = [module.eks]
}

provider "kubernetes" {
  host                   = data.aws_eks_cluster.cluster[0].endpoint
  cluster_ca_certificate = base64decode(data.aws_eks_cluster.cluster[0].certificate_authority[0].data)
  token                  = data.aws_eks_cluster_auth.cluster_auth[0].token
}

provider "helm" {
  kubernetes {
    host                   = data.aws_eks_cluster.cluster.endpoint
    cluster_ca_certificate = base64decode(data.aws_eks_cluster.cluster.certificate_authority[0].data)
    token                  = data.aws_eks_cluster_auth.cluster_auth.token
  }
}

#  Only create helm release if cluster exists
resource "helm_release" "lb_controller" {

  name          = "aws-load-balancer-controller"
  repository    = "https://aws.github.io/eks-charts"
  chart         = "aws-load-balancer-controller"
  namespace     = "kube-system"
  version       = "1.6.2"
  timeout       = 600
  wait          = true
  wait_for_jobs = true
  depends_on    = [module.eks]

  set {
    name  = "clusterName"
    value = module.eks.cluster_name
  }

  set {
    name  = "serviceAccount.create"
    value = "true"
  }

  set {
    name  = "serviceAccount.name"
    value = "aws-load-balancer-controller"
  }

  set {
    name  = "serviceAccount.annotations.eks\\.amazonaws\\.com/role-arn"
    value = module.eks.lb_role_arn
  }

  set {
    name  = "region"
    value = "us-east-1"
  }

  set {
    name  = "vpcId"
    value = module.network.vpc_id
  }
}

# Create the ECR Repository
resource "aws_ecr_repository" "humangov_app_repo" {
  name                 = "humangov-app"
  image_tag_mutability = "MUTABLE"
  force_delete         = true

  image_scanning_configuration {
    scan_on_push = true
  }
}


 module "argocd" {
  source = "./modules/argocd"
  
  eks_cluster_name = module.eks.cluster_name

  depends_on = [module.eks]
} 