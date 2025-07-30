
# 🛠️ Cloud Custodian - 위반 항목 대응 자동화

**정책 위반 항목 대응 자동화 시스템을 위한 Cloud Custodian 정책 작성 및 AWS 환경 구성**


## 📁 디렉토리 구성

### [`custodian-terraform-02/`](https://github.com/WHS3-CloudGuardians/Cloud-infra/tree/main/cloud-custodian/custodian-terraform-02)
- Cloud Custodian 실행을 위한 AWS 환경 구성용 Terraform 코드
- IAM Role, SQS 등 리소스 생성 포함

### [`policies/`](https://github.com/WHS3-CloudGuardians/Cloud-infra/tree/main/cloud-custodian/policies)
- Cloud Custodian 정책 정의 YAML 파일
- Prowler의 CHECKID와 동일한 정책 이름으로 구성 → 위반 사항 매핑 및 탐지 용이
- 위험도 기반 Slack 알림 시스템 구축
- **중요도 높은 항목에 한해 제한적 자동조치 적용**

### [`templates/`](https://github.com/WHS3-CloudGuardians/Cloud-infra/tree/main/cloud-custodian/templates)
- Cloud Custodian 정책 정의 템플릿 파일


## 사용 방법
상세한 사용법은 가이드 문서 참고 : [CloudCustodian 사용 가이드](https://www.notion.so/CloudCustodian-240c86faa56f80a19175fd28d234d8e3)

1. [`custodian-terraform-02/`](https://github.com/WHS3-CloudGuardians/Cloud-infra/tree/main/cloud-custodian/custodian-terraform-02)디렉토리에서 AWS 환경 구성
→ 자세한 내용은 해당 디렉토리의 [`README.md`](https://github.com/WHS3-CloudGuardians/Cloud-infra/tree/main/cloud-custodian/custodian-terraform-02) 참조

2. 정책 디렉토리([`policies/`](https://github.com/WHS3-CloudGuardians/Cloud-infra/tree/main/cloud-custodian/policies))로 이동
    ```
    cd policies/
    ```

3. 특정 서비스에 대한 정책 실행
    ``` bash
    custodian run -s output access.yaml
    ```
    - `access.yaml` : access 서비스에 대한 custodian 정책 파일
    - 실행 결과는 `./output` 디렉토리에 저장

4. Slack 알림 혹은 로컬 로그를 통해 결과 확인
    ```
    cat output/accessanalyzer_enabled/resources.json
    ```
    - `accessanalyzer_enabled` 정책에 탐지된 리소스 확인

5. AWS Lambda에서 배포된 정책 제거

>💡 기타  
> Cloud Custodian 정책은 보안 점검 자동화의 핵심 도구로, 실제 운영 환경 적용 전 충분한 테스트 권장  
> 자동조치는 매우 제한적으로 적용했으며, 주로 Slack 알림에 초점
