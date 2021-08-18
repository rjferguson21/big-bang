# Big Bang KeyCloak SSO Quick Start

## Overview

This assumes you have ran quickstart.md and have a k3d cluster, with BB deployed, and are able to ingress to sites hosted on the cluster. 

This covers Input config values and imperative config needed to enable keycloak in the same cluster.



## Additional Imperative Config Steps
1. update coredns
2. KeyCloak GUI stuff. 

-----------------------------------

## Quickly Install Additional Software

### Install kustomize
curl -s "https://raw.githubusercontent.com/kubernetes-sigs/kustomize/master/hack/install_kustomize.sh" | bash 
chmod +x kustomize 
sudo mv kustomize /usr/bin/kustomize 

-----------------------------------

ssh k3d




IMAGE_CACHE=${HOME}/.bigbang-container-image-cache
SERVER_IP="10.10.16.11" #(public and private both work)
cd ~
mkdir -p ${IMAGE_CACHE}

k3d cluster create \
    --volume /etc/machine-id:/etc/machine-id \
    --volume ${IMAGE_CACHE}:/var/lib/rancher/k3s/agent/containerd/io.containerd.content.v1.content \
    --k3s-server-arg "--disable=traefik" \
    --k3s-server-arg "--tls-san=$SERVER_IP" \
    --port 80:80@loadbalancer \
    --port 443:443@loadbalancer \
    --api-port 6443


# k3d cluster delete big-bang-quick-start


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


cat << EOF > ~/keycloak_sso_quickstart_helm_values.yaml
addons:
  keycloak:
    enabled: true
    values:
      hostname: bigbang.dev  #keycloak gets appended in front of this value
      replicas: 1
      resources:
        limits: {}
  authservice:
    enabled: true
    values:
      resources:
        limits: {}

istio:
  ingressGateways:
    public-ingressgateway:
      type: "LoadBalancer"
  gateways:
    public:
      ingressGateway: "public-ingressgateway"
      hosts:
      - "*.{{ .Values.hostname }}"
    passthrough:
      ingressGateway: "public-ingressgateway"
      hosts:
      - "keycloak.bigbang.dev"
      tls:
        mode: "PASSTHROUGH"
EOF



helm upgrade --install bigbang $HOME/bigbang/chart \
--values $HOME/ib_creds.yaml \
--values $HOME/bigbang/chart/ingress-certs.yaml \
--values $HOME/bigbang/tests/ci/keycloak-certs/keycloak-passthrough-values.yaml \
--values $HOME/demo_values.yaml \
--values $HOME/keycloak_sso_quickstart_helm_values.yaml \
--namespace=bigbang --create-namespace


o cool I'm kind of able to get to keycloak.bigbang.dev it just says cert date is wrong
so I need to replace this reference with a more up to date reference
--values $HOME/bigbang/tests/ci/keycloak-certs/keycloak-passthrough-values.yaml

idea of how to get a more up to date reference

DEMO_HTTPS_CERT=$(curl -s https://repo1.dso.mil/platform-one/big-bang/bigbang/-/raw/master/chart/ingress-certs.yaml | grep -i "BEGIN CERTIFICATE" -A 100 | grep "END CERTIFICATE" -B 100 | tr -d " ")

DEMO_HTTPS_KEY=$(curl -s https://repo1.dso.mil/platform-one/big-bang/bigbang/-/raw/master/chart/ingress-certs.yaml | grep -i "BEGIN PRIVATE KEY" -A 100 | grep "END PRIVATE KEY" -B 100 | tr -d " ")

echo "$DEMO_HTTPS_CERT"
echo "$DEMO_HTTPS_KEY"



### configured hostfile of laptop and verified grafana.bigbang.dev worked


