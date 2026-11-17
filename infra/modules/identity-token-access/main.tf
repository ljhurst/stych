data "aws_iam_policy_document" "boundary" {
  statement {
    sid       = "OutboundIdentityToken"
    actions   = ["sts:GetWebIdentityToken"]
    resources = ["*"]

    condition {
      test     = "ForAllValues:StringEquals"
      variable = "sts:IdentityTokenAudience"
      values   = var.audiences
    }
  }
}
