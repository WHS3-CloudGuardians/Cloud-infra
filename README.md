<div align="center">

# AWS 보안 컴플라이언스 자동화
### Prowler & CloudCustodian을 활용한 ISMS-P 정책 점검 및 대응 시스템 구현

[<img src="https://img.shields.io/badge/-readme.md-important?style=flat&logo=google-chrome&logoColor=white" />]() [<img src="https://img.shields.io/badge/프로젝트 기간-2025.5 ~ 2025.8-green?style=flat&logo=&logoColor=white" />]()
</div> 

## 프로젝트 개요

### 목적
클라우드 보안 위협 증가에 대한 대비와 컴플라이언스 수동 점검의 한계 극복

오픈 소스를 활용하여 AWS 환경에서 보안 점검 및 대응 자동화 구현

### 과정
1. 정책 점검과 대응 시스템을 실행할 안전/취약한 AWS 인프라 구축
2. Prowler을 이용하여 ISMS-P 정책 점검 
    - Prowler의 ISMS-P 점검 기준 확인
3. CloudCustodian을 활용한 위반 사항 대응

### 성과
- 4개의 아키텍처에 대한 안전/취약한 인프라 구축 
    - 총 29개의 AWS 리소스 포함
- Prowler 오픈소스 기여
    - Prowler의 ISMS-P 점검 기준 재매핑
    - 매핑 결과 Prowler PR 후, Merge 완료
    - 매핑 근거를 해설한 "매핑 해설서" 작성
- CloudCustodian 정책 작성
    - 알림 중심의 대응, 영향이 명확한 항목만 제한적 조치
    - 리소스 위험도에 따른 슬랙 알림 다양화


## 저장소 구성
### [Terraform](https://github.com/WHS3-CloudGuardians/Cloud-infra/tree/main/terraform)
- 안전/취약한 인프라에 대한 AWS 환경 구축 Terraform 코드 
    - 실무 서비스 환경과 유사한 메인 아키텍처 1종
    - 다양한 AWS 리소스 포함을 위한 서브 아키텍처 3종

### [Whs-Prowler](https://github.com/WHS3-CloudGuardians/Cloud-infra/tree/main/whs-prowler)
- AWS 환경에 대한 보안 점검을 위한 Prolwer
    - ISMS-P 점검 기준 재매핑 진행

### [Cloud-Custodian](https://github.com/WHS3-CloudGuardians/Cloud-infra/tree/main/cloud-custodian)
- AWS 환경에 대한 정책 기반 모니터링과 자동 조치를 위한 CloudCustodian
    - 정책 정의 YAML 파일
    - 정책 적용 및 점검 자동화 스크립트

### [Docs](https://github.com/WHS3-CloudGuardians/Cloud-infra/tree/main/docs)
- 프로젝트 관련 문서
- Prowler의 ISMS-P 점검 기준 매핑표  


#### 사용 방법은 각 폴더의 README 참조



</br></br></br></br>
<div align="center">

## 구름수비대 

</div> 

PM [이찬휘](https://github.com/iChanee)

기술팀 
[나영민](https://github.com/skdudals99)
[이다솔](https://github.com/dasol729)
[손예은](https://github.com/ye-nni)
[김진호](https://github.com/oscarjhk)
[송채영](https://github.com/buddle031)

정책팀 
[김건희](https://github.com/ghkim583)
[옥재은](https://github.com/Jaen-923)
