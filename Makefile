ONESHELL:
SHELL = /bin/bash

butane_dev_systemd := "deploy/config/systemd.bu"
butane_dev_users := "deploy/config/users.bu"
butane_storage_dev := "deploy/config/storage-dev.bu"
butane_dev_cluster := "deploy/config/dev-cluster.bu"

ignition_dev_systemd := "deploy/ignitions/systemd.ign"
ignition_dev_users := "deploy/ignitions/users.ign"
ignition_storage_dev := "deploy/ignitions/storage-dev.ign"
ignition_dev_cluster := "deploy/ignitions/dev-cluster.ign"
ignition-gen-dev:
	hack/manage_ignition.sh generate dev
	hack/manage_ignition.sh validate dev

ignition-gen-prod:
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

image := "$(images)/fedora-coreos-39.20240407.3.0-qemu.x86_64.qcow2"
vm_name := "rick-dev"
vcpus := "2"
ram_mb := "4096"
disk_gb := "30"
raid_disk_gb := "5"
disk_serial1 := "raid10.1"
disk_serial2 := "raid10.2"
disk_serial3 := "raid10.3"
disk_serial4 := "raid10.4"
disk_serial5 := "raid5.1"
disk_serial6 := "raid5.2"
disk_serial7 := "raid5.3"
disk_serial8 := "backups"
vm-dev-create: ignition-validate
	chcon --verbose \
		  --type \
		  svirt_home_t \
		  ${ignition_dev_cluster}

# TODO get guest vm working with bridge networking as non root user
	# Spice graphics are used to allow mounting of /dev/dri to containers
	virt-install --connect="qemu:///system" \
		--name="${vm_name}" \
		--vcpus="${vcpus}" \
		--memory="${ram_mb}" \
		--os-variant="fedora-coreos-${stream}" \
		--import \
		--graphics=spice \
		--disk="size=${disk_gb},backing_store=${image},serial=coreos-boot-disk,boot.order=1" \
		--disk="size=${raid_disk_gb},format=qcow2,serial=${disk_serial1},boot.order=2" \
		--disk="size=${raid_disk_gb},format=qcow2,serial=${disk_serial2},boot.order=2" \
		--disk="size=${raid_disk_gb},format=qcow2,serial=${disk_serial3},boot.order=2" \
		--disk="size=${raid_disk_gb},format=qcow2,serial=${disk_serial4},boot.order=2" \
		--disk="size=${raid_disk_gb},format=qcow2,serial=${disk_serial5},boot.order=2" \
		--disk="size=${raid_disk_gb},format=qcow2,serial=${disk_serial6},boot.order=2" \
		--disk="size=${raid_disk_gb},format=qcow2,serial=${disk_serial7},boot.order=2" \
		--disk="size=${raid_disk_gb},format=qcow2,serial=${disk_serial8},boot.order=2" \
		--network network=default \
		--noautoconsole \
		--qemu-commandline="-fw_cfg name=opt/com.coreos/config,file=${PWD}/${ignition_dev_cluster}"

vm-dev-delete:
	sudo virsh destroy ${vm_name}
	sudo virsh undefine ${vm_name} --remove-all-storage

vm_ip_address := "192.168.122.2"
ssh_id := ~/.ssh/id_ed25519
k3s-token-upload:
	hack/upload_k3s_token.sh ${vm_name} \
							 ${ssh_id} \
							 ${vm_ip_address}
