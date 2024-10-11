# Provider setup
provider "aws" {
  region = "us-east-1"
}

# VPC and Subnet setup
resource "aws_vpc" "my_vpc" {
  cidr_block = "10.0.0.0/16"
}

resource "aws_subnet" "public_subnet_1" {
  vpc_id                  = aws_vpc.my_vpc.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = "us-east-1a"
  map_public_ip_on_launch = true
}

resource "aws_subnet" "public_subnet_2" {
  vpc_id                  = aws_vpc.my_vpc.id
  cidr_block              = "10.0.3.0/24"
  availability_zone       = "us-east-1b"
  map_public_ip_on_launch = true
}

resource "aws_subnet" "private_subnet_1" {
  vpc_id            = aws_vpc.my_vpc.id
  availability_zone = "us-east-1a"
  cidr_block        = "10.0.2.0/24"
}

resource "aws_subnet" "private_subnet_2" {
  vpc_id            = aws_vpc.my_vpc.id
  availability_zone = "us-east-1b"
  cidr_block        = "10.0.4.0/24"
}

resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.my_vpc.id
}

resource "aws_nat_gateway" "nat_gateway" {
  allocation_id = aws_eip.nat_eip.id
  subnet_id     = aws_subnet.public_subnet_1.id
}

resource "aws_eip" "nat_eip" {
  domain = "vpc"
}

resource "aws_route_table" "public_rt" {
  vpc_id = aws_vpc.my_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }
}

resource "aws_route_table" "private_rt" {
  vpc_id = aws_vpc.my_vpc.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.nat_gateway.id
  }
}

resource "aws_route_table_association" "public_association_1" {
  subnet_id      = aws_subnet.public_subnet_1.id
  route_table_id = aws_route_table.public_rt.id
}

resource "aws_route_table_association" "public_association_2" {
  subnet_id      = aws_subnet.public_subnet_2.id
  route_table_id = aws_route_table.public_rt.id
}

resource "aws_route_table_association" "private_association_1" {
  subnet_id      = aws_subnet.private_subnet_1.id
  route_table_id = aws_route_table.private_rt.id
}

resource "aws_route_table_association" "private_association_2" {
  subnet_id      = aws_subnet.private_subnet_2.id
  route_table_id = aws_route_table.private_rt.id
}





resource "aws_lb_target_group" "app_tg-1" {
  name     = "app-target-group-1"
  port     = 8000
  protocol = "HTTP"
  vpc_id   = aws_vpc.my_vpc.id

  health_check {
    interval            = 30
    path                = "/"
    protocol            = "HTTP"
    timeout             = 5
    healthy_threshold   = 5
    unhealthy_threshold = 2
  }
}


# ECS Cluster
resource "aws_ecs_cluster" "ecs_cluster" {
  name = "my-ecs-cluster"
}

# ECR Repository
resource "aws_ecr_repository" "app_ecr" {
  name = "my-app-repo"
}

# # IAM Role for CodeBuild
# resource "aws_iam_role" "codebuild_role" {
#   name = "codebuild_role"

#   assume_role_policy = jsonencode({
#     Version = "2012-10-17"
#     Statement = [
#       {
#         Action    = "sts:AssumeRole"
#         Principal = {
#           Service = "codebuild.amazonaws.com"
#         }
#         Effect    = "Allow"
#         Sid       = ""
#       },
#     ]
#   })
# }

# # IAM Role for CodePipeline (Newly Added)
# resource "aws_iam_role" "codepipeline_role" {
#   name = "codepipeline_role"

#   assume_role_policy = jsonencode({
#     Version = "2012-10-17"
#     Statement = [
#       {
#         Action    = "sts:AssumeRole"
#         Principal = {
#           Service = "codepipeline.amazonaws.com"
#         }
#         Effect    = "Allow"
#         Sid       = ""
#       },
#     ]
#   })
# }

# # IAM Role for CodeDeploy
# resource "aws_iam_role" "codedeploy_role" {
#   name = "codedeploy_role"

#   assume_role_policy = jsonencode({
#     Version = "2012-10-17"
#     Statement = [
#       {
#         Action    = "sts:AssumeRole"
#         Principal = {
#           Service = "codedeploy.amazonaws.com"
#         }
#         Effect    = "Allow"
#         Sid       = ""
#       },
#     ]
#   })
# }


# Fetch the existing ECS Task Execution Role
data "aws_iam_role" "ecs_task_execution_role" {
  name = "ecsTaskExecutionRole"
}

# Attach the policy to the existing role
resource "aws_iam_role_policy_attachment" "ecs_task_execution_policy" {
  role       = data.aws_iam_role.ecs_task_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}



# S3 Bucket for Pipeline Artifacts (Newly Added)
resource "aws_s3_bucket" "pipeline_artifacts" {
  bucket = "my-app-pipeline-artifacts1" # Choose a unique bucket name
}

# # CodeBuild Project
# resource "aws_codebuild_project" "build_project" {
#   name          = "my-app-build"
#   service_role  = aws_iam_role.codebuild_role.arn

#   source {
#     type      = "CODEPIPELINE"
#     buildspec = "buildspec.yml"
#   }

#   artifacts {
#     type = "CODEPIPELINE"
#   }

#   environment {
#     compute_type = "BUILD_GENERAL1_SMALL"
#     image        = "aws/codebuild/standard:4.0"
#     type         = "LINUX_CONTAINER"

#     environment_variable {
#       name  = "ECR_REPOSITORY"
#       value = aws_ecr_repository.app_ecr.name
#     }
#   }

#   cache {
#     type  = "LOCAL"
#     modes = ["LOCAL_SOURCE_CACHE", "LOCAL_DOCKER_LAYER_CACHE"]
#   }
# }

# # CodeDeploy Application
# resource "aws_codedeploy_app" "codedeploy_app" {
#   name              = "my-app-codedeploy"
#   compute_platform  = "ECS"
# }

# # CodeDeploy Deployment Group
# resource "aws_codedeploy_deployment_group" "codedeploy_deployment_group" {
#   app_name              = aws_codedeploy_app.codedeploy_app.name
#   deployment_group_name = "my-app-deployment-group"

#   service_role_arn = aws_iam_role.codedeploy_role.arn

#   ecs_service {
#     cluster_name = aws_ecs_cluster.ecs_cluster.name
#     service_name = aws_ecs_service.ecs_service.id  # Changed to .id instead of .name
#   }

#   deployment_config_name = "CodeDeployDefault.ECSAllAtOnce"
# }

# # CodePipeline configuration
# resource "aws_codepipeline" "pipeline" {
#   name     = "my-app-pipeline"
#   role_arn = aws_iam_role.codepipeline_role.arn

#   artifact_store {
#     location = aws_s3_bucket.pipeline_artifacts.bucket
#     type     = "S3"
#   }

#   stage {
#     name = "Source"
#     action {
#       name             = "Source"
#       category         = "Source"
#       owner            = "ThirdParty"
#       provider         = "GitHub"
#       version          = "1"
#       output_artifacts = ["source_output"]

#       configuration = {
#         Owner      = "ankur-rezang"
#         Repo       = "nat-habit-Assignment"
#         Branch     = "main"
#         OAuthToken = "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"
#       }
#     }
#   }

#   stage {
#     name = "Build"
#     action {
#       name             = "Build"
#       category         = "Build"
#       owner            = "AWS"
#       provider         = "CodeBuild"
#       version          = "1"
#       input_artifacts  = ["source_output"]
#       output_artifacts = ["build_output"]

#       configuration = {
#         ProjectName = aws_codebuild_project.build_project.name
#       }
#     }
#   }

#   stage {
#     name = "Deploy"
#     action {
#       name             = "Deploy"
#       category         = "Deploy"
#       owner            = "AWS"
#       provider         = "CodeDeploy"
#       version          = "1"
#       input_artifacts  = ["build_output"]

#       configuration = {
#         ApplicationName     = aws_codedeploy_app.codedeploy_app.name
#         DeploymentGroupName = aws_codedeploy_deployment_group.codedeploy_deployment_group.deployment_group_name  # Fixed attribute
#       }
#     }
#   }
# }

# CloudWatch Log Group
resource "aws_cloudwatch_log_group" "app_logs" {
  name              = "my-app-log-group" # Change the name as needed
  retention_in_days = 7                  # Adjust retention period as necessary

  tags = {
    Name = "my-app-log-group"
  }
}
# Create CloudWatch Alarms

resource "aws_cloudwatch_metric_alarm" "cpu_utilization_alarm" {
  alarm_name          = "HighCPUUtilization"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "1"
  metric_name         = "CPUUtilization"
  namespace           = "AWS/ECS"
  period              = "300"
  statistic           = "Average"
  threshold           = "70" # Set threshold as needed
  alarm_description   = "Alarm when CPU exceeds 70%"
  dimensions = {
    ServiceName = aws_ecs_service.ecs_service.name
    ClusterName = aws_ecs_cluster.ecs_cluster.name
  }

  alarm_actions = [
    # SNS Topic ARN for notifications
  ]

  ok_actions = [
    # SNS Topic ARN for notifications
  ]
}

resource "aws_cloudwatch_metric_alarm" "ecs_service_failure_alarm" {
  alarm_name          = "ECSServiceFailure"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "1"
  metric_name         = "ServiceFailures"
  namespace           = "AWS/ECS"
  period              = "300"
  statistic           = "Sum"
  threshold           = "0" # Set threshold as needed
  alarm_description   = "Alarm when service fails"
  dimensions = {
    ServiceName = aws_ecs_service.ecs_service.name
    ClusterName = aws_ecs_cluster.ecs_cluster.name
  }

  alarm_actions = [
    # SNS Topic ARN for notifications
  ]

  ok_actions = [
    # SNS Topic ARN for notifications
  ]
}



# ECS Task Definition
resource "aws_ecs_task_definition" "app_task" {
  family                   = "my-ecs-task"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = "256"
  memory                   = "512"
  execution_role_arn       = data.aws_iam_role.ecs_task_execution_role.arn
  container_definitions = jsonencode([{
    name      = "my-app-container"
    image     = "${aws_ecr_repository.app_ecr.repository_url}:latest"
    essential = true
    portMappings = [{
      containerPort = 8000
      hostPort      = 8000
      protocol      = "tcp"
    }]
    logConfiguration = {
      logDriver = "awslogs"
      options = {
        "awslogs-group"         = aws_cloudwatch_log_group.app_logs.name
        "awslogs-region"        = "us-east-1" # Change as necessary
        "awslogs-stream-prefix" = "ecs"
      }
    }



  }])
}

# Application Load Balancer (ALB)
resource "aws_lb" "app_alb" {
  name               = "app-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb_sg.id]
  subnets            = [aws_subnet.public_subnet_1.id, aws_subnet.public_subnet_2.id]

  enable_deletion_protection = false
}

# Application Load Balancer Target Group
resource "aws_lb_target_group" "app_tg" {
  name        = "app-target-group"
  port        = 8000
  protocol    = "HTTP"
  vpc_id      = aws_vpc.my_vpc.id
  target_type = "ip" # Use "ip" as the target type for awsvpc network mode
  health_check {
    path                = "/"
    interval            = 30
    timeout             = 5
    healthy_threshold   = 3
    unhealthy_threshold = 3
  }
}

# ALB Listener
resource "aws_lb_listener" "app_listener" {
  load_balancer_arn = aws_lb.app_alb.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.app_tg.arn
  }
}

# ECS Service
resource "aws_ecs_service" "ecs_service" {
  name            = "my-app-service"
  cluster         = aws_ecs_cluster.ecs_cluster.id
  task_definition = aws_ecs_task_definition.app_task.arn

  network_configuration {
    subnets          = [aws_subnet.private_subnet_1.id]
    security_groups  = [aws_security_group.ecs_security_group.id]
    assign_public_ip = false # Fixed: Use boolean value instead of string
  }

  desired_count = 2
  launch_type   = "FARGATE"

  load_balancer {
    target_group_arn = aws_lb_target_group.app_tg.arn
    container_name   = "my-app-container"
    container_port   = 8000
  }


  depends_on = [
    aws_lb.app_alb,
    aws_lb_target_group.app_tg,
    aws_lb_listener.app_listener
  ]


}




# Security Group for ALB
resource "aws_security_group" "alb_sg" {
  name        = "alb-sg"
  description = "Allow HTTP traffic from the internet"
  vpc_id      = aws_vpc.my_vpc.id

  ingress {
    from_port   = 8000
    to_port     = 8000
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# Security Group for ECS
resource "aws_security_group" "ecs_security_group" {
  name        = "ecs-sg"
  description = "Allow traffic to ECS containers"
  vpc_id      = aws_vpc.my_vpc.id

  ingress {
    from_port   = 8000
    to_port     = 8000
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}


# Output for ALB DNS Name
output "load_balancer_url" {
  value = aws_lb.app_alb.dns_name
}


