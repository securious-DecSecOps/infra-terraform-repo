#!/bin/bash
set -eux

dnf update -y

dnf install -y docker git jq unzip python3 python3-pip

systemctl enable docker
systemctl start docker

systemctl enable amazon-ssm-agent
systemctl start amazon-ssm-agent

cat <<'EOF' > /etc/motd
SecuBank CI / Supply Chain Server
- Docker
- Jenkins 예정
- Harbor 예정
- Trivy / SBOM / Checkov 예정
EOF