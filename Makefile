ONESHELL:
SHELL = /bin/bash

deploy-manifests-prod:
	hack/deploy_manifests.sh deploy/butane/base/coreos/files/k3s/manifests

kustomize_base_dir := "pkg"
kube-manifests-gen-staging:
	hack/gen_kube_manifests.sh ${kustomize_base_dir} deploy/butane/overlays/staging/coreos/files/k3s/manifests staging

manifests_prod_dir := "deploy/butane/overlays/prod/coreos/usr/local/etc/k3s/server/manifests"
kube-manifests-gen-prod:
	rm -rf ${manifests_prod_dir}/*.yaml
	hack/gen_kube_manifests.sh ${kustomize_base_dir} ${manifests_prod_dir} prod

ignition_dest := "deploy/.ignition"
ignition-gen-base: kube-manifests-gen-staging
	hack/ignition/gen_ignition.sh deploy/butane/base/main.bu ${ignition_dest}/base_main.ign

ignition-gen-staging: kube-manifests-gen-staging
	hack/ignition/gen_ignition.sh deploy/butane/overlays/staging/main.bu ${ignition_dest}/staging_main.ign

ignition-gen-prod: kube-manifests-gen-prod
	hack/ignition/gen_ignition.sh deploy/butane/overlays/prod/main.bu ${ignition_dest}/prod_main.ign

ignition-gen-rpi4:
	hack/ignition/gen_ignition.sh deploy/butane/overlays/rpi4/main.bu ${ignition_dest}/rpi4_main.ign

ignition-gen-rpi02w-0:
	hack/ignition/gen_ignition.sh deploy/butane/overlays/rpi02w.0/main.bu ${ignition_dest}/rpi02w-0_main.ign

ignition-serve-http-base:
	hack/ignition/deploy/serve_ignition.sh base

ignition-serve-http-staging:
	hack/ignition/deploy/serve_ignition.sh staging

ignition-serve-http-prod: ignition-gen-prod
	hack/ignition/deploy/serve_ignition.sh prod

ignition-serve-http-rpi4:
	hack/ignition/deploy/serve_ignition.sh rpi4

ignition-serve-http-rpi02w-0: ignition-gen-rpi02w-0
	hack/ignition/deploy/serve_ignition.sh rpi02w-0

stream := "stable"
coreos-installer-image := "quay.io/coreos/coreos-installer:release"
# TODO add --post-install to setup btrfs subvolumes
installer-download-live-baremetal:
	podman --remote=false run \
			--security-opt label=disable \
			--pull=always \
			--rm \
			-v ./deploy/iso:/data \
			-w /data \
			${coreos-installer-image} \
			download \
				-s ${stream} \
				-p metal \
				-f iso

# TODO get the latest iso file from deploy/isos to use here
unmodified_iso := "fedora-coreos-41.20250315.3.0-live.x86_64.iso"
output_iso := "baremetal_fetch_remote_ignition.iso"
# Example of writing this image to a drive:
# Replace this with the correct drive!
# iso_dest_drive="/dev/sdc"
# sudo dd if=deploy/iso/custom/cluster_custom_installer.iso of="$iso_dest_drive" status=progress && sudo sync
installer-customize-embed-ign:
	podman --remote=false run \
			--security-opt label=disable \
			--pull=always \
			--rm \
			-v ./deploy/iso:/data \
			-v ./hack/coreos-installer:/data/hack \
			-w /data \
			${coreos-installer-image} \
				iso \
				customize \
					--dest-device /dev/disk/by-id/nvme-WD_Blue_SN570_2TB_22423T802136 \
					--dest-ignition config/live.ign \
					--dest-console ttyS0,115200n8 \
					--dest-console tty0 \
					--pre-install hack/post-install.sh \
					-o custom/${output_iso} \
					./${unmodified_iso}

images := "$(HOME)/.local/share/libvirt/images"
installer-download-libvirt:
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

staging_vm_name := "rick-dev"
vm-staging-create: ignition-gen-staging
	chcon -t svirt_home_t ${ignition_dest}/staging_main.ign
	hack/manage_dev_vm.sh create ${staging_vm_name} ${ignition_dest}/staging_main.ign

vm-staging-delete:
	hack/manage_dev_vm.sh delete ${staging_vm_name}

vm_ip_address := "192.168.122.2"
ssh_id := ~/.ssh/id_ed25519
# TODO make this configurable to use with production systems
k3s-token-upload:
	hack/upload_k3s_token.sh "rick-dev" \
							 ${ssh_id} \
							 ${vm_ip_address}
