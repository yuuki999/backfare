.PHONY: cfn-create
cfn-create:
	aws cloudformation create-stack --stack-name production-stack --template-body file:///home/yuuki/projects/transportation_expense_settlement/aws/cloudformation/production.yml

.PHONY: cfn-update
cfn-update:
	aws cloudformation update-stack --stack-name production-stack --template-body file:///home/yuuki/projects/transportation_expense_settlement/aws/cloudformation/production.yml