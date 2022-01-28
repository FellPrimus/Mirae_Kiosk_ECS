resource "aws_ecr_repository" "kiosk_test_repo" {
  name = "kiosk_test_repo"
  image_scanning_configuration {
    scan_on_push = true
  }

  tags = {
    Name        = "kiosk_test_repo"
  }
}

resource "aws_ecr_lifecycle_policy" "test_repo_policy" {
  repository = aws_ecr_repository.kiosk_test_repo.name

  policy = <<EOF
{
    "rules": [
        {
            "rulePriority": 1,
            "description": "Keep last 30 images",
            "selection": {
                "tagStatus": "tagged",
                "tagPrefixList": ["v"],
                "countType": "imageCountMoreThan",
                "countNumber": 5
            },
            "action": {
                "type": "expire"
            }
        }
    ]
}
EOF
}
