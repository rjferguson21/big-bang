# How to deploy Keycloak for development
This example values override file is provided for development purposes only. Operational deployments use a different configuration including but not limited to:
- a custom realm would not automatically be loaded. 
- needed secrets would be created independently through a GitOps process rather than using the keycolak chart to create secrets
- the certificate would not be inlined in the values.yaml but instead the keycloak-tlscert and keycloak-tlskey secrets are created independently through a GitOps process
- an external database would be used
- master realm would be disabled to prevent admin login

This values override file has only Istio and Keycolak enabled. All other core and addon packages are disabled. If you are deploying this development configuration on a k3d cluster, multiple istio ingress is not supported by default. You must follow the instructions in the [development environment addendum](/docs/developer/development-environment.md#multi-ingress-gateway-support-with-metallb-and-k3d) for how to configure k3d with MetalLB.  

Here are some of the URL paths that are available in Keycloak  
Admin UI. See [default admin credentials](/docs/guides/using_bigbang/default_credentials.md)
https://keycloak.bigbang.dev/auth/admin   
User registration and/or account page  
https://keycloak.bigbang.dev/  

For a keycloak realm config file that already has some sso clients configured, reach out to one of the Keycloak package codeowners. Within the Keycloak admin UI delete the existing custom realm, and then import the new one. If the cert in the example values override file has expired. Get a current *.bigbang.dev cert at [/chart/ingress-certs.yaml](/chart/ingress-certs.yaml) and open a Gitlab issue so we can update the example values override file.