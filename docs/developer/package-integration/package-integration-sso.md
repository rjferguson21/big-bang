# Big Bang Package: Single Sign On (SSO)

Big Bang has configuration for Single Sign-On (SSO) authentication using an identity provider, like Keycloak.  If the package supports SSO, you will need to integrate Big Bang's configuration with the package.  If the package does not support SSO, an [authentication service](https://repo1.dso.mil/platform-one/big-bang/apps/core/authservice) can be used to intercept traffic and provide SSO.  This document details how to setup your package for either scenario.

## Prerequisites

The development environment can be set up in one of two ways: 
    (1) Two k3d clusters with keycloak in one cluster and Big Bang and all other apps in the second cluster (see [this quick start guide](https://repo1.dso.mil/platform-one/big-bang/bigbang/-/blob/master/docs/guides/deployment_scenarios/sso_quickstart.md) for more information)
    (2) One k3d cluster using metallb to have keycloak, Big Bang, and all other apps in the one cluster (see [this example config](https://repo1.dso.mil/platform-one/big-bang/bigbang/-/blob/master/docs/example_configs/dev-sso-values.yaml) for more information)

## Integration

### SSO Integration
#### SAML Example (Sonarqube)

#### OIDC Example (GitLab)

### AuthService Integration

#### Example (Jaeger)

## Validation
