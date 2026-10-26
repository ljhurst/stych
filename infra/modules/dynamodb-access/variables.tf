variable "account_id" {
  description = "AWS account the project's tables live in"
  type        = string
}

variable "region" {
  description = "AWS region the project's tables live in"
  type        = string
}

variable "tables" {
  description = "Name patterns of the project's tables, e.g. fife-*; their indexes are covered too"
  type        = list(string)
}

variable "data_actions" {
  description = "Item-level actions the project's operators may run on its tables"
  type        = list(string)
  default     = ["dynamodb:GetItem", "dynamodb:PutItem", "dynamodb:UpdateItem", "dynamodb:DeleteItem", "dynamodb:Query", "dynamodb:Scan", "dynamodb:ConditionCheckItem"]
}

variable "boundary_actions" {
  description = "Item-level actions the project's workload roles may run; defaults to data_actions"
  type        = list(string)
  default     = null
}
