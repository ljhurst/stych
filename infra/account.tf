data "aws_caller_identity" "current" {}

data "aws_region" "current" {}

locals {
  account_id = data.aws_caller_identity.current.account_id
  region     = data.aws_region.current.region
}

# Lets IAM principals mint AWS-signed JWTs (sts:GetWebIdentityToken) to call
# external services without static keys. Each project's boundary decides which
# of its roles may, and for which audience. Destroying it disables the feature
# account-wide.
resource "aws_iam_outbound_web_identity_federation" "this" {
  lifecycle {
    prevent_destroy = true
  }
}
