# Security Groups (Secondary)
resource "aws_security_group" "secondary_alb" {
  provider    = aws.secondary
  name        = "${var.project_name}-secondary-alb-sg"
  description = "Allows public HTTP ingress"
  vpc_id      = aws_vpc.secondary.id

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

resource "aws_security_group" "secondary_app" {
  provider    = aws.secondary
  name        = "${var.project_name}-secondary-app-sg"
  description = "Allows ingress from ALB only"
  vpc_id      = aws_vpc.secondary.id

  ingress {
    from_port       = 80
    to_port         = 80
    protocol        = "tcp"
    security_groups = [aws_security_group.secondary_alb.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# Application Load Balancer (Secondary)
resource "aws_lb" "secondary" {
  provider           = aws.secondary
  name               = "${var.project_name}-secondary-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.secondary_alb.id]
  subnets            = [aws_subnet.secondary_public_a.id, aws_subnet.secondary_public_b.id]
}

resource "aws_lb_target_group" "secondary" {
  provider    = aws.secondary
  name        = "${var.project_name}-secondary-tg"
  port        = 80
  protocol    = "HTTP"
  vpc_id      = aws_vpc.secondary.id
  target_type = "instance"

  health_check {
    path                = "/"
    interval            = 15
    timeout             = 3
    healthy_threshold   = 2
    unhealthy_threshold = 2
  }
}

resource "aws_lb_listener" "secondary" {
  provider          = aws.secondary
  load_balancer_arn = aws_lb.secondary.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.secondary.arn
  }
}

# IAM Instance Profile in Secondary Region (reuses the global IAM role)
resource "aws_iam_instance_profile" "secondary" {
  provider = aws.secondary
  name     = "${var.project_name}-secondary-instance-profile"
  role     = aws_iam_role.app_role.name
}

# Fetch latest Ubuntu AMI in Secondary region
data "aws_ami" "secondary_ubuntu" {
  provider    = aws.secondary
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

# Launch Template (Secondary)
resource "aws_launch_template" "secondary" {
  provider      = aws.secondary
  name_prefix   = "${var.project_name}-secondary-lt-"
  image_id      = data.aws_ami.secondary_ubuntu.id
  instance_type = "t3.micro"

  iam_instance_profile {
    arn = aws_iam_instance_profile.secondary.arn
  }

  network_interfaces {
    associate_public_ip_address = false
    security_groups             = [aws_security_group.secondary_app.id]
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
              REGION = "us-west-2"
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
                              h1 {{ color: #10b981; }} /* Green title for US-WEST-2 */
                              .badge {{ background: #047857; padding: 5px 10px; border-radius: 4px; font-weight: bold; }}
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

# Auto Scaling Group (Secondary)
resource "aws_autoscaling_group" "secondary" {
  provider            = aws.secondary
  name                = "${var.project_name}-secondary-asg"
  vpc_zone_identifier = [aws_subnet.secondary_private_a.id, aws_subnet.secondary_private_b.id]
  target_group_arns   = [aws_lb_target_group.secondary.arn]
  min_size            = 1
  max_size            = 2
  desired_capacity    = 1

  launch_template {
    id      = aws_launch_template.secondary.id
    version = "$Latest"
  }

  tag {
    key                 = "Name"
    value               = "${var.project_name}-secondary-app"
    propagate_at_launch = true
  }
}
