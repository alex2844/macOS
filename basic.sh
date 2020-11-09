#!/usr/bin/env bash

ARGS=$@;
BIOS=$(dirname $0)/bios;
OSK='ourhardworkbythesewordsguardedpleasedontsteal(c)AppleComputerInc';

[ -z "$DISPLAY" ] || [ "$HEADLESS" = "1" ] || [ "$HEADLESS" = "true" ] && {
	ARGS="${ARGS} -display none -vnc :1 -k en-us";
} || {
	ARGS="${ARGS} -device ich9-intel-hda -device hda-output";
}
[ -z "$RAM" ] && {
	RAM=$(awk '/MemFree/ { printf "%d", $2/1024 }' /proc/meminfo)
	[[ "$RAM" -lt '2048' ]] && {
		RAM=$(awk '/MemAvailable/ { printf "%d", $2/1024-1024 }' /proc/meminfo)
		[[ "$RAM" -lt '128' ]] && {
			RAM='128';
		}
	}
}
[ -z "$CPUS" ] && {
	CPUS=$(nproc);
}

#[ -z "$SYSTEM_DISK" ] && {
#	read -e -p "path of SYSTEM_DISK: " -i 'SystemDisk.qcow2' SYSTEM_DISK;
#}

if [[ ! -z `type -p apt` ]]; then
	if [[ -z `type -p python3` || -z `type -p pip3` || -z `type -p qemu-system-x86_64` ]]; then
		echo 'Install lib';
		sudo apt install python3 python3-pip qemu-system
	fi
fi

#[[ $SYSTEM_DISK =~ 'dev' ]] && {
#	SYSTEM_DISK="${SYSTEM_DISK},format=raw";
#} || [ -r "$SYSTEM_DISK" ] || {
#	[[ `df -m ./ | sed '1d' | awk '{print $4}'` -lt '65000' ]] && {
#		echo 'Error: not enough memory';
#		exit 1;
#	} || {
#		qemu-img create -f qcow2 SystemDisk.qcow2 64G
#	}
#}
[ ! -r "BaseSystem.img" ] && {
	bash jumpstart.sh;
}

ARGS=(
	-enable-kvm
	-m $RAM
	-smp $CPUS
	-machine q35,accel=kvm
	-cpu Penryn,vendor=GenuineIntel,kvm=on,+sse3,+sse4.2,+aes,+xsave,+avx,+xsaveopt,+xsavec,+xgetbv1,+avx2,+bmi2,+smep,+bmi1,+fma,+movbe,+invtsc
	-device isa-applesmc,osk="$OSK"
	-smbios type=2
	-drive if=pflash,format=raw,readonly,file="$BIOS/OVMF_CODE.fd"
	-drive if=pflash,format=raw,file="$BIOS/OVMF_VARS-1024x768.fd"
	-vga qxl
	-usb -device usb-kbd -device usb-tablet
	-netdev user,hostfwd=tcp::2222-:22,hostfwd=tcp::5902-:5900,id=net0
	-device e1000-82545em,netdev=net0,id=net0,mac=52:54:00:0e:0d:20
	#-drive id=InstallMedia,format=raw,if=none,file=BaseSystem.img
	#-device ide-hd,bus=sata.3,drive=InstallMedia
	-drive id=esp,file=ESP.qcow2,format=qcow2,media=disk
	-drive id=sda,file=/dev/sda,format=raw,media=disk
	-drive id=sdb,file=/dev/sdb,format=raw,media=disk
	-drive id=sdc,file=/dev/sdc,format=raw,media=disk
	# -drive id=SystemDisk,if=none,file="${SYSTEM_DISK}"
	# -device ide-hd,bus=sata.4,drive=SystemDisk
	-drive file=/mnt/cloud/Soft/Boot/virtio-win-0.1.189.iso,media=cdrom # https://fedorapeople.org/groups/virt/virtio-win/direct-downloads/archive-virtio/virtio-win-0.1.189-1/virtio-win-0.1.189.iso
	$ARGS
)
qemu-system-x86_64 "${ARGS[@]}"
