#!/usr/bin/env bash

#
# You may have to set VM_NAME on your own, if you don't use a config.yaml for your Vagrantfile
#
VM_NAME=$(cat config.yaml | grep name | sed 's/^ *name: //g')

# - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

NEW_SIZE_IN_GB=$(($1*1024))
WAS_VMDK=false

# is VBoxManage available?
if type VBoxManage2 &> /dev/null ; then
	echo "VBoxManage (Virtual Box) is required to use this script"
    exit
fi

# is the first parameter set?
if [ -z "$NEW_SIZE_IN_GB" ]; then
	echo "Missing parameter 1: New size in GB."
	echo "Usage example: './resize-vm.sh 15' to resize the virtual machine to 15GB"
	exit
fi

# start
echo "#"
echo "# Resizing the VM '$VM_NAME'"
echo "#"

# is the vm running?
if grep --quiet "${VM_NAME}" <<< $(VBoxManage list runningvms); then
	echo "The VM is running. Please halt it before attempting to resize the machine."
	exit
fi

# cloning process and hdd type check
echo " "
echo "(1) Cloning old hdd to vdi format..."
HDD=$(VBoxManage list hdds | grep "${VM_NAME}" | sed 's/^Location: *//g' | grep -v "Snapshots")
OLD_HDD=$HDD
echo "- ${HDD}"

if grep --quiet ".vdi$" <<< $HDD; then
	echo "- Cloning not necessary. The hdd is already a vdi image"
else
	if grep --quiet ".vmdk$" <<< $HDD ; then
		echo "- Cloning..."
		WAS_VMDK=true
		HDD=$(sed 's/.vmdk$/.vdi/g' <<< $HDD)
		VBoxManage clonemedium disk "${OLD_HDD}" "${HDD}" --format VDI
	else
		echo "- The hdd image is not supported. Only .vdi or .vmdk files are"
		exit;
	fi
fi

# resizing process
echo " "
echo "(2) Resizing to a size of ${NEW_SIZE_IN_GB} MB"
VBoxManage modifymedium disk "${HDD}" --resize $NEW_SIZE_IN_GB

# reinstalling
echo " "
echo "(3) Replacing VM..."
VBoxManage storageattach "${VM_NAME}" --storagectl "SATA Controller" --device 0 --port 0 --type hdd --medium "${HDD}" --hotpluggable on

if [ "$WAS_VMDK" = true ]; then
	VBoxManage closemedium disk "${OLD_HDD}" --delete
fi
