ONESHELL:
SHELL = /bin/bash

kube-manifests-gen:
	hack/gen_kube_manifests.sh pkg deploy/manifests

ignition-gen-dev: kube-manifests-gen
	hack/manage_ignition.sh generate dev
	hack/manage_ignition.sh validate dev

ignition-gen-prod: kube-manifests-gen
	hack/manage_ignition.sh generate prod
	hack/manage_ignition.sh validate prod

stream := "stable"
download-live-installer:
	podman run --security-opt \
		   label=disable \
		   --pull=always \
		   --rm \
		   -v ./deploy/isos:/data \
		   -w /data \
		   quay.io/coreos/coreos-installer:release \
		   		download \
				-s ${stream} \
				-p metal \
				-f iso

# TODO get the latest iso file from deploy/isos to use here
# TODO fix production deployment storage.bu
installer-create-custom-iso: ignition-gen-prod
	podman run --security-opt \
		   label=disable \
		   --pull=always \
		   --rm \
		   -v ./deploy:/data \
		   -w /data \
		   quay.io/coreos/coreos-installer:release \
		   		iso \
				customize \
				    --dest-device /dev/disk/by-id/nvme-WD_Blue_SN570_2TB_22423T802136 \
    				--dest-ignition ignition/cluster.ign \
    				--dest-console ttyS0,115200n8 \
    				--dest-console tty0 \
    				--network-keyfile config/static-ip.nmconnection \
    				-o isos/cluster_custom_installer.iso \
					isos/fedora-coreos-40.20240602.3.0-live.x86_64.iso


images := "$(HOME)/.local/share/libvirt/images"
download-libvirt-installer: $(images)
	podman run \
		   --pull=always \
		   --rm \
		   -v ${images}:/data \
		   -w /data \
		   quay.io/coreos/coreos-installer:release \
		   		download \
				-s ${stream} \
				-p qemu \
				-f qcow2.xz \
				--decompress

vm-dev-create: ignition-gen-dev
	hack/manage_dev_vm.sh create

vm-dev-delete:
	hack/manage_dev_vm.sh delete

vm_ip_address := "192.168.122.2"
ssh_id := ~/.ssh/id_ed25519
k3s-token-upload:
	hack/upload_k3s_token.sh "rick-dev" \
							 ${ssh_id} \
							 ${vm_ip_address}
