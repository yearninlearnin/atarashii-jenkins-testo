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

resource "aws_s3_object" "armaggedon_repo" {
  bucket       = aws_s3_bucket.umaidev_pub_gcheck.id
  key          = "screenshots/armaggedon.md"
  source       = "screenshots/armaggedon.md"
  content_type = "text/markdown"
}

resource "aws_s3_object" "extension_email" {
  bucket = aws_s3_bucket.umaidev_pub_gcheck.id
  key    = "screenshots/extension-email.png"
  source = "screenshots/extension-email.png"
  etag   = filemd5("screenshots/extension-email.png")
}


resource "aws_s3_object" "tiqs_msg_to_group" {
  bucket = aws_s3_bucket.umaidev_pub_gcheck.id
  key    = "screenshots/tiqs-msg-to-group.jpg"
  source = "screenshots/tiqs-msg-to-group.jpg"
  etag   = filemd5("screenshots/tiqs-msg-to-group.jpg")
}

resource "aws_s3_object" "webhook_page" {
  bucket = aws_s3_bucket.umaidev_pub_gcheck.id
  key    = "screenshots/webhook-page.png"
  source = "screenshots/webhook-page.png"
  etag   = filemd5("screenshots/webhook-page.png")
}


resource "aws_s3_object" "pipeline" {
  bucket = aws_s3_bucket.umaidev_pub_gcheck.id
  key    = "screenshots/pipeline.png"
  source = "screenshots/pipeline.png"
  etag   = filemd5("screenshots/pipeline.png")
}


resource "aws_s3_object" "polling_log" {
  bucket = aws_s3_bucket.umaidev_pub_gcheck.id
  key    = "screenshots/polling-log.png"
  source = "screenshots/polling-log.png"
  etag   = filemd5("screenshots/polling-log.png")
}

