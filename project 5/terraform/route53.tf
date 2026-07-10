# Lookup existing Route 53 Hosted Zone for domain (Only if domain_name is provided)
data "aws_route53_zone" "selected" {
  count        = var.domain_name != "" ? 1 : 0
  provider     = aws.primary
  name         = var.domain_name
  private_zone = false
}

# Health Check for Primary Load Balancer
resource "aws_route53_health_check" "primary" {
  count             = var.domain_name != "" ? 1 : 0
  provider          = aws.primary
  fqdn              = aws_lb.primary.dns_name
  port              = 80
  type              = "HTTP"
  resource_path     = "/"
  request_interval  = 30
  failure_threshold = 3

  tags = {
    Name = "${var.project_name}-primary-health-check"
  }
}

# Health Check for Secondary Load Balancer
resource "aws_route53_health_check" "secondary" {
  count             = var.domain_name != "" ? 1 : 0
  provider          = aws.primary
  fqdn              = aws_lb.secondary.dns_name
  port              = 80
  type              = "HTTP"
  resource_path     = "/"
  request_interval  = 30
  failure_threshold = 3

  tags = {
    Name = "${var.project_name}-secondary-health-check"
  }
}

# Route 53 Latency-Based Alias Record for Primary Region (us-east-1)
resource "aws_route53_record" "primary" {
  count    = var.domain_name != "" ? 1 : 0
  provider = aws.primary
  zone_id  = data.aws_route53_zone.selected[0].zone_id
  name     = "app.${var.domain_name}"
  type     = "A"

  set_identifier = "primary-us-east-1"

  latency_routing_policy {
    region = var.primary_region
  }

  alias {
    name                   = aws_lb.primary.dns_name
    zone_id                = aws_lb.primary.zone_id
    evaluate_target_health = true
  }

  health_check_id = aws_route53_health_check.primary[0].id
}

# Route 53 Latency-Based Alias Record for Secondary Region (us-west-2)
resource "aws_route53_record" "secondary" {
  count    = var.domain_name != "" ? 1 : 0
  provider = aws.primary
  zone_id  = data.aws_route53_zone.selected[0].zone_id
  name     = "app.${var.domain_name}"
  type     = "A"

  set_identifier = "secondary-us-west-2"

  latency_routing_policy {
    region = var.secondary_region
  }

  alias {
    name                   = aws_lb.secondary.dns_name
    zone_id                = aws_lb.secondary.zone_id
    evaluate_target_health = true
  }

  health_check_id = aws_route53_health_check.secondary[0].id
}
