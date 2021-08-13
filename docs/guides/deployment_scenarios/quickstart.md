# Big Bang Quick Start

## Overview

This guide is designed to offer an easy to deploy preview of BigBang, so new users can get to a hands-on state as quickly as possible.
Note: The current implementation of the Quick Start limits the ability to customize the BigBang Deployment. It is doing a GitOps defined deployment from a repository you don't control.

## Step 1. Provision a Virtual Machine

The following requirements are recommended for Demo Purposes:

* 1 Virtual Machine with 64GB RAM, 16-Core CPU (This will become a single node cluster)
* Ubuntu Server 20.04 LTS (Ubuntu comes up slightly faster than RHEL, although both work fine)
* Network connectivity to said Virtual Machine (provisioning with a public IP and a security group locked down to your IP should work. Otherwise a Bare Metal server or even a vagrant box Virtual Machine configured for remote ssh works fine.)
Note: The quick start repositories' `init-k3d.sh` starts up k3d using flags to disable the default ingress controller and map the virtual machine's port 443 to a Docker-ized Load Balancer's port 443, which will eventually map to the istio ingress gateway. That along with some other things (Like leveraging a Lets Encrypt Free HTTPS Wildcard Certificate) are done to lower the prerequisites barrier to make basic demos easier.

## Step 2. SSH into machine and install prerequisite software
* ssh and passwordless sudo should be configured on the remote machine

1. Setup SSH

    ```shell
    # [User@Laptop:~]
    touch ~/.ssh/config
    chmod 600 ~/.ssh/config
    cat ~/.ssh/config
    temp="""##########################
    Host k3d
      Hostname 1.2.3.4  #IP Address of k3d node
      IdentityFile ~/.ssh/bb-onboarding-attendees.ssh.privatekey   #ssh key authorized to access k3d node
      User ubuntu
      StrictHostKeyChecking no   #Useful for vagrant where you'd reuse IP from repeated tear downs
    #########################"""
    echo "$temp" | sudo tee -a ~/.ssh/config  #tee -a, appends to preexisting config file
    ```

2. ssh to instance

    ```shell
    [admin@Laptop:~]
    ssh k3d

    [ubuntu@Ubuntu_VM:~]
    ```

3. Install Docker and add $USER to docker group

    ```shell
    [ubuntu@Ubuntu_VM:~]
    curl -fsSL https://get.docker.com | bash && sudo usermod --append --groups docker $USER
    ```

4. Logout and login so usermod add $USER to docker group change can take effect

    ```bash
    [ubuntu@Ubuntu_VM:~]
    exit

    [admin@Laptop:~]
    ssh k3d
    ```

5. Verify Docker Installation
    ```bash
    [ubuntu@Ubuntu_VM:~]
    docker ps
    # CONTAINER ID   IMAGE                      COMMAND                  CREATED        STATUS        PORTS
    # ^-- represents success
    ```

6. Install k3d
  
    ```bash
    [ubuntu@Ubuntu_VM:~]
    wget -q -P  /tmp https://github.com/rancher/k3d/releases/download/v4.4.7/k3d-linux-amd64
    mv /tmp/k3d-linux-amd64 /tmp/k3d
    sudo chmod +x /tmp/k3d
    sudo mv -v /tmp/k3d /usr/local/bin/
    ```

7. Verify k3d installation

    ```bash
    [ubuntu@Ubuntu_VM:~]
    k3d --version
    # k3d version v4.4.7
    # k3s version v1.21.2-k3s1 (default)
    ```

8. Install Kubectl

    ```bash
    [ubuntu@Ubuntu_VM:~]
    wget -q -P /tmp "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"    
    sudo chmod +x /tmp/kubectl
    sudo mv /tmp/kubectl /usr/local/bin/kubectl
    sudo ln -s /usr/local/bin/kubectl /usr/local/bin/k  #equivalent of alias k=kubectl
    ```

9. Verify kubectl installation

    ```bash
    kubectl version --client
    # Client Version: version.Info{Major:"1", Minor:"22", GitVersion:"v1.22.0", GitCommit:"c2b5237ccd9c0f1d600d3072634ca66cefdf272f", GitTreeState:"clean", BuildDate:"2021-08-04T18:03:20Z", GoVersion:"go1.16.6", Compiler:"gc", Platform:"linux/amd64"}
    ```

10. Install Terraform

    ```bash
    [ubuntu@Ubuntu_VM:~]
    wget https://releases.hashicorp.com/terraform/1.0.4/terraform_1.0.4_linux_amd64.zip
    sudo apt update -y && sudo apt install unzip -y && unzip terraform_1.0.4_linux_amd64.zip && sudo mv terraform /usr/local/bin/ && rm terraform_1.0.4_linux_amd64.zip
    ```

11. Verify terraform installation

    ```shell
    [ubuntu@Ubuntu_VM:~]
    terraform version
    # Terraform v1.0.4
    ```

## Step 3. Configure Host OS prerequisites
* Run Operating System Pre-configuration

    ```shell
    # [ubuntu@k3d:~]
    # ECK implementation of ElasticSearch needs the following or will see OOM errors
    sudo sysctl -w vm.max_map_count=524288

    # SonarQube host OS pre-requisites
    sudo sysctl -w fs.file-max=131072
    ulimit -n 131072 
    ulimit -u 8192 

    echo 'vm.max_map_count=524288' > /etc/sysctl.d/vm-max_map_count.conf   # Needed for ECK to run correctly without OOM errors
    echo 'fs.file-max=131072' > /etc/sysctl.d/fs-file-max.conf   # Needed by Sonarqube
    sysctl --load  #reload updated config
    # Alternative form of above 3 commands:
    # sudo sysctl -w vm.max_map_count=524288
    # sudo sysctl -w fs.file-max=131072

    ulimit -n 131072  # Needed by Sonarqube
    ulimit -u 8192    # Needed by Sonarqube

    # Preload kernel modules required by istio-init, required for selinux enforcing instances using istio-init
    modprobe xt_REDIRECT
    modprobe xt_owner
    modprobe xt_statistic
    # Persist modules after reboots
    printf "xt_REDIRECT\nxt_owner\nxt_statistic\n" | sudo tee -a /etc/modules

    # Kubernetes requires swap disabled
    # Turn off all swap devices and files (won't last reboot)
    sudo swapoff -a 
    # For swap to stay off you can remove any references found via 
    # cat /proc/swaps
    # cat /etc/fstab
    ```

## Step 4. Verify your IronBank Image Pull Credentials work

1. It's best practice to get early left shifted feedback whenever possible (verification commands above)    
   So before adding credentials to a config file and not finding out there's an issue with them    
   until ImagePullBackOff is seen during deployment, we'll do a quick verification of the credentials.

2. Look up your IronBank image pull credentials
    1. In a web browser go to <https://registry1.dso.mil>
    2. Login via OIDC provider
    3. Top right of the page, click your name --> User Profile
    4. Your image pull username is labeled "Username"
    5. Your image pull password is labeled "CLI secret"
       (Note: The image pull credentials are tied to the life cycle of an OIDC token which expires after 3 days, so if 3 days have passed since your last login to IronBank, the credentials will stop working until you re-login to the <https://registry1.dso.mil> GUI)

3. Verify your credentials work

    ```shell
    [ubuntu@k3d:~]
    docker login https://registry1.dso.mil -u YOUR_USERNAME
    # It'll prompt for "Password: " 
    # You won't see feedback for anything you type or paste, paste your password and press enter
    # Login Succeeded
    ```

## Step 5. Clone the Big Bang Quick Start Repo

<https://repo1.dso.mil/platform-one/quick-start/big-bang#big-bang-quick-start>

1. Clone the repo

    ```shell
    # [ubuntu@k3d:~]
    cd ~
    git clone https://repo1.dso.mil/platform-one/quick-start/big-bang.git
    cd ~/big-bang
    ```

2. Create a terraform.tfvars file with your registry1 credentials in your copy of the cloned repo

    ```shell
    # [ubuntu@k3d:~/big-bang]
    vi ~/big-bang/terraform.tfvars
    ```

3. Add the following contents to the newly created file

    ```plaintext
    registry1_username="REPLACE_ME"
    registry1_password="REPLACE_ME"
    ```

## Step 6. Follow the deployment directions on the Big Bang Quick Start Repo

[Link to Big Bang Quick Start Repo](https://repo1.dso.mil/platform-one/quick-start/big-bang#big-bang-quick-start)

## Step 7. Add the LEF HTTPS Demo Certificate

* A Lets Encrypt Free HTTPS Wildcard Certificate, for *.bigbang.dev is included in the repo, we'll apply it from a regularly updated upstream source of truth.

    ```shell
    [ubuntu@k3d:~/big-bang]
    # Download Encrypted HTTPS Wildcard Demo Cert
    curl https://repo1.dso.mil/platform-one/big-bang/bigbang/-/raw/master/hack/secrets/ingress-cert.yaml > ~/ingress-cert.enc.yaml
    
    # Download BigBang's Demo GPG Key Pair to a local file
    curl https://repo1.dso.mil/platform-one/big-bang/bigbang/-/raw/master/hack/bigbang-dev.asc > /tmp/demo-bigbang-gpg-keypair.dev
    
    # Import the Big Bang Demo Key Pair into keychain
    gpg --import /tmp/demo-bigbang-gpg-keypair.dev
    
    # Install sops (Secret Operations CLI tool by Mozilla)
    curl -L https://github.com/mozilla/sops/releases/download/v3.6.1/sops-v3.6.1.linux > sops
    chmod +x sops
    sudo mv sops /usr/bin/sops
    
    # Decrypt and apply to the cluster
    sops --decrypt ~/ingress-cert.enc.yaml | kubectl apply -f - --namespace=istio-system
    ```

## Step 8. Edit your Laptop's HostFile to access the web pages hosted on the BigBang Cluster

```shell
# [ubuntu@k3d:~/big-bang]
# Short version of, kubectl get virtualservices --all-namespaces
$ k get vs -A  

NAMESPACE    NAME                                      GATEWAYS                HOSTS                          AGE
monitoring   monitoring-monitoring-kube-alertmanager   ["istio-system/main"]   ["alertmanager.bigbang.dev"]   8d
monitoring   monitoring-monitoring-kube-grafana        ["istio-system/main"]   ["grafana.bigbang.dev"]        8d
monitoring   monitoring-monitoring-kube-prometheus     ["istio-system/main"]   ["prometheus.bigbang.dev"]     8d
argocd       argocd-argocd-server                      ["istio-system/main"]   ["argocd.bigbang.dev"]         8d
kiali        kiali                                     ["istio-system/main"]   ["kiali.bigbang.dev"]          8d
jaeger       jaeger                                    ["istio-system/main"]   ["tracing.bigbang.dev"]        8d
```

* Linux/Mac Users:

```shell
# [admin@Laptop:~]
sudo vi /etc/hosts
```

* Windows Users:

1. Right click Notepad -> Run as Administrator
1. Open C:\Windows\System32\drivers\etc\hosts

* Add the following entries to the hostfile, where 1.2.3.4 = k3d virtual machine's IP

```plaintext
1.2.3.4  alertmanager.bigbang.dev
1.2.3.4  grafana.bigbang.dev
1.2.3.4  prometheus.bigbang.dev
1.2.3.4  argocd.bigbang.dev
1.2.3.4  kiali.bigbang.dev
1.2.3.4  tracing.bigbang.dev
```

* Remember to un-edit your hostfile when done
