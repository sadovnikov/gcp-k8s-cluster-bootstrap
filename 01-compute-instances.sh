
gcloud compute networks create ${CLUSTER_NAME} --subnet-mode custom
gcloud compute networks subnets create kubernetes --network ${CLUSTER_NAME} --range 10.240.0.0/24

gcloud compute firewall-rules create ${CLUSTER_NAME}-allow-internal \
  --allow tcp,udp,icmp \
  --network ${CLUSTER_NAME} \
  --source-ranges 10.240.0.0/24,10.200.0.0/16

gcloud compute firewall-rules create ${CLUSTER_NAME}-allow-external \
  --allow tcp:22,tcp:6443,icmp \
  --network ${CLUSTER_NAME} \
  --source-ranges 0.0.0.0/0

gcloud compute addresses create ${CLUSTER_NAME} --region $(gcloud config get-value compute/region)
# https://www.googleapis.com/compute/v1/projects/cluster-bootstrap-385111/regions/europe-west3/addresses/k8s-bootstra

gcloud compute addresses list --filter="name=('${CLUSTER_NAME}')"
# 34.89.137.32

# creating controllers
for i in 0 1 2; do
  gcloud compute instances create controller-${i} \
    --async \
    --boot-disk-size 200GB \
    --can-ip-forward \
    --image-family ubuntu-2004-lts \
    --image-project ubuntu-os-cloud \
    --machine-type e2-standard-2 \
    --private-network-ip 10.240.0.1${i} \
    --scopes compute-rw,storage-ro,service-management,service-control,logging-write,monitoring \
    --subnet kubernetes \
    --tags ${CLUSTER_NAME},controller
done

# creating workers
for i in 0 1 2; do
  gcloud compute instances create worker-${i} \
    --async \
    --boot-disk-size 200GB \
    --can-ip-forward \
    --image-family ubuntu-2004-lts \
    --image-project ubuntu-os-cloud \
    --machine-type e2-standard-2 \
    --metadata pod-cidr=10.200.${i}.0/24 \
    --private-network-ip 10.240.0.2${i} \
    --scopes compute-rw,storage-ro,service-management,service-control,logging-write,monitoring \
    --subnet kubernetes \
    --tags ${CLUSTER_NAME},worker
done

# validation
gcloud compute instances list --filter="tags.items=${CLUSTER_NAME}"