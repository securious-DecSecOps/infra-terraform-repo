#!/bin/bash
set -euxo pipefail
# DefectDojo 전용 서버 부트스트랩 (EC2 첫 부팅 시 1회 실행)
# 로그 확인: SSM 접속 후  sudo cat /var/log/cloud-init-output.log

# --- swap 4GB (t3.medium 4GB RAM 메모리 쿠션, OOM 방지) ---
if ! swapon --show | grep -q /swapfile; then
  fallocate -l 4G /swapfile
  chmod 600 /swapfile
  mkswap /swapfile
  swapon /swapfile
  echo '/swapfile none swap sw 0 0' >> /etc/fstab
fi

# --- docker + docker compose v2 ---
dnf update -y
dnf install -y docker git
systemctl enable --now docker
usermod -aG docker ec2-user || true
mkdir -p /usr/local/lib/docker/cli-plugins
curl -SL https://github.com/docker/compose/releases/download/v2.29.7/docker-compose-linux-x86_64 \
  -o /usr/local/lib/docker/cli-plugins/docker-compose
chmod +x /usr/local/lib/docker/cli-plugins/docker-compose

# --- DefectDojo (공식 docker-compose) ---
cd /opt
git clone https://github.com/DefectDojo/django-DefectDojo.git
cd django-DefectDojo
# NOTE: DefectDojo는 빌드가 무겁다(t3.medium엔 부담). 가능하면 릴리스 이미지 사용 권장.
#       정확한 기동 절차는 버전마다 다를 수 있으니 DefectDojo 공식 문서 확인.
#       기본 절차:
docker compose up --no-deps -d || docker compose up -d
# 초기 admin 비밀번호는 initializer 로그에서 확인:
#   docker compose logs initializer 2>&1 | grep -i "admin password"
# UI 포트: 8080 (nginx). SSM 포트포워딩으로 접속:
#   aws ssm start-session --target <id> --document-name AWS-StartPortForwardingSession \
#     --parameters '{"portNumber":["8080"],"localPortNumber":["8080"]}'
