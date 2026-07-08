# Query the latest Amazon Linux 2023 AMI
data "aws_ami" "amazon_linux" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-2023.*-x86_64"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

# EC2 Launch Template defining configurations for scaled instances
resource "aws_launch_template" "web" {
  name_prefix   = "${var.project_name}-launch-template-"
  image_id      = data.aws_ami.amazon_linux.id
  instance_type = var.instance_type

  network_interfaces {
    associate_public_ip_address = false
    security_groups             = [aws_security_group.ec2.id]
  }

  # Shell script to install Apache and configure dynamic metadata serving
  user_data = base64encode(<<-EOF
              #!/bin/bash
              # Update system and install apache + postgresql client
              dnf update -y
              dnf install -y httpd postgresql15
              
              # Start web server
              systemctl start httpd
              systemctl enable httpd
              
              # Fetch instance metadata using IMDSv2
              TOKEN=$(curl -s -X PUT "http://169.254.169.254/latest/api/token" -H "X-aws-ec2-metadata-token-ttl-seconds: 21600")
              INSTANCE_ID=$(curl -s -H "X-aws-ec2-metadata-token: $TOKEN" http://169.254.169.254/latest/meta-data/instance-id)
              AVAIL_ZONE=$(curl -s -H "X-aws-ec2-metadata-token: $TOKEN" http://169.254.169.254/latest/meta-data/placement/availability-zone)
              LOCAL_IP=$(curl -s -H "X-aws-ec2-metadata-token: $TOKEN" http://169.254.169.254/latest/meta-data/local-ipv4)
              
              # Write custom landing page displaying metadata
              cat <<HTML > /var/www/html/index.html
              <!DOCTYPE html>
              <html lang="en">
              <head>
                <meta charset="UTF-8">
                <title>High Availability Cloud Architecture</title>
                <style>
                  body { font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif; background-color: #f0f2f5; margin: 0; padding: 50px 0; text-align: center; }
                  .container { max-width: 600px; margin: auto; background: white; padding: 40px; border-radius: 12px; box-shadow: 0 4px 15px rgba(0,0,0,0.05); }
                  h1 { color: #0070f3; font-size: 24px; margin-bottom: 20px; }
                  p { font-size: 16px; color: #4b5563; line-height: 1.6; margin: 8px 0; }
                  .badge { display: inline-block; background: #e0f2fe; color: #0369a1; padding: 4px 8px; border-radius: 6px; font-weight: 600; font-size: 14px; }
                </style>
              </head>
              <body>
                <div class="container">
                  <h1>Multi-Tier HA Architecture Status</h1>
                  <p>Success! This host is serving requests securely from a private subnet.</p>
                  <hr style="border: 0; border-top: 1px solid #e5e7eb; margin: 20px 0;">
                  <p><strong>Instance ID:</strong> <span class="badge">$INSTANCE_ID</span></p>
                  <p><strong>Availability Zone:</strong> <span class="badge">$AVAIL_ZONE</span></p>
                  <p><strong>Local IP:</strong> <span class="badge">$LOCAL_IP</span></p>
                </div>
              </body>
              </html>
              HTML
              EOF
  )

  lifecycle {
    create_before_destroy = true
  }

  tag_specifications {
    resource_type = "instance"
    tags = {
      Name = "${var.project_name}-web-server"
    }
  }
}

# Auto Scaling Group deploying instances in Private Subnets across Multi-AZs
resource "aws_autoscaling_group" "web" {
  name_prefix         = "${var.project_name}-asg-"
  vpc_zone_identifier = aws_subnet.private[*].id
  target_group_arns   = [aws_lb_target_group.web.arn]
  
  # Configure ASG size
  min_size            = 2
  max_size            = 4
  desired_capacity    = 2
  
  force_delete        = true
  health_check_type   = "ELB" # Trigger instance replacement if ALB health checks fail
  health_check_grace_period = 150

  launch_template {
    id      = aws_launch_template.web.id
    version = "$Latest"
  }

  lifecycle {
    create_before_destroy = true
  }
}
