#!/bin/bash

set -eu

while true; do
    read -e -p "Please enter a Cloud-init image file path: " image_file_path
    if [[ -z "$image_file_path" ]]; then
        printf "\033[31mError\033[m: File path cannot be empty. Please enter again.\n"
    elif [[ ! -e "$image_file_path" ]]; then
        printf "\033[31mError\033[m: File does not exist. Please enter again.\n"
    elif [[ ! "$image_file_path" = /* ]]; then
        image_file_path=$(realpath "$image_file_path")
        break
    else
        break
    fi
done

while true; do
    read -p "Please enter VMID (100~999999999): " vmid
    if [[ $vmid =~ ^[0-9]+$ ]]; then
        if ((vmid >= 100 && vmid <= 999999999)); then
            break
        else
            printf "\033[31mError\033[m: Please enter a vmid within the range of 100 to 999999999.\n"
        fi
    else
        printf "\033[31mError\033[m: vmid must be an integer.\n"
    fi
done

while true; do
    read -p "Please enter volume name (default: local-lvm): " volume
    volume=${volume:-local-lvm}

    # Check if VG exists
    if pvs --noheadings -o vg_name | grep -q -w "$volume"; then
        break
    else
        printf "\033[31mError\033[m: Volume Group '$volume' does not exist. Please enter again."
    fi
done

while true; do
    read -p "Please enter template vm name: " vm_name
    if [ -z "$vm_name" ]; then
        printf "\033[31mError\033[m: template vm name cannot be empty. Please enter a template vm name.\n"
    else
        break
    fi
done


# Check if the file exists
snippet_file_path="/var/lib/vz/snippets/vendor_ntp.yaml"

if [ ! -f "$snippet_file_path" ]; then
    echo "File does not exist: $snippet_file_path"
    
    # Create the file with specified content
    cat << EOF > "$snippet_file_path"
#cloud-config
ntp:
  servers:
    - time.soka.ac.jp
packages:
  - qemu-guest-agent
EOF

    echo "File created: $snippet_file_path"
fi


qm create $vmid --memory 2048 --net0 virtio,bridge=vmbr0 --scsihw virtio-scsi-pci --name $vm_name

qm set $vmid --scsi0 $volume:0,import-from=$image_file_path

qm resize $vmid scsi0 16G

qm set $vmid --ide2 $volume:cloudinit

qm set $vmid --boot order=scsi0

qm set $vmid --serial0 socket --vga serial0

qm set $vmid --agent 1

qm set $vmid --cicustom "vendor=local:snippets/vendor_ntp.yaml"

qm template $vmid
