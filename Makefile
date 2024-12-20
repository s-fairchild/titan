ONESHELL:
SHELL = /bin/bash

deploy-manifests-prod:
	hack/deploy_manifests.sh deploy/butane/base/coreos/files/k3s/manifests

# TODO update manifest gen for new overlays layout
kube-manifests-gen-staging:
	hack/gen_kube_manifests.sh pkg deploy/butane/overlays/staging/coreos/files/k3s/manifests dev

ignition_dest := "deploy/.ignition/"
kube-manifests-gen-prod:
	hack/gen_kube_manifests.sh pkg deploy/butane/base/coreos/files/k3s/manifests prod

# TODO make base setup with no kubernetes manifests
ignition-gen-base: kube-manifests-gen-staging
	hack/ignition/gen_ignition.sh deploy/butane/base/main.bu ${ignition_dest}/base_main.ign

ignition-gen-staging: kube-manifests-gen-staging
	hack/ignition/gen_ignition.sh deploy/butane/overlays/staging/main.bu ${ignition_dest}/staging_main.ign

ignition-gen-prod: kube-manifests-gen-prod
	hack/ignition/gen_ignition.sh deploy/butane/overlays/staging/main.bu ${ignition_dest}/prod_main.ign

ignition-serve-http-base: ignition-gen-base
	hack/ignition/deploy/serve_ignition.sh base

# TODO make a build and push target for the custom container image
ignition-serve-http-staging: ignition-gen-staging
	hack/ignition/deploy/serve_ignition.sh staging

ignition-serve-http-prod: ignition-gen-prod
	hack/ignition/deploy/serve_ignition.sh prod

stream := "stable"
coreos-installer-image := "quay.io/coreos/coreos-installer:release"
# TODO add --post-install to setup btrfs subvolumes
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
# TODO remove static-ip.nmconnection file reference
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
					isos/fedora-coreos-41.20241027.3.0-live.x86_64.iso


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
