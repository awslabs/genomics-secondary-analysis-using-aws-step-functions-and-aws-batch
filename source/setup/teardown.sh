#!/usr/bin/env bash

set -x

PROJECT_NAME=${PROJECT_NAME:-GenomicsWorkflow}
PROJECT_NAME_LOWER_CASE=`echo "$PROJECT_NAME" | awk '{print tolower($0)}'`

STACKNAME_ZONE=${PROJECT_NAME}Zone
STACKNAME_PIPE=${PROJECT_NAME}Pipe
STACKNAME_CODE=${PROJECT_NAME}Code

# Get Bucket Names from Stacks
ZONE_BUCKET=$(aws cloudformation describe-stacks --stack-name $STACKNAME_ZONE --query 'Stacks[].Outputs[?OutputKey==`ZoneBucket`].OutputValue' --output text); echo ${ZONE_BUCKET}
LOGS_BUCKET=$(aws cloudformation describe-stacks --stack-name $STACKNAME_ZONE --query 'Stacks[].Outputs[?OutputKey==`LogsBucket`].OutputValue' --output text); echo ${LOGS_BUCKET}
RESULTS_BUCKET=$(aws cloudformation describe-stacks --stack-name $STACKNAME_CODE --query 'Stacks[].Outputs[?OutputKey==`JobResultsBucket`].OutputValue' --output text); echo ${RESULTS_BUCKET}

# Get Repo Names from Stacks
PIPE_REPO=$(aws cloudformation describe-stacks --stack-name $STACKNAME_ZONE --query 'Stacks[].Outputs[?OutputKey==`RepoName`].OutputValue' --output text); echo ${PIPE_REPO}
CODE_REPO=$(aws cloudformation describe-stacks --stack-name $STACKNAME_PIPE --query 'Stacks[].Outputs[?OutputKey==`RepoName`].OutputValue' --output text); echo ${CODE_REPO}

# Disable Termination Protection on Stacks
aws cloudformation update-termination-protection --no-enable-termination-protection --stack-name $STACKNAME_ZONE
aws cloudformation update-termination-protection --no-enable-termination-protection --stack-name $STACKNAME_PIPE

# Delete Stacks
aws cloudformation delete-stack --stack-name $STACKNAME_CODE; aws cloudformation wait stack-delete-complete --stack-name $STACKNAME_CODE
aws cloudformation delete-stack --stack-name $STACKNAME_PIPE; aws cloudformation wait stack-delete-complete --stack-name $STACKNAME_PIPE
aws cloudformation delete-stack --stack-name $STACKNAME_ZONE; aws cloudformation wait stack-delete-complete --stack-name $STACKNAME_ZONE

# Delete container images
IMAGES=$(aws ecr describe-repositories --query "repositories[?starts_with(repositoryName, \`$PROJECT_NAME_LOWER_CASE\`) == \`true\`].repositoryName" --output text)
for image in ${IMAGES[@]}; do
    aws ecr delete-repository --force --repository-name $image
done

# Empty and delete Buckets
[ ! -z "$ZONE_BUCKET" ] && aws s3 rb --force s3://${ZONE_BUCKET}/
[ ! -z "$LOGS_BUCKET" ] && aws s3 rb --force s3://${LOGS_BUCKET}/
[ ! -z "$RESULTS_BUCKET" ] && aws s3 rb --force s3://${RESULTS_BUCKET}/

# Delete Repos
[ ! -z "$CODE_REPO" ] && aws codecommit delete-repository --repository-name ${CODE_REPO}
[ ! -z "$PIPE_REPO" ] && aws codecommit delete-repository --repository-name ${PIPE_REPO}

echo "teardown complete"