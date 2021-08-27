# Big Bang Quick Start

[[_TOC_]]

## Overview

This quick start guide explains in beginner-friendly terminology how to complete the following tasks in under an hour:

1. Turn a virtual machine (VM) into a k3d single-node Kubernetes cluster.
1. Deploy Big Bang on the cluster using a demonstration and local development-friendly workflow.

    > Note: This guide mainly focuses on the scenario of deploying Big Bang to a remote VM with enough resources to run Big Bang [(see step 1 for recommended resources)](#step-1:-provision-a-virtual-machine). If your workstation has sufficient resources, or you are willing to disable packages to lower the resource requirements, then local development is possible. This quick start guide is valid for both remote and local deployment scenarios.

1. Customize the demonstration deployment of Big Bang.

## Important Background Contextual Information

This quick start guide optimizes the speed at which a demonstrable and tinker-able deployment can be achieved by minimizing prerequisite dependencies and substituting them with quickly implementable alternatives. Refer to the [Customer Template Repo](https://repo1.dso.mil/platform-one/big-bang/customers/template) for guidance on production deployments.

* Operating System Prerequisite: Any Linux distribution that supports Docker should work.
* Operating System Pre-configuration: This quick start includes easy paste-able commands to quickly satisfy this prerequisite.
* Kubernetes Cluster Prerequisite: is implemented using k3d (k3s in Docker)
* Default Storage Class Prerequisite: k3d ships with a local volume storage class.
* Support for automated provisioning of Kubernetes Service of type LB Prerequisite: is implemented by taking advantage of k3d's ability to easily map port 443 of the VM to port 443 of a Dockerized LB that forwards traffic to a single Istio Ingress Gateway.
Important limitations of this quick start guide's implementation of k3d to be aware of:
  * Multiple Ingress Gateways aren't supported by this implementation as they would each require their own LB, and this trick of using the host's port 443 only works for automated provisioning of a single service of type LB that leverages port 443.
  * Multiple Ingress Gateways makes a demoable/tinkerable KeyCloak and locally hosted SSO deployment much easier.
  * Multiple Ingress Gateways can be demoed on k3d if configuration tweaks are made, MetalLB is used, and you are developing using a local Linux Desktop. (network connectivity limitations of the implementation would only allow a the web browser on the k3d host server to see the webpages.)
  * If you want to easily demo and tinker with Multiple Ingress Gateways and Keycloak, then MetalLB + k3s (or another non-Dockerized Kubernetes distribution) would be a happy path to look into. (or alternatively create an issue ticket requesting prioritization of a keycloak quick start or better yet a Merge Request.)
* Access to Container Images Prerequisite is satisfied by using personal image pull credentials and internet connectivity to <registry1.dso.mil>
* Customer Controlled Private Git Repo Prerequisite isn't required due to substituting declarative git ops installation of the Big Bang Helm chart with an imperative helm cli based installation.
* Encrypting Secrets as code Prerequisite is substituted with clear text secrets on your local machine.
* Installing and Configuring Flux Prerequisite: Not using GitOps for the quick start eliminates the need to configure flux, and installation is covered within this guide.
* HTTPS Certificate and hostname configuration Prerequisites: Are satisfied by leveraging default hostname values and the demo HTTPS wildcard certificate that's uploaded to the Big Bang repo, which is valid for *.bigbang.dev,*.admin.bigbang.dev, and a few others. The demo HTTPS wildcard certificate is signed by the Lets Encrypt Free, a Certificate Authority trusted on the public internet, so demo sites like grafana.bigbang.dev will show a trusted HTTPS certificate.
* DNS Prerequisite: is substituted by making use of your workstation's Hosts file.

## Step 1: Provision a Virtual Machine

The following requirements are recommended for Demo Purposes:

* 1 Virtual Machine with 32GB RAM, 8-Core CPU (t3a.2xlarge for AWS users) should be sufficient.
* Ubuntu Server 20.04 LTS (Ubuntu comes up slightly faster than CentOS, in reality any Linux distribution with Docker installed should work)
* Network connectivity to Virtual Machine (provisioning with a public IP and a security group locked down to your IP should work. Otherwise a Bare Metal server or even a Vagrant Box Virtual Machine configured for remote ssh works fine.)

> Note: If your workstation has Docker, lots of RAM/CPU, and has ports 80, 443, and 6443 free, you can use your workstation in place of a remote virtual machine and do local development.

## Step 2: SSH to Remote VM

* ssh and passwordless sudo should be configured on the remote machine
* You can skip this step if you are doing local development.

1. Setup SSH

    ```shell
    # [admin@Unix_Laptop:~]
    mkdir -p ~/.ssh
    chmod 700 ~/.ssh
    touch ~/.ssh/config
    chmod 600 ~/.ssh/config
    temp="""##########################
    Host k3d
      Hostname x.x.x.x  #IP Address of k3d node
      IdentityFile ~/.ssh/bb-onboarding-attendees.ssh.privatekey   #ssh key authorized to access k3d node
      User ubuntu
      StrictHostKeyChecking no   #Useful for vagrant where you'd reuse IP from repeated tear downs
    #########################"""
    echo "$temp" | sudo tee -a ~/.ssh/config  #tee -a, appends to preexisting config file
    ```

1. SSH to instance

    ```shell
    # [admin@Laptop:~]
    ssh k3d

    # [ubuntu@Ubuntu_VM:~]
    ```

## Step 3: Install Prerequisite Software

Note: This guide follows the DevOps best practice of left-shifting feedback on mistakes and surfacing errors as early in the process as possible. This is done by leveraging tests and verification commands.

1. Install Docker and add $USER to Docker group.

    > Docker provides a convenience script at get.docker.com to install Docker into development environments quickly and non-interactively. The convenience script is not recommended for production environments.

    ```shell
    # [ubuntu@Ubuntu_VM:~]
    curl -fsSL https://get.docker.com | bash && sudo usermod --append --groups Docker $USER
    ```

1. Logout and login to allow the `usermod` change to take effect.

    ```shell
    # [ubuntu@Ubuntu_VM:~]
    exit
    ```

    ```shell
    # [admin@Laptop:~]
    ssh k3d
    ```

1. Verify Docker Installation

    ```shell
    # [ubuntu@Ubuntu_VM:~]
    Docker run hello-world
    ```

    ```console
    Hello from Docker!
    ```

1. Install latest version of k3d

    ```shell
    # [ubuntu@Ubuntu_VM:~]
    wget -q -O - https://raw.githubusercontent.com/rancher/k3d/main/install.sh | bash
    ```

1. Verify k3d installation

    ```shell
    # [ubuntu@Ubuntu_VM:~]
    k3d --version
    ```

    ```console
    # k3d version v4.4.7
    # k3s version v1.21.2-k3s1 (default)
    ```

1. Install latest version of kubectl

    ```shell
    # [ubuntu@Ubuntu_VM:~]
    wget -q -P /tmp "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
    sudo chmod +x /tmp/kubectl
    sudo mv /tmp/kubectl /usr/local/bin/kubectl

    # Create a symbolic link from k to kubectl
    sudo ln -s /usr/local/bin/kubectl /usr/local/bin/k
    ```

1. Verify kubectl installation

    ```shell
    # [ubuntu@Ubuntu_VM:~]
    kubectl version --client
    ```

    ```console
    Client Version: version.Info{Major:"1", Minor:"22", GitVersion:"v1.22.0", GitCommit:"c2b5237ccd9c0f1d600d3072634ca66cefdf272f", GitTreeState:"clean", BuildDate:"2021-08-04T18:03:20Z", GoVersion:"go1.16.6", Compiler:"gc", Platform:"linux/amd64"}
    ```

1. Install Kustomize

    ```shell
    # [ubuntu@Ubuntu_VM:~]
    curl -s "https://raw.githubusercontent.com/kubernetes-sigs/kustomize/master/hack/install_kustomize.sh" | bash
    chmod +x kustomize
    sudo mv kustomize /usr/bin/kustomize
    ```

1. Verify Kustomize installation

    ```shell
    # [ubuntu@Ubuntu_VM:~]
    kustomize version
    ```

    ```console
    {Version:kustomize/v4.2.0 GitCommit:d53a2ad45d04b0264bcee9e19879437d851cb778 BuildDate:2021-06-30T22:49:26Z GoOs:linux GoArch:amd64}
    ```

1. Install Helm

    ```shell
    # [ubuntu@Ubuntu_VM:~]
    curl https://raw.githubusercontent.com/helm/helm/master/scripts/get-helm-3 | bash
    ```

1. Verify Helm installation

    ```shell
    # [ubuntu@Ubuntu_VM:~]
    helm version
    ```

    ```console
    version.BuildInfo{Version:"v3.6.3", GitCommit:"d506314abfb5d21419df8c7e7e68012379db2354", GitTreeState:"dirty", GoVersion:"go1.16.5"}
    ```

## Step 4: Configure Host OS prerequisites

* Run Operating System Pre-configuration

    ```shell
    # [ubuntu@Ubuntu_VM:~]
    # ECK implementation of ElasticSearch needs the following or will see OOM errors
    sudo sysctl -w vm.max_map_count=524288

    # SonarQube host OS pre-requisites
    sudo sysctl -w fs.file-max=131072
    ulimit -n 131072
    ulimit -u 8192

    # Needed for ECK to run correctly without OOM errors
    echo 'vm.max_map_count=524288' > /etc/sysctl.d/vm-max_map_count.conf

    # Needed by Sonarqube
    echo 'fs.file-max=131072' > /etc/sysctl.d/fs-file-max.conf

    # Load updated configuration
    sysctl --load

    # Alternative form of above 3 commands:
    # sudo sysctl -w vm.max_map_count=524288
    # sudo sysctl -w fs.file-max=131072

    # Needed by Sonarqube
    ulimit -n 131072
    ulimit -u 8192

    # Preload kernel modules required by istio-init, required for SELinux enforcing instances using istio-init
    modprobe xt_REDIRECT
    modprobe xt_owner
    modprobe xt_statistic

    # Persist modules after reboots
    printf "xt_REDIRECT\nxt_owner\nxt_statistic\n" | sudo tee -a /etc/modules

    # Kubernetes requires swap disabled
    # Turn off all swap devices and files (won't last reboot)
    sudo swapoff -a

    # For swap to stay off, you can remove any references found via
    # cat /proc/swaps
    # cat /etc/fstab
    ```

## Step 5:  Create a k3d Cluster

After reading the notes on the purpose of k3d's command flags, you will be able to copy and paste the command to create a k3d cluster.

### Explanation of k3d Command Flags, Relevant to the Quick Start

`SERVER_IP="10.10.16.11"` and `--k3s-server-arg "--tls-san=$SERVER_IP"`
: This associates an extra IP to the Kubernetes API server's generated HTTPS certificate.
**Here's an explanation of the effect:**

   1. If you are running k3d from a local host or you plan to run 100% of kubectl commands while ssh'd into the k3d server, then you can omit these flags or paste unmodified incorrect values with no ill effect.

   2. If you plan to run k3d on a remote server, but run kubectl, helm, and kustomize commands from a workstation, which would be needed if you wanted to do something like kubectl port-forward then you would need to specify the remote server's public or private IP address here. After pasting the ~/.kube/config file from the k3d server to your workstation, you will need to edit the IP inside of the file from 0.0.0.0 to the value you used for SERVER_IP.

**Tips for looking up the value to plug into SERVER_IP:**

* Method 1: If your k3d server is a remote box
    Then run the following command from your workstation
    `cat ~/.ssh/config | grep k3d -A 6`
* Method 2: If the remote server was provisioned with a Public IP
    Then run the following command from the server hosting k3d
    `curl ifconfig.me --ipv4`
* Method 3: If the server hosting k3d only has a Private IP
    Then run the following command from the server hosting k3d
    `ip address`
    (You'll see more than 1 address, use the one in the same subnet as your workstation)

1. `--volume /etc/machine-id:/etc/machine-id`
is required for fluentbit log shipper to work.
1. `IMAGE_CACHE=${HOME}/.k3d-container-image-cache`, `cd ~`, `mkdir -p ${IMAGE_CACHE}`, and `--volume ${IMAGE_CACHE}:/var/lib/rancher/k3s/agent/containerd/io.containerd.content.v1.content`
Make it so that if you fully deploy Big Bang and then want to reset the cluster to a fresh state to retest some deployment logic. Then after running `k3d cluster delete k3s-default` and redeploying, subsequent redeployments will be faster because all container images used will have been prefetched.
1. `--servers 1 --agents 3` flags are not used and shouldn't be added
This is because the image caching logic works more reliably on a one node Dockerized cluster, vs a four node Dockerized cluster. If you need to add these flags to simulate multi nodes to test pod and node affinity rules, then you should remove the image cache flags, or you may experience weird image pull errors.
1. `--port 80:80@loadbalancer` and `--port 443:443@loadbalancer`
Map the virtual machine's port 80 and 443 to port 80 and 443 of a Dockerized LB that will point to the nodeports of the Dockerized k3s node.

### k3d commands

```shell
# [ubuntu@Ubuntu_VM:~]
SERVER_IP="10.10.16.11" #(Change this value, if you need remote kubectl access)

IMAGE_CACHE=${HOME}/.k3d-container-image-cache

cd ~
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

### Verification Command

```shell
# [ubuntu@Ubuntu_VM:~]
k get node    # (the paste-able install commands, symbolically linked k to kubectl)
# NAME                       STATUS   ROLES                  AGE   VERSION
# k3d-k3s-default-server-0   Ready    control-plane,master   40s   v1.21.2+k3s1
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
    docker login registry1.dso.mil -username $REGISTRY1_USERNAME -password $REGISTRY1_PASSWORD
    
    # Turn on bash history
    set -o history
    ```

## Step 7: Clone your desired version of the Big Bang Umbrella Helm Chart

```shell
# [ubuntu@Ubuntu_VM:~]
cd ~
git clone https://repo1.dso.mil/platform-one/big-bang/bigbang.git
cd ~/bigbang

# Checkout version 1.14.0 of Big Bang
git checkout tags/1.14.0
git status
```

```console
HEAD detached at 1.14.0
# (Pinning to specific versions is a DevOps best practice)
# HEAD is git speak for current context within a tree of commits
```

## Step 8: Install Flux

```shell
# [ubuntu@Ubuntu_VM:~]
# Check the value of your environmental variable to confirm it's still populated.
# If you switch terminals or re-login, you may need to reestablish these variables.
echo $REGISTRY1_USERNAME
cd ~/bigbang
$HOME/bigbang/scripts/install_flux.sh -u $REGISTRY1_USERNAME -p $REGISTRY1_PASSWORD
k get po -n=flux-system
kubectl get pods --namespace=flux-system
```

## Step 9: Create helm values .yaml files to act as input variables for the Big Bang Helm Chart

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
    elasticsearch:
      master:
        count: 1
        resources:
          requests:
            cpu: 0.5
            memory: 2Gi
          limits: {}
      data:
        count: 1
        resources:
          requests:
            cpu: 0.5
            memory: 2Gi
          limits: {}
gatekeeper:
  enabled: false
  values:
    replicas: 1
    resources:
      limits: {}
    violations:
      allowedDockerRegistries:
        enforcementAction: dryrun
EOF
```

## Step 10: Install Big Bang using the local development workflow

```shell
# [ubuntu@Ubuntu_VM:~]
helm upgrade --install bigbang $HOME/bigbang/chart \
--values $HOME/bigbang/chart/ingress-certs.yaml \
--values $HOME/ib_creds.yaml \
--values $HOME/demo_values.yaml \
--namespace=bigbang --create-namespace
```

Explanation of flags in the imperative helm install command:

1. `upgrade --install`
This makes the command more idempotent by allowing the exact same command to work for both the initial installation and upgrade use cases.
2. `bigbang $HOME/bigbang/chart`
bigbang is the name of the helm release that you'd see if you run `helm list -n=bigbang`
$HOME/bigbang/chart is a reference to the helm chart being installed
3. `--values $HOME/bigbang/chart/ingress-certs.yaml`
references demo HTTPS certs embedded in the public repo (the *.bigbang.dev wildcard cert, signed by the Lets Encrypt Free, public internet Certificate Authority)
4. `--namespace=bigbang --create-namespace`
Means it'll install the bigbang helm chart in the bigbang namespace and create the namespace if it doesn't exist.

## Step 11: Edit your Laptop's HostFile to access the web pages hosted on the BigBang Cluster

> Remember to un-edit your Hosts file when your finished tinkering

```shell
# [ubuntu@Ubuntu_VM:~]
k get vs -A
kubectl get virtualservices --all-namespaces
# NAMESPACE    NAME                                      GATEWAYS                HOSTS                          AGE
# monitoring   monitoring-monitoring-kube-alertmanager   ["istio-system/main"]   ["alertmanager.bigbang.dev"]   8d
# monitoring   monitoring-monitoring-kube-grafana        ["istio-system/main"]   ["grafana.bigbang.dev"]        8d
# monitoring   monitoring-monitoring-kube-prometheus     ["istio-system/main"]   ["prometheus.bigbang.dev"]     8d
# argocd       argocd-argocd-server                      ["istio-system/main"]   ["argocd.bigbang.dev"]         8d
# kiali        kiali                                     ["istio-system/main"]   ["kiali.bigbang.dev"]          8d
# jaeger       jaeger                                    ["istio-system/main"]   ["tracing.bigbang.dev"]        8d
```

### Linux/Mac Users

```shell
# [admin@Laptop:~]
sudo vi /etc/hosts
```

### Windows Users

1. Right click Notepad -> Run as Administrator
2. Open C:\Windows\System32\drivers\etc\hosts
3. Add the following entries to the Hosts file, where x.x.x.x = k3d virtual machine's IP.

  > Hint: find and replace is your friend)

```plaintext
x.x.x.x  alertmanager.bigbang.dev
x.x.x.x  grafana.bigbang.dev
x.x.x.x  prometheus.bigbang.dev
x.x.x.x  argocd.bigbang.dev
x.x.x.x  kiali.bigbang.dev
x.x.x.x  tracing.bigbang.dev
```

## Step 12: Visit a webpage

In a browser, visit one of the sites listed using the `k get vs -A` command

## Step 13: Play

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
--values $HOME/bigbang/chart/ingress-certs.yaml \
--values $HOME/ib_creds.yaml \
--values $HOME/demo_values.yaml \
--values $HOME/tinkering.yaml \
--namespace=bigbang --create-namespace

# NOTE: There may be a ~1 minute delay for the change to apply

k get vs -A
# Now ArgoCD shows up
```
