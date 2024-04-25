# Cluster

## Dev Cluster Setup

1. Configure libvirt and qemu
   1. [Configure qemu permissions](https://bbs.archlinux.org/viewtopic.php?pid=2028719#p2028719)

## Bootstrap the cluster

1. Fill in steps

### To Do Items

1. Setup k3d registry node to serve as cluster registry
2. Embed script to create podman secrets required for server nodes to run
3. Test on a [libvirt vm](https://docs.fedoraproject.org/en-US/fedora-coreos/provisioning-libvirt/)
   1. After successful cluster testing, configure a separate butane config holding the bare metal server's [disk configuration](https://docs.fedoraproject.org/en-US/fedora-coreos/storage/)
   2. Create a dev and prod butane files, including the storage config in the production file
   3. Disable
      1. [Automatic updates](https://docs.fedoraproject.org/en-US/fedora-coreos/auto-updates/), the server can't be rebooting whenever
      2. [Node counting](https://docs.fedoraproject.org/en-US/fedora-coreos/counting/)
   4. [Create Users and Groups](https://docs.fedoraproject.org/en-US/fedora-coreos/authentication/) for applications pods
   5. Setup make target to start a temporary [PXE http server](https://docs.fedoraproject.org/en-US/fedora-coreos/remote-ign/) running in podman

1. References
   1. [Getting Started with Fedora CoreOS](https://docs.fedoraproject.org/en-US/fedora-coreos/getting-started/)
   2. [Butane Config v1.5](https://coreos.github.io/butane/config-fcos-v1_5/)