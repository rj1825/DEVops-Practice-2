# Cloud Security, Compliance & Auto-Remediator

[![Security Remediator CI](https://github.com/your-github-username/devops-portfolio-project-3/actions/workflows/ci.yaml/badge.svg)](https://github.com/your-github-username/devops-portfolio-project-3/actions)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![AWS](https://img.shields.io/badge/AWS-%23FF9900.svg?style=flat&logo=amazon-aws&logoColor=white)](https://aws.amazon.com/)
[![Terraform](https://img.shields.io/badge/terraform-%235835CC.svg?style=flat&logo=terraform&logoColor=white)](https://www.terraform.io/)
[![Python](https://img.shields.io/badge/python-3670A0?style=flat&logo=python&logoColor=ffdd54)](https://www.python.org/)

This repository implements an **Event-Driven Cloud Security Remediator** on AWS using Terraform and Python. It showcases DevSecOps best practices, real-time posture management (CSPM), automated incident remediation, and closed-loop alerting.

---

## 🏗️ Architecture Layout

The system intercepts API calls recorded in CloudTrail in real-time, filters them using EventBridge rules, and triggers a Python Lambda function to instantly revert security policy violations.

```mermaid
graph TD
    User[User / Attacker] -->|1. Creates Public S3 or Insecure SG| AWS[AWS Resources]
    AWS -->|2. Logs API Call| CloudTrail[AWS CloudTrail]
    CloudTrail -->|3. Forwards Event| EventBridge[EventBridge Event Bus]
    
    subgraph Detection & Filtering
        EventBridge -->|4. Filters Match API| Rule1[S3 Audit Rule]
        EventBridge -->|4. Filters Match API| Rule2[Security Group Audit Rule]
    end
    
    subgraph Compute & Auto-Remediation
        Rule1 -->|5. Triggers| Lambda[Python Remediator Lambda]
        Rule2 -->|5. Triggers| Lambda
        Lambda -->|6. PUT PublicAccessBlock| AWS
        Lambda -->|6. RevokeSecurityGroupIngress| AWS
    end
    
    subgraph Operations Alerting
        Lambda -->|7. Publish Alert| SNS[SNS Alerts Topic]
        SNS -->|8. Dispatch Email| Admin[Security Operations Team]
    end
```

---

## 🌟 Key DevSecOps Highlights

*   **Real-Time Active Posture Management:** Traditional security audits run periodically (e.g. daily or weekly), leaving large windows of vulnerability. This event-driven design **closes security violations in under 5 seconds** from the moment of creation.
*   **Principle of Least Privilege IAM:** The Lambda function runs with a highly restricted role: it has read/write privileges *only* for S3 public access blocks, EC2 security group ingress rules, and SNS publishing. It cannot terminate instances, access databases, or write other IAM roles.
*   **Targeted Remediation:** The EC2 SG remediator parses specific ingress rules. If a Security Group has multiple legitimate rules (e.g. port 80/443 open) but adds one rule for port 22 open to `0.0.0.0/0`, the Lambda **only revokes the insecure SSH rule**, leaving other rules untouched.
*   **S3 Guardrails Enforcement:** The S3 remediator monitors bucket actions. If a bucket's Public Access Block configuration is deleted or modified to allow public traffic, the Lambda instantly puts a full Public Access Block in place.
*   **Closed-Loop Operations Alerting:** Once a remediation occurs, the Lambda publishes details (violator user, event time, resource ID, action taken) to an SNS topic, notifying the security team via email *after* the risk is already mitigated.

---

## 🚀 Deployment Guide

### Prerequisites
*   An active AWS Account.
*   AWS CLI installed and configured (`aws configure`).
*   Terraform installed (`>= 1.5.0`).
*   **AWS CloudTrail enabled** (required to send API events to EventBridge).

### 1. Initialize and Validate Code
Clone the repository and navigate to the `terraform/` directory:
```bash
cd terraform
terraform init
terraform validate
```

### 2. Deploy to AWS
Apply the configuration to provision the pipeline:
```bash
terraform apply -auto-approve
```
*Note: Make sure to override the `alert_email` variable (either via `-var="alert_email=your-email@example.com"` or in a `terraform.tfvars` file) to receive actual alarm emails. AWS will send a confirmation email; click **Confirm Subscription** in the email.*

---

## 🧪 How to Test and Verify

### 1. Test S3 Auto-Remediation
1. Create a public S3 bucket (or edit an existing one to remove the Public Access Block configuration) in your AWS Console.
2. Within 5 seconds, refresh the S3 bucket page.
3. **Expected Result:** The "Block all public access" configuration will automatically be set back to **Enabled (Locked)**.
4. Check your inbox: you will receive a security alert email detailing the S3 bucket remediation.

### 2. Test Security Group Auto-Remediation
1. Open any EC2 Security Group in your AWS Console.
2. Add an Ingress Rule allowing **SSH (Port 22)** from source **`0.0.0.0/0`** (Anywhere-IPv4) and click Save.
3. Refresh the Security Group page.
4. **Expected Result:** The violating `0.0.0.0/0` ingress rule will disappear from the list.
5. Check your inbox: you will receive an email notification detailing the Security Group ID, the rule revoked, and the actor who created it.

### 3. Check CloudWatch Execution Logs
To inspect how the Lambda function executed:
1. Open **AWS CloudWatch** in your console.
2. Go to **Log Groups** -> `/aws/lambda/security-remediator-function`.
3. View the latest stream to see log statements like:
   `[WARNING] Vulnerability found in Security Group sg-...! Open SSH (0.0.0.0/0) detected. Remediating...`

---

## 🧹 Teardown
To destroy all provisioned AWS resources and avoid billing charges:
```bash
terraform destroy -auto-approve
```
