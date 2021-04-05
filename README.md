# Genomics Secondary Analysis Using AWS Step Functions and AWS Batch

<img src="https://d1.awsstatic.com/Solutions/Solutions%20Category%20Template%20Draft/Solution%20Architecture%20Diagrams/genomics-secondary-analysis-architecture-diagram.102c69721d29289d37ac46615dc602034e69bcc0.png" style="width:75vw">

This solution provides a framework for Next Generation Sequencing (NGS) genomics secondary-analysis pipelines using AWS Step Functions and AWS Batch. It deploys AWS services to develop and run custom workflow pipelines, monitor pipeline status and performance, fail-over to on-demand, handle errors, optimize for cost, and secure data with least-privileges.

The solution is designed to be starting point for developing your own custom genomics workflow pipelines using Amazon States Language and AWS Step Functions using continuous integration / continuous deployment (CI/CD) principles. That is everything - from the workflow definitions, to the resources they need to run on top of - is code, tracked in version control, and automatically built, tested, and deployed when developers make changes.

## Standard deployment

To deploy this solution in your account use the "Launch in the AWS Console" button found on the [solution landing page](https://aws.amazon.com/solutions/implementations/genomics-secondary-analysis-using-aws-step-functions-and-aws-batch/?did=sl_card&trk=sl_card).

We recommend deploying the solution this way for most use cases.

This will create all resources you need to get started developing and running genomics secondary analysis pipelines. This includes an example containerized toolset and definition for a simple variant calling pipeline using BWA-MEM, Samtools, and BCFtools.

Install options

## Customized deployment

A fully customized solution can be deployed for the following use cases:

* Modifying or adding additional resources deployed during installation
* Modifying the "Landing Zone" of the solution - e.g. adding additional artifacts or customizing the "Pipe" CodePipeline

Fully customized solutions need to be self-hosted in your own AWS account, and you will be responsible for any costs incurred in doing so.

To deploy and self-host a fully customized solution use the instructions below.

_Note_: All commands assume a `bash` shell.

### Customize

Clone the repository, and make desired changes

#### File Structure

```
.
├── CHANGELOG.md
├── CODE_OF_CONDUCT.md
├── CONTRIBUTING.md
├── LICENSE.txt
├── NOTICE.txt
├── README.md
├── deployment
│   ├── build-s3-dist.sh
│   └── run-unit-tests.sh
└── source
    ├── code
    │   ├── buildspec.yml
    │   ├── cfn
    │   │   ├── cloudwatch-dashboard.cfn.yaml
    │   │   ├── core
    │   │   │   ├── batch.cfn.yaml
    │   │   │   ├── iam.cfn.yaml
    │   │   │   └── networking.cfn.yaml
    │   │   └── workflow-variantcalling-simple.cfn.yaml
    │   ├── containers
    │   │   ├── _common
    │   │   │   ├── README.md
    │   │   │   ├── aws.dockerfile
    │   │   │   ├── build.sh
    │   │   │   ├── entrypoint.aws.sh
    │   │   │   └── push.sh
    │   │   ├── bcftools
    │   │   │   └── Dockerfile
    │   │   ├── buildspec.yml
    │   │   ├── bwa
    │   │   │   └── Dockerfile
    │   │   └── samtools
    │   │       └── Dockerfile
    │   └── main.cfn.yml
    ├── pipe
    │   ├── README.md
    │   ├── buildspec.yml
    │   ├── cfn
    │   │   ├── container-buildproject.cfn.yaml
    │   │   └── iam.cfn.yaml
    │   └── main.cfn.yml
    ├── setup
    │   ├── lambda
    │   │   ├── lambda.py
    │   │   └── requirements.txt
    │   ├── setup.sh
    │   ├── teardown.sh
    │   └── test.sh
    ├── setup.cfn.yaml
    └── zone
        ├── README.md
        └── main.cfn.yml

```

| Path | Description |
| :-   | :-          |
| deployment | Scripts for building and deploying a customized distributable |
| deployment/build-s3-dist.sh | Shell script for packaging distribution assets |
| deployment/run-unit-tests.sh | Shell script for execution unit tests |
| source     | Source code for the solution |
| source/setup.cfn.yaml | CloudFormation template used to install the solution |
| source/setup/         | Assets used by the installation and un-installation process |
| source/zone/ | Source code for the solution landing zone - location for common assets and artifacts used by the solution |
| source/pipe/ | Source code for the solution deployment pipeline - the CI/CD pipeline that builds and deploys the solution codebase |
| source/code/ | Source code for the solution codebase - source code for containerized tooling, workflow definitions, and AWS resources for workflow execution |

### Run unit tests

```bash
cd ./deployment
chmod +x ./run-unit-tests.sh
./run-unit-tests.sh
```

### Build and deploy

#### Create deployment buckets

The solution requires two buckets for deployment:

1. `<bucket-name>` for the solution's primary CloudFormation template
2. `<bucket-name>-<aws_region>` for additional artifacts and assets that the solution requires - these are stored regionally to reduce latency during installation and avoid inter-regional transfer costs

#### Configure and build the distributable

```bash
export DIST_OUTPUT_BUCKET=<bucket-name>
export SOLUTION_NAME=<solution-name>
export VERSION=<version>

chmod +x ./build-s3-dist.sh
./build-s3-dist.sh $DIST_OUTPUT_BUCKET $SOLUTION_NAME $VERSION
```

#### Deploy the distributable

_Note:_ you must have the AWS Command Line Interface (CLI) installed for this step. Learn more about the AWS CLI [here](https://docs.aws.amazon.com/cli/latest/userguide/cli-chap-welcome.html).

```bash
cd ./deployment

# deploy global assets
# this only needs to be done once
aws s3 cp \
    ./global-s3-assets/ s3://<bucket-name>/$SOLUTION_NAME/$VERSION \
    --recursive \
    --acl bucket-owner-full-control

# deploy regional assets
# repeat this step for as many regions as needed
aws s3 cp \
    ./regional-s3-assets/ s3://<bucket-name>-<aws_region>/$SOLUTION_NAME/$VERSION \
    --recursive \
    --acl bucket-owner-full-control
```

### Install the customized solution

The link to the primary CloudFormation template will look something like:

```text
https://<bucket-name>.s3-<region>.amazonaws.com/genomics-secondary-analysis-using-aws-step-functions-and-aws-batch.template
```

Use this link to install the customized solution into your AWS account in a specific region using the [AWS Cloudformation Console](https://us-west-2.console.aws.amazon.com/cloudformation/home?region=us-west-2#/stacks/create/template).


---

Copyright 2021 Amazon.com, Inc. or its affiliates. All Rights Reserved.

Licensed under the Apache License Version 2.0 (the "License"). You may not use this file except in compliance with the License. A copy of the License is located at

    http://www.apache.org/licenses/

or in the "license" file accompanying this file. This file is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, express or implied. See the License for the specific language governing permissions and limitations under the License.
