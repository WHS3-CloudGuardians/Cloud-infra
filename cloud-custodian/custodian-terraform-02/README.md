- wls로 실행함
- env 파일에서 본인의 acount ID 수정해야 함. 실행하기 전에 터미널 창에서 aws configure로 본인 계정 엑세스 키 사용하기 
  
- $ source .env
- $ make build          # c7n-mailer.zip 만들어야 함. 만드는데 시간 소용 어느 정도 있음 5분 ~ 7분 정도 
- $ ls -lh modules/custodian-mailer/c7n-mailer.zip  # zip 파일이 제대로 만들어졌는지 확인하기 
- $ terraform init
- $ terraform apply -var-file=env/dev.tfvars

