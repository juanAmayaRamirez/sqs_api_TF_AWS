validate:
	terraform fmt
	terraform validate
plan:
	terraform plan -var-file=variables/dev.tfvars -out=tfplan 
apply:
	terraform apply tfplan
show:
	terraform show
graph:
	terraform graph -type=plan | dot -Tsvg > .files/graph.svg
destroy:
	terraform destroy -var-file=variables/dev.tfvars

