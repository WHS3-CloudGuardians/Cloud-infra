<div align="center">

# AWS 보안 점검 자동화 시스템  
### Prowler & CloudCustodian 기반 ISMS-P 대응 아키텍처 구현

[![README](https://img.shields.io/badge/-README-important?logo=markdown)]()  
[![화이트햇 스쿨](https://img.shields.io/badge/화이트햇_스쿨_3기-blueviolet?style=flat)]()  
[![구름수비대](https://img.shields.io/badge/구름수비대-팀-blue?style=flat&logo=cloud)]()
[![프로젝트 기간](https://img.shields.io/badge/2025.05~2025.08-진행-green?style=flat)]()  

</div>

---

## 프로젝트 개요

### 목적
- 클라우드 보안 위협 증가와 수동 점검의 한계를 극복하기 위한 자동화 대응 시스템 구축
- 오픈소스를 기반으로 AWS 환경에서 ISMS-P 중심의 보안 점검 및 대응 자동화 구현

### 수행 내용
1. 안전/취약한 상태를 모두 포함한 AWS 인프라 구성
2. **Prowler를 활용한 ISMS-P 정책 점검**
   - 커스텀 기준 매핑 및 공식 오픈소스 반영
3. **CloudCustodian을 통한 위반 항목 대응 자동화**
   - 알림 중심 대응 및 자동 리소스 제어

### ✅ 주요 성과
- **5종의 인프라 아키텍처 구축**
  - 총 29개의 AWS 리소스 포함
- **Prowler 공식 저장소 기여**
  - ISMS-P 기준 재매핑 및 PR → **공식 기준으로 병합 완료**
  - 매핑 기준 해설 포함한 문서 작성
- **CloudCustodian 정책 구현**
  - 위험도 기반 Slack 알림 시스템 구축
  - 중요도 높은 항목에 한해 제한적 자동조치 적용

---

## 📂 저장소 구성

### [`/terraform`](https://github.com/WHS3-CloudGuardians/Cloud-infra/tree/main/terraform)
- AWS 환경 구성용 Terraform 코드
- 메인 아키텍처 1종 + 서브 아키텍처 4종 구성

### [`/whs-prowler`](https://github.com/WHS3-CloudGuardians/Cloud-infra/tree/main/whs-prowler)
- ISMS-P 기반 보안 점검 자동화 (Prowler 사용)
- 점검 기준 재매핑 및 공식 병합된 커스텀 기준 포함

### [`/cloud-custodian`](https://github.com/WHS3-CloudGuardians/Cloud-infra/tree/main/cloud-custodian)
- CloudCustodian 정책 정의 및 실행 자동화
- YAML 정책 파일 및 실행 스크립트 포함

### [`/docs`](https://github.com/WHS3-CloudGuardians/Cloud-infra/tree/main/docs)
- 프로젝트 문서 및 Prowler ISMS-P 매핑표/해설서
- 📄 [Notion 프로젝트 문서](https://www.notion.so/AWS-23fc86faa56f80ce9865ffe805df09e8?source=copy_link)

> 📎 각 폴더의 `README.md`를 통해 사용 방법 및 세부 설명 제공

---

## ☁️ 프로젝트 팀 - **구름수비대**

### 🙂 PM  
- [이찬휘](https://github.com/iChanee)

### 🛠️ 기술팀   
- [나영민](https://github.com/skdudals99)  
- [이다솔](https://github.com/dasol729)  
- [손예은](https://github.com/ye-nni)  
- [김진호](https://github.com/oscarjhk)  
- [송채영](https://github.com/buddle031)

### 📚 정책팀 
- [옥재은](https://github.com/Jaen-923)
- [김건희](https://github.com/ghkim583)  

---

> 본 프로젝트는 실무 보안 대응과 오픈소스 기여 경험을 함께 달성한 사례로, 실제 정책 연동부터 자동화까지의 전 과정을 포함하고 있습니다.
