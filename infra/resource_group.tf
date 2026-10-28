resource "aws_resourcegroups_group" "stych" {
  name = "stych-prod"

  resource_query {
    query = jsonencode({
      ResourceTypeFilters = ["AWS::AllSupported"]
      TagFilters = [
        {
          Key    = "Project"
          Values = ["stych"]
        }
      ]
    })
  }
}
