#!/bin/bash

if aws s3 cp eks-min.yaml s3://jd-system 1> /dev/null; then
  echo "Successfully uploaded eks-min.yaml file to S3 bucket"
else
  echo "eks-min.yaml upload to S3 failed!"
  exit
fi

if aws cloudformation create-stack --stack-name eks-min --capabilities CAPABILITY_NAMED_IAM --template-url https://jd-system.s3.eu-central-1.amazonaws.com/eks-min.yaml 1> /dev/null; then
  echo "Successfully initialized eks-min stack creation"
else
  echo "eks-min stack creation failed!"
  exit
fi

#aws cloudformation delete-stack --stack-name eks-min
while ! aws cloudformation describe-stacks --stack-name eks-min | grep StackStatus.*CREATE_COMPLETE 1> /dev/null;
do
  sleep 1
  echo "Waiting for eks-min stack creation to complete..."
done
echo "eks-min stack successfully created"

aws eks --region eu-central-1 update-kubeconfig --name eks-min-cluster 

NODE_INSTANCE_ROLE_ARN=$(aws cloudformation describe-stacks --stack-name eks-min | grep NodeInstanceRoleArn -A1 | grep -o 'arn:aws:iam::[^"]*')
echo "NODE_INSTANCE_ROLE_ARN: $NODE_INSTANCE_ROLE_ARN"
NODE_INSTANCE_ROLE_ARN_ESCAPED=${NODE_INSTANCE_ROLE_ARN/\//\\\/}
sed -i'' -e "8s/.*/    - rolearn: $NODE_INSTANCE_ROLE_ARN_ESCAPED/" aws-auth-cm.yaml

kubectl apply -f aws-auth-cm.yaml

