# Cluster

## How to Deploy a Development Cluster

1. Configure libvirt and qemu
   1. [Configure qemu permissions](https://bbs.archlinux.org/viewtopic.php?pid=2028719#p2028719)
2. 

### To Do Items

1. Setup k3d registry node to serve as cluster registry
1. Set these sysctls
   ```bash
   Sysctl=net/netfilter/nf_conntrack_tcp_timeout_close_wait=3600
   Sysctl=net/netfilter/nf_conntrack_tcp_timeout_established=86400
   Sysctl=net/netfilter/nf_conntrack_max=196608
   ```
1. [CIS Hardening Guide](https://docs.k3s.io/security/hardening-guide)
    * [API Server audit configuration](https://docs.k3s.io/security/hardening-guide?_highlight=seccomp#api-server-audit-configuration)
    * [Configuration for Kubernetes Components](https://docs.k3s.io/security/hardening-guide?_highlight=seccomp#configuration-for-kubernetes-components)

2. References
   1. [Getting Started with Fedora CoreOS](https://docs.fedoraproject.org/en-US/fedora-coreos/getting-started/)
   2. [Butane Config v1.5](https://coreos.github.io/butane/config-fcos-v1_5/)
