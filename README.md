# Cluster

## How to Deploy a Development Cluster

1. Configure libvirt and qemu
   1. [Configure qemu permissions](https://bbs.archlinux.org/viewtopic.php?pid=2028719#p2028719)
2. 

### To Do Items

1. Setup k3d registry node to serve as cluster registry
3. Test on a [libvirt vm](https://docs.fedoraproject.org/en-US/fedora-coreos/provisioning-libvirt/)
   4. [Create Users and Groups](https://docs.fedoraproject.org/en-US/fedora-coreos/authentication/) for applications pods
   5. Setup make target to start a temporary [PXE http server](https://docs.fedoraproject.org/en-US/fedora-coreos/remote-ign/) running in podman

1. References
   1. [Getting Started with Fedora CoreOS](https://docs.fedoraproject.org/en-US/fedora-coreos/getting-started/)
   2. [Butane Config v1.5](https://coreos.github.io/butane/config-fcos-v1_5/)