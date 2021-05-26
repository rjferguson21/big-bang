# High Side Environment Deployments: 
When deploying to higher information impact level environments (~IL5, NIPRNet, SIPRNet, JWICS, [CloudOne](https://software.af.mil/team/cloud-one/), AWS C2S, AWS SC2S, Azure Government, Azure Government Secret, Secret Enclaves, TS Enclaves, etc, additional restrictions and security measures tend to be in place. 


## High Side Deployments - Summarized:
* Airgap deployments are the happy path for high side deployments (happy path as in known to work / avoids headaches). The main reason it's a happy path is that you can stand up Kubernetes and BigBang and then deal with the nuances and additional restrictions of the high side environment. 
* An airgap deployment of BigBang involves: 
  * Airgapped container registry
  * Airgapped git repo
  * Airgapped Kubernetes Cluster
  * Airgapped BigBang
* In other words if you're planning to do a high side deployment of Big Bang in the future, it's recommended that you leverage a Kubernetes Distribution and cluster bootstrapping method that is airgap friendly. (kubeadm isn't exactly airgap friendly. Vendor supported Kubernetes Distributions tend to be airgap friendly in terms of documentation, helper scripts, airgap deployment tooling, and having the option of vendor reach back support for airgapped deployments.) 


## High Side Deployments - Additional Information: 
It's common to encounter significant network restrictions like: 
* No internet access (airgap)
* If Internet connectivity does exist it'll likely involve whitelisted endpoints and network ingress/egress going through web proxies. (Web Proxy as in trusted MITM HTTPS traffic inspection proxies, that decrypt, inspect, and reencrypt HTTPS traffic. In order to work they require the OS, and some applications, to be configured to trust additional Certificate Authorities from private PKI. Additionally environment variables like HTTP_PROXY, HTTPS_PROXY, NO_PROXY, may need to be configured in multiple places in order for traffic to flow correctly.) 
* Mirrors of internet resources like RPM/container repos could exist, but leverage HTTPS certs signed by private PKI, which requires private Certificate Authorities to be trusted by the OS and potentially application configuration components. 

# General Recommendation for High Side Deployments of BigBang: 
* Treat high side deployments as if they were [airgapped](airgap) 

(briefly explain that you treat it like an airgap deployment and link to those docs)
The assumption that your kube distro was installed via an airgap install/upgrade methodology, and this is why it's a good idea to pair with vendors.

* Don't make use of HTTP_PROXY, 
* following airgap deployment docs allows you to pretend the web proxy doesn't exist and avoid the headaches of

