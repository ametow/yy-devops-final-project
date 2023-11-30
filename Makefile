init:
	terraform -chdir=./terraform init

deploy: init
	terraform -chdir=./terraform apply

clean:
	terraform -chdir=./terraform destroy