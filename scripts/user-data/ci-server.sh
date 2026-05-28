#!/bin/bash
set -euxo pipefail
# SecuBank CI / Supply Chain 서버 부트스트랩 (EC2 첫 부팅 시 1회 실행)
# 로그 확인: SSM 접속 후  sudo cat /var/log/cloud-init-output.log

# --- 기본 패키지 + docker ---
dnf update -y
dnf install -y docker git jq unzip tar python3 python3-pip
systemctl enable --now docker
systemctl enable --now amazon-ssm-agent

# --- docker compose 플러그인 (AL2023 docker엔 compose 미포함) ---
COMPOSE_VER="v2.29.7"
mkdir -p /usr/local/lib/docker/cli-plugins
if ! docker compose version >/dev/null 2>&1; then
  curl -fsSL "https://github.com/docker/compose/releases/download/${COMPOSE_VER}/docker-compose-linux-x86_64" \
    -o /usr/local/lib/docker/cli-plugins/docker-compose
  chmod +x /usr/local/lib/docker/cli-plugins/docker-compose
fi

# --- 사설 IP (IMDSv2) — Harbor hostname 용, 재생성 시에도 자동으로 맞음 ---
TOKEN=$(curl -sX PUT "http://169.254.169.254/latest/api/token" -H "X-aws-ec2-metadata-token-ttl-seconds: 300")
PRIV_IP=$(curl -s -H "X-aws-ec2-metadata-token: ${TOKEN}" http://169.254.169.254/latest/meta-data/local-ipv4)

# --- docker insecure-registries (http Harbor push/pull용; Harbor 설치 前 설정해 재시작 bounce 회피) ---
mkdir -p /etc/docker
cat > /etc/docker/daemon.json <<EOF
{
  "insecure-registries": ["${PRIV_IP}:8082"]
}
EOF
systemctl restart docker

# --- Harbor (사설IP:8082, http, https 비활성) ---
HARBOR_VER="v2.14.4"            # 검증된 버전 고정
HARBOR_HTTP_PORT="8082"
HARBOR_ADMIN_PW="Harbor12345"   # PoC용. 운영 전 반드시 교체/폐기
if [ ! -d /opt/harbor ]; then
  curl -fL -o /opt/harbor-offline.tgz \
    "https://github.com/goharbor/harbor/releases/download/${HARBOR_VER}/harbor-offline-installer-${HARBOR_VER}.tgz"
  tar xzf /opt/harbor-offline.tgz -C /opt
fi
cd /opt/harbor
cp -f harbor.yml.tmpl harbor.yml
sed -i "s/^hostname:.*/hostname: ${PRIV_IP}/" harbor.yml
sed -i "s/^  port: 80$/  port: ${HARBOR_HTTP_PORT}/" harbor.yml
sed -i '/^https:/,/^  private_key:/ s/^/#/' harbor.yml
sed -i "s/^harbor_admin_password:.*/harbor_admin_password: ${HARBOR_ADMIN_PW}/" harbor.yml
./install.sh

# --- Jenkins (8083) — Java 21 필수 (Jenkins 2.555+는 Java 17 불가) ---
dnf install -y java-21-amazon-corretto wget
wget -q -O /etc/yum.repos.d/jenkins.repo https://pkg.jenkins.io/redhat-stable/jenkins.repo
rpm --import https://pkg.jenkins.io/redhat-stable/jenkins.io-2023.key
dnf install -y jenkins
JAVA21=$(ls -d /usr/lib/jvm/java-21-amazon-corretto* 2>/dev/null | head -1)
mkdir -p /etc/systemd/system/jenkins.service.d
cat > /etc/systemd/system/jenkins.service.d/override.conf <<EOF
[Service]
Environment="JENKINS_PORT=8083"
Environment="JAVA_HOME=${JAVA21}"
EOF
usermod -aG docker jenkins          # 파이프라인이 호스트 docker로 이미지 빌드
systemctl daemon-reload
systemctl enable --now jenkins

# --- 보안 스캐너 CLI (파이프라인이 호출) ---
BIN=/usr/local/bin
# trivy (이미지/SBOM 취약점)
curl -sfL https://raw.githubusercontent.com/aquasecurity/trivy/main/contrib/install.sh | sh -s -- -b "$BIN"
# syft (SBOM 생성)
curl -sSfL https://raw.githubusercontent.com/anchore/syft/main/install.sh | sh -s -- -b "$BIN"
# cosign (이미지 서명/검증)
curl -sSfLo "$BIN/cosign" https://github.com/sigstore/cosign/releases/latest/download/cosign-linux-amd64
chmod +x "$BIN/cosign"
# gitleaks (시크릿 스캔)
GL_VER=$(curl -s https://api.github.com/repos/gitleaks/gitleaks/releases/latest | grep -oP '"tag_name": "v\K[^"]+')
curl -sSfL -o /tmp/gitleaks.tgz "https://github.com/gitleaks/gitleaks/releases/download/v${GL_VER}/gitleaks_${GL_VER}_linux_x64.tar.gz"
tar xzf /tmp/gitleaks.tgz -C "$BIN" gitleaks
chmod +x "$BIN/gitleaks"
# kubescape (K8s misconfig: NSA/MITRE/CIS)
curl -s https://raw.githubusercontent.com/kubescape/kubescape/master/install.sh | /bin/bash || true
# checkov (IaC misconfig) — 시스템 RPM 파이썬 충돌 회피 위해 전용 venv 격리
dnf install -y python3.11
python3.11 -m venv /opt/checkov-venv
/opt/checkov-venv/bin/pip install --upgrade pip
/opt/checkov-venv/bin/pip install checkov
ln -sf /opt/checkov-venv/bin/checkov "$BIN/checkov"

# --- motd ---
cat <<'EOF' > /etc/motd
SecuBank CI / Supply Chain Server
- Docker + compose
- Harbor (8082)  admin / Harbor12345
- Jenkins (8083)  초기 admin pw: /var/lib/jenkins/secrets/initialAdminPassword
- Scanners: trivy / syft / cosign / gitleaks / kubescape / checkov
EOF
