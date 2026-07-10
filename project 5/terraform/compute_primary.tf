# Security Groups (Primary)
resource "aws_security_group" "primary_alb" {
  provider    = aws.primary
  name        = "${var.project_name}-primary-alb-sg"
  description = "Allows public HTTP ingress"
  vpc_id      = aws_vpc.primary.id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_security_group" "primary_app" {
  provider    = aws.primary
  name        = "${var.project_name}-primary-app-sg"
  description = "Allows ingress from ALB only"
  vpc_id      = aws_vpc.primary.id

  ingress {
    from_port       = 80
    to_port         = 80
    protocol        = "tcp"
    security_groups = [aws_security_group.primary_alb.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# Application Load Balancer
resource "aws_lb" "primary" {
  provider           = aws.primary
  name               = "${var.project_name}-primary-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.primary_alb.id]
  subnets            = [aws_subnet.primary_public_a.id, aws_subnet.primary_public_b.id]
}

resource "aws_lb_target_group" "primary" {
  provider    = aws.primary
  name        = "${var.project_name}-primary-tg"
  port        = 80
  protocol    = "HTTP"
  vpc_id      = aws_vpc.primary.id
  target_type = "instance"

  health_check {
    path                = "/"
    interval            = 15
    timeout             = 3
    healthy_threshold   = 2
    unhealthy_threshold = 2
  }
}

resource "aws_lb_listener" "primary" {
  provider          = aws.primary
  load_balancer_arn = aws_lb.primary.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.primary.arn
  }
}

# IAM Instance Profile for App Instances (allows read/write to DynamoDB)
resource "aws_iam_role" "app_role" {
  provider = aws.primary
  name     = "${var.project_name}-app-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_policy" "app_policy" {
  provider    = aws.primary
  name        = "${var.project_name}-app-policy"
  description = "Allows app instances to read/write to DynamoDB global tables"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "dynamodb:GetItem",
          "dynamodb:PutItem",
          "dynamodb:UpdateItem",
          "dynamodb:Scan"
        ]
        Resource = "*" # DynamoDB ARN is resolved dynamically
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "app" {
  provider   = aws.primary
  policy_arn = aws_iam_policy.app_policy.arn
  role       = aws_iam_role.app_role.name
}

resource "aws_iam_instance_profile" "primary" {
  provider = aws.primary
  name     = "${var.project_name}-primary-instance-profile"
  role     = aws_iam_role.app_role.name
}

# Fetch latest Ubuntu AMI in Primary region
data "aws_ami" "primary_ubuntu" {
  provider    = aws.primary
  most_recent = true
  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }
  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
  owners = ["099720109477"]
}

# Launch Template (Primary)
resource "aws_launch_template" "primary" {
  provider      = aws.primary
  name_prefix   = "${var.project_name}-primary-lt-"
  image_id      = data.aws_ami.primary_ubuntu.id
  instance_type = "t3.micro"

  iam_instance_profile {
    arn = aws_iam_instance_profile.primary.arn
  }

  network_interfaces {
    associate_public_ip_address = false
    security_groups             = [aws_security_group.primary_app.id]
  }

  # Boostrap script: Launches Python HTTP server displaying region info and writing a page view metric to DynamoDB
  user_data = base64encode(<<-EOF
              #!/bin/bash
              sudo apt-get update -y
              sudo apt-get install -y python3-pip
              pip3 install boto3

              # Create app directory
              mkdir -p /home/ubuntu/app
              cd /home/ubuntu/app

              # Write python web server script
              cat << 'PY_EOF' > server.py
              import http.server
              import socketserver
              import boto3
              import time
              from datetime import datetime

              PORT = 80
              REGION = "us-east-1"
              DYNAMODB_TABLE = "${var.project_name}-visits"

              class MyHandler(http.server.SimpleHTTPRequestHandler):
                  def do_GET(self):
                      self.send_response(200)
                      self.send_header("Content-type", "text/html")
                      self.end_headers()
                      
                      # Write page view record to DynamoDB
                      client_ip = self.client_address[0]
                      timestamp = datetime.utcnow().isoformat()
                      
                      try:
                          dynamodb = boto3.resource('dynamodb', region_name=REGION)
                          table = dynamodb.Table(DYNAMODB_TABLE)
                          table.put_item(
                              Item={
                                  'session_id': f"{timestamp}_{client_ip}",
                                  'timestamp': timestamp,
                                  'region': REGION,
                                  'client_ip': client_ip
                              }
                          )
                          db_status = "SUCCESS: Visited recorded in DynamoDB Global Table!"
                      except Exception as e:
                          db_status = f"ERROR: Failed writing to DB. Error: {str(e)}"
                          
                      html = f"""
                      <html>
                      <head>
                          <title>Global Active-Active Web App</title>
                          <style>
                              body {{ font-family: Arial, sans-serif; background: #0f172a; color: #f8fafc; text-align: center; padding-top: 100px; }}
                              .card {{ background: #1e293b; border-radius: 8px; max-width: 500px; margin: 0 auto; padding: 40px; box-shadow: 0 4px 6px -1px rgba(0, 0, 0, 0.1); }}
                              h1 {{ color: #38bdf8; }}
                              .badge {{ background: #0284c7; padding: 5px 10px; border-radius: 4px; font-weight: bold; }}
                          </style>
                      </head>
                      <body>
                          <div class="card">
                              <h1>Global Active-Active App</h1>
                              <p>Served from Region: <span class="badge">{REGION}</span></p>
                              <p>Local Instance Host: <strong>{socketserver.socket.gethostname()}</strong></p>
                              <p>Database Action: <span style="color: #4ade80;">{db_status}</span></p>
                          </div>
                      </body>
                      </html>
                      """
                      self.wfile.write(bytes(html, "utf-8"))

              with socketserver.TCPServer(("", PORT), MyHandler) as httpd:
                  print("serving at port", PORT)
                  httpd.serve_forever()
              PY_EOF

              # Run the python web server in background
              nohup python3 server.py > /dev/null 2>&1 &
              EOF
  )

  lifecycle {
    create_before_destroy = true
  }
}

# Auto Scaling Group (Primary)
resource "aws_autoscaling_group" "primary" {
  provider            = aws.primary
  name                = "${var.project_name}-primary-asg"
  vpc_zone_identifier = [aws_subnet.primary_private_a.id, aws_subnet.primary_private_b.id]
  target_group_arns   = [aws_lb_target_group.primary.arn]
  min_size            = 1
  max_size            = 2
  desired_capacity    = 1

  launch_template {
    id      = aws_launch_template.primary.id
    version = "$Latest"
  }

  tag {
    key                 = "Name"
    value               = "${var.project_name}-primary-app"
    propagate_at_launch = true
  }
}
