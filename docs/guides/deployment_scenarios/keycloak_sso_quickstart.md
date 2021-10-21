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
cat << EOFinstall-keycloakEOF > ~/qs/install-keycloak.txt

```

## Step 7: Install Keycloak on Keycloak Cluster
```shell
# [admin@Laptop:~]
cat << EOFinstall-keycloakEOF > ~/qs/install-keycloak.txt
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
  --values \$HOME/ib_creds.yaml \
  --values \$HOME/keycloak_qs_demo_values.yaml \
  --values \$HOME/bigbang/chart/keycloak-dev-values.yaml \
  --namespace=bigbang --create-namespace
EOFinstall-keycloakEOF

ssh keycloak-cluster < ~/qs/install-keycloak.txt 

export KUBECONFIG=$HOME/.kube/keycloak-cluster
kubectl wait --for=condition=ready --timeout=10m pod/keycloak-0 -n=keycloak #takes about 5min
```




## Step 11: Verify Big Bang has had enough time to finish installing

* If you try to run the command in Step 12 too soon, you'll see an ignorable temporary error message

    ```shell
    # [ubuntu@Ubuntu_VM:~]
    kubectl get virtualservices --all-namespaces
    
    # Note after running the above command, you may see an ignorable temporary error message
    # The error message may be different based on your timing, but could look like this:
    #     error: the server doesn't have a resource type "virtualservices"
    #     or
    #     No resources found
    
    # The above errors could be seen if you run the command too early 
    # Give Big Bang some time to finish installing, then run the following command to check it's status
    
    k get po -A
    ```

* If after running `k get po -A` (which is the shorthand of `kubectl get pods --all-namespaces`) you see something like the following, then you need to wait longer

    ```console
    NAMESPACE           NAME                                                READY   STATUS              RESTARTS   AGE
    kube-system         metrics-server-86cbb8457f-dqsl5                     1/1     Running             0          39m
    kube-system         coredns-7448499f4d-ct895                            1/1     Running             0          39m
    flux-system         notification-controller-65dffcb7-qpgj5              1/1     Running             0          32m
    flux-system         kustomize-controller-d689c6688-6dd5n                1/1     Running             0          32m
    flux-system         source-controller-5fdb69cc66-s9pvw                  1/1     Running             0          32m
    kube-system         local-path-provisioner-5ff76fc89d-gnvp4             1/1     Running             1          39m
    flux-system         helm-controller-6c67b58f78-6dzqw                    1/1     Running             0          32m
    gatekeeper-system   gatekeeper-controller-manager-5cf7696bcf-xclc4      0/1     Running             0          4m6s
    gatekeeper-system   gatekeeper-audit-79695c56b8-qgfbl                   0/1     Running             0          4m6s
    istio-operator      istio-operator-5f6cfb6d5b-hx7bs                     1/1     Running             0          4m8s
    eck-operator        elastic-operator-0                                  1/1     Running             1          4m10s
    istio-system        istiod-65798dff85-9rx4z                             1/1     Running             0          87s
    istio-system        public-ingressgateway-6cc4dbcd65-fp9hv              0/1     ContainerCreating   0          46s
    logging             logging-fluent-bit-dbkxx                            0/2     Init:0/1            0          44s
    monitoring          monitoring-monitoring-kube-admission-create-q5j2x   0/1     ContainerCreating   0          42s
    logging             logging-ek-kb-564d7779d5-qjdxp                      0/2     Init:0/2            0          41s
    logging             logging-ek-es-data-0                                0/2     Init:0/2            0          44s
    istio-system        svclb-public-ingressgateway-ggkvx                   5/5     Running             0          39s
    logging             logging-ek-es-master-0                              0/2     Init:0/2            0          37s
    ```

* Wait up to 10 minutes then re-run `k get po -A`, until all pods show STATUS Running

* `helm list -n=bigbang` should also show STATUS deployed

    ```console
    NAME                         	NAMESPACE        	REVISION	UPDATED                                	STATUS  	CHART                             	APP VERSION
    bigbang                      	bigbang          	1       	2021-10-07 19:16:13.990755769 +0000 UTC	deployed	bigbang-1.17.0
    eck-operator-eck-operator    	eck-operator     	1       	2021-10-07 19:16:18.300583454 +0000 UTC	deployed	eck-operator-1.6.0-bb.2           	1.6.0
    gatekeeper-system-gatekeeper 	gatekeeper-system	1       	2021-10-07 19:16:20.783813062 +0000 UTC	deployed	gatekeeper-3.5.2-bb.1             	v3.5.2
    istio-operator-istio-operator	istio-operator   	1       	2021-10-07 19:16:20.564511742 +0000 UTC	deployed	istio-operator-1.10.4-bb.1
    istio-system-istio           	istio-system     	1       	2021-10-07 19:17:18.267592579 +0000 UTC	deployed	istio-1.10.4-bb.3
    jaeger-jaeger                	jaeger           	1       	2021-10-07 19:29:15.866513597 +0000 UTC	deployed	jaeger-operator-2.23.0-bb.2       	1.24.0
    kiali-kiali                  	kiali            	1       	2021-10-07 19:29:14.362710144 +0000 UTC	deployed	kiali-operator-1.39.0-bb.2        	1.39.0
    logging-cluster-auditor      	logging          	1       	2021-10-07 19:20:55.145508137 +0000 UTC	deployed	cluster-auditor-0.3.0-bb.7        	1.16.0
    logging-ek                   	logging          	1       	2021-10-07 19:17:50.022767703 +0000 UTC	deployed	logging-0.1.21-bb.0               	7.13.4
    logging-fluent-bit           	logging          	1       	2021-10-07 19:29:42.290601582 +0000 UTC	deployed	fluent-bit-0.16.6-bb.0            	1.8.6
    monitoring-monitoring        	monitoring       	1       	2021-10-07 19:18:02.816162712 +0000 UTC	deployed	kube-prometheus-stack-14.0.0-bb.10	0.46.0
    ```

## Step 12: Edit your workstation's Hosts file to access the web pages hosted on the Big Bang Cluster

Run the following command, which is the short hand equivalent of `kubectl get virtualservices --all-namespaces` to see a list of websites you'll need to add to your hosts file

```shell
k get vs -A
```

```console
NAMESPACE    NAME                                      GATEWAYS                  HOSTS                          AGE
logging      kibana                                    ["istio-system/public"]   ["kibana.bigbang.dev"]         38m
monitoring   monitoring-monitoring-kube-grafana        ["istio-system/public"]   ["grafana.bigbang.dev"]        36m
monitoring   monitoring-monitoring-kube-alertmanager   ["istio-system/public"]   ["alertmanager.bigbang.dev"]   36m
monitoring   monitoring-monitoring-kube-prometheus     ["istio-system/public"]   ["prometheus.bigbang.dev"]     36m
kiali        kiali                                     ["istio-system/public"]   ["kiali.bigbang.dev"]          35m
jaeger       jaeger                                    ["istio-system/public"]   ["tracing.bigbang.dev"]        35m
```

### Linux/Mac Users

```shell
# [admin@Laptop:~]
sudo vi /etc/hosts
```

### Windows Users

1. Right click Notepad -> Run as Administrator
1. Open C:\Windows\System32\drivers\etc\hosts

### Linux/Mac/Windows Users

Add the following entries to the Hosts file, where x.x.x.x = k3d virtual machine's IP.

> Hint: find and replace is your friend

```plaintext
x.x.x.x  kibana.bigbang.dev
x.x.x.x  grafana.bigbang.dev
x.x.x.x  alertmanager.bigbang.dev
x.x.x.x  prometheus.bigbang.dev
x.x.x.x  kiali.bigbang.dev
x.x.x.x  tracing.bigbang.dev
x.x.x.x  argocd.bigbang.dev
```

## Step 13: Visit a webpage

In a browser, visit one of the sites listed using the `k get vs -A` command

## Step 14: Play

Here's an example of post deployment customization of Big Bang.
After looking at <https://repo1.dso.mil/platform-one/big-bang/bigbang/-/blob/master/chart/values.yaml>
It should make sense that the following is a valid edit

```shell
# [ubuntu@Ubuntu_VM:~]

cat << EOF > ~/tinkering.yaml
addons:
  argocd:
    enabled: true
EOF

helm upgrade --install bigbang $HOME/bigbang/chart \
--values https://repo1.dso.mil/platform-one/big-bang/bigbang/-/raw/master/chart/ingress-certs.yaml \
--values $HOME/ib_creds.yaml \
--values $HOME/demo_values.yaml \
--values $HOME/tinkering.yaml \
--namespace=bigbang --create-namespace

# NOTE: There may be a ~1 minute delay for the change to apply

k get vs -A
# Now ArgoCD should show up, if it doesn't wait a minute and rerun the command

k get po -n=argocd
# Once these are all Running you can visit argocd's webpage
```

> Remember to un-edit your Hosts file when you are finished tinkering.
