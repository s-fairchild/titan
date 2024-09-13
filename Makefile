ONESHELL:
SHELL = /bin/bash

deploy-manifests-prod:
	hack/deploy_manifests.sh deploy/manifests

kube-manifests-gen-dev:
	hack/gen_kube_manifests.sh pkg deploy/manifests dev

kube-manifests-gen-prod:
	hack/gen_kube_manifests.sh pkg deploy/manifests prod

ignition-gen-dev: kube-manifests-gen-dev
	hack/manage_ignition.sh generate dev
	hack/manage_ignition.sh validate dev

ignition-gen-prod: kube-manifests-gen-prod
	hack/manage_ignition.sh generate prod
	hack/manage_ignition.sh validate prod

stream := "stable"
coreos-installer-image := "quay.io/coreos/coreos-installer:release"
download-installer-baremetal-live:
	podman --remote=false run \
			--security-opt label=disable \
			--pull=always \
			--rm \
			-v ./deploy/isos:/data \
			-w /data \
			${coreos-installer-image} \
			download \
				-s ${stream} \
				-p metal \
				-f iso

# TODO get the latest iso file from deploy/isos to use here
installer-create-custom-iso: ignition-gen-prod
	podman --remote=false run \
			--security-opt label=disable \
			--pull=always \
			--rm \
			-v ./deploy:/data \
			-w /data \
			${coreos-installer-image} \
				iso \
				customize \
					--dest-device /dev/disk/by-id/nvme-WD_Blue_SN570_2TB_22423T802136 \
					--dest-ignition ignition/cluster.ign \
					--dest-console ttyS0,115200n8 \
					--dest-console tty0 \
					--network-keyfile config/coreos-files/static-ip.nmconnection \
					-o isos/cluster_custom_installer.iso \
					isos/fedora-coreos-40.20240825.3.0-live.x86_64.iso


images := "$(HOME)/.local/share/libvirt/images"
download-installer-libvirt:
	podman --remote=false run \
			--pull=always \
			--security-opt label=disable \
			--rm \
			-v ${images}:/data \
			-w /data \
			${coreos-installer-image} \
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
# TODO make this configurable to use with production systems
k3s-token-upload:
	hack/upload_k3s_token.sh "rick-dev" \
							 ${ssh_id} \
							 ${vm_ip_address}
