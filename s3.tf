resource "aws_s3_bucket" "kiosk-test-bucket" {
  bucket = "kiosk-ticket-test-bucket"
  acl    = "log-delivery-write"

  policy = jsonencode({
	"Version": "2012-10-17",
	"Statement": [
		{
			"Effect": "Allow",
			"Principal": {
				"AWS": "arn:aws:iam::503237308475:root"
			},
			"Action": "s3:PutObject",
			"Resource": "arn:aws:s3:::kiosk-ticket-test-bucket/*"
		},
		{
			"Effect": "Allow",
			"Principal": "*",
			"Action": "s3:PutObject",
			"Resource": "arn:aws:s3:::kiosk-ticket-test-bucket/*",
			"Condition": {
				"StringEquals": {
					"s3:x-amz-acl": "bucket-owner-full-control"
				}
			}
		},
		{
			"Effect": "Allow",
			"Principal": "*",
			"Action": "s3:GetBucketAcl",
			"Resource": "arn:aws:s3:::kiosk-ticket-test-bucket"
		}
	]
})

## 수집 로그 수명주기 정책
  lifecycle_rule {
    id      = "log_lifecycle"
    enabled = true

    prefix  = "log/"

    #5일 뒤 GLACIER로 이관
    transition {
      days   = 5
      storage_class = "GLACIER"
    }

    #10일 뒤 로그 삭제
    expiration {
      days = 10
    }
  }
  
  force_destroy= true
  
}
