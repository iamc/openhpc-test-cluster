#!/bin/bash

NCOMPUTES="$1"
if [ -z "$NCOMPUTES" ] || [ "$NCOMPUTES" -lt 1 ] || [ "$NCOMPUTES" -gt 10 ]; then
    echo "You must request between 1 and 10 compute nodes ($NCOMPUTES requested)."
    exit 1
fi

PXEBOOT_ISO="$2"
if [ ! -f "$PXEBOOT_ISO" ]; then
    echo "You must supply a PXEBOOT ISO that exists."
    exit 1
fi

COMPUTE_DEFS=""
VAGRANT_DEFS=""
for ((i=1;i<=NCOMPUTES;i++)); do
    COMPUTE_DEFS+=`cat <<EOF
c_name[$((i-1))]=c$i
c_ip[$((i-1))]=192.168.7.$((i+2))
c_mac[$((i-1))]=22:1a:2b:00:00:$((i-1))$((i-1))
EOF`
    COMPUTE_DEFS+=$'\n'
    VAGRANT_DEFS+=`cat <<EOF
    config.vm.define "c$i", autostart: false do |c$i|
      c$i.vm.provider "virtualbox" do |vboxc$i|
        vboxc$i.memory = 1024
        vboxc$i.cpus = 2
        # Enable if you need to debug PXE.
        #vboxc$i.gui = 'true'
        vboxc$i.customize [
          'modifyvm', :id,
          '--nic1', 'intnet',
          '--intnet1', 'provisioning',
          '--boot1', 'dvd',
          '--boot2', 'none',
          '--boot3', 'none',
          '--boot4', 'none',
          '--macaddress1', '221a2b0000$((i-1))$((i-1))'
        ]

        vboxc$i.customize [
          "storageattach", :id,
          "--storagectl", "IDE",
          "--port", "0",
          "--device", "0",
          "--type", "dvddrive",
          "--medium", "${PXEBOOT_ISO}"
        ]
      end
      c$i.vm.boot_timeout = 1
    end
EOF`
    VAGRANT_DEFS+=$'\n'
done

cp recipe.sh.tmpl cluster/recipe.sh
cp input.local.tmpl cluster/input.local
sed -i "s/<NCOMPUTES>/$NCOMPUTES/g;" cluster/input.local
sed "s/enable_clustershell:-0/enable_clustershell:-1/" cluster/input.local
echo "$COMPUTE_DEFS" >> cluster/input.local
cp Vagrantfile.header.tmpl cluster/Vagrantfile
echo "$VAGRANT_DEFS" >> cluster/Vagrantfile
cat Vagrantfile.footer.tmpl >> cluster/Vagrantfile
cp slurm.conf cluster/slurm.conf
cp slurmdbd.conf cluster/slurmdbd.conf
cp slurmdbd.sql cluster/slurmdbd.sql
cp slurm-setup.sh cluster/slurm-setup.sh
cp cgroup.conf cluster/cgroup.conf
cp cgroup_allowed_devices_file.conf cluster/cgroup_allowed_devices_file.conf

cp "$PXEBOOT_ISO" "cluster/$PXEBOOT_ISO"
