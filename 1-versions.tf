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
      version = ">= 6.0" 
    }
  }
}