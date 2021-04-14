# Twistlcok 

## Overview

[Twistlock Administration Guide](https://docs.paloaltonetworks.com/prisma/prisma-cloud/20-04/prisma-cloud-compute-edition-admin/welcome/getting_started.html)

## Contents

[Developer Guide](docs/developer-guide.md)

## Big Bang Touchpoints

```mermaid
graph LR
  subgraph "Twistlock"
    twistlockpods("Twistlock Pod(s)")
    twistlockservice{{Twistlock Console}} --> twistlockpods("Twistlockt Pod(s)")
  end      

  subgraph "Ingress"
    ig(Ingress Gateway) --"App Port"--> Twistlock Console
  end

```

### UI

Twistlock Console serves as the user interface within Twistlock. The graphical
user interface (GUI) lets you define policy, configure and control your Twistlock deployment, and view the overall health (from a security perspective) of your container environment


### Storage
```yaml
console:
  persistence:
    size: 100Gi
    accessMode: ReadWriteOnce
```

### Database
N/A

### Istio Configuration

Istio is disabled in the twistlock chart by default and can be enabled by setting the following values in the bigbang chart:

```yaml
hostname: bigbang.dev
istio:
  enabled: true
```

## High Availability
N/A

## Single Sign on (SSO)

Twistlock supports user authentication using SAML.   [Twistlock SAML integration](https://docs.paloaltonetworks.com/prisma/prisma-cloud/19-11/prisma-cloud-compute-edition-admin/access_control/integrate_saml)

## Licensing

[TwistLock  License Documentation](https://docs.paloaltonetworks.com/prisma/prisma-cloud/20-04/prisma-cloud-compute-edition-admin/welcome/licensing.html)

### Health Checks

Twistlock provides API endpoints to monitor the health and availability of deployed components  at `/api/v1/_ping` 
Example command: curl -u admin:Password ‘https:<console-ip>:8083/api/ v1/_ping
