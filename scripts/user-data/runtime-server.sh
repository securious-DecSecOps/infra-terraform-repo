#!/bin/bash
set -eux

dnf update -y

dnf install -y git jq unzip curl

systemctl enable amazon-ssm-agent
systemctl start amazon-ssm-agent

cat <<'EOF' > /etc/motd
SecuBank Runtime Server
- k3s 예정
- ArgoCD 예정
- VulnBank Runtime 예정
EOF