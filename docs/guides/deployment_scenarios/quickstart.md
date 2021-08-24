# Big Bang Quick Start


## Overview
This quick start guide explains in beginner friendly level of detail how to complete the following tasks in under a hour:
1. Turn a VM into a k3d single node Kubernets Cluster.
2. Deploy Big Bang on the Cluster using a Demo/local development friendly workflow.    
> (Note: This guide mainly focuses on the scenario of deploying Big Bang to a remote VM with enough resources to run Big Bang. If your workstation has enough resources, or you're willing to disable packages to lower the resource requirements, then local development is possible. This quickstart guide is valid for both remote and localhost deployment scenarios)
3. Customize the Demo Deployment of Big Bang.


## Important Background Contextual Information:
**BLUF: This quickstart guide optimizes the speed at which a demoable tinkerable deployment can be achieved by minimizing prerequisite dependencies and substituting them with quickly implementable alternatives. Refer to the [Customer Template Repo](https://repo1.dso.mil/platform-one/big-bang/customers/template) for guidance on production deployments.**
* OS Prerequisite: Any Linux distro that supports docker should work.
* OS Preconfiguration: This quickstart includes easy copy pasteable commands to quickly satisfy this prerequisite.
* Kubernetes Cluster Prerequisite: is implemented using k3d (k3s in docker)
* Default Storage Class Prerequisite: k3d ships with a local volume storage class.
* Support for automated provisioning of Kubernetes Service of type LB Prerequisite: is implemented by taking advantage of k3d's ability to easily map port 443 of the VM to port 443 of a Docker-ized LB that forwards traffic to a single Istio Ingress Gateway.     
Important limitations of this quickstart guide's implementation of k3d to be aware of:    
  * Multiple Ingress Gateways aren't supported by this implementation as they would each require their own LB, and this trick of using the host's port 443 only works for automated provisioning of a single service of type LB that leverages port 443.
  * Multiple Ingress Gateways makes a demoable/tinkerable KeyCloak and locally hosted SSO deployment much easier.
  * Multiple Ingress Gateways can be demoed on k3d if configuration tweaks are made, MetalLB is used, and you're developing using a local Linux Desktop. (network connectivity limitations of the implementation would only allow a the web browser on the k3d host server to see the webpages.)
  * If you want to easily demo and tinker with Multiple Ingress Gateways and Keycloak, MetalLB + k3s (or another non dockerized Kubernetes Distro) would be a happy path to look into. (It'd be highly recommended that you have solid Kubernetes chops and are able to successfully implement this quickstart, before investigating an advanced use case, but if you figure it out a PR for a Multi Ingress Gateway and Keycloak quickstart would be welcome, and if that's something you'd like to see prioritized make an issue ticket.)
* Access to Container Images Prerequsite is satisfied by using personal image pull credentials and internet connectivity to <registry1.dso.mil>
* Customer Controlled Private Git Repo Prerequisite isn't required due to substituting declarative git ops installation of the Big Bang Helm chart with an imperative helm cli based installation.
* Encrypting Secrets as code Prerequsite is substituted with clear text secrets on your local machine.
* Installing and Configuring Flux Prerequisite: Not using GitOps for the quickstart eliminates the need to configure flux, and installation is covered within this guide.
* HTTPS Certificate and hostname configuration Prerequisites: Are satisfied by leveraging default hostname values and the demo HTTPS wildcard certificate that's uploaded to the Big Bang repo, which is valid for *.bigbang.dev, *.admin.bigbang.dev, and a few others. The demo HTTPS wildcard certificate is signed by the Lets Encrypt Free, a Certificate Authority trusted on the public internet, so demo sites like grafana.bigbang.dev will show a trusted HTTPS certificate.
* DNS Prerequisite: is substituted by making use of your Laptop's hostfile.


## Step 1. Provision a Virtual Machine

The following requirements are recommended for Demo Purposes:

* 1 Virtual Machine with 32GB RAM, 8-Core CPU (This will become a single node cluster) (Note 64GB RAM / 16 CPU core is recommended for those who want to do lots of customizing.)
* Ubuntu Server 20.04 LTS (Ubuntu comes up slightly faster than CentOS, although both work fine)
* Network connectivity to said Virtual Machine (provisioning with a public IP and a security group locked down to your IP should work. Otherwise a Bare Metal server or even a vagrant box Virtual Machine configured for remote ssh works fine.)


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
-----------------------------------------------------------------------
(Split this in it's own section per feedback about supporting local dev, read through to see if anything would need tweaked like if local dev logout and back in on the ssh k3d part)


3. Install Docker and add $USER to docker group

    ```shell
    [ubuntu@Ubuntu_VM:~]
    curl -fsSL https://get.docker.com | bash && sudo usermod --append --groups docker $USER
    ```

4. Logout and login to allow the "usermod add $USER to docker group" change to take effect

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

10. Install Kustomize 

    ```bash
    curl -s "https://raw.githubusercontent.com/kubernetes-sigs/kustomize/master/hack/install_kustomize.sh" | bash 
    chmod +x kustomize 
    sudo mv kustomize /usr/bin/kustomize 
    ```

11. Verify Kustomize installation

    ```bash
    kustomize version
    # {Version:kustomize/v4.2.0 GitCommit:d53a2ad45d04b0264bcee9e19879437d851cb778 BuildDate:2021-06-30T22:49:26Z GoOs:linux GoArch:amd64}
    ```


10. Install helm

    ```bash
    [ubuntu@Ubuntu_VM:~]
    curl https://raw.githubusercontent.com/helm/helm/master/scripts/get-helm-3 | bash
    ```

11. Verify helm installation

    ```shell
    [ubuntu@Ubuntu_VM:~]
    helm version
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

## Step 4. Spin up a k3d Cluster
You'll be copy pasting some commands to spin up a k3d cluster.

The following notes explain some of the commands flags:
1. `SERVER_IP="10.10.16.11" #(Change this value)`    
`--k3s-server-arg "--tls-san=$SERVER_IP"`
If (k3d is running on your beefy localhost)

If you plan to run 100% of kubectl and helm commands from the k3d server then this flag isn't needed and using an incorrect value like 10.10.16.11 (or removing the flag entirely) won't hurt. 

This flag is not needed if you plan to run 100% of your commands

# ^-- If you're on the same network as the server hosting k3d 
# then you can use the private IP, otherwise use the public IP.


2. `--volume /etc/machine-id:/etc/machine-id` is needed by fluentbit log shipper
3. --volume ${IMAGE_CACHE}:/var/lib/rancher/k3s/agent/containerd/io.containerd.content.v1.content

The image cache makes it so that if you run 
k3d cluster delete k3s-default
And then rerun the above command to reset your cluster for a from scratch deployment.
Then the 2nd time you deploy the images will already be cached locally / won't be repulled from IronBank, so iterative redeployments from scratch will occur faster. 

1. `--servers 1 --agents 3` flags are not used, because the image cacheing works more reliably on a 1 node dockerized cluster, vs a 4 node dockerized cluster.

4. 
If you don't specify this flag then only the server hosting k3d will be able to kubectl to the cluster. 


scp k3d:~/.kube/config ~/.kube/config
vi ~/.kube/config #(replace 0.0.0.0 with the value of SERVER_IP)
(now kubectl from laptop is an option)




```bash
SERVER_IP="10.10.16.11" #(Change this value)

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

## Step 5. 



```bash
set +o history  #turn off bash history
export REGISTRY1_USERNAME=REPLACE_ME
export REGISTRY1_PASSWORD=REPLACE_ME
docker login registry1.dso.mil -u $REGISTRY1_USERNAME -p $REGISTRY1_PASSWORD
set -o history  #turn on bash history
```


### Clone vervion 1.14.0 of BB UHC
cd ~
git clone https://repo1.dso.mil/platform-one/big-bang/bigbang.
cd ~/bigbang
git checkout tags/1.14.0 #Checkout version 1.14.0 of Big Bang



### Install Flux
cd ~/bigbang
$HOME/bigbang/scripts/install_flux.sh -u $REGISTRY1_USERNAME -p $REGISTRY1_PASSWORD


### Create values yaml files


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


helm upgrade --install bigbang $HOME/bigbang/chart \
--values $HOME/ib_creds.yaml \
--values $HOME/bigbang/chart/ingress-certs.yaml \
--values $HOME/bigbang/tests/ci/keycloak-certs/keycloak-passthrough-values.yaml \
--values $HOME/demo_values.yaml \
--namespace=bigbang --create-namespace

# ^-- run throug the above command explaining it to new users and explain ingress-certs.yaml = the dev demo cert deployed from the helm values file.


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
