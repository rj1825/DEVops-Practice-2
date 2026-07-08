# IAM Role for API Gateway to write directly to SQS
resource "aws_iam_role" "api_gateway" {
  name = "${var.project_name}-api-gateway-role"

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

# IAM Policy allowing SendMessage to SQS
resource "aws_iam_policy" "api_gateway" {
  name   = "${var.project_name}-api-gateway-policy"
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = "sqs:SendMessage"
        Resource = aws_sqs_queue.main.arn
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "api_gateway" {
  policy_arn = aws_iam_policy.api_gateway.arn
  role       = aws_iam_role.api_gateway.name
}

# API Gateway REST API definition
resource "aws_api_gateway_rest_api" "ingest" {
  name        = "${var.project_name}-api"
  description = "Serverless API Gateway with direct SQS integration"

  endpoint_configuration {
    types = ["REGIONAL"]
  }
}

# API Gateway resource /ingest
resource "aws_api_gateway_resource" "ingest" {
  rest_api_id = aws_api_gateway_rest_api.ingest.id
  parent_id   = aws_api_gateway_rest_api.ingest.root_resource_id
  path_part   = "ingest"
}

# POST Method on /ingest
resource "aws_api_gateway_method" "ingest" {
  rest_api_id   = aws_api_gateway_rest_api.ingest.id
  resource_id   = aws_api_gateway_resource.ingest.id
  http_method   = "POST"
  authorization = "NONE"
}

# Direct integration: API Gateway to SQS SendMessage action
# This bypasses any intermediate Lambda, saving cost and reducing latency.
resource "aws_api_gateway_integration" "ingest" {
  rest_api_id             = aws_api_gateway_rest_api.ingest.id
  resource_id             = aws_api_gateway_resource.ingest.id
  http_method             = aws_api_gateway_method.ingest.http_method
  type                    = "AWS"
  integration_http_method = "POST"
  uri                     = "arn:aws:apigateway:${var.aws_region}:sqs:path/${aws_sqs_queue.main.name}"
  credentials             = aws_iam_role.api_gateway.arn

  # Maps headers to tell SQS to expect URL-encoded form data
  request_parameters = {
    "integration.request.header.Content-Type" = "'application/x-www-form-urlencoded'"
  }

  # Request template to package incoming JSON payload into the SQS MessageBody parameter
  request_templates = {
    "application/json" = "Action=SendMessage&MessageBody=$util.urlEncode($input.body)"
  }
}

# 200 Method Response for the client
resource "aws_api_gateway_method_response" "success" {
  rest_api_id = aws_api_gateway_rest_api.ingest.id
  resource_id = aws_api_gateway_resource.ingest.id
  http_method = aws_api_gateway_method.ingest.http_method
  status_code = "200"

  response_models = {
    "application/json" = "Empty"
  }
}

# 200 Integration Response mapping SQS response back to client
resource "aws_api_gateway_integration_response" "success" {
  rest_api_id = aws_api_gateway_rest_api.ingest.id
  resource_id = aws_api_gateway_resource.ingest.id
  http_method = aws_api_gateway_method.ingest.http_method
  status_code = aws_api_gateway_method_response.success.status_code

  # Respond back to the user with a clean JSON indicating success
  response_templates = {
    "application/json" = jsonencode({
      status    = "SUCCESS"
      message   = "Message queued successfully"
      messageId = "$xp.messageId" # Extracts message ID returned by SQS
    })
  }

  depends_on = [
    aws_api_gateway_integration.ingest
  ]
}

# Deployment of the API Gateway configuration
resource "aws_api_gateway_deployment" "ingest" {
  rest_api_id = aws_api_gateway_rest_api.ingest.id

  triggers = {
    redeployment = sha1(jsonencode([
      aws_api_gateway_resource.ingest.id,
      aws_api_gateway_method.ingest.id,
      aws_api_gateway_integration.ingest.id,
      aws_api_gateway_integration_response.success.id,
      aws_api_gateway_method_response.success.id,
    ]))
  }

  lifecycle {
    create_before_destroy = true
  }

  depends_on = [
    aws_api_gateway_integration.ingest
  ]
}

# Deploy to 'prod' environment stage
resource "aws_api_gateway_stage" "prod" {
  deployment_id = aws_api_gateway_deployment.ingest.id
  rest_api_id   = aws_api_gateway_rest_api.ingest.id
  stage_name    = "prod"
}
