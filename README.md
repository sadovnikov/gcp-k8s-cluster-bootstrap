# Bootstrapping K8S Cluster in GCP

## Prerequisites

* Google Cloud SDK. This can be checked with `gcloud version`
* Installed `kubectl`
* Installed Helm 3

## Creating the cluster

### 01. Configure connection with GCP

* Create a new project in GCP. Set its ID in `00-init.sh`, variable `CLOUDSDK_CORE_PROJECT`
* Select the VPC Network name
* Select the compute regions and zone. Correct commands in `00-init.sh`
* execute `. ./00-init.sh`

### 02. Preparing VM Instances

* execute commands from [01-compute-instances.sh](01-compute-instances.sh)
* execute `gcloud compute ssh controller-0` to generate SSH key, which will be place in your Cloud Shell

### 03. Install containerd, kubeadm, kubelet 

SSH to every VM and executed commands from [02-kubeadm-install.sh](02-kubeadm-install.sh). 
This script requires user to confirm the installations.

In all VMs, 
* update `sudo vi /etc/containerd/config.toml` to remove `disabled_plugins` and
* restart containerd by `sudo systemctl restart containerd`

### 04. Creating the cluster

On the controller VM execute the "kubeadm init" command below, where `34.89.137.32` can be retrieved with
`gcloud compute addresses list --filter="name=('${CLUSTER_NAME}')"`

```bash
sudo kubeadm init --pod-network-cidr 192.168.0.0/16 --control-plane-endpoint 34.89.137.32
```

Note the commands to use on other VMs to join the cluster

```
You can now join any number of control-plane nodes by copying certificate authorities
and service account keys on each node and then running the following as root:

kubeadm join 34.89.137.32:6443 --token vvdj3r.9g3f29j7a99crzux \
--discovery-token-ca-cert-hash sha256:33093777ed87c219c5df0345a620ee28043c5739ad8fd2bc5ac4a00e0ea41bae \
--control-plane

Then you can join any number of worker nodes by running the following on each as root:

kubeadm join 34.89.137.32:6443 --token vvdj3r.9g3f29j7a99crzux \
--discovery-token-ca-cert-hash sha256:33093777ed87c219c5df0345a620ee28043c5739ad8fd2bc5ac4a00e0ea41bae
```

Execute the last command on all worker nodes

### 05. Installing CNI based Pod network add-on (Calico)

Execute the commands below on the controller node

```bash
kubectl create -f https://raw.githubusercontent.com/projectcalico/calico/v3.25.1/manifests/tigera-operator.yaml
kubectl create -f https://raw.githubusercontent.com/projectcalico/calico/v3.25.1/manifests/custom-resources.yaml
```

### 06. Check the readiness of the nodes

```bash
kubectl get nodes -o wide
```

## Logging

I attempted to install logging using Helm charts of ElasticSearch, Kibana and LogStash.
It failed because of the necessity to configure ES credentials and certificate.
The prepared [Helm chart](elk) is in this repository.

```
kubectl create namespace elk
helm upgrade elk-stack elk --namespace=elk --install
```

Another attempt was to install [Elastic Cloud on Kubernetes](https://www.elastic.co/guide/en/cloud-on-k8s/current/k8s-deploy-elasticsearch.html),
which got delayed due to necessity to manually create PVs.

## Monitoring

Two local PVs are create manually and bound to the `worker-0` node. 
THIS IS NOT SUITABLE FOR REAL USE.

```bash
sudo mkdir -p /mnt/monitoring-prometheus-server 
sudo chmod 777 /mnt/monitoring-prometheus-server
sudo mkdir -p /mnt/storage-monitoring-alertmanager-0
sudo chmod 777 /mnt/storage-monitoring-alertmanager-0
```

```
kubectl create namespace monitoring
helm upgrade monitoring monitoring --namespace=monitoring --install
```

In order to open Grafana UI:
* run `kubectl -n monitoring port-forward service/monitoring-grafana 3000:80` 
* open http://127.0.0.1:3000/
* login with `admin` / `YBCblHTWaSCZk0SSKKqIRQO87rREUN2dpUIHERyd`
* a dashboard is available at http://127.0.0.1:3000/d/dda42d7e-e412-4073-9152-94d641236529/kubernetes-cluster-monitoring-via-prometheus
