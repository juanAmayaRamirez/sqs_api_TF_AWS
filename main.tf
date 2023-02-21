# providers
provider "aws" {
  region  = var.aws_region
  profile = var.profile
}

provider "archive" {}

# zip lambda code
data "archive_file" "lambda_code" {
  type        = "zip"
  source_dir  = "functions/lambda1/"
  output_path = "lambda1.zip"
}

# Create Lambda Role
resource "aws_iam_role" "iam_role_for_lambda" {
  name = "iam_role_for_lambda"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })
}

# add policy attatchment 
## sqs
resource "aws_iam_role_policy_attachment" "lambda_sqs_role_policy" {
  role       = aws_iam_role.iam_role_for_lambda.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSQSFullAccess"
}
## sns
resource "aws_iam_role_policy_attachment" "lambda_sns_role_policy" {
  role       = aws_iam_role.iam_role_for_lambda.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSNSFullAccess"
}

# Create lambda function
resource "aws_lambda_function" "function" {
  function_name = "my-lambda"

  filename         = data.archive_file.lambda_code.output_path
  source_code_hash = data.archive_file.lambda_code.output_base64sha256

  role    = aws_iam_role.iam_role_for_lambda.arn
  handler = "app.lambda_handler"
  runtime = "python3.9"

  environment {
    variables = {
      "GREETING" = "hello"
    }
  }
}

# Lambda triggers
resource "aws_lambda_event_source_mapping" "sqs_event" {
  event_source_arn = aws_sqs_queue.queue.arn
  function_name    = aws_lambda_function.function.arn
}

# lambda destinations
resource "aws_lambda_function_event_invoke_config" "sns_invoke" {
  function_name = aws_lambda_function.function.function_name
  destination_config {
    on_failure {
      destination = aws_sqs_queue.dead_letter_queue.arn
    }
    on_success {
      destination = aws_sns_topic.sns.arn
    }
  }
}

# Create an SQS queue
resource "aws_sqs_queue" "queue" {
  name                      = "my-queue"
  message_retention_seconds = 120
  redrive_policy            = "{\"deadLetterTargetArn\":\"${aws_sqs_queue.dead_letter_queue.arn}\",\"maxReceiveCount\":4}"
}

resource "aws_sqs_queue" "dead_letter_queue" {
  name = "my-dead-letter-queue"
}

resource "aws_sns_topic" "sns" {
  name = "sns_topic"
}

# Create Apigateway Role
resource "aws_iam_role" "apigateway_role" {
  name = "apigateway-sqs-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "apigateway.amazonaws.com"
        }
      }
    ]
  })
}

# Create  Apigateway Policy
resource "aws_iam_policy" "sqs_policy" {
  name = "sqs-policy"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "sqs:SendMessage"
        ]
        Effect   = "Allow"
        Resource = aws_sqs_queue.queue.arn
      }
    ]
  })
}

# Attach the policy to the role
resource "aws_iam_role_policy_attachment" "apigateway_policy_attachment" {
  policy_arn = aws_iam_policy.sqs_policy.arn
  role       = aws_iam_role.apigateway_role.name
}

# Create the API Gateway
resource "aws_api_gateway_rest_api" "api" {
  name        = "my-api"
  description = "My API Gateway"

  endpoint_configuration {
    types = ["REGIONAL"]
  }
}

# Create a resource for the API Gateway
resource "aws_api_gateway_resource" "resource" {
  rest_api_id = aws_api_gateway_rest_api.api.id
  parent_id   = aws_api_gateway_rest_api.api.root_resource_id
  path_part   = "my-resource"
}

# Create a method for the API Gateway
resource "aws_api_gateway_method" "method" {
  rest_api_id          = aws_api_gateway_rest_api.api.id
  resource_id          = aws_api_gateway_resource.resource.id
  request_validator_id = aws_api_gateway_request_validator.validator.id
  http_method          = "POST"
  authorization        = "NONE"
  request_parameters = {
    "method.request.header.Content-Type" = true
  }
  request_models = {
    "application/json" = aws_api_gateway_model.model.name
  }
}
resource "aws_api_gateway_model" "model" {
  rest_api_id  = aws_api_gateway_rest_api.api.id
  name         = "sqs"
  description  = "models used to map json body"
  content_type = "application/json"
  schema       = <<EOF
    {
      "$schema": "http://json-schema.org/draft-04/schema#",
      "title":"Item Schema",
          "type": "object",
          "properties":{
              "ID":{ "type": "number"},
              "name":{ "type": "string"},
              "price":{ "type": "number"}
          },
          "required":["ID","name","price"]

    }
    EOF
}
# Create an integration for the API Gateway that connects to the SQS queue
resource "aws_api_gateway_integration" "integration" {
  rest_api_id = aws_api_gateway_rest_api.api.id
  resource_id = aws_api_gateway_resource.resource.id
  http_method = aws_api_gateway_method.method.http_method
  credentials = aws_iam_role.apigateway_role.arn

  type                    = "AWS"
  integration_http_method = "POST"
  uri                     = "arn:aws:apigateway:${var.aws_region}:sqs:path/${aws_sqs_queue.queue.name}"

  request_templates = {
    "application/json" = "Action=SendMessage&MessageBody=$input.body"
  }
  request_parameters = {
    "integration.request.header.Content-Type" = "'application/x-www-form-urlencoded'"
  }
  passthrough_behavior = "NEVER"
}

# Create Integration response
resource "aws_api_gateway_integration_response" "integration_response" {
  rest_api_id = aws_api_gateway_rest_api.api.id
  resource_id = aws_api_gateway_resource.resource.id
  http_method = aws_api_gateway_method.method.http_method
  status_code = aws_api_gateway_method_response.response_200.status_code
  depends_on = [
    aws_api_gateway_integration.integration
  ]
  # response_templates = {
  #   "application/json" = ""
  # }
}

# Create method response
resource "aws_api_gateway_method_response" "response_200" {
  rest_api_id = aws_api_gateway_rest_api.api.id
  resource_id = aws_api_gateway_resource.resource.id
  http_method = aws_api_gateway_method.method.http_method
  status_code = "200"
}

# Create a deployment for the API Gateway
resource "aws_api_gateway_deployment" "deployment" {
  rest_api_id = aws_api_gateway_rest_api.api.id
  triggers = {
    redeployment = sha1(join(",",
      [
        jsonencode(aws_api_gateway_method.method),
        jsonencode(aws_api_gateway_integration.integration),
        jsonencode(aws_api_gateway_integration_response.integration_response),
        jsonencode(aws_api_gateway_method_response.response_200),
        jsonencode(aws_api_gateway_resource.resource),
      ]
    ))
  }
  depends_on = [
    aws_api_gateway_method.method,
    aws_api_gateway_integration.integration
  ]
  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_api_gateway_stage" "stage" {
  deployment_id = aws_api_gateway_deployment.deployment.id
  rest_api_id   = aws_api_gateway_rest_api.api.id
  stage_name    = "test"
}

resource "aws_api_gateway_request_validator" "validator" {
  name                        = "example"
  rest_api_id                 = aws_api_gateway_rest_api.api.id
  validate_request_body       = true
  validate_request_parameters = true
}