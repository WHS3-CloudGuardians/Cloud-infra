//모듈 전체에서 사용할 변수 정의.

variable "region" {
  description = "AWS 리전"
  type        = string
  default     = "ap-northeast-2"
}

variable "env" {
  description = "환경 이름 (e.g. dev, prod)"
  type        = string
}

variable "account_id" {
  description = "AWS Account ID"
  type        = string
}

variable "kafka_topic" {
  description = "MSK에서 사용할 토픽 이름"
  type        = string
  default     = "events"
}
