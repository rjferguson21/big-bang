## Kubernetes Storage Options


## Feature Matrix

| Product | BB Compatible  | FOSS | In Ironbank | Airgap Compatible | Cloud Agnostic | RWX Support | 
| --------- | --------- | --------- | --------- | --------- | --------- | --------- |    
Amazon EBS CSI    | **X** |  N/A  |  | AWS Dependent | No | Native |
Azure Disk CSI    |       |  N/A  |  | Azure Dependent | No | Native |
Longhorn v1.1.0   | **X** | **X** |  | Yes - [Docs](https://longhorn.io/docs/1.1.0/advanced-resources/deploy/airgap/) | Yes, uses host storage | Native
OpenEBS (jiva)    | **X** | **X** |  | Manual Work Required | Yes, uses host storage | **Alpha version [Docs](https://docs.openebs.io/docs/next/rwm.html)
Rook-Ceph         | **X** | **X** |  | Manual Work Required | Yes, uses host storage | Native
Portworx          | **X** |       |  | [Docs](https://docs.portworx.com/portworx-install-with-kubernetes/operate-and-maintain-on-kubernetes/pxcentral-onprem/install/px-central/) | Yes, uses host storage | Native

## Benchmark Results

Benchmarks were tested on AWS with RKE2 and GP2 ebs volumes using using FIO, see [example](./benchmark.yaml)

Azure was tested using ?

| Product | Random Read/Write IOPS | Average Latency (usec) Read/Write | Sequential Read/Write | Mixed Random Read/Write IOPS |
| --------- | --------- | --------- | --------- | --------- |
Amazon EBS CSI  | 2997/2996. BW: 128MiB/s / 128MiB/s | 1331.61 | 129MiB/s / 131MiB/s | 7203/2390
Azure Disk CSI  |  |  |  | 
Longhorn v1.1.0 | 6155/1551 BW: 230MiB/s / 96.3MiB/s | 1042.53 | 319MiB/s / 130MiB/s | 3804/1267
OpenEBS (jiva) | 2183/770. BW: 76.8MiB/s / 45.8MiB/s | 2059.55 | 132MiB/s / 98.2MiB/s | 1590/533
Rook-Ceph | 10.7k/3205. BW: 503MiB/s / 148MiB/s | 548.36/s | 496MiB/s / 154MiB/s | 6664/2228
Portworx   |  |  |  | 



## Amazon EBS CSI

[Website/Docs]()

### REQUIREMENTS

### Notes


## Longhorn

[Website/Docs]()

### REQUIREMENTS

### Notes

## OpenEBS

[Website/Docs]()

### REQUIREMENTS

### Notes

## Rook-Ceph

[Website/Docs]()

### REQUIREMENTS

### Notes

## Portworx

[Website/Docs]()

### REQUIREMENTS

### Notes
