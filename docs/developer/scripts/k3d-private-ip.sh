#!/bin/bash

# check for environment variable
if [[ -z "${MY_NAME}" ]]; then
  echo "You must set MY_NAME environment variable. This is used to name resources in AWS:"
  echo "export MY_NAME=happy.camper"
  exit 1
fi

if [  -z $1 ]
then 
  echo "no modifier entered, bringing up a standard instance"
  InstSize="t3a.2xlarge"
  SpotPrice="0.35"
elif [ $1 = "big" ]
then 
  echo "Bringing up large spot instance"
  InstSize="m5a.4xlarge"
  SpotPrice="0.69"
else
  echo "Bringing up standard spot instance"
  InstSize="t3a.2xlarge"
  SpotPrice="0.35"
fi


####Configure Environment
# Assign a name for your SSH Key Pair.  Typically, people use their username to make it easy to identify
KeyName="${MY_NAME}-dev"
# Assign a name for your Security Group.  Typically, people use their username to make it easy to identify
SG="${MY_NAME}-dev"
# Identify which VPC to create the spot instance in
VPC="vpc-2ffbd44b"  # default VPC


#### SSH Key Pair
# Create SSH key if it doesn't exist
echo -n Checking if key pair ${KeyName} exists ...
aws ec2 describe-key-pairs --output json --no-cli-pager --key-names ${KeyName} > /dev/null 2>&1 || keypair=missing
if [ "${keypair}" == "missing" ]; then
  echo -e "missing\nCreating key pair ${KeyName} ... "
  aws ec2 create-key-pair --output json --no-cli-pager --key-name ${KeyName} | jq -r '.KeyMaterial' > ~/.ssh/${KeyName}.pem
  chmod 600 ~/.ssh/${KeyName}.pem
  echo done
else
  echo found
fi


#### Security Group
# Create security group if it doesn't exist
echo -n "Checking if security group ${SG} exists ..."
aws ec2 describe-security-groups --output json --no-cli-pager --group-names ${SG} > /dev/null 2>&1 || secgrp=missing
if [ "${secgrp}" == "missing" ]; then
  echo -e "missing\nCreating security group ${SG} ... "
  aws ec2 create-security-group --output json --no-cli-pager --description "IP based filtering for ${SG}" --group-name ${SG} --vpc-id ${VPC}
  echo done
else
  echo found
fi

# Lookup the security group created to get the ID
echo -n Retrieving ID for security group ${SG} ...
SecurityGroupId=$(aws ec2 describe-security-groups --output json --no-cli-pager --group-names ${SG} --query "SecurityGroups[0].GroupId" --output text)
echo done

# Add name tag to security group
aws ec2 create-tags --resources ${SecurityGroupId} --tags Key=Name,Value=${SG}


# Add rule for IP based filtering
WorkstationIP=`curl http://checkip.amazonaws.com/ 2> /dev/null`
echo -n Checking if ${WorkstationIP} is authorized in security group ...
aws ec2 describe-security-groups --output json --no-cli-pager --group-names ${SG} | grep ${WorkstationIP} > /dev/null || ipauth=missing
if [ "${ipauth}" == "missing" ]; then
  echo -e "missing\nAdding ${WorkstationIP} to security group ${SG} ..."
  aws ec2 authorize-security-group-ingress --output json --no-cli-pager --group-name ${SG} --protocol tcp --port 22 --cidr ${WorkstationIP}/32
  echo done
else
  echo found
fi


##### Launch Specification
# Typical settings for Big Bang development
AMIName="ubuntu/images/hvm-ssd/ubuntu-focal-20.04-amd64-server*"
InstanceType="${InstSize}"
VolumeSize=120

# Lookup the image name to find the latest version
echo -n Retrieving latest image ID matching ${AMIName} ...
ImageId=$(aws ec2 describe-images --output json --no-cli-pager --filters "Name=name,Values=${AMIName}" --query "reverse(sort_by(Images, &CreationDate))[:1].ImageId" --output text)
echo done

# Create the launch spec
echo -n Creating launch_spec.json ...
mkdir -p ~/aws
##notworking line.  "InstanceInitiatedShutdownBehavior":"Terminate",
cat << EOF > ~/aws/launch_spec.json
{
  "ImageId": "${ImageId}",
  "InstanceType": "${InstanceType}",
  "KeyName": "${KeyName}",
  "SecurityGroupIds": [ "${SecurityGroupId}" ],
  "BlockDeviceMappings": [
    {
      "DeviceName": "/dev/sda1",
      "Ebs": {
        "DeleteOnTermination": true,
        "VolumeType": "gp2",
        "VolumeSize": ${VolumeSize}
      }
    }
  ]
}
EOF


#### Request a Spot Instance
# Location of your private SSH key created during setup
PEM=~/.ssh/${KeyName}.pem

# Request a spot instance with our launch spec for the max. of 6 hours
# NOTE: t3a.2xlarge spot price is 0.35 m5a.4xlarge is 0.69
echo Requesting spot instance ...
#Old spot request
#SIR=`aws ec2 request-spot-instances \
#  --output json --no-cli-pager \
#  --instance-count 1 \
##broken**  --attribute InstanceInitiatedShutdownBehavior=Terminate \
##  --instance-initiated-shutdown-behavior terminate \
#  --block-duration-minutes 360 \
#  --type "one-time" \
#  --spot-price "${SpotPrice}" \
#  --launch-specification file://$HOME/aws/launch_spec.json \
#  | jq -r '.SpotInstanceRequests[0].SpotInstanceRequestId'`
SIR=`aws ec2 request-spot-instances \
  --output json --no-cli-pager \
  --instance-count 1 \
  --type "one-time" \
  --spot-price "${SpotPrice}" \
  --launch-specification file://$HOME/aws/launch_spec.json \
  | jq -r '.SpotInstanceRequests[0].SpotInstanceRequestId'`

# Check if spot instance request was not created
if [ -z ${SIR} ]; then
  exit 1;
fi

# Request was created, now you need to wait for it to be filled
echo Waiting for spot instance request ${SIR} to be fulfilled ...
aws ec2 wait spot-instance-request-fulfilled --output json --no-cli-pager --spot-instance-request-ids ${SIR}

# Get the instanceId
InstId=`aws ec2 describe-spot-instance-requests --output json --no-cli-pager --spot-instance-request-ids ${SIR} | jq -r '.SpotInstanceRequests[0].InstanceId'`

# Add name tag to spot instance
aws ec2 create-tags --resources ${InstId} --tags Key=Name,Value=${MY_NAME}-dev

# Request was fulfilled, but instance is still spinng up, so wait on that
echo Waiting for instance ${InstId} to be ready ...
aws ec2 wait instance-running --output json --no-cli-pager --instance-ids ${InstId}

# Save the instance ID off into a file in case we need it later
echo ${InstId} >> ~/aws/active_instances

# Get the public IP address of our instance
PublicIP=`aws ec2 describe-instances --output json --no-cli-pager --instance-ids ${InstId} | jq -r '.Reservations[0].Instances[0].PublicIpAddress'`

# Get the private IP address of our instance
PrivateIP=`aws ec2 describe-instances --output json --no-cli-pager --instance-ids ${InstId} | jq -r '.Reservations[0].Instances[0].PrivateIpAddress'`

echo Instance private IP is ${PrivateIP}
echo Instance at ${PublicIP} is ready.

# Remove previous keys related to this IP from your SSH known hosts so you don't end up with a conflict
ssh-keygen -f "${HOME}/.ssh/known_hosts" -R "${PublicIP}"

echo "ssh init"
ssh -i ~/.ssh/${KeyName}.pem -o ConnectionAttempts=10 -o StrictHostKeyChecking=no ubuntu@${publicIP} "hostname"
echo

##### Configure Instance
echo
echo
echo "starting instance config"
echo "Machine config"
ssh -i ~/.ssh/${KeyName}.pem -t -o StrictHostKeyChecking=no ubuntu@${PublicIP} "sudo sysctl -w vm.max_map_count=524288"
ssh -i ~/.ssh/${KeyName}.pem -t -o StrictHostKeyChecking=no ubuntu@${PublicIP} "sudo bash -c \"echo 'vm.max_map_count=524288' > /etc/sysctl.d/vm-max_map_count.conf\""
ssh -i ~/.ssh/${KeyName}.pem -t -o StrictHostKeyChecking=no ubuntu@${PublicIP} "sudo bash -c \"echo 'fs.file-max=131072' > /etc/sysctl.d/fs-file-max.conf\""
ssh -i ~/.ssh/${KeyName}.pem -t -o StrictHostKeyChecking=no ubuntu@${PublicIP} "sudo bash -c 'sysctl -p'"
ssh -i ~/.ssh/${KeyName}.pem -t -o StrictHostKeyChecking=no ubuntu@${PublicIP} "sudo bash -c 'ulimit -n 131072'"
ssh -i ~/.ssh/${KeyName}.pem -t -o StrictHostKeyChecking=no ubuntu@${PublicIP} "sudo bash -c 'ulimit -u 8192'"
ssh -i ~/.ssh/${KeyName}.pem -t -o StrictHostKeyChecking=no ubuntu@${PublicIP} "sudo bash -c 'modprobe xt_REDIRECT'"
ssh -i ~/.ssh/${KeyName}.pem -t -o StrictHostKeyChecking=no ubuntu@${PublicIP} "sudo bash -c 'modprobe xt_owner'"
ssh -i ~/.ssh/${KeyName}.pem -t -o StrictHostKeyChecking=no ubuntu@${PublicIP} "sudo bash -c 'modprobe xt_statistic'"

echo
echo
echo "installing packages"
ssh -i ~/.ssh/${KeyName}.pem -t -o StrictHostKeyChecking=no ubuntu@${PublicIP} "sudo apt remove -y docker docker-engine docker.io containerd runc"
ssh -i ~/.ssh/${KeyName}.pem -t -o StrictHostKeyChecking=no ubuntu@${PublicIP} "sudo apt -y update"
ssh -i ~/.ssh/${KeyName}.pem -t -o StrictHostKeyChecking=no ubuntu@${PublicIP} "sudo apt install -y apt-transport-https ca-certificates curl gnupg-agent software-properties-common"

echo
echo
# Add the Docker repository, we are installing from Docker and not the Ubuntu APT repo.
ssh -i ~/.ssh/${KeyName}.pem -t -o StrictHostKeyChecking=no ubuntu@${PublicIP} "curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -"
ssh -i ~/.ssh/${KeyName}.pem -t -o StrictHostKeyChecking=no ubuntu@${PublicIP} "sudo apt-key fingerprint 0EBFCD88"
ssh -i ~/.ssh/${KeyName}.pem -t -o StrictHostKeyChecking=no ubuntu@${PublicIP} 'sudo add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable"'
ssh -i ~/.ssh/${KeyName}.pem -t -o StrictHostKeyChecking=no ubuntu@${PublicIP} 'sudo curl -fsSLo /usr/share/keyrings/kubernetes-archive-keyring.gpg https://packages.cloud.google.com/apt/doc/apt-key.gpg'
ssh -i ~/.ssh/${KeyName}.pem -t -o StrictHostKeyChecking=no ubuntu@${PublicIP} 'echo "deb [signed-by=/usr/share/keyrings/kubernetes-archive-keyring.gpg] https://apt.kubernetes.io/ kubernetes-xenial main" | sudo tee /etc/apt/sources.list.d/kubernetes.list'


echo
echo
# Install Docker
echo "install Docker"
ssh -i ~/.ssh/${KeyName}.pem -t -o StrictHostKeyChecking=no ubuntu@${PublicIP} "sudo apt update && sudo apt install -y docker-ce docker-ce-cli containerd.io kubectl jq tree vim"

echo
echo
# Add your base user to the Docker group so that you do not need sudo to run docker commands
ssh -i ~/.ssh/${KeyName}.pem -t -o StrictHostKeyChecking=no ubuntu@${PublicIP} "sudo usermod -aG docker ubuntu"

echo
echo
# install k3d on instance
echo "Installing k3d on instance"
ssh -i ~/.ssh/${KeyName}.pem -t -o StrictHostKeyChecking=no ubuntu@${PublicIP} "wget -q -O - https://raw.githubusercontent.com/rancher/k3d/main/install.sh | TAG=v4.4.7 bash"
echo
echo "k3d version"
ssh -i ~/.ssh/${KeyName}.pem -t -o StrictHostKeyChecking=no ubuntu@${PublicIP} "k3d version"
echo
echo "creating k3d cluster"

ssh -i ~/.ssh/${KeyName}.pem -t -o StrictHostKeyChecking=no ubuntu@${PublicIP} "k3d cluster create  --servers 1  --agents 3 --volume /etc/machine-id:/etc/machine-id  --k3s-server-arg "--disable=traefik"  --k3s-server-arg "--disable=metrics-server" --k3s-server-arg "--tls-san=${PrivateIP}" --port 80:80@loadbalancer --port 443:443@loadbalancer --api-port 6443"
ssh -i ~/.ssh/${KeyName}.pem -t -o StrictHostKeyChecking=no ubuntu@${PublicIP} "kubectl config use-context k3d-k3s-default"
ssh -i ~/.ssh/${KeyName}.pem -t -o StrictHostKeyChecking=no ubuntu@${PublicIP} "kubectl cluster-info"

echo
echo
echo "copy kubeconfig"
scp -i ~/.ssh/${KeyName}.pem -o StrictHostKeyChecking=no ubuntu@${PublicIP}:/home/ubuntu/.kube/config ~/.kube/${MY_NAME}-dev-config
sed -i "s/0\.0\.0\.0/${PrivateIP}/g" ~/.kube/${MY_NAME}-dev-config


# add tools
echo Installing k9s...
ssh -i ~/.ssh/${KeyName}.pem -t -o StrictHostKeyChecking=no ubuntu@${PublicIP} 'curl -sS https://webinstall.dev/k9s | bash'
echo Installing kubectl...
ssh -i ~/.ssh/${KeyName}.pem -t -o StrictHostKeyChecking=no ubuntu@${PublicIP} 'curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"'
ssh -i ~/.ssh/${KeyName}.pem -t -o StrictHostKeyChecking=no ubuntu@${PublicIP} 'sudo mv /home/ubuntu/kubectl /usr/local/bin/'
ssh -i ~/.ssh/${KeyName}.pem -t -o StrictHostKeyChecking=no ubuntu@${PublicIP} 'sudo chmod +x /usr/local/bin/kubectl'

# fix /etc/hosts for new cluster
# echo "Fixing /etc/hosts"
# sudo sed -i '/bigbang.dev/d' /etc/hosts
# sudo bash -c "echo '## begin bigbang.dev section' >> /etc/hosts"
# for i in {kibana,alertmanager,grafana,prometheus,twistlock,argocd,kiali,tracing}; do sudo bash -c "echo \"${PublicIP} ${i}.bigbang.dev\" >> /etc/hosts" ; done
# sudo bash -c "echo '## end bigbang.dev section' >> /etc/hosts"

echo
echo "ssh to instance:"
echo "ssh -i ~/.ssh/${KeyName}.pem ubuntu@${PublicIP}"
echo
echo "Start sshuttle:"
echo "sshuttle --dns -vr ubuntu@${PublicIP} 172.31.0.0/16 --ssh-cmd 'ssh -i ~/.ssh/${KeyName}.pem'"
echo
echo "To use kubectl from your local workstation you must set the KUBECONFIG environment variable:"
echo "export KUBECONFIG=~/.kube/${MY_NAME}-dev-config"
echo
