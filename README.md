# SecuBank AWS Terraform Infrastructure

SecuBank 프로젝트의 AWS 기반 인프라를 Terraform으로 생성하기 위한 레포지토리입니다.

이 레포는 애플리케이션 코드나 Kubernetes manifest를 관리하는 곳이 아니라, AWS 위에 SecuBank 실습 환경을 올리기 위한 **기반 인프라**를 코드로 관리합니다.

---

## 1. 레포 역할

SecuBank 프로젝트는 크게 다음 레포로 나뉩니다.

| 레포 | 역할 |
|---|---|
| `app-source-repo` | VulnBank 애플리케이션 소스 코드 |
| `devsecops-path` | Jenkins 기반 빌드/스캔/증적/정책 파이프라인 |
| `gitops-manifest-repo` | ArgoCD가 바라보는 Kubernetes 배포 manifest |
| `infra-terraform-repo` | AWS VPC, EC2, Security Group, IAM, SSM 접속 구성 |

이 레포의 목적은 다음과 같습니다.

- AWS 인프라를 콘솔 수동 생성이 아닌 Terraform 코드로 관리
- 동일한 인프라를 반복 생성/삭제 가능하게 구성
- CI 서버와 Runtime 서버의 역할을 분리
- SSH 키 공유 없이 SSM Session Manager 기반 접속 사용
- 실습 종료 후 비용 절감을 위해 인프라 삭제 또는 EC2 중지 가능

---

## 2. 현재 생성되는 인프라

`envs/dev` 기준으로 `terraform apply`를 실행하면 다음 리소스가 생성됩니다.

| 구분 | 리소스 | 설명 |
|---|---|---|
| Network | VPC | `10.0.0.0/16` 대역의 SecuBank 전용 VPC |
| Network | Public Subnet | EC2 2대가 배치되는 public subnet |
| Network | Internet Gateway | 외부 인터넷 통신을 위한 IGW |
| Network | Route Table | public subnet의 기본 라우팅 |
| Security | CI Security Group | Jenkins/Harbor 접근 및 outbound 허용 |
| Security | Runtime Security Group | k3s API, NodePort 접근 및 outbound 허용 |
| IAM | EC2 SSM Role | EC2가 SSM에 등록되기 위한 IAM Role |
| IAM | Instance Profile | EC2에 SSM Role을 연결하기 위한 Profile |
| Compute | EC2 CI 서버 | Jenkins, Harbor, Trivy, SBOM, Checkov 예정 |
| Compute | EC2 Runtime 서버 | k3s, ArgoCD, VulnBank 배포 예정 |

---

## 3. EC2 역할

### 3.1 EC2-1: Runtime / Deploy 서버

Terraform resource 이름: `runtime`

역할:

- k3s Cluster 운영
- ArgoCD 설치 예정
- VulnBank Web Pod 배포 예정
- VulnBank Postgres Pod 배포 예정
- Kubernetes Service / NodePort 제공 예정

예상 구성:

```text
k3s
ArgoCD
VulnBank Web Pod
VulnBank Postgres Pod
Service / NodePort
```

---

### 3.2 EC2-2: CI / Supply Chain 서버

Terraform resource 이름: `ci`

역할:

- Jenkins 기반 CI 파이프라인 실행
- Docker image build
- Trivy image scan
- SBOM 생성
- Checkov manifest scan
- Harbor registry push
- GitOps repo image tag 수정

예상 구성:

```text
Docker
Jenkins
Harbor
Trivy
Syft or CycloneDX
Checkov
kubectl
helm
git
jq/yq
```

---

## 4. 디렉터리 구조

```text
infra-terraform-repo/
├── README.md
├── .gitignore
├── envs/
│   └── dev/
│       ├── main.tf
│       ├── providers.tf
│       ├── versions.tf
│       ├── variables.tf
│       ├── outputs.tf
│       └── terraform.tfvars.example
├── modules/
│   ├── network/
│   ├── security-groups/
│   ├── iam/
│   └── ec2/
└── scripts/
    └── user-data/
        ├── ci-server.sh
        └── runtime-server.sh
```

---

## 5. 사전 준비

### 5.1 AWS CLI Profile 설정

이 프로젝트는 AWS CLI profile 이름을 `secubank`로 사용하는 것을 기준으로 합니다.

```bash
aws configure --profile secubank
```

입력 예시:

```text
AWS Access Key ID: 발급받은 Access Key
AWS Secret Access Key: 발급받은 Secret Key
Default region name: ap-northeast-2
Default output format: json
```

설정 확인:

```bash
aws sts get-caller-identity --profile secubank
```

정상이라면 프로젝트 AWS 계정 ID가 출력되어야 합니다.

```text
Account: <프로젝트 AWS Account ID>
Arn: arn:aws:iam::<Account ID>:user/<UserName>
```

현재 프로젝트 기본 리전은 서울 리전입니다.

```text
ap-northeast-2
```

---

### 5.2 Session Manager Plugin 설치

이 프로젝트는 EC2 접속에 SSH가 아니라 AWS Systems Manager Session Manager를 사용합니다.

로컬 WSL/Ubuntu 환경에서 SSM 접속을 하려면 Session Manager Plugin이 필요합니다.

```bash
cd ~

curl "https://s3.amazonaws.com/session-manager-downloads/plugin/latest/ubuntu_64bit/session-manager-plugin.deb" -o "session-manager-plugin.deb"

sudo dpkg -i session-manager-plugin.deb
```

설치 확인:

```bash
session-manager-plugin
```

정상 메시지 예시:

```text
The Session Manager plugin is installed successfully. Use the AWS CLI to start a session.
```

---

## 6. Terraform 실행 방법

### 6.1 작업 디렉터리 이동

```bash
cd ~/secubank-devsecops/infra-terraform-repo/envs/dev
```

---

### 6.2 tfvars 파일 생성

```bash
cp terraform.tfvars.example terraform.tfvars
```

`terraform.tfvars`는 개인 설정이 들어가는 파일이므로 GitHub에 올리지 않습니다.

---

### 6.3 관리자 접근 IP 설정

본인 공인 IP 확인:

```bash
curl ifconfig.me
```

`terraform.tfvars`에서 아래 값을 수정합니다.

```hcl
allowed_admin_cidr = "본인공인IP/32"
```

예시:

```hcl
allowed_admin_cidr = "211.237.242.58/32"
```

이 값은 Jenkins UI, Harbor UI, VulnBank NodePort 접근을 허용할 IP 대역입니다.

---

### 6.4 Terraform 초기화

```bash
terraform init
```

---

### 6.5 포맷 정리

```bash
terraform fmt -recursive
```

---

### 6.6 문법 검증

```bash
terraform validate
```

---

### 6.7 생성 계획 확인

```bash
terraform plan
```

생성 예정 리소스가 다음과 같이 표시되면 정상입니다.

```text
Plan: 20 to add, 0 to change, 0 to destroy.
```

---

### 6.8 인프라 생성

```bash
terraform apply
```

확인 메시지가 나오면 아래 값을 입력합니다.

```text
yes
```

---

## 7. Terraform Output

`terraform apply` 완료 후 다음 값들이 출력됩니다.

| Output | 의미 |
|---|---|
| `ci_instance_id` | CI 서버 EC2 instance ID |
| `runtime_instance_id` | Runtime 서버 EC2 instance ID |
| `ci_public_ip` | CI 서버 public IP |
| `ci_private_ip` | CI 서버 private IP |
| `runtime_public_ip` | Runtime 서버 public IP |
| `runtime_private_ip` | Runtime 서버 private IP |
| `jenkins_url` | Jenkins 접속 URL 예정 |
| `harbor_url` | Harbor 접속 URL 예정 |
| `vulnbank_nodeport_url` | VulnBank NodePort 접속 URL 예정 |
| `ssm_connect_ci` | CI 서버 SSM 접속 명령어 |
| `ssm_connect_runtime` | Runtime 서버 SSM 접속 명령어 |

주의: 현재 단계에서는 Jenkins, Harbor, k3s, ArgoCD가 아직 설치되지 않았을 수 있습니다.  
따라서 `jenkins_url`, `harbor_url`, `vulnbank_nodeport_url`은 인프라 생성 직후 바로 접속되지 않을 수 있습니다.

---

## 8. EC2 접속 방법

이 프로젝트는 SSH key pair를 사용하지 않고 SSM Session Manager로 접속합니다.

### 8.1 CI 서버 접속

```bash
aws ssm start-session --target <ci_instance_id> --profile secubank
```

예시:

```bash
aws ssm start-session --target i-xxxxxxxxxxxxxxxxx --profile secubank
```

---

### 8.2 Runtime 서버 접속

```bash
aws ssm start-session --target <runtime_instance_id> --profile secubank
```

예시:

```bash
aws ssm start-session --target i-yyyyyyyyyyyyyyyyy --profile secubank
```

접속 성공 시 다음과 같은 프롬프트가 표시됩니다.

```text
Starting session with SessionId: ...
sh-5.2$
```

SSM 세션 종료:

```bash
exit
```

---

## 9. 비용 관리: stop과 destroy 차이

### 9.1 terraform destroy

```bash
terraform destroy
```

`terraform destroy`는 Terraform으로 생성한 인프라를 삭제합니다.

삭제 대상:

- EC2
- EBS root volume
- VPC
- Subnet
- Internet Gateway
- Route Table
- Security Group
- IAM Role / Instance Profile

주의:

- EC2 안에 수동으로 설치한 Jenkins, Harbor, k3s, ArgoCD 설정도 모두 사라집니다.
- 현재 EC2 root volume은 `delete_on_termination = true`로 설정되어 있으므로 destroy 시 볼륨도 삭제됩니다.
- 완전히 재현 가능한 상태가 아니라면 운영 중인 서버에는 destroy를 사용하지 않습니다.

사용 상황:

```text
아직 서버에 중요한 설치물이 없을 때
실습 검증만 하고 비용을 최소화하고 싶을 때
처음부터 다시 인프라를 생성해도 되는 경우
```

---

### 9.2 EC2 stop/start

EC2를 중지하면 인스턴스 실행 비용은 줄일 수 있지만, EBS 볼륨 비용은 계속 발생할 수 있습니다.

사용 상황:

```text
Jenkins/Harbor/k3s/ArgoCD를 설치해둔 상태
설정과 데이터를 유지하고 싶은 상태
다음 실습 때 이어서 사용해야 하는 경우
```

주의:

- EC2를 stop 후 start하면 public IP가 바뀔 수 있습니다.
- public IP가 바뀌면 Jenkins/Harbor/NodePort URL도 바뀝니다.
- 다시 접속 주소는 Terraform output 또는 AWS Console에서 확인해야 합니다.

---

## 10. 운영 기준

현재 단계의 권장 운영 기준은 다음과 같습니다.

| 상황 | 권장 방식 |
|---|---|
| 인프라 생성 테스트만 한 경우 | `terraform destroy` |
| 서버에 Jenkins/Harbor/k3s를 수동 설치한 경우 | EC2 stop/start |
| 설치 과정이 user-data 또는 script로 자동화된 경우 | destroy 후 재생성 가능 |
| 장기간 사용하지 않을 경우 | destroy 권장 |
| 다음 날 바로 이어서 실습할 경우 | stop 권장 |

---

## 11. 보안그룹 포트 기준

현재 Terraform에서는 다음 접근을 허용합니다.

| 대상 | 포트 | 허용 대상 | 설명 |
|---|---:|---|---|
| CI 서버 | 8083 | `allowed_admin_cidr` | Jenkins UI 예정 |
| CI 서버 | 8082 | `allowed_admin_cidr` | Harbor UI 예정 |
| CI 서버 | 8082 | Runtime SG | Runtime 서버가 Harbor image pull |
| Runtime 서버 | 6443 | CI SG | CI 서버가 k3s API 접근 |
| Runtime 서버 | 30080 | `allowed_admin_cidr` | VulnBank NodePort 예정 |
| CI/Runtime | outbound all | `0.0.0.0/0` | 패키지 설치 및 외부 통신 |

SSH 22번 포트는 열지 않습니다.  
EC2 접속은 SSM Session Manager를 사용합니다.

---

## 12. 현재 완료된 것

현재 완료된 검증 항목:

- Terraform init 성공
- Terraform validate 성공
- Terraform apply 성공
- VPC/Subnet/IGW/Route Table 생성 확인
- Security Group 생성 확인
- IAM Role / Instance Profile 생성 확인
- EC2 2대 생성 확인
- CI 서버 SSM 접속 확인
- Runtime 서버 SSM 접속 확인

---

## 13. 앞으로 할 일

### 13.1 README 및 Terraform 코드 정리

- 현재 Terraform 코드 GitHub push
- 팀원이 따라 할 수 있도록 README 작성
- `.gitignore` 점검
- `terraform.tfvars`와 `terraform.tfstate`가 올라가지 않도록 확인

---

### 13.2 설치 자동화 방향 결정

다음 항목을 수동 설치할지, 스크립트화할지 결정합니다.

CI 서버:

- Jenkins
- Harbor
- Trivy
- Syft 또는 CycloneDX
- Checkov
- kubectl
- helm

Runtime 서버:

- k3s
- ArgoCD
- namespace 구성
- GitOps repo 연동

---

### 13.3 GitOps / CI 연결

- Jenkins에서 `app-source-repo` checkout
- Docker build
- Harbor push
- GitOps repo image tag 수정
- ArgoCD sync
- Runtime 배포 확인

---

## 14. 주의사항

다음 파일은 GitHub에 올리지 않습니다.

```text
terraform.tfvars
*.tfstate
*.tfstate.*
.terraform/
*.tfplan
```

다음 파일은 올려도 됩니다.

```text
terraform.tfvars.example
.terraform.lock.hcl
```

`.terraform.lock.hcl`은 Terraform provider 버전 고정을 위해 커밋하는 것을 권장합니다.

---

## 15. 기본 명령어 요약

### 15.1 인프라 생성

```bash
cd ~/secubank-devsecops/infra-terraform-repo/envs/dev

export AWS_PROFILE=secubank

terraform init
terraform fmt -recursive
terraform validate
terraform plan
terraform apply
```

---

### 15.2 SSM 접속

```bash
aws ssm start-session --target <instance-id> --profile secubank
```

---

### 15.3 인프라 삭제

```bash
terraform destroy
```

---

### 15.4 상태 확인

```bash
terraform state list
```

---

## 16. 현재 단계에서의 권장 작업 흐름

지금 단계에서는 서버에 Jenkins/Harbor/k3s를 바로 수동 설치하기보다, 먼저 Terraform 코드와 README를 정리해서 GitHub에 push하는 것을 우선합니다.

권장 순서:

```text
1. README 작성
2. 현재 Terraform 코드 push
3. CI/Runtime 설치 스크립트 분리 작성
4. 다시 terraform apply
5. SSM 접속
6. 설치 스크립트 실행
7. Jenkins/Harbor/k3s 설치 검증
```

이렇게 진행하면 인프라를 삭제하더라도 설치 절차를 다시 재현할 수 있습니다.

---

## 17. Git 커밋 예시

README 작성 후 다음 명령어로 커밋합니다.

```bash
cd ~/secubank-devsecops/infra-terraform-repo

git add README.md
git add .gitignore
git add envs/dev/*.tf
git add envs/dev/terraform.tfvars.example
git add envs/dev/.terraform.lock.hcl
git add modules
git add scripts

git status
git commit -m "Add AWS Terraform infrastructure guide"
git push origin main
```

커밋 전에 반드시 `terraform.tfvars`, `terraform.tfstate`, `.terraform/`이 포함되지 않았는지 확인합니다.
