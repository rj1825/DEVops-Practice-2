# Security Group for On-Premises Legacy Database Host
resource "aws_security_group" "onprem_db" {
  name        = "${var.project_name}-onprem-db-sg"
  description = "Allows SSH management and PGSQL ingress from Cloud VPC"
  vpc_id      = aws_vpc.onprem.id

  # Allow administrative SSH access (Bastion simulation)
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Allow PostgreSQL access ONLY from the target AWS Cloud VPC range (peering private route)
  ingress {
    from_port   = 5432
    to_port     = 5432
    protocol    = "tcp"
    cidr_blocks = [aws_vpc.cloud.cidr_block]
  }

  # Allow outbound traffic to download dependencies during bootstrap
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.project_name}-onprem-db-sg"
  }
}

# Fetch latest Ubuntu AMI
data "aws_ami" "ubuntu" {
  most_recent = true
  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }
  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
  owners = ["099720109477"] # Canonical
}

# EC2 Instance representing the Legacy Database Host
# Placed in the public subnet for ease of dependency installation, but PGSQL ingress restricted to private peering.
resource "aws_instance" "onprem_db_host" {
  ami                         = data.aws_ami.ubuntu.id
  instance_type               = "t3.micro"
  subnet_id                   = aws_subnet.onprem_public.id
  vpc_security_group_ids      = [aws_security_group.onprem_db.id]
  associate_public_ip_address = true

  # Bootstrapping legacy database: Install PostgreSQL and seed dummy records
  user_data = <<-EOF
              #!/bin/bash
              sudo apt-get update -y
              sudo apt-get install -y postgresql postgresql-contrib

              # Configure PostgreSQL to accept connections on all IP addresses
              sudo sed -i "s/#listen_addresses = 'localhost'/listen_addresses = '*'/g" /etc/postgresql/14/main/postgresql.conf
              
              # Add permissions for Cloud VPC CIDR (172.16.0.0/16) in pg_hba.conf
              echo "host all all 172.16.0.0/16 md5" | sudo tee -a /etc/postgresql/14/main/pg_hba.conf

              # Configure PostgreSQL for Logical Replication (AWS DMS Requirement)
              echo "wal_level = logical" | sudo tee -a /etc/postgresql/14/main/postgresql.conf
              echo "max_replication_slots = 10" | sudo tee -a /etc/postgresql/14/main/postgresql.conf
              echo "max_wal_senders = 10" | sudo tee -a /etc/postgresql/14/main/postgresql.conf

              # Restart service
              sudo systemctl restart postgresql

              # Create user and seed database
              sudo -u postgres psql -c "CREATE USER ${var.db_username} WITH PASSWORD '${var.db_password}' SUPERUSER;"
              sudo -u postgres psql -c "CREATE DATABASE legacy_db;"
              
              # Seed database table
              sudo -u postgres psql -d legacy_db -c "
              CREATE TABLE employees (
                  id SERIAL PRIMARY KEY,
                  name VARCHAR(100) NOT NULL,
                  role VARCHAR(100) NOT NULL,
                  hire_date DATE NOT NULL
              );
              INSERT INTO employees (name, role, hire_date) VALUES ('Alice Smith', 'Cloud Architect', '2023-01-15');
              INSERT INTO employees (name, role, hire_date) VALUES ('Bob Jones', 'DevOps Specialist', '2023-06-20');
              INSERT INTO employees (name, role, hire_date) VALUES ('Charlie Brown', 'Security Analyst', '2024-03-10');
              "
              EOF

  tags = {
    Name = "${var.project_name}-onprem-legacy-db"
  }
}
