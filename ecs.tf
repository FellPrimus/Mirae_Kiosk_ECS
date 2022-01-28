## ECS Cluster
resource "aws_ecs_cluster" "kiosk-test-cluster" {
  name = "kiosk-test-cluster"

  setting {
    name  = "containerInsights"
    value = "enabled"
    #s3_bucket_name = "kiosk-ticket-test-bucket"
  }
/*
  configuration {
    execute_command_configuration {
    logging    = "OVERRIDE"
      log_configuration {
      cloud_watch_encryption_enabled = true
      cloud_watch_log_group_name     = aws_cloudwatch_log_group.kiosk-cluster-testlog.name
      
      }
     }
    }
*/
    tags = {
        Name = "kiosk-test-cluster"
    }
}

/*
## Cloudwatch Log group
resource "aws_cloudwatch_log_group" "kiosk-cluster-testlog" {
  name = "kiosk-cluster-testlog"
}
*/

#######################################################################################
## 작업 정의
# ECS 테스크를 실행 IAM 역할 생성
resource "aws_iam_role" "ecs_task_execution_role" {
  name = "kiosk-test-execution-role"
 
  assume_role_policy = <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Action": "sts:AssumeRole",
            "Principal": {
             "Service": "ecs-tasks.amazonaws.com"
            },
            "Effect": "Allow",
            "Sid": ""
            }
        ]
}
    EOF
}


# ECS 태스크를 실행하기 위한 권한 연결
resource "aws_iam_role_policy_attachment" "ecs_task_execution_role" {
    role        = aws_iam_role.ecs_task_execution_role.name
    policy_arn  = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

# ECS 작업 정의
resource "aws_ecs_task_definition" "name" {
    family                      = "ecs-exam-task-1"
    network_mode                = "awsvpc"
    requires_compatibilities    = ["FARGATE"]
    cpu                         = 256
    memory                      = 512
    execution_role_arn          = aws_iam_role.ecs_task_execution_role.arn
    # task_role_arn               = aws_iam_role.ecs_task_role.arn # 
    container_definitions       = jsonencode([{
        name            = "ecs-exam-01"
        image           = "503237308475.dkr.ecr.us-west-2.amazonaws.com/study-cafe:study-cafe-1"
        essential       = true
        portMappings    = [
            {
                containerPort   = 80
                hostPort        = 80
            }
        ]
    }
    ])

    tags = {
        Name        = "ecs_task_kiosk_ticket_1"
        Project     = "kiosk"
        Team        = "ticket"
    }
}



#서비스 정의
resource "aws_ecs_service" "kiosk-testcl-service" {
 name                               = "test-service"
 cluster                            = aws_ecs_cluster.kiosk-test-cluster.id
 task_definition                    = aws_ecs_task_definition.name.arn
 desired_count                      = 2 #Task의 수
 deployment_minimum_healthy_percent = 50 #활성화 되어야 할 task의 하한 % 예) 2개중 1개만 실행되도 배포
 deployment_maximum_percent         = 200 #상한 %
 launch_type                        = "FARGATE"
 scheduling_strategy                = "REPLICA"
 
 network_configuration {
   #security_groups  = var.ecs_service_security_groups #SG 설정 후 다시 볼 것
   subnets         = aws_subnet.sub-pri1-10-0-3-0.*.id
   assign_public_ip = false #public ip 주소 ENI에 할당
 }
 
 load_balancer {
   #target_group_arn = var.aws_alb_target_group_arn #서비스와 연결할 로드 밸런서 대상 그룹의 ARN / ALB 필수
   container_name   = "${var.name}-container-${var.environment}"

   container_port   = var.container_port
 }
 
 lifecycle {
   ignore_changes = [task_definition, desired_count] #생성 후 변경할 수 없는 값
 }

 tags = {
     Environment = "kiosk-test"
 }
}


#####################################################################
## Load Balancer 
#####################################################################

resource "aws_lb" "kiosk-test-lb" {
  name               = "kiosk-test-lb1"
  internal           = false       # subnet 내에 위치할 경우 True
  load_balancer_type = "application"
  #security_groups    = var.alb_security_groups
  subnets            = [aws_subnet.sub-pri1-10-0-3-0.id, aws_subnet.sub-pri2-10-0-4-0.id]
 
  enable_deletion_protection = false # True일 경우, AWS API를 통해 삭제가 불가능하다.테라폼이 로드 밸런서를 삭제하는걸 방지 

  access_logs {
    bucket  = aws_s3_bucket.kiosk-test-bucket.bucket
    prefix  = "kiosk-test-lb"
    enabled = true
  }

}
 
resource "aws_alb_target_group" "kiosk-test-tg" {
  name        = "kiosk-test-tg"
  port        = 80
  protocol    = "HTTP"
  vpc_id      = aws_vpc.vpc-10-0-0-0.id
  target_type = "ip" # 타입 instance / id / lambda
 
  health_check {
   healthy_threshold   = "3"
   interval            = "30"
   protocol            = "HTTP"
   matcher             = "200"
   timeout             = "3"
   path                = "/ping" #추후 수정 필요
   unhealthy_threshold = "2"
  }
}

resource "aws_alb_listener" "http" {
  load_balancer_arn = aws_lb.kiosk-test-lb.id
  port              = 80
  protocol          = "HTTP"
 
  default_action {
   type = "forward"
   target_group_arn = aws_alb_target_group.kiosk-test-tg.arn
   
  }
}
