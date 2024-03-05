# SaaS Boost Workshop - PNPSECURE

https://bit.ly/436HIlJ

## 워크샵 소개

이번 워크샵은 각 실습을 통해 다음 내용을 만들어 갑니다.

* AWS CodePipeline을 활용하여 기본적인 DevOps 파이프라인
* AWS SaaS Boost를 활용하여 As a Service 아키텍처 발판 마련
* AWS SaaS Boost를 활용하여 컨테이너화된 기존 솔루션을 테넌트 별 독립된 AWS ECS 클러스터 환경으로 제공하는 체계
* Amazon QuickSight를 활용하여 테넌트 별 SaaS 자원 소비량을 분석하는 대시보드
 
워크샵을 시작하기 전에 SaaS 전환 전략부터 살펴 보겠습니다.

[SaaS 전환 전략](https://catalog.us-east-1.prod.workshops.aws/workshops/ddef0709-6faa-4832-ad54-2044d65c0659/ko-KR/intro/01-migstrategy)

## 워크샵 환경 구성

### AWS Cloud9 IDE 설치

[워크샵 환경 구성 - 개인 계정에서 진행](https://catalog.us-east-1.prod.workshops.aws/workshops/ddef0709-6faa-4832-ad54-2044d65c0659/ko-KR/fast-lab/prep/02-self-paced)

반드시 amazonlinux2 사용

### SaaS Boost 설치

[SaaS Boost 설치 및 환경구성과 Tenant 생성](https://catalog.us-east-1.prod.workshops.aws/workshops/ddef0709-6faa-4832-ad54-2044d65c0659/ko-KR/fast-lab/lab1)

위 링크에서 아래의 두 개 메뉴까지 진행 (시간이 소요되는 작업이라 미리 진행 후 DevOps 파이프라인 진행)

* SaaS Boost 설치 사전준비
* SaaS Boost 설치

#### trouble shoot

##### install java 11

```shell
sudo yum install java-11-amazon-corretto
```

#### java version of maven

```shell
export JAVA_HOME=/usr/lib/jvm/java-11-amazon-corretto.x86_64
```

## LAB 1. 샘플 어플리케이션 설치, DevOps 파이프라인 생성

### clone this project

```shell
cd ~/environment
git clone https://github.com/pablo-saas/pnpsecure-saas-boost-workshop.git
```

### install terraform

```shell
sudo yum install -y yum-utils
sudo yum-config-manager --add-repo https://rpm.releases.hashicorp.com/AmazonLinux/hashicorp.repo
sudo yum -y install terraform
```

### deploy pipeline

```shell
cd ~/environment/pnpsecure-saas-boost-workshop/sample-iac
terraform init
terraform apply
```

### check resource

* AWS CodePipeline
** CodePipeline trigger update
* Amazon ECR
* AWS ECS

### push sample to AWS CodeCommit 

#### remote aws-saas-boost git configuration

```shell
cd ~/environment/aws-saas-boost
rm -rf .git
```

#### add AWS CodeCommit remote

```shell
cd samples/java
git init
git remote add origin <codecommit grc url>
```

#### add buildspec.yml

location "~/environment/aws-saas-boost/samples/java/buildspec.yml"

```yaml
version: 0.2

phases:
  install:
    runtime_versions:
      java: corretto11
  pre_build:
    commands:
      - echo logging in to Amazon ECR...
      - aws ecr get-login-password --region ap-northeast-2 | docker login --username AWS --password-stdin <ACCOUNT-ID>.dkr.ecr.ap-northeast-2.amazonaws.com
      - REPOSITORY_URI=<ACCOUNT-ID>.dkr.ecr.ap-northeast-2.amazonaws.com/saas-boost
      - IMAGE_TAG=build-$(echo $CODEBUILD_RESOLVED_SOURCE_VERSION | cut -c 1-7)
      - printenv
  build:
    commands:
      - mvn clean package
      - echo Building the Docker image...
      - docker build -t $REPOSITORY_URI:latest .
      - docker tag $REPOSITORY_URI:latest $REPOSITORY_URI:$IMAGE_TAG
      - docker images
  post_build:
    commands:
      - echo Pushing the Docker image...
      - docker push $REPOSITORY_URI:latest
      - docker push $REPOSITORY_URI:$IMAGE_TAG
      - echo Writing image definition file...
      - printf '[{"name":"saas-boost","imageUri":"%s"}]' $REPOSITORY_URI:$IMAGE_TAG > imagedefinitions.json
artifacts:
  files:
    - imagedefinitions.json
```

#### push sample codes

```shell
git checkout -b main
git add .
git commit -m "init"
git push --set-upstream origin main
```

#### update application

아래 링크의 step 8부터 진행

[Lab1 - CI/CD 파이프라인 개선](https://catalog.us-east-1.prod.workshops.aws/workshops/ddef0709-6faa-4832-ad54-2044d65c0659/ko-KR/lab1/part7)


## [LAB 2. SaaS Boost 설치 및 환경구성과 Tenant 생성)[https://catalog.us-east-1.prod.workshops.aws/workshops/ddef0709-6faa-4832-ad54-2044d65c0659/ko-KR/lab2]

## LAB 3. SKIP

## [LAB 4. SaaS 비용분석 Dashboard 구성](https://catalog.us-east-1.prod.workshops.aws/workshops/ddef0709-6faa-4832-ad54-2044d65c0659/ko-KR/lab4)
