#!/bin/bash

usage()
{
    echo "usage: deploy-eks-min.sh [[[-bn bucket-name] [-bu bucket-url]] | [-h]]"
}

CF_BUCKET_NAME=
CF_BUCKET_URL=
CF_SCRIPT_NAME=eks-min.yaml

while [ "$1" != "" ]; do
  case $1 in
    -bn | --bucket-name )   shift
                            CF_BUCKET_NAME=$1
                            ;;
    -bu | --bucket-url )    shift
                            CF_BUCKET_URL=$1
                            ;;
    -h | --help )           usage
                            exit
                            ;;
    * )                     usage
                            exit 1
  esac
  shift
done

if aws s3 cp $CF_SCRIPT_NAME s3://$CF_BUCKET_NAME 1> /dev/null; then
  echo "Successfully uploaded eks-min.yaml file to S3 bucket"
else
  echo "eks-min.yaml upload to S3 failed!"
  exit
fi

if aws cloudformation create-stack --stack-name eks-min --capabilities CAPABILITY_NAMED_IAM --template-url $CF_BUCKET_URL/$CF_SCRIPT_NAME 1> /dev/null; then
  echo "Successfully initialized eks-min stack creation"
else
  echo "eks-min stack creation failed!"
  exit
fi

#aws cloudformation delete-stack --stack-name eks-min
while aws cloudformation describe-stacks --stack-name eks-min | grep StackStatus.*CREATE_IN_PROGRESS 1> /dev/null;
do
  sleep 1
  echo "Waiting for eks-min stack creation to complete..."
done

if aws cloudformation describe-stacks --stack-name eks-min | grep StackStatus.*CREATE_COMPLETE 1> /dev/null; then
  echo "eks-min stack successfully created"
else
  echo "eks-min stack failed to create, check AWS console for details!"
  exit
fi

aws eks --region eu-central-1 update-kubeconfig --name eks-min-cluster 

NODE_INSTANCE_ROLE_ARN=$(aws cloudformation describe-stacks --stack-name eks-min | grep NodeInstanceRoleArn -A1 | grep -o 'arn:aws:iam::[^"]*')
echo "NODE_INSTANCE_ROLE_ARN: $NODE_INSTANCE_ROLE_ARN"
NODE_INSTANCE_ROLE_ARN_ESCAPED=${NODE_INSTANCE_ROLE_ARN/\//\\\/}
sed -i'' -e "8s/.*/    - rolearn: $NODE_INSTANCE_ROLE_ARN_ESCAPED/" aws-auth-cm.yaml

kubectl apply -f aws-auth-cm.yaml

