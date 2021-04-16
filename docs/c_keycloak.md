# Big Bang Keycloak

Big Bang's integration with Keycloak requires special considerations and configuration compared to other applications.  This document will help you get it setup correctly.

## Keycloak with Other Addons

Due to the sensitivity of Keycloak, Big Bang does not support deploying KeyCloak and any other add-ons.  Keycloak should be deployed with the core Big Bang applications (e.g. Istio, Monitoring, Logging) only.

## Keycloak's Custom Image

The upstream [Keycloak Helm chart](https://repo1.dso.mil/platform-one/big-bang/apps/security-tools/keycloak) is customized for use in Platform One.  It contains the following modifications from a standard Keycloak deployment:

- DoD Certificate Authorities
- Customized Platform One registration
- Customized Platform One realm, with IL2, IL4, and IL5 isolation
- Redirects for specific keycloak endpoints to work with Platform One deployments
- A customized image, based on Iron Bank's Keycloak, that adds a plugin to support the above features

## Keycloak Admin password

To override the default admin credentials in Keycloak, set the following in Big Bang's `values.yaml`:

```yaml
keycloak:
  values:
    secrets:
      credentials:
        stringData:
          adminuser: your_admin_username
          password: your_admin_password
```

## Keycloak TLS

To properly configure Keycloak TLS, you must provide Keycloak a certificate in `keycloak.ingress` that does not overlap with any TLS terminated app certificate.  See [the details](#certificate-overlap-problem) for further information on why this is a problem.

In the Big Bang implementation, all core apps will be deployed to the `admin` subdomain of your domain (set in `hostname`).  This means an endpoint for prometheus, for example, would be at `prometheus.admin.yourdomain`.

You will need two wildcard SAN certificates, one for `*.admin.yourdomain` and one for `*.yourdomain`, when Keycloak is enabled.  The `*.admin.yourdomain` cert goes into `instio.ingress` and the `*.yourdomain` cert goes into `keycloak.ingress`.

In the following configuration for Big Bang, we provide a certificate for `*.admin.bigbang.dev` to TLS terminated apps and a `*.bigbang.dev` certificate to Keycloak.

```yaml
hostname: bigbang.dev
istio:
  ingress:
    key: |-
      <Private Key for *.admin.bigbang.dev>
    cert: |-
      <Certificate for *.admin.bigbang.dev>
addons:
  keycloak:
    enabled: true
    ingress:
      key: |-
        <Private key for *.bigbang.dev>
      cert: |-
        <Certificate for *.bigbang.dev>
```

### Certificate Overlap Problem

Modern browsers will reuse established TLS connections when the destination's IP and port are the same and the current certificate is valid.  See the [HTTP/2 spec]((https://httpwg.org/specs/rfc7540.html#rfc.section.9.1.1) for details.  If our cluster has a single load balancer and listens on port 443 for multiple apps, then the IP address and port for all apps in the cluster will be the same from the browser's point of view.  Normally, this isn't a problem because Big Bang uses TLS termination for all applications.  The encryption occurs between Istio and the browser no matter which hostname you use, so the connection can be reused without problems.

With Keycloak, we need to passthrough TLS rather than terminate it at Istio.  If we have other apps, like Kiali, that are TLS terminated, Istio needs two server entries in its Gateway to passthrough TLS for hosts matching `keycloak.bigbang.dev` and to terminate TLS for other hosts.  If the certificate used for TLS is valid for both Keycloak and other apps (e.g. the cert includes a SAN of `*.bigbang.dev`), then the browser thinks it can reuse connections between the applications (the IP, port, and cert are the same).  If you access a TLS terminated app first (e.g. `kiali.bigbang.dev`), then try to access `keycloak.bigbang.dev`, the browser tries to reuse the connection to the terminated app, resulting in a [data leak](https://cve.mitre.org/cgi-bin/cvename.cgi?name=CVE-2020-11767) to the terminated app and a 404 error in the browser.  Istio is [supposed to handle this](https://github.com/istio/istio/issues/13589) situation, but does not.

To workaround this situation, you have to isolate the applications by IP, port, or certificate so the browser will not reuse the connection between them.  You can use external load balancers or different ingress ports to create unique IPs or ports for the applications.  Or you can create non-overlapping certs for the applications.  This does not prevent you from using wildcard certs, since you could have one cert for `*.bigbang.dev` and another for `*.admin.bigbang.dev` that don't overlap.  Alternatively, you can create one cert for `kiali.bigbang.dev` and other TLS terminated apps and another cert for `keycloak.bigbang.dev`.

> All of the core and addon apps are TLS terminated except Keycloak.