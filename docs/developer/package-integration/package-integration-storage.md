# Big Bang Package: Object Storage

If the package supports object storage (e.g. S3 buckets), it must be integrated with Big Bang's storage configuration.  This document will detail how to do this.

In BigBang MinIO is a consistent, performant and scalable object store for the cloud strategies. Minio is Kubernetes-native by design and is S3 compatible.

## Prerequisites

Addon Minio is enabled at the BigBang level. Alternatively, you have (1) an existing Minio Instance, (2) an AWS S3 AccessKey and SecretKey, or (3) an existing S3 bucket for the deployment.

## Integration

Minio object storage can be integrated in bigbang with entries in the bigbang value.yaml at the package level. 

NOTE: Some packages may have in-built object storage and the implementation may vary.

```yaml
{{- if or .Values.addons.minio.enabled}}
minio:
  enabled: {{ .Values.<chartname>.minio.enabled }}
    disableSSL: false
    endpoint: {{  .Values.<chartname>.minio.endpoint }}
    accessKey: {{   .Values.<chartname>.minio.accessKey }}
    secretKey: {{   .Values.<chartname>.minio.secretKey }}
    bucketName: {{   .Values.<chartname>.minio.bucketName }}
{{ end }}

```

## Validation
