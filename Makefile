include aws.env
include ecr.env

GRADLE_DOCKER_IMAGE=gradle:6.0

.PHONY: package tag login publish clean check-region check-repo check-account check-env service cluster

build:
	docker run -u gradle --rm -v ${CURDIR}:/home/gradle/project -v ${HOME}/.m2:/home/gradle/.m2 -w /home/gradle/project $(GRADLE_DOCKER_IMAGE) gradle build

package: build
	docker build -t scorekeep-api .

check-repo:
	test -n "$(ECR_REPO)" || (echo "ECR_REPO must be defined in ecr.env"; exit 1)

check-account:
	test -n "$(ACCOUNT_ID)" || (echo "ACCOUNT_ID must be defined in aws.env"; exit 1)

check-region:
	test -n "$(AWS_REGION)" || (echo "AWS_REGION must be defined in aws.env"; exit 1)

check-env: check-repo check-region check-account

tag: package check-env
	docker tag scorekeep-api:latest $(ECR_REPO)

run-local: package check-env
	docker run -v ~/.aws/:/root/.aws/:ro --net=host --attach STDOUT -e AWS_REGION=$(AWS_REGION) -e NOTIFICATION_TOPIC=arn:aws:sns:$(AWS_REGION):$(ACCOUNT_ID):scorekeep-notifications --name scorekeep-api scorekeep-api

stop-local:
	docker stop scorekeep-api && docker rm scorekeep-api

login: check-region
	@$(shell aws ecr get-login --no-include-email --region $(AWS_REGION))

publish: tag login check-env
	docker push $(ECR_REPO)

clean: build
	find -d build | xargs rm -fd
