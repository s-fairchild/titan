ONESHELL:
SHELL = /bin/bash

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

kube-manifests-gen:
	hack/gen_kube_manifests.sh pkg deploy/manifests

vm_ip_address := "192.168.122.2"
ssh_id := ~/.ssh/id_ed25519
k3s-token-upload:
	hack/upload_k3s_token.sh "rick-dev" \
							 ${ssh_id} \
							 ${vm_ip_address}
