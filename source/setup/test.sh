#!/bin/bash

# Test the example workflow with demo data to ensure that the solution is 
# installed properly

set -e
set -x

PROJECT_NAME=${PROJECT_NAME:-GenomicsWorkflow}
PROJECT_NAME_LOWER_CASE=`echo "$PROJECT_NAME" | awk '{print tolower($0)}'`

STACKNAME_CODE=${PROJECT_NAME}Code

WORKFLOW_ARN=$(aws cloudformation describe-stacks --stack-name $STACKNAME_CODE --query 'Stacks[].Outputs[?OutputKey==`WorkflowSimpleArn`].OutputValue' --output text)
WORKFLOW_INPUT=$(aws cloudformation describe-stacks --stack-name $STACKNAME_CODE --query 'Stacks[].Outputs[?OutputKey==`WorkflowSimpleInput`].OutputValue' --output text)

echo "executing workflow: $WORKFLOW_ARN"
EXECUTION_ARN=$(\
    aws stepfunctions \
        start-execution \
        --state-machine-arn "$WORKFLOW_ARN" \
        --input "$WORKFLOW_INPUT" \
        --query 'executionArn' \
        --output text
)

POLLING_INTERVAL=30  # seconds
POLLING_TIMEOUT=1800  # seconds

# poll execution status
POLLING_ELAPSED_TIME=0
while true; do
    if [ $POLLING_ELAPSED_TIME -gt $POLLING_TIMEOUT ]; then
        echo "workflow execution exceeded timeout - cancelling" >&2
        aws stepfunctions stop-execution --execution-arn $EXECUTION_ARN
        STATUS=CANCELLED
        break
    fi

    STATUS=$(\
        aws stepfunctions \
            describe-execution \
            --execution-arn "$EXECUTION_ARN" \
            --query 'status' \
            --output text
    )

    if [[ "$STATUS" == "RUNNING" ]]; then
        sleep $POLLING_INTERVAL
        ((POLLING_ELAPSED_TIME+=$POLLING_INTERVAL))
    elif [[ "$STATUS" == "SUCCEEDED" ]]; then
        echo "workflow $STATUS"
        break
    else
        # workflow FAILED, ABORTED, TIMED_OUT, CANCELLED
        echo "workflow $STATUS" >&2
        exit 255
    fi
done

# wait for compute to cool down
# this needs to happen before the stack can be torn down
echo "waiting for compute cool down"
LOWPRIORITY_QUEUE_ARN=$(
    aws cloudformation \
        list-stack-resources \
        --stack-name $STACKNAME_CODE \
        --query 'StackResourceSummaries[?LogicalResourceId == `LowPriorityQueue`].PhysicalResourceId' \
        --output text
)
SPOT_CE_ARN=$(\
    aws cloudformation \
        list-stack-resources \
        --stack-name $STACKNAME_CODE \
        --query 'StackResourceSummaries[?LogicalResourceId == `SpotEnv`].PhysicalResourceId' \
        --output text
)
SPOT_CE_NAME=$(\
    aws batch \
        describe-compute-environments \
        --compute-environments $SPOT_CE_ARN \
        --query 'computeEnvironments[0].computeEnvironmentName' \
        --output text
)

# poll compute environment state
POLLING_ELAPSED_TIME=0
while true; do
    if [ $POLLING_ELAPSED_TIME -gt $POLLING_TIMEOUT ]; then
        echo "compute cooldown exceeded timeout - forcing" >&2

        AUTOSCALE_GROUPS=$(\
            aws autoscaling \
                describe-auto-scaling-groups \
                --query "AutoScalingGroups[?starts_with(AutoScalingGroupName, \`$SPOT_CE_NAME\`)==\`true\`]" \
                --output text
        )

        for autoscale_group in ${AUTOSCALE_GROUPS[@]}; do
            aws autoscaling delete-auto-scaling-group --auto-scaling-group-name $autoscale_group --force-delete
        done

        break
    fi

    DESIRED_CPUS=$(\
        aws batch \
            describe-compute-environments \
            --compute-environments $SPOT_CE_ARN \
            --query 'computeEnvironments[0].computeResources.desiredvCpus' \
            --output text
    )

    if [ $DESIRED_CPUS -gt 0 ]; then
        sleep $POLLING_INTERVAL
        ((POLLING_ELAPSED_TIME+=$POLLING_INTERVAL))
    else
        echo "cool down complete"
        break
    fi
done

if [[ ! $STATUS == "SUCCEEDED" ]]; then
    echo "smoke test failed" >&2
    exit 255    
fi

echo "smoke test completed successfully"
