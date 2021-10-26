# Big Bang Quick Start

[[_TOC_]]


## Overview
This Keycloak SSO Quick Start Guide explains how to complete the following tasks in under 2 hours:
1. Given 2 VMs (each with 8 cpu cores / 32 GB ram) that are each setup for ssh, turn the 2 VMs into 2 single node k3d clusters.      
Why 2 VMs?, 2 reasons:     
  1. It works around k3d only supporting 1 LB, but Keycloak needs it's own LB with TCP_PASSTHROUGH.
  1. This mimicks the way the Big Bang team recommends Keycloak be deployed in production, giving it it's own dedicated cluster (Note: from a technical standpoint there's nothing stopping it from being hosted on the same cluster).
1. Use Big Bang demo workflow to turn 1 k3d cluster into a Keycloak Cluster.
1. Use Big Bang demo workflow to turn 1 k3d cluster into a Workload Cluster.
1. In the KeyCloak Cluster:
  * Deploy Keycloak 
  * Create a User
1. In the Workload Cluster: 
  * Deploy auth service and a mock mission application
  * Protect the mock mission application, by configuring auth service to interface with Keycloak and require users to login to Keycloak before being able to access the mock mission application.

> Note: This document assumes familiarity with the generic Big Bang quick start guide.     
Differences between this an the previous Quick Start:      
* Topics explained in previous quick start guides won't have notes or they will be less detailed.
* The previous quick start supported deploying k3d to either localhost or remote VM, this quick start only supports deployment to remote VMs.
* The previous quick start supported multiple linux distributions, this one requires Ubuntu 20.04 configured for password less sudo (this guide has more automation of prerequisites, so we needed a standard to automate against.)
* The automation also assumes Admin's Laptop has a Unix Shell. (Mac, Linux, or Windows Subsystem for Linux)
* This quick start assumes you have kubectl installed on your Admin Laptop

## Step 1: Provision 2 Virtual Machines
* 2 Virtual Machines each with 32GB RAM, 8-Core CPU (t3a.2xlarge for AWS users), and 100GB of disk space should be sufficient.


## Step 2: Setup SSH to both VMs
1. Setup SSH to both VMs

    ```shell
    # [admin@Unix_Laptop:~]
    mkdir -p ~/.ssh
    chmod 700 ~/.ssh
    touch ~/.ssh/config
    chmod 600 ~/.ssh/config
    temp="""##########################
    Host keycloak-cluster
      Hostname x.x.x.x  #IP Address of k3d node
      IdentityFile ~/.ssh/bb-onboarding-attendees.ssh.privatekey
      User ubuntu
      StrictHostKeyChecking no
    Host workload-cluster
      Hostname x.x.x.x  #IP Address of k3d node
      IdentityFile ~/.ssh/bb-onboarding-attendees.ssh.privatekey
      User ubuntu
      StrictHostKeyChecking no
    #########################"""
    echo "$temp" | sudo tee -a ~/.ssh/config  #tee -a, appends to preexisting config file
    ```

1. Verify SSH works for both VMs

    ```shell
    # [admin@Laptop:~]
    ssh keycloak-cluster

    # [ubuntu@Ubuntu_VM:~]
    exit

    # [admin@Laptop:~]
    ssh workload-cluster

    # [ubuntu@Ubuntu_VM:~]
    exit

    # [admin@Laptop:~]
    ```


## Step 3: Prep work - Install dependencies and configure both VMs
1. Set some Variables and push them to each VM
* We'll pass some environment variables into the VMs that will help with automation
* We'll also update the PS1 var so we can tell the 2 machines apart when sshed in.
* All of the commands in the following section are run from the Admin Laptop

```shell
# [admin@Laptop:~]
mkdir -p ~/qs
BIG_BANG_VERSION="1.18.0"
REGISTRY1_USERNAME="REPLACE_ME"
REGISTRY1_PASSWORD="REPLACE_ME"
echo $REGISTRY1_PASSWORD | docker login https://registry1.dso.mil --username=$REGISTRY1_USERNAME --password-stdin | grep "Login Succeeded" ; echo $? | grep 0 && echo "This validation check shows your registry1 credentials are valid, please continue." || for i in {1..10}; do echo "Validation check shows error, fix your registry1 credentials before moving on."; done

export KEYCLOAK_IP=$(cat ~/.ssh/config | grep keycloak-cluster -A 1 | grep Hostname | awk '{print $2}')
echo "\n\n\n$KEYCLOAK_IP is the IP of the k3d node that will host Keycloak on Big Bang"

export WORKLOAD_IP=$(cat ~/.ssh/config | grep workload-cluster -A 1 | grep Hostname | awk '{print $2}')
echo "$WORKLOAD_IP is the IP of the k3d node that will host Workloads on Big Bang"
echo "Please manually verify that the IPs of your keycloak and workload k3d VMs look correct before moving on."



cat << EOFkeycloak-k3d-prepwork-commandsEOF > ~/qs/keycloak-k3d-prepwork-commands.txt
# Idempotent logic:
lines_in_file=()
lines_in_file+=( 'export PS1="\[\033[01;32m\]\u@keycloak-cluster\[\033[00m\]:\[\033[01;34m\]\w\[\033[00m\]\$ "' )
lines_in_file+=( 'export CLUSTER_NAME="keycloak-cluster"' )
lines_in_file+=( 'export BIG_BANG_VERSION="$BIG_BANG_VERSION"' )
lines_in_file+=( 'export K3D_IP="$KEYCLOAK_IP"' )
lines_in_file+=( 'export REGISTRY1_USERNAME="$REGISTRY1_USERNAME"' )
lines_in_file+=( 'export REGISTRY1_PASSWORD="$REGISTRY1_PASSWORD"' )

for line in "\${lines_in_file[@]}"; do
  grep -qF "\${line}" ~/.bashrc
  if [ \$? -ne 0 ]; then echo "\${line}" >> ~/.bashrc ; fi
done
EOFkeycloak-k3d-prepwork-commandsEOF


cat << EOFworkload-k3d-prepwork-commandsEOF > ~/qs/workload-k3d-prepwork-commands.txt
# Idempotent logic:
lines_in_file=()
lines_in_file+=( 'export PS1="\[\033[01;32m\]\u@workload-cluster\[\033[00m\]:\[\033[01;34m\]\w\[\033[00m\]\$ "' )
lines_in_file+=( 'export CLUSTER_NAME="workload-cluster"' )
lines_in_file+=( 'export BIG_BANG_VERSION="$BIG_BANG_VERSION"' )
lines_in_file+=( 'export K3D_IP="$WORKLOAD_IP"' )
lines_in_file+=( 'export REGISTRY1_USERNAME="$REGISTRY1_USERNAME"' )
lines_in_file+=( 'export REGISTRY1_PASSWORD="$REGISTRY1_PASSWORD"' )

for line in "\${lines_in_file[@]}"; do
  grep -qF "\${line}" ~/.bashrc
  if [ \$? -ne 0 ]; then echo "\${line}" >> ~/.bashrc ; fi
done
EOFworkload-k3d-prepwork-commandsEOF

# run the above commands against the remote shell in parallel and wait for finish
ssh keycloak-cluster < ~/qs/keycloak-k3d-prepwork-commands.txt &
ssh workload-cluster < ~/qs/workload-k3d-prepwork-commands.txt &
wait
# Explanation: (We're basically doing Ansible w/o Ansible's dependencies)
# ssh keycloak-cluster < ~/qs/keycloak-k3d-prepwork-commands.txt
# ^-- runs script against remote VM 
# & at the end of the command means to let it run in the background
# using it allows us to run the script against both machines in parallel.
# wait command waits for background processes to finish
```

1. Take a look at one of the VMs to understand what happened
```shell
# [admin@Laptop:~]
# First a command to confirm ~/.bashrc was updated as expected
ssh keycloak-cluster 'tail ~/.bashrc' 

# Then ssh in to see the differences
ssh keycloak-cluster

# [ubuntu@keycloak-cluster:~$]
echo "Notice the prompt makes it obvious which VM you ssh'ed into"
echo "Notice the prompt has access to environment variables that are useful for automation"
env | grep -i name
env | grep IP
exit

# [admin@Laptop:~]
```

1. Configure host OS prerequisites and install prerequisite software on both VMs
```shell
# [admin@Laptop:~]
# Note ? is escaped in some places in the form of \?, this prevents substitution
# by the local machine, which allows the remote VM to do the substituting. 
cat << EOFshared-k3d-prepwork-commandsEOF > ~/qs/shared-k3d-prepwork-commands.txt
# Configure OS
sudo sysctl -w vm.max_map_count=524288
sudo sysctl -w fs.file-max=131072
ulimit -n 131072
ulimit -u 8192
sudo sysctl --load
sudo modprobe xt_REDIRECT
sudo modprobe xt_owner
sudo modprobe xt_statistic
printf "xt_REDIRECT\nxt_owner\nxt_statistic\n" | sudo tee -a /etc/modules
sudo swapoff -a

# Install git
sudo apt install git -y

# Install docker (note we use escape some vars we want the remote linux to substitute)
sudo apt update -y && sudo apt install apt-transport-https ca-certificates curl gnupg lsb-release -y 
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor | sudo tee /usr/share/keyrings/docker-archive-keyring.gpg 
echo "deb [arch=amd64 signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu \$(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null 
sudo apt update -y && sudo apt install docker-ce docker-ce-cli containerd.io -y && sudo usermod --append --groups docker \$USER

# Install k3d
wget -q -O - https://github.com/rancher/k3d/releases/download/v4.4.7/k3d-linux-amd64 > k3d
echo 51731ffb2938c32c86b2de817c7fbec8a8b05a55f2e4ab229ba094f5740a0f60 k3d | sha256sum -c | grep OK
if [ \$? == 0 ]; then chmod +x k3d && sudo mv k3d /usr/local/bin/k3d ; fi

# Install kubectl
wget -q -O - https://dl.k8s.io/release/v1.22.1/bin/linux/amd64/kubectl > kubectl
echo 78178a8337fc6c76780f60541fca7199f0f1a2e9c41806bded280a4a5ef665c9 kubectl | sha256sum -c | grep OK
if [ \$? == 0 ]; then chmod +x kubectl && sudo mv kubectl /usr/local/bin/kubectl; fi
sudo ln -s /usr/local/bin/kubectl /usr/local/bin/k || true

# Install kustomize
wget -q -O - https://github.com/kubernetes-sigs/kustomize/releases/download/kustomize%2Fv4.3.0/kustomize_v4.3.0_linux_amd64.tar.gz > kustomize.tar.gz
echo d34818d2b5d52c2688bce0e10f7965aea1a362611c4f1ddafd95c4d90cb63319 kustomize.tar.gz | sha256sum -c | grep OK
if [ \$? == 0 ]; then tar -xvf kustomize.tar.gz && chmod +x kustomize && sudo mv kustomize /usr/local/bin/kustomize && rm kustomize.tar.gz ; fi    

# Install helm
wget -q -O - https://get.helm.sh/helm-v3.6.3-linux-amd64.tar.gz > helm.tar.gz
echo 07c100849925623dc1913209cd1a30f0a9b80a5b4d6ff2153c609d11b043e262 helm.tar.gz | sha256sum -c | grep OK
if [ \$? == 0 ]; then tar -xvf helm.tar.gz && chmod +x linux-amd64/helm && sudo mv linux-amd64/helm /usr/local/bin/helm && rm -rf linux-amd64 && rm helm.tar.gz ; fi
EOFshared-k3d-prepwork-commandsEOF

# [admin@Laptop:~]
# Run the above prereq script against both VMs
ssh keycloak-cluster < ~/qs/shared-k3d-prepwork-commands.txt &
ssh workload-cluster < ~/qs/shared-k3d-prepwork-commands.txt &
wait

# Verify install was successful
cat << EOFshared-k3d-prepwork-verification-commandsEOF > ~/qs/shared-k3d-prepwork-verification-commands.txt
docker ps >> /dev/null ; echo \$? | grep 0 >> /dev/null && echo "SUCCESS: docker installed" || echo "ERROR: issue with docker install"
k3d version >> /dev/null ; echo \$? | grep 0 >> /dev/null && echo "SUCCESS: k3d installed" || echo "ERROR: issue with k3d install"
kubectl version --client >> /dev/null ; echo \$? | grep 0 >> /dev/null && echo "SUCCESS: kubectl installed" || echo "ERROR: issue with kubectl install"
kustomize version >> /dev/null ; echo \$? | grep 0 >> /dev/null && echo "SUCCESS: kustomize installed" || echo "ERROR: issue with kustomize install"
helm version >> /dev/null ; echo \$? | grep 0 >> /dev/null && echo "SUCCESS: helm installed" || echo "ERROR: issue with helm install" 
EOFshared-k3d-prepwork-verification-commandsEOF

ssh keycloak-cluster < ~/qs/shared-k3d-prepwork-verification-commands.txt 
ssh workload-cluster < ~/qs/shared-k3d-prepwork-verification-commands.txt
```


## Step 4: Create k3d cluster on both VMs and make sure you have access to both
```shell
# [admin@Laptop:~]
# Note: 
# ssh keycloak-cluster 'env | grep K3D_IP'
# shows that env vars defined in ~/.bashrc aren't populated when using non interactive shell method
# The following workaround is used to grab their values for use in non interactive shell
# export K3D_IP=\$(cat ~/.bashrc  | grep K3D_IP | cut -d \" -f 2)

cat << EOFshared-k3d-install-commandsEOF > ~/qs/shared-k3d-install-commands.txt
export K3D_IP=\$(cat ~/.bashrc  | grep K3D_IP | cut -d \" -f 2)
export CLUSTER_NAME=\$(cat ~/.bashrc  | grep CLUSTER_NAME | cut -d \" -f 2)

IMAGE_CACHE=\${HOME}/.k3d-container-image-cache
mkdir -p \${IMAGE_CACHE}
k3d cluster create \$CLUSTER_NAME \
    --k3s-server-arg "--tls-san=\$K3D_IP" \
    --volume /etc/machine-id:/etc/machine-id \
    --volume \${IMAGE_CACHE}:/var/lib/rancher/k3s/agent/containerd/io.containerd.content.v1.content \
    --k3s-server-arg "--disable=traefik" \
    --port 80:80@loadbalancer \
    --port 443:443@loadbalancer \
    --api-port 6443
sed -i "s/0.0.0.0/\$K3D_IP/" ~/.kube/config
# Explanation:
# sed = stream editor 
# -i 's/...   (i = inline), (s = substitution, basically cli find and replace)
# / / / are delimiters the separate what to find and what to replace.
# \$K3D_IP, is a variable with $ escaped, so the var will be processed by the remote VM.
# This was done to allow kubectl access from a remote machine.
EOFshared-k3d-install-commandsEOF

ssh keycloak-cluster < ~/qs/shared-k3d-install-commands.txt &
ssh workload-cluster < ~/qs/shared-k3d-install-commands.txt &
wait

mkdir -p ~/.kube
scp keycloak-cluster:~/.kube/config ~/.kube/keycloak-cluster
scp workload-cluster:~/.kube/config ~/.kube/workload-cluster

export KUBECONFIG=$HOME/.kube/keycloak-cluster
k get node
export KUBECONFIG=$HOME/.kube/workload-cluster
k get node
```


## Step 5: Clone Big Bang and Install Flux on both Clusters
```shell
# [admin@Laptop:~]
cat << EOFshared-flux-install-commandsEOF > ~/qs/shared-flux-install-commands.txt
export REGISTRY1_USERNAME=\$(cat ~/.bashrc  | grep REGISTRY1_USERNAME | cut -d \" -f 2)
export REGISTRY1_PASSWORD=\$(cat ~/.bashrc  | grep REGISTRY1_PASSWORD | cut -d \" -f 2)
export BIG_BANG_VERSION=\$(cat ~/.bashrc  | grep BIG_BANG_VERSION | cut -d \" -f 2)

cd ~
git clone https://repo1.dso.mil/platform-one/big-bang/bigbang.git
cd ~/bigbang
git checkout tags/\$BIG_BANG_VERSION
\$HOME/bigbang/scripts/install_flux.sh -u \$REGISTRY1_USERNAME -p \$REGISTRY1_PASSWORD
EOFshared-flux-install-commandsEOF

ssh keycloak-cluster < ~/qs/shared-flux-install-commands.txt &
ssh workload-cluster < ~/qs/shared-flux-install-commands.txt &
wait

export KUBECONFIG=$HOME/.kube/keycloak-cluster
kubectl get po -n=flux-system
export KUBECONFIG=$HOME/.kube/workload-cluster
kubectl get po -n=flux-system
```


## Step 6: Install Big Bang on Workload Cluster
```shell
# [admin@Laptop:~]
cat << EOFdeploy-workloadsEOF > ~/qs/deploy-workloads.txt
export REGISTRY1_USERNAME=\$(cat ~/.bashrc  | grep REGISTRY1_USERNAME | cut -d \" -f 2)
export REGISTRY1_PASSWORD=\$(cat ~/.bashrc  | grep REGISTRY1_PASSWORD | cut -d \" -f 2)

cat << EOF > ~/ib_creds.yaml
registryCredentials:
  registry: registry1.dso.mil
  username: "\$REGISTRY1_USERNAME"
  password: "\$REGISTRY1_PASSWORD"
EOF

cat << EOF > ~/demo_values.yaml
logging:
  values:
    kibana:
      count: 1
      resources:
        requests:
          cpu: 1m
          memory: 1Mi
        limits:
          cpu: null  # nonexistent cpu limit results in faster spin up
          memory: null
    elasticsearch:
      master:
        count: 1
        resources:
          requests:
            cpu: 1m
            memory: 1Mi
          limits:
            cpu: null
            memory: null
      data:
        count: 1
        resources:
          requests:
            cpu: 1m
            memory: 1Mi
          limits: 
            cpu: null
            memory: null

clusterAuditor:
  values:
    resources:
      requests:
        cpu: 1m
        memory: 1Mi
      limits:
        cpu: null
        memory: null

gatekeeper:
  enabled: true
  values:
    replicas: 1
    controllerManager:
      resources:
        requests:
          cpu: 1m
          memory: 1Mi
        limits:
          cpu: null
          memory: null
    audit:
      resources:
        requests:
          cpu: 1m
          memory: 1Mi
        limits:
          cpu: null
          memory: null
    violations:
      allowedDockerRegistries:
        enforcementAction: dryrun

istio:
  values:
    values:
      global:
        proxy:
          resources:
            requests:
              cpu: 0m
              memory: 0Mi
            limits:
              cpu: 0m
              memory: 0Mi

twistlock:
  enabled: false
EOF

helm upgrade --install bigbang \$HOME/bigbang/chart \
  --values https://repo1.dso.mil/platform-one/big-bang/bigbang/-/raw/master/chart/ingress-certs.yaml \
  --values \$HOME/bigbang/chart/dev-k3d-values.yaml \
  --values \$HOME/ib_creds.yaml \
  --values \$HOME/demo_values.yaml \
  --namespace=bigbang --create-namespace
EOFdeploy-workloadsEOF

ssh workload-cluster < ~/qs/deploy-workloads.txt

# You can run these commands to check it out, 
# but there's no need to wait for the deployment to finish before moving on.
export KUBECONFIG=$HOME/.kube/workload-cluster
kubectl get hr -A
```


## Step 7: Install Keycloak on Keycloak Cluster
```shell
# [admin@Laptop:~]
cat << EOFdeploy-keycloakEOF > ~/qs/deploy-keycloak.txt
export REGISTRY1_USERNAME=\$(cat ~/.bashrc  | grep REGISTRY1_USERNAME | cut -d \" -f 2)
export REGISTRY1_PASSWORD=\$(cat ~/.bashrc  | grep REGISTRY1_PASSWORD | cut -d \" -f 2)

cat << EOF > ~/ib_creds.yaml
registryCredentials:
  registry: registry1.dso.mil
  username: "\$REGISTRY1_USERNAME"
  password: "\$REGISTRY1_PASSWORD"
EOF

cat << EOF > ~/keycloak_qs_demo_values.yaml
eckoperator:
  enabled: false
logging:
  enabled: false
fluentbit:
  enabled: false
monitoring:
  enabled: false
clusterAuditor:
  enabled: false
gatekeeper:
  enabled: false
kiali:
  enabled: false
jaeger:
  enabled: false
istio:
  ingressGateways:
    public-ingressgateway:
      type: "NodePort"
  values:
    values: 
      global: 
        proxy: 
          resources:
            requests:
              cpu: 0m 
              memory: 0Mi
            limits:
              cpu: 0m
              memory: 0Mi
twistlock:
  enabled: false
EOF

helm upgrade --install bigbang \$HOME/bigbang/chart \
  --values https://repo1.dso.mil/platform-one/big-bang/bigbang/-/raw/master/chart/keycloak-dev-values.yaml \
  --values \$HOME/ib_creds.yaml \
  --values \$HOME/keycloak_qs_demo_values.yaml \
  --namespace=bigbang --create-namespace
EOFdeploy-keycloakEOF

ssh keycloak-cluster < ~/qs/deploy-keycloak.txt 
```


## Step 8: Edit your workstation's Hosts file to access the web pages hosted on the Big Bang Clusters

### Linux/Mac Users
```shell
# [admin@Laptop:~]
export KEYCLOAK_IP=$(cat ~/.ssh/config | grep keycloak-cluster -A 1 | grep Hostname | awk '{print $2}')
export WORKLOAD_IP=$(cat ~/.ssh/config | grep workload-cluster -A 1 | grep Hostname | awk '{print $2}')

echo "$KEYCLOAK_IP keycloak.bigbang.dev" | sudo tee -a /etc/hosts
echo "$WORKLOAD_IP authdemo.bigbang.dev" | sudo tee -a /etc/hosts
echo "$WORKLOAD_IP alertmanager.bigbang.dev" | sudo tee -a /etc/hosts
echo "$WORKLOAD_IP grafana.bigbang.dev" | sudo tee -a /etc/hosts
echo "$WORKLOAD_IP prometheus.bigbang.dev" | sudo tee -a /etc/hosts
echo "$WORKLOAD_IP argocd.bigbang.dev" | sudo tee -a /etc/hosts
echo "$WORKLOAD_IP kiali.bigbang.dev" | sudo tee -a /etc/hosts
echo "$WORKLOAD_IP tracing.bigbang.dev" | sudo tee -a /etc/hosts
echo "$WORKLOAD_IP kibana.bigbang.dev" | sudo tee -a /etc/hosts

cat /etc/hosts
```

### Windows Users
* Edit similiarly using method mentioned in the generic quickstart


## Step 9: Make sure the clusters had enough time to finish deployment
```shell
# [admin@Laptop:~]
export KUBECONFIG=$HOME/.kube/keycloak-cluster
kubectl get pods -A
kubectl wait --for=condition=ready --timeout=10m pod/keycloak-0 -n=keycloak #takes about 5min
kubectl get hr -A
kubectl get svc -n=istio-system # verify EXTERNAL-IP isn't stuck in pending

export KUBECONFIG=$HOME/.kube/workload-cluster
kubectl get hr -A
kubectl wait --for=condition=ready --timeout=10m hr/jaeger -n=bigbang #takes about 10-15mins
kubectl get hr -A
kubectl get svc -n=istio-system # verify EXTERNAL-IP isn't stuck in pending
```

## Step 10: Verify that you can access websites hosted in both clusters
* In a Web Browser try to visit the following 2 webpages
  * <keycloak.bigbang.dev>
  * <grafana.bigbang.dev>


## Step 11: Create a user in keycloak
> Note: Additional Keycloak documentation can be found in these locations:    
> https://repo1.dso.mil/platform-one/big-bang/apps/security-tools/keycloak
> https://repo1.dso.mil/platform-one/big-bang/bigbang/-/blob/master/charter/packages/keycloak/Architecture.md
1. Visit <keycloak.bigbang.dev>
2. Follow the self registration link https://keycloak.bigbang.dev/register
3. Create a demo account, the email you specify doesn't have to exist for demo purposes, make sure you write down the demo username and password.
4. Create an MFA device.
5. It'll say "You need to verify your email address to activate your account"
6. Visit <https://keycloak.bigbang.dev/auth/admin>
7. Login as a keycloak admin, using the default creds of admin:password
8. In the GUI Navigate to: Manage > Users > [View all users] > Edit your demo user     
In the GUI Manually:     
* Delete "Verify Email" from Required User Actions and click save.     
* Toggle Email Verified from Off to True     

## Step 12: Deploy a mock mission application to the workload cluster
```shell
# [admin@Laptop:~]
cat << EOFdeploy-mock-mission-appEOF > ~/qs/deploy-mock-mission-app.txt

#Creating demo namespace
k create ns mock-mission-app 

#Adding namespace to the service mesh
k label ns mock-mission-app istio-injection=enabled 

# Adding docker_cred to namespace so istio side car image pull will work.
base64ed_dockercreds=\$(kubectl get secret private-registry -n=istio-system --output="jsonpath={.data.\.dockerconfigjson}")
temp="""
apiVersion: v1
kind: Secret
type: kubernetes.io/dockerconfigjson
metadata:
  name: private-registry
data:
  .dockerconfigjson: \$base64ed_dockercreds
"""
echo "\$temp" | kubectl apply -f - -n=mock-mission-app

# Deploying mock mission application
kubectl apply -k github.com/stefanprodan/podinfo//kustomize -n=mock-mission-app

# Exposing via Istio Ingress Gateway
temp="""
apiVersion: networking.istio.io/v1beta1
kind: VirtualService
metadata:
  name: mission
spec:
  gateways:
  - istio-system/public
  hosts:
  - authdemo.bigbang.dev
  http:
  - route:
    - destination:
         host: podinfo
         port:
            number: 9898
"""
echo "\$temp" | kubectl apply -f - -n=mock-mission-app
EOFdeploy-mock-mission-appEOF

ssh workload-cluster < ~/qs/deploy-mock-mission-app.txt
```


## Step 13: Visit the newly added webpage
* In a browser navigate to <authdemo.bigbang.dev>


## Step 14: Deploy auth service to the workload cluster and use it to protect the mock mission app
```shell
# [admin@Laptop:~]
cat << EOFdeploy-auth-service-demoEOF > ~/qs/deploy-auth-service-demo.txt

cat << EOF > ~/pods-in-deployment-label-patch.yaml
spec:
  template:
    metadata:
      labels:
        protect: keycloak
EOF

kubectl patch deployment podinfo --type merge --patch "\$(cat ~/pods-in-deployment-label-patch.yaml)" -n=mock-mission-app

cat << EOF > ~/auth_service_demo_values.yaml
addons:
  authservice:
    enabled: true
    values:
      chains:
        full:
          callback_uri:
          match:
            prefix: ""
EOF

helm upgrade --install bigbang \$HOME/bigbang/chart \
  --values https://repo1.dso.mil/platform-one/big-bang/bigbang/-/raw/master/chart/ingress-certs.yaml \
  --values \$HOME/bigbang/chart/dev-k3d-values.yaml \
  --values \$HOME/ib_creds.yaml \
  --values \$HOME/demo_values.yaml \
  --values \$HOME/auth_service_demo_values.yaml \
  --namespace=bigbang --create-namespace
EOFdeploy-auth-service-demoEOF

ssh workload-cluster < ~/qs/deploy-auth-service-demo.txt

export KUBECONFIG=$HOME/.kube/workload-cluster

```


