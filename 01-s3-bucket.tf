# Provider.tf
provider "aws" {
  region = "us-west-1"
}

# versions.tf
terraform {
  required_version = ">= 1.5.0"
  # Remote backend S3 for terraform state file so I dont get teabagged.
  backend "s3" {
    bucket  = "umaidev-int-state"         # Name of the S3 bucket
    key     = "umai/jenkins-prod.tfstate" # The name of the state file in the bucket
    region  = "us-west-1"                 # Use a variable for the region
    encrypt = true                        # Enable server-side encryption (optional but recommended)
  }
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 6.0" # Use latest version if possible
    }
  }
}

###########################################################################################

resource "aws_s3_bucket" "umaidev_pub_gcheck" {
  bucket        = "umaidev-pub-gcheck"
  force_destroy = true

  tags = {
    Name = "Umai public Gcheck"
  }
}

#Bucket policy: public read-only
resource "aws_s3_bucket_policy" "umaidev_pub_gcheck" {
  bucket     = aws_s3_bucket.umaidev_pub_gcheck.id
  depends_on = [aws_s3_bucket_public_access_block.umaidev_pub_gcheck]

  policy = data.aws_iam_policy_document.umaidev_pub_gcheck_public_read.json
}

data "aws_iam_policy_document" "umaidev_pub_gcheck_public_read" {
  statement {
    sid    = "PublicReadOnly"
    effect = "Allow"

    principals {
      type        = "*"
      identifiers = ["*"]
    }

    actions = [
      "s3:GetObject",
    ]

    resources = [
      "${aws_s3_bucket.umaidev_pub_gcheck.arn}/*",
    ]
  }
}


# Allows public read, but block everything else
resource "aws_s3_bucket_public_access_block" "umaidev_pub_gcheck" {
  bucket = aws_s3_bucket.umaidev_pub_gcheck.id

  block_public_acls       = true
  block_public_policy     = false
  ignore_public_acls      = true
  restrict_public_buckets = false
}

#placeholder until I grab deliverables
# resource "aws_s3_object" "skeleton1" {
#   bucket = aws_s3_bucket.umaidev_pub_gcheck.id
#   key    = "screenshots/deliverable1.png"
#   source = "screenshots/deliverable1.png"
#   etag   = filemd5("screenshots/deliverable1.png")
# }

#placeholder until I grab deliverables
# resource "aws_s3_object" "skeleton1" {
#   bucket = aws_s3_bucket.umaidev_pub_gcheck.id
#   key    = "screenshots/deliverable1.png"
#   source = "screenshots/deliverable1.png"
#   etag   = filemd5("screenshots/deliverable1.png")
# }

#placeholder until I grab deliverables
# resource "aws_s3_object" "skeleton1" {
#   bucket = aws_s3_bucket.umaidev_pub_gcheck.id
#   key    = "screenshots/deliverable1.png"
#   source = "screenshots/deliverable1.png"
#   etag   = filemd5("screenshots/deliverable1.png")
# }

#placeholder until I grab deliverables
# resource "aws_s3_object" "skeleton1" {
#   bucket = aws_s3_bucket.umaidev_pub_gcheck.id
#   key    = "screenshots/deliverable1.png"
#   source = "screenshots/deliverable1.png"
#   etag   = filemd5("screenshots/deliverable1.png")
# }