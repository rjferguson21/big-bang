# ImagePullPolicy at Big Bang Level

Big Bang is currently working to standardize the adoption of a global image pull policy so that customers can set a single value and have it passed to all packages. This work is not yet complete, but should allow customers easier control over their global pull policy.

In the meantime we have begun to document the package overrides required in preparation for this change.

# ImagePullPolicy per Package

| Package | Default | Value Override |
|---|---|---|
| Istio Controlplane | None | <pre lang="yaml">istio:<br>  values:<br>    imagePullPolicy: IfNotPresent</pre> |
| Istio Operator | `IfNotPresent` | No override available |
| Jaeger | `Always` | <pre lang="yaml">jaeger:<br>  values:<br>    image:<br>      pullPolicy: IfNotPresent</pre> |
| Kiali | `IfNotPresent` | <pre lang="yaml">kiali:<br>  values:<br>    image:<br>      pullPolicy: IfNotPresent<br>    cr:<br>      spec:<br>        deployment:<br>          image_pull_policy: IfNotPresent</pre> |
| Cluster Auditor | `Always` | <pre lang="yaml">clusterAuditor:<br>  values:<br>    image:<br>      imagePullPolicy: IfNotPresent</pre> |
| OPA Gatekeeper | `IfNotPresent` | <pre lang="yaml">gatekeeper:<br>  values:<br>    postInstall:<br>      labelNamespace:<br>        image:<br>          pullPolicy: IfNotPresent<br>    postUpgrade:<br>      cleanupCRD:<br>        image:<br>          pullPolicy: IfNotPresent<br>    image:<br>      pullPolicy: IfNotPresent</pre> |
| Elasticsearch / Kibana | None | No override available |
| ECK Operator | `IfNotPresent` | <pre lang="yaml">eckoperator:<br>  values:<br>    image:<br>      pullPolicy: IfNotPresent</pre> |
| Fluentbit | `Always` | <pre lang="yaml">fluentbit:<br>  values:<br>    image:<br>      pullPolicy: IfNotPresent</pre> |
| Monitoring | Varies | To be documented |
| Twistlock | None | No override available |
| ArgoCD | Varies | <pre lang="yaml">addons:<br>  argocd:<br>    values:<br>      global:<br>        image:<br>          imagePullPolicy: IfNotPresent<br>      controller:<br>        image:<br>          imagePullPolicy: IfNotPresent<br>      dex:<br>        image:<br>          imagePullPolicy: IfNotPresent<br>      redis-bb:<br>        image:<br>          pullPolicy: IfNotPresent<br>      server:<br>        image:<br>          imagePullPolicy: IfNotPresent<br>      repoServer:<br>        image:<br>          imagePullPolicy: IfNotPresent</pre> |
| Authservice | `IfNotPresent` | <pre lang="yaml">addons:<br>  authservice:<br>    values:<br>      image:<br>        pullPolicy: IfNotPresent</pre> |
| MinIO Operator | `IfNotPresent` | <pre lang="yaml">addons:<br>  minioOperator:<br>    values:<br>      operator:<br>        image:<br>          pullPolicy: IfNotPresent</pre> |
| MinIO | `IfNotPresent` | <pre lang="yaml">addons:<br>  minio:<br>    values:<br>      tenants:<br>        image:<br>          pullPolicy: IfNotPresent</pre> |
| Gitlab | None | <pre lang="yaml">addons:<br>  gitlab:<br>    values:<br>      global:<br>        image:<br>          pullPolicy: IfNotPresent</pre> |
| Gitlab Runners | `IfNotPresent` | <pre lang="yaml">addons:<br>  gitlabRunner:<br>    values:<br>      imagePullPolicy: IfNotPresent</pre> |
| Nexus | To be documented | To be documented |
| Sonarqube | To be documented | To be documented |
| Anchore | To be documented | To be documented |
| Mattermost Operator | To be documented | To be documented |
| Mattermost | To be documented | To be documented |
| Velero | To be documented | To be documented |
| Keycloak | To be documented | To be documented |
