#!/bin/bash
set -euxo pipefail

# SecuBank Runtime 서버 부트스트랩 (EC2 첫 부팅 시 1회 실행)
# 로그 확인: SSM 접속 후 sudo cat /var/log/cloud-init-output.log

log() {
  echo "[runtime-server] $*"
}

HARBOR_REGISTRY="10.0.1.10:8082"
GITOPS_REPO_RAW="https://raw.githubusercontent.com/securious-DecSecOps/gitops-manifest-repo/main"

log "Installing base packages"
dnf update -y
dnf install -y git jq unzip tar curl
systemctl enable --now amazon-ssm-agent

log "Configuring k3s registry mirror for Harbor before k3s starts"
mkdir -p /etc/rancher/k3s
cat > /etc/rancher/k3s/registries.yaml <<EOF
mirrors:
  "${HARBOR_REGISTRY}":
    endpoint:
      - "http://${HARBOR_REGISTRY}"
configs:
  "${HARBOR_REGISTRY}":
    auth:
      username: admin
      password: Harbor12345
    tls:
      insecure_skip_verify: true
EOF
cat /etc/rancher/k3s/registries.yaml

log "Installing k3s without flannel, network-policy, or traefik; Cilium will provide CNI"
curl -sfL https://get.k3s.io | INSTALL_K3S_EXEC="--flannel-backend=none --disable-network-policy --disable=traefik" sh -

export KUBECONFIG=/etc/rancher/k3s/k3s.yaml

log "Installing latest compatible Cilium CLI"
CILIUM_CLI_VER="$(curl -s https://raw.githubusercontent.com/cilium/cilium-cli/main/stable.txt)"
curl -L --fail -o /tmp/cilium.tgz "https://github.com/cilium/cilium-cli/releases/download/${CILIUM_CLI_VER}/cilium-linux-amd64.tar.gz"
tar xzf /tmp/cilium.tgz -C /usr/local/bin
rm -f /tmp/cilium.tgz

log "Installing Cilium with Hubble relay and UI"
cilium install \
  --set hubble.relay.enabled=true \
  --set hubble.ui.enabled=true
cilium status --wait
k3s kubectl get nodes

log "Installing ArgoCD"
k3s kubectl create namespace argocd --dry-run=client -o yaml | k3s kubectl apply -f -
k3s kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
k3s kubectl -n argocd rollout status deploy/argocd-server --timeout=300s

log "Applying GitOps root application"
k3s kubectl apply -n argocd -f "${GITOPS_REPO_RAW}/argocd/root/aws-dev.yaml"

log "Runtime bootstrap complete"
cat <<'EOF' > /etc/motd
SecuBank Runtime Server
- k3s (flannel=none, Cilium CNI)
- Cilium + Hubble
- ArgoCD
- VulnBank Runtime via GitOps root Application
EOF
