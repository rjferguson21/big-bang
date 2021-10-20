# Big Bang Quick Start

[[_TOC_]]


## Overview
This Keycloak SSO Quick Start Guide explains how to complete the following tasks in under 2 hours:
1. Given 2 VMs (each with 8 cpu cores / 32 GB ram) that are each setup for ssh, turn the 2 VMs into 2 single node k3d clusters.
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


## Step 3: Install k3d on both VMs
1. Set some Variables and push them to each VM
* We'll pass some environment variables into the VMs that will help with automation
* We'll also update the PS1 var so we can tell the 2 machines apart when sshed in.
* All of the commands in the following section are run from the Admin Laptop

```shell
# [admin@Laptop:~]
mkdir ~/qs
BIG_BANG_VERSION="1.18.0"
REGISTRY1_USERNAME="REPLACE_ME"
REGISTRY1_PASSWORD="REPLACE_ME"
echo $REGISTRY1_PASSWORD | docker login https://registry1.dso.mil --username=$REGISTRY1_USERNAME --password-stdin | grep "Login Succeeded" ; echo $? | grep 0 && echo "This validation check shows your registry1 credentials are valid, please continue." || for i in {1..10}; do echo "Validation check shows error, fix your registry1 credentials before moving on."; done

export KEYCLOAK_IP=$(cat ~/.ssh/config | grep keycloak-cluster -A 1 | grep Hostname | awk '{print $2}')
echo "\n\n\n$KEYCLOAK_IP is the IP of the k3d node that will host Keycloak on Big Bang"

export WORKLOAD_IP=$(cat ~/.ssh/config | grep workload-cluster -A 1 | grep Hostname | awk '{print $2}')
echo "$WORKLOAD_IP is the IP of the k3d node that will host Workloads on Big Bang"
echo "Please manually verify that the IP of your keycloak and workload k3d VMs looks correct before moving on."



cat << EOFkeycloak-k3d-prepwork-commandsEOF > ~/qs/keycloak-k3d-prepwork-commands.txt
echo 'export PS1="\[\033[01;32m\]\u@keycloak-cluster\[\033[00m\]:\[\033[01;34m\]\w\[\033[00m\]\$ "'  >> ~/.bashrc
echo 'export K3D_IP="$KEYCLOAK_IP"'  >> ~/.bashrc
echo 'export BIG_BANG_VERSION="$BIG_BANG_VERSION"'  >> ~/.bashrc
echo 'export REGISTRY1_USERNAME="$REGISTRY1_USERNAME"'  >> ~/.bashrc
echo 'export REGISTRY1_PASSWORD="$REGISTRY1_PASSWORD"'  >> ~/.bashrc
EOFkeycloak-k3d-prepwork-commandsEOF

cat << EOFworkload-k3d-prepwork-commandsEOF > ~/qs/workload-k3d-prepwork-commands.txt
echo 'export PS1="\[\033[01;32m\]\u@workload-cluster\[\033[00m\]:\[\033[01;34m\]\w\[\033[00m\]\$ "'  >> ~/.bashrc
echo 'export K3D_IP="$WORKLOAD_IP"'  >> ~/.bashrc
echo 'export BIG_BANG_VERSION="$BIG_BANG_VERSION"'  >> ~/.bashrc
echo 'export REGISTRY1_USERNAME="$REGISTRY1_USERNAME"'  >> ~/.bashrc
echo 'export REGISTRY1_PASSWORD="$REGISTRY1_PASSWORD"'  >> ~/.bashrc
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

1. Take a look at each VM to understand what happened
```shell
# [admin@Laptop:~]
ssh keycloak-cluster

# [ubuntu@keycloak-cluster:~$]
echo "Notice the prompt makes it obvious which VM you ssh'ed into"
echo $REGISTRY1_USERNAME
echo "Notice the prompt has access to environment variables that are useful for automation"
echo $K3D_IP
exit

# [admin@Laptop:~]
ssh workload-cluster

# [ubuntu@workload-cluster:~$]
echo $K3D_IP
echo "Good the prompt is different so you can tell them apart, and IP variable was different"
exit
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
sudo apt update -y && sudo apt install apt-transport-https ca-certificates curl gnupg lsb-release -y && curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add - && echo "deb [arch=amd64 signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu \$(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null && sudo apt update -y && sudo apt install docker-ce docker-ce-cli containerd.io -y && sudo usermod --append --groups docker \$USER

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
ssh workload-cluster 'helm version' #This confirms above install was successful
```

1. Create k3d cluster for both VMs

## Step 4:



```shell
# [ubuntu@Ubuntu_VM:~]
SERVER_IP="10.10.16.11" #(Change this value, if you need remote kubectl access)

# Create image cache directory
IMAGE_CACHE=${HOME}/.k3d-container-image-cache

mkdir -p ${IMAGE_CACHE}

k3d cluster create \
    --k3s-server-arg "--tls-san=$SERVER_IP" \
    --volume /etc/machine-id:/etc/machine-id \
    --volume ${IMAGE_CACHE}:/var/lib/rancher/k3s/agent/containerd/io.containerd.content.v1.content \
    --k3s-server-arg "--disable=traefik" \
    --port 80:80@loadbalancer \
    --port 443:443@loadbalancer \
    --api-port 6443
```

### k3d Cluster Verification Command

```shell
# [ubuntu@Ubuntu_VM:~]
kubectl config use-context k3d-k3s-default
kubectl get node
```

```console
Switched to context "k3d-k3s-default".
NAME                       STATUS   ROLES                  AGE   VERSION
k3d-k3s-default-server-0   Ready    control-plane,master   11m   v1.21.3+k3s1
```

## Step 6: Verify Your IronBank Image Pull Credentials

1. Here we continue to follow the DevOps best practice of enabling early left-shifted feedback whenever possible; Before adding credentials to a configuration file and not finding out there is an issue until after we see an ImagePullBackOff error during deployment, we will do a quick left-shifted verification of the credentials.

1. Look up your IronBank image pull credentials
    1. In a web browser go to [https://registry1.dso.mil](https://registry1.dso.mil)
    1. Login via OIDC provider
    1. In the top right of the page, click your name, and then User Profile
    1. Your image pull username is labeled "Username"
    1. Your image pull password is labeled "CLI secret"
      > Note: The image pull credentials are tied to the life cycle of an OIDC token which expires after ~3 days, so if 3 days have passed since your last login to IronBank, the credentials will stop working until you re-login to the [https://registry1.dso.mil](https://registry1.dso.mil) GUI

1. Verify your credentials work

    ```shell
    # [ubuntu@Ubuntu_VM:~]
    # Turn off bash history
    set +o history

    export REGISTRY1_USERNAME=<REPLACE_ME>
    export REGISTRY1_PASSWORD=<REPLACE_ME>
    echo $REGISTRY1_PASSWORD | docker login registry1.dso.mil --username $REGISTRY1_USERNAME --password-stdin
    
    # Turn on bash history
    set -o history
    ```

## Step 7: Clone your desired version of the Big Bang Umbrella Helm Chart

```shell
# [ubuntu@Ubuntu_VM:~]
cd ~
git clone https://repo1.dso.mil/platform-one/big-bang/bigbang.git
cd ~/bigbang

# Checkout version 1.17.0 of Big Bang
# (Pinning to specific version to improve reproducibility)
git checkout tags/1.17.0
git status
```

```console
HEAD detached at 1.17.0
```

> HEAD is git speak for current context within a tree of commits

## Step 8: Install Flux

* The `echo $REGISTRY1_USERNAME` is there to verify the value of your environmental variable is still populated. If you switch terminals or re-login, you may need to reestablish these variables.

    ```shell
    # [ubuntu@Ubuntu_VM:~]
    echo $REGISTRY1_USERNAME
    cd ~/bigbang
    $HOME/bigbang/scripts/install_flux.sh -u $REGISTRY1_USERNAME -p $REGISTRY1_PASSWORD
    # NOTE: After running this command the terminal may appear to be stuck on
    # "networkpolicy.networking.k8s.io/allow-webhooks created"
    # It's not stuck, the end of the .sh script has a kubectl wait command, give it 5 min
    # Also if you have slow internet/hardware you might see a false error message
    # error: timed out waiting for the condition on deployments/helm-controller
    
    # As long as the following command shows STATUS Running you're good to move on
    kubectl get pods --namespace=flux-system
    ```
    
    ```console
    NAME                                     READY   STATUS    RESTARTS   AGE
    kustomize-controller-d689c6688-bnr96     1/1     Running   0          3m8s
    notification-controller-65dffcb7-zk796   1/1     Running   0          3m8s
    source-controller-5fdb69cc66-g5dlh       1/1     Running   0          3m8s
    helm-controller-6c67b58f78-cvxmv         1/1     Running   0          3m8s
    ```

## Step 9: Create helm values .yaml files to act as input variables for the Big Bang Helm Chart

> Note for those new to linux: The following are multi line copy pasteable commands to quickly generate config files from the CLI, make sure you copy from cat to EOF, if you get stuck in the terminal use ctrl + c

```shell
# [ubuntu@Ubuntu_VM:~]
cat << EOF > ~/ib_creds.yaml
registryCredentials:
  registry: registry1.dso.mil
  username: "$REGISTRY1_USERNAME"
  password: "$REGISTRY1_PASSWORD"
EOF


cat << EOF > ~/demo_values.yaml
logging:
  values:
    kibana:
      count: 1
      resources:
        requests:
          cpu: 400m
          memory: 1Gi
        limits:
          cpu: null  # nonexistent cpu limit results in faster spin up
          memory: null
    elasticsearch:
      master:
        count: 1
        resources:
          requests:
            cpu: 400m
            memory: 2Gi
          limits:
            cpu: null
            memory: null
      data:
        count: 1
        resources:
          requests:
            cpu: 400m
            memory: 2Gi
          limits: 
            cpu: null
            memory: null

clusterAuditor:
  values:
    resources:
      requests:
        cpu: 400m
        memory: 2Gi
      limits:
        cpu: null
        memory: null

gatekeeper:
  enabled: false
  values:
    replicas: 1
    controllerManager:
      resources:
        requests:
          cpu: 100m
          memory: 512Mi
        limits:
          cpu: null
          memory: null
    audit:
      resources:
        requests:
          cpu: 400m
          memory: 768Mi
        limits:
          cpu: null
          memory: null
    violations:
      allowedDockerRegistries:
        enforcementAction: dryrun

istio:
  values:
    values: # possible values found here https://istio.io/v1.5/docs/reference/config/installation-options (ignore 1.5, latest docs point here)
      global: # global istio operator values
        proxy: # mutating webhook injected istio sidecar proxy's values
          resources:
            requests:
              cpu: 0m # null get ignored if used here
              memory: 0Mi
            limits:
              cpu: 0m
              memory: 0Mi

twistlock:
  enabled: false # twistlock requires a license to work, so we're disabling it
EOF
```

## Step 10: Install Big Bang using the local development workflow

```shell
# [ubuntu@Ubuntu_VM:~]
helm upgrade --install bigbang $HOME/bigbang/chart \
  --values https://repo1.dso.mil/platform-one/big-bang/bigbang/-/raw/master/chart/ingress-certs.yaml \
  --values $HOME/ib_creds.yaml \
  --values $HOME/demo_values.yaml \
  --namespace=bigbang --create-namespace
```

Explanation of flags used in the imperative helm install command:

`upgrade --install`
: This makes the command more idempotent by allowing the exact same command to work for both the initial installation and upgrade use cases.

`bigbang $HOME/bigbang/chart`
: bigbang is the name of the helm release that you'd see if you run `helm list -n=bigbang`. `$HOME/bigbang/chart` is a reference to the helm chart being installed.

`--values https://repo1.dso.mil/platform-one/big-bang/bigbang/-/raw/master/chart/ingress-certs.yaml`
: References demonstration HTTPS certificates embedded in the public repository. The *.bigbang.dev wildcard certificate is signed by Let's Encrypt, a free public internet Certificate Authority. Note the URL path to the copy of the cert on master branch is used instead of `$HOME/bigbang/chart/ingress-certs.yaml`, because the Let's Encrypt certs expire after 3 months, and if you deploy a tagged release of BigBang, like 1.15.0, the version of the cert stored in the tagged git commit / release of Big Bang could be expired. Referencing the master branches copy via URL ensures you receive the latest version of the cert, which won't be expired.

`--namespace=bigbang --create-namespace`
: Means it will install the bigbang helm chart in the bigbang namespace and create the namespace if it doesn't exist.


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
