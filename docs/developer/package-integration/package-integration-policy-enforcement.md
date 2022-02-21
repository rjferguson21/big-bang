# Big Bang Package: Policy Enforcement

Big Bang has several policies for Kubernetes resources to ensure best practices and security.  For example, images must be pulled from Iron Bank, or containers must be run as non-root.  These policies are currently enforced by [OPA Gatekeeper](https://repo1.dso.mil/platform-one/big-bang/apps/core/policy), which gets deployed as the first package in Big Bang.

When integrating your package, you must adhere to the policies that are enforced or your resources will be denied by the Kubernetes admission controller.  The following is how to identify and fix policy violations.

## Prerequisites

- a K8s cluster with Big Bang installed.
- cluster admin access to the cluster with [kubectl](https://kubernetes.io/docs/tasks/tools/).

## Integration

#### 1. Deploying a Policy Enforcement Tool (OPA Gatekeeper) 

The policy enforcement tool is deployed as the first package in the default Big Bang configuration. This is so that the enforcement tool can effectively protect the cluster from the start. Your package will be deployed on top of the Big Bang enforcement tool. The policy enforcment tool will control your pacakge's access to the cluster.

#### 2. Identifying Violations Found on Your Application

In the following section, you will be shown how to identify violations found in your package. The app [PodInfo](https://repo1.dso.mil/platform-one/big-bang/apps/sandbox/podinfo) will be used for all of the examples. Gatekeeper has three enforcement actions `deny`, `dryrun`, and `warn`. Only `deny` will prohibit access to the cluster, but the `warn` and `dryrun` constraints should be fixed as well as they are generally best practice.

In this example we will be attempting to install PodInfo onto our cluster:
```bash
➜ helm install flux-podinfo chart                              
NAME: flux-podinfo
LAST DEPLOYED: Mon Feb 14 11:24:26 2022
NAMESPACE: default
STATUS: deployed
REVISION: 1
NOTES:
1. Get the application URL by running these commands:
  echo "Visit http://127.0.0.1:8080 to use your application"
  kubectl -n default port-forward deploy/flux-podinfo 8080:9898
```
Everything looks good with the deployment, but upon further inspection we can see that our app hasn't deployed properly.
```bash
➜ kubectl get all -n default
NAME                   TYPE        CLUSTER-IP   EXTERNAL-IP   PORT(S)             AGE
service/kubernetes     ClusterIP   10.43.0.1    <none>        443/TCP             52m
service/flux-podinfo   ClusterIP   10.43.39.6   <none>        9898/TCP,9999/TCP   20s

NAME                           READY   UP-TO-DATE   AVAILABLE   AGE
deployment.apps/flux-podinfo   0/1     0            0           19s

NAME                                      DESIRED   CURRENT   READY   AGE
replicaset.apps/flux-podinfo-84d5bccfd6   1         0         0       19s
```

To see why your pods haven't spun up we can check the logs of the Gatekeeper manager pods using the label selector. By default the logs command outputs only 10 lines. To output all of the logs we can add the `--tail` flag and set the value to `-1`.
```bash
kubectl logs -l control-plane=controller-manager -n gatekeeper-system --tail=-1
```
This is going to output a lot of logs to sift through so we can do a simple `grep` command looking for the resource that you deployed, in this case flux-podinfo.

```bash
kubectl logs -l control-plane=controller-manager -n gatekeeper-system --tail=-1 | grep "flux-podinfo"
```
And we'll see one of the log lines will looks something like the following:
```json
{
  "level": "info",
  "ts": 1645018228.7589638,
  "logger": "webhook",
  "msg": "denied admission",
  "process": "admission",
  "event_type": "violation",
  "constraint_name": "no-privileged-containers",
  "constraint_group": "constraints.gatekeeper.sh",
  "constraint_api_version": "v1beta1",
  "constraint_kind": "K8sPSPPrivilegedContainer2",
  "constraint_action": "deny",
  "resource_group": "",
  "resource_api_version": "v1",
  "resource_kind": "Pod",
  "resource_namespace": "default",
  "resource_name": "flux-podinfo-84d5bccfd6-4l6tq",
  "request_username": "system:serviceaccount:kube-system:replicaset-controller"
}
```
We can see the `constraint_action: deny` indidicates that our resource was denied access to the cluster. The `contstraint_name` and `constraint_kind` can provide us a way to get more information as to why our resource was denied. Running the following command will help you do so.

```bash
kubectl get <constraint_kind.constraints.gatekeeper.sh/<constraint_name> -o json | jq '.status.violations | map(select(.namespace==<resource_namespace>))'
```
Replacing the command with our information give us the following:
```bash
kubectl get K8sPSPPrivilegedContainer2.constraints.gatekeeper.sh/no-privileged-containers -o json | jq '.status.violations | map(select(.namespace=="default"))'
```

#### 3. Fixing Policy Violations

Running a container as privileged is something we want to avoid. See [this reference](https://kubesec.io/basics/containers-securitycontext-privileged-true/) for more info.

To fix this issue, navigate to your package's `chart/values.yaml` or `deployment.yaml` and removing `privileged: true` or explicitly setting it to `false`.  

#### 3. Exemptions to Policy Exceptions

If you require an exception to a policy, please reference our [exception doc](https://repo1.dso.mil/platform-one/big-bang/apps/core/policy/-/blob/main/docs/exceptions.md) for more information.


## Validation

After we fixed the violation, we can run `helm upgrade flux-podinfo chart` and check that our pods spin up.

```bash
kubectl get all -n default
```
