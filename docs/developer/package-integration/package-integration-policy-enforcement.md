# Big Bang Package: Policy Enforcement

Big Bang has several policies for Kubernetes resources to ensure best practices and security.  For example, images must be pulled from Iron Bank, or containers must be run as non-root.  These policies are currently enforced by [OPA Gatekeeper](https://repo1.dso.mil/platform-one/big-bang/apps/core/policy), which gets deployed as the first package in Big Bang.

When integrating your package, you must adhere to the policies that are enforced or your resources will be denied by the Kubernetes admission controller.  The following is how to identify and fix policy violations.

## Prerequisites

- a K8s cluster with Big Bang installed.
- cluster admin access to the cluster with [kubectl](https://kubernetes.io/docs/tasks/tools/).
- [jq](https://stedolan.github.io/jq/) to help filter the results.

## Integration

#### 1. Deploying a Policy Enforcement Tool (OPA Gatekeeper) 

The policy enforcement tool is deployed as the first package in the default Big Bang configuration. This is so that the enforcement tool can effectively protect the cluster from the start. Your package will be deployed on top of the Big Bang enforcement tool. The policy enforcment tool will control your pacakge's access to the cluster.

#### 2. Identifying Violations Found on Your Application

In the following section, you will be shown how to identify violations found in your package. The app [PodInfo](https://repo1.dso.mil/platform-one/big-bang/apps/sandbox/podinfo) will be used for all of the examples. Gatekeeper has three enforcement actions `deny`, `dryrun`, and `warn`. Only `deny` will prohibit access to the cluster, but the `warn` and `dryrun` constraints should be fixed as well as they are generally best practice.




#### 3. Fixing Policy Violations
#### 3. Exemptions to Policy Exceptions


## Validation
