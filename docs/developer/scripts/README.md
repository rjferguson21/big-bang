# Development k3d cluster automation

NOTE: This script does not does not install Flux or deploy BigBang.  
      You must handle those deployments after your k3d dev cluster is ready.

## Install and Configure Dependencies

1. Install aws cli

      ```shell
      curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
      unzip awscliv2.zip
      sudo ./aws/install
      aws --version
      ```

1. Configure aws cli

      ```shell
      aws configure
      # aws_access_key_id - The AWS access key part of your credentials
      # aws_secret_access_key - The AWS secret access key part of your credentials
      # region - us-gov-west-1
      # output - JSON

      # Verify configuration
      aws configure list
      ```

1. Install jq  
      <https://stedolan.github.io/jq/download/>

## Usage

The default with no options specified is to use the EC2 public IP for the k3d cluster and the security group.

```shell
./docs/developer/scripts/k3d-dev.sh -h
AWS User Name: your.name
Usage:
k3d-dev.sh -b -p -m -d -h

 -b   use big M5 instance. Default is t3.2xlarge
 -p   use private IP for security group and k3d cluster
 -m   create k3d cluster with metalLB
 -d   destroy related AWS resources
 -h   output help
```
