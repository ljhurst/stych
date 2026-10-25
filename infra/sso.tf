data "aws_caller_identity" "current" {}

data "aws_ssoadmin_instances" "this" {}

data "aws_identitystore_user" "luke" {
  identity_store_id = one(data.aws_ssoadmin_instances.this.identity_store_ids)

  alternate_identifier {
    unique_attribute {
      attribute_path  = "UserName"
      attribute_value = "luke"
    }
  }
}

locals {
  account_id       = data.aws_caller_identity.current.account_id
  sso_instance_arn = one(data.aws_ssoadmin_instances.this.arns)
  sso_user_id      = data.aws_identitystore_user.luke.user_id
}
