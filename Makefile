SHELL := /usr/bin/env bash

.PHONY: infra plan apply destroy setup app status clean

AWS_REGION ?= us-west-2
ENV ?= prod

infra:
	AWS_REGION=$(AWS_REGION) bash scripts/deploy-infra.sh

plan:
	cd terraform/environments/$(ENV) && terraform plan -var="aws_region=$(AWS_REGION)"

apply:
	cd terraform/environments/$(ENV) && terraform apply -auto-approve -var="aws_region=$(AWS_REGION)"

destroy:
	cd terraform/environments/$(ENV) && terraform destroy -auto-approve -var="aws_region=$(AWS_REGION)"

setup:
	AWS_REGION=$(AWS_REGION) bash scripts/setup-cluster.sh

app:
	AWS_REGION=$(AWS_REGION) bash scripts/deploy-wordpress.sh

status:
	AWS_REGION=$(AWS_REGION) bash scripts/setup-cluster.sh status

clean:
	AWS_REGION=$(AWS_REGION) bash scripts/cleanup.sh


