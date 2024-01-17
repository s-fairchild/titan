# Cluster

## Bootstrap flow New Clusters

### Idea flow 1

  1. Design
     1. podman socket listening on the host system to provision management-cluster
     2. Create k3d management cluster on host with the following manifests
        1. kubevirt
        2. kubekey
     3. All workloads run on the kubevirt provisioned kvm/qemu virtual machines
  2. Install k3d management cluster
  3. Provision kubevirt vm
  4. run `kubekey` against newly provisioned VM
  5. Worker cluster is running in libvirt VM now
  6. Can join/remove other raspberry pi hosts with kubekey

### Idea flow 2

