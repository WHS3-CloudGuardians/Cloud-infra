배포를 할 때 .env 파일에 있는 
export TF_VAR_account_id=001848367358 <- 여기의 id를 본인 AWS id로 작성해야 함

터미널에 입력한 명령어 - git bash에서 실행함
$ source .env
$ terraform plan -var-file=env/dev.tfvars
$ terraform apply
