terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = "ap-northeast-1"
}

# -----------------------------
# DynamoDB
# -----------------------------
resource "aws_dynamodb_table" "memo" {
  name         = "memo_table2"
  billing_mode = "PAY_PER_REQUEST"

  hash_key = "id"

  attribute {
    name = "id"
    type = "S"
  }
}

# -----------------------------
# IAM Role for Lambda
# -----------------------------
resource "aws_iam_role" "lambda_exec" {
  name = "memo-api-role2"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "lambda.amazonaws.com"
      }
    }]
  })
}

resource "aws_iam_role_policy_attachment" "lambda_basic" {
  role       = aws_iam_role.lambda_exec.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

# DynamoDB へのアクセス権限（PutItem / GetItem）
resource "aws_iam_role_policy" "lambda_dynamo" {
  name = "lambda-dynamo-policy"
  role = aws_iam_role.lambda_exec.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = [
        "dynamodb:PutItem",
        "dynamodb:GetItem"
      ]
      Resource = aws_dynamodb_table.memo.arn
    }]
  })
}

# -----------------------------
# Lambda Function
# -----------------------------
resource "aws_lambda_function" "memo_lambda" {
  function_name = "memo-api2"
  handler       = "lambda_function.lambda_handler"
  runtime       = "python3.12"

  filename         = "lambda.zip"
  source_code_hash = filebase64sha256("lambda.zip")

  role = aws_iam_role.lambda_exec.arn
}

# -----------------------------
# API Gateway (HTTP API)
# -----------------------------
resource "aws_apigatewayv2_api" "memo_api" {
  name          = "memo-Gateway2"
  protocol_type = "HTTP"
}

resource "aws_apigatewayv2_integration" "lambda_integration" {
  api_id           = aws_apigatewayv2_api.memo_api.id
  integration_type = "AWS_PROXY"
  integration_uri  = aws_lambda_function.memo_lambda.invoke_arn
}

resource "aws_apigatewayv2_route" "default_route" {
  api_id    = aws_apigatewayv2_api.memo_api.id
  route_key = "POST /memo"
  target    = "integrations/${aws_apigatewayv2_integration.lambda_integration.id}"
}

resource "aws_apigatewayv2_stage" "default_stage" {
  api_id      = aws_apigatewayv2_api.memo_api.id
  name        = "$default"
  auto_deploy = true
}

# Lambda に API Gateway から呼び出す権限を付与
resource "aws_lambda_permission" "allow_apigw" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.memo_lambda.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.memo_api.execution_arn}/*/*"
}

# -----------------------------
# Output
# -----------------------------
output "api_endpoint" {
  value = aws_apigatewayv2_api.memo_api.api_endpoint
}
