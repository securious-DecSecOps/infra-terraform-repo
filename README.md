# Infrastructure (Terraform) — DevSecOps Golden Path

[SecuBank DevSecOps Golden Path](https://securious-decsecops.github.io/secubank-docs/)의 AWS 인프라를 코드로 정의한다. `terraform apply` + EC2 user-data 부트스트랩으로 CI / 런타임 / 증적 환경을 1회에 세운다.

## 토폴로지

`ap-northeast-2`, 단일 VPC(`10.0.0.0/16`) + Public Subnet(`10.0.1.0/24`), **SSH 미사용 — SSM Session Manager로만 접속**.

| EC2 | 역할 | 부트스트랩 |
| --- | --- | --- |
| CI / Supply Chain (t3.xlarge) | Jenkins · Harbor · SonarQube · 스캐너 6종 | `scripts/user-data/ci-server.sh` |
| Runtime (t3.xlarge, k3s) | k3s · Cilium/Hubble · Falco · kube-bench · ArgoCD | `scripts/user-data/runtime-server.sh` |
| DefectDojo (t3.medium) | ASOC 증적 통합 | `scripts/user-data/defectdojo-server.sh` |

## 구조

```
modules/network/          # VPC · Subnet · IGW · Route
modules/iam/              # EC2용 SSM 역할(SSH 키 없음)
modules/security-groups/  # 역할별 보안그룹 (인바운드는 VPC/관리자 IP만)
modules/ec2/              # EC2 인스턴스 + user-data 주입
envs/dev/                 # 환경 조립 (main/variables/outputs/providers)
scripts/user-data/        # 부팅 시 1회 실행되는 스택 설치 스크립트
```

## 사용

```bash
cd envs/dev
cp terraform.tfvars.example terraform.tfvars   # allowed_admin_cidr 등 설정
terraform init
terraform plan
terraform apply

terraform output           # instance id, ssm 접속 명령, URL
# 접속: aws ssm start-session --target <instance-id>
```

## 보안 기본값

- `allowed_admin_cidr`는 절대 `0.0.0.0/0` 금지 — 취약 워크로드가 인터넷에 노출된다. SSM 포트포워딩 사용 시 `10.0.0.0/16`, 직접 접속 시 본인 IP `/32`만.
- 인스턴스 접속은 SSM(포트 22 비개방). IAM은 `AmazonSSMManagedInstanceCore` 최소 권한 기준.
- PoC용 자격증명은 운영 전 반드시 교체/폐기.

## License

Apache License 2.0 — `LICENSE` 참고.
