# IAM Role for CodeBuild
resource "aws_iam_role" "codebuild_role" {
  name = "humangov-codebuild-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{ Action = "sts:AssumeRole", Effect = "Allow", Principal = { Service = "codebuild.amazonaws.com" } }]
  })
}

# 2. Permissions (Logs, ECR, Secrets Manager, AND S3)
resource "aws_iam_role_policy" "codebuild_policy" {
  role = aws_iam_role.codebuild_role.name

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      # 1. Logging Access
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "*"
      },
      # 2. ECR Access (Push/Pull)
      {
        Effect = "Allow"
        Action = [
          "ecr:GetAuthorizationToken",
          "ecr:BatchCheckLayerAvailability",
          "ecr:GetDownloadUrlForLayer",
          "ecr:BatchGetImage",
          "ecr:PutImage",
          "ecr:InitiateLayerUpload",
          "ecr:UploadLayerPart",
          "ecr:CompleteLayerUpload"
        ]
        Resource = "*"
      },
      # 3. Secrets Manager Access (For GitHub Token)
      {
        Effect = "Allow"
        Action = ["secretsmanager:GetSecretValue"]
        Resource = "arn:aws:secretsmanager:*:*:secret:humangov-gitOps/github-token-*" 
      },
      # 4. S3 Access (The Fix for your Error)
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:GetObjectVersion",
          "s3:GetBucketVersioning"
        ]
        Resource = [
          aws_s3_bucket.codepipeline_bucket.arn,
          "${aws_s3_bucket.codepipeline_bucket.arn}/*"
        ]
      }
    ]
  })
}

# CodeBuild Project
resource "aws_codebuild_project" "humangov_build" {
  name          = "humangov-build"
  service_role  = aws_iam_role.codebuild_role.arn
  artifacts { type = "CODEPIPELINE" }

  environment {
    compute_type    = "BUILD_GENERAL1_SMALL"
    image           = "aws/codebuild/standard:7.0"
    type            = "LINUX_CONTAINER"
    privileged_mode = true 

    environment_variable {
      name  = "AWS_REGION"
      value = var.region
    }
    environment_variable {
      name  = "ECR_REPO_URL"
      value = var.ecr_repo_url
    }
  }

  source {
    type      = "CODEPIPELINE"
    buildspec = "buildspec.yml"
  }
}

# CodePipeline (Source + Build ONLY) - No Deploy Stage!
resource "aws_codepipeline" "humangov_pipeline" {
  name     = "humangov-pipeline"
  role_arn = aws_iam_role.codepipeline_role.arn

  artifact_store {
    location = aws_s3_bucket.codepipeline_bucket.bucket
    type     = "S3"
  }

  stage {
    name = "Source"
    action {
      name             = "Source"
      category         = "Source"
      owner            = "AWS"
      provider         = "CodeStarSourceConnection"
      version          = "1"
      output_artifacts = ["source_output"]
      configuration = {
        ConnectionArn    = var.codestar_connection_arn
        FullRepositoryId = "SimeonAkinnuoye/humangov-gitops" # CHECK THIS
        BranchName       = "main"
      }
    }
  }

  stage {
    name = "Build"
    action {
      name             = "Build"
      category         = "Build"
      owner            = "AWS"
      provider         = "CodeBuild"
      input_artifacts  = ["source_output"]
      version          = "1"
      configuration = {
        ProjectName = aws_codebuild_project.humangov_build.name
      }
    }
  }
}

# Boilerplate Resources (Bucket & Pipeline Role)
resource "aws_s3_bucket" "codepipeline_bucket" {
  bucket_prefix = "humangov-codepipeline-"
  force_destroy = true
}

resource "aws_iam_role" "codepipeline_role" {
  name = "humangov-codepipeline-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{ Action = "sts:AssumeRole", Effect = "Allow", Principal = { Service = "codepipeline.amazonaws.com" } }]
  })
}

resource "aws_iam_role_policy" "codepipeline_policy" {
  role = aws_iam_role.codepipeline_role.name
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = ["s3:GetObject", "s3:GetObjectVersion", "s3:GetBucketVersioning", "s3:PutObjectAcl", "s3:PutObject"]
        Resource = [aws_s3_bucket.codepipeline_bucket.arn, "${aws_s3_bucket.codepipeline_bucket.arn}/*"]
      },
      {
        Effect = "Allow"
        Action = ["codebuild:BatchGetBuilds", "codebuild:StartBuild"]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = ["codestar-connections:UseConnection"]
        Resource = var.codestar_connection_arn
      }
    ]
  })
}