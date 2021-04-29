## Kubernetes Storage Options


## Feature Matrix

| Product | BB Compatible  | FOSS | In Ironbank  | RWX Support | Airgap Compatible | Cloud Agnostic |
| --------- | --------- | --------- | --------- | --------- | --------- | --------- |    
Amazon EBS CSI    | **X** |  N/A  |  | **X** | AWS Dependent | No | 
Azure Disk CSI    |       |  N/A  |  | **X** | Azure Dependent | No | 
Longhorn v1.1.0   | **X** | **X** |  | **X** | Yes - [Docs](https://longhorn.io/docs/1.1.0/advanced-resources/deploy/airgap/) | Yes, uses host storage | 
OpenEBS (jiva)    | **X** | **X** |  | **X** **[Alpha](https://docs.openebs.io/docs/next/rwm.html)** | Manual Work Required | Yes, uses host storage |  
Rook-Ceph         | **X** | **X** |  | **X** | Manual Work Required | Yes, uses host storage | 
Portworx          | **X** |       |  | **X** | [Docs](https://docs.portworx.com/portworx-install-with-kubernetes/operate-and-maintain-on-kubernetes/pxcentral-onprem/install/px-central/) | Yes, uses host storage |

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
Portworx  2.6 | 3016/19.3k. BW: 74.5MiB/s / 85.1MiB/s | 1296.84/517.00 |  113MiB/s / 124MiB/s | 27.9k/9317

Random Read/Write IOPS: 3016/19.3k. BW: 74.5MiB/s / 85.1MiB/s
Average Latency (usec) Read/Write: 1337.31/523.19
Sequential Read/Write: 90.7MiB/s / 124MiB/s
Mixed Random Read/Write IOPS: 33.7k/11.3

## Amazon EBS CSI

[Website/Docs](https://docs.aws.amazon.com/eks/latest/userguide/ebs-csi.html)

### REQUIREMENTS

- Must be using AWS
### Notes

- Super easy use, apply CSI spec and you done!

## Azure Disk CSI

[Website/Docs](https://docs.microsoft.com/en-us/azure/aks/azure-disk-csi)

### REQUIREMENTS

- Must be using Azure
### Notes


## Longhorn

[Website/Docs](https://longhorn.io/)

### REQUIREMENTS

- RWX requires `nfs-common` to be installed on the nodes. [Longhorn RWX Docs](https://longhorn.io/docs/1.1.0/advanced-resources/rwx-workloads/)

### Notes

- 100% Opensource
- Easiest to install
- Documented airgap install process
- GUI provides data and observability; replica status, cluster health status, backup status, and backup initiation/recovery.
## OpenEBS

[Website/Docs](https://openebs.io/)

### REQUIREMENTS

- Blank, un-partitioned attached disk(s)
- RWX is in Alpha and requires work. [OpenEBS RWX Docs [](https://docs.openebs.io/docs/next/rwm.html)

### Notes



## Rook-Ceph

[Website/Docs](https://rook.io/)

### REQUIREMENTS

### Notes

- :+1: 100% Opensource
- :+1: Very Fast

## Portworx

[Website/Docs](https://docs.portworx.com/portworx-install-with-kubernetes/)

### REQUIREMENTS

- Blank, un-partitioned attached disk(s)

### Notes

- Portworx Essentials is free **up to** 5nodes, 5TB Storage, 500 volumes
- Portworx Enterprise and PX-Backup require paid licenses 
- Best Mixed IOPS, average read/write performance
- Install is very picky about the container runtime hostpath
- Tested on Konvoy 1.6.1 due to Portworx issues when using RKE2
