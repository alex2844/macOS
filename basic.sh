#!/usr/bin/env bash

ARGS=$@;
VMDIR=$PWD;
OVMF=$VMDIR/firmware;
OSK='ourhardworkbythesewordsguardedpleasedontsteal(c)AppleComputerInc';

[ -z "$DISPLAY" ] || [ "$HEADLESS" = "1" ] || [ "$HEADLESS" = "true" ] && {
	echo 'ssh';
	ARGS="${ARGS} -nographic -vnc :1 -k en-us";
} || {
	ARGS="${ARGS} -device ich9-intel-hda -device hda-output";
	[ $DISPLAY == *:0 ] && {
		echo 'no ssh';
	} || {
		echo 'ssh -X';
		[ $(id -u) = 0 ] && {
			sudo xauth add $(xauth list $DISPLAY);
		}
	}
}
[ -z "$RAM" ] && {
	RAM='4G';
}
[ -z "$THREADS" ] && {
	THREADS='4';
}
[ -z "$CORES" ] && {
	CORES='2';
}
[ -z "$SOCKETS" ] && {
	SOCKETS='1';
}
[ -z "$SYSTEM_DISK" ] && {
	read -e -p "path of SYSTEM_DISK: " -i 'SystemDisk.qcow2' SYSTEM_DISK;
}

# sudo apt-get install qemu-system qemu-utils python3 python3-pip  # for Ubuntu, Debian, Mint, and PopOS.
# sudo pacman -S qemu python python-pip python-wheel  # for Arch.
# sudo xbps-install -Su qemu python3 python3-pip   # for Void Linux.
# sudo zypper in qemu-tools qemu-kvm qemu-x86 qemu-audio-pa python3-pip  # for openSUSE Tumbleweed
# sudo dnf install qemu qemu-img python3 python3-pip # for Fedora
# sudo emerge -a qemu python:3.4 pip # for Gentoo
if [[ ! -z `type -p apt` ]]; then
	if [[ -z `type -p python3` || -z `type -p pip3` || -z `type -p qemu-system-x86_64` ]]; then
		echo 'Install lib';
		sudo apt install python3 python3-pip qemu-system
	fi
fi

[[ $SYSTEM_DISK =~ 'dev' ]] && {
	SYSTEM_DISK="${SYSTEM_DISK},format=raw";
} || [ -r "$SYSTEM_DISK" ] || {
	[[ `df -m ./ | sed '1d' | awk '{print $4}'` -lt '65000' ]] && {
		echo 'Error: not enough memory';
		exit 1;
	} || {
		qemu-img create -f qcow2 SystemDisk.qcow2 64G
	}
}
[ ! -r "BaseSystem.img" ] && {
	bash jumpstart.sh;
}

qemu-system-x86_64 \
	-enable-kvm \
	-m $RAM \
	-machine q35,accel=kvm \
	-smp "$THREADS",cores="$CORES",sockets="$SOCKETS" \
	-cpu Penryn,vendor=GenuineIntel,kvm=on,+sse3,+sse4.2,+aes,+xsave,+avx,+xsaveopt,+xsavec,+xgetbv1,+avx2,+bmi2,+smep,+bmi1,+fma,+movbe,+invtsc \
	-device isa-applesmc,osk="$OSK" \
	-smbios type=2 \
	-drive if=pflash,format=raw,readonly,file="$OVMF/OVMF_CODE.fd" \
	-drive if=pflash,format=raw,file="$OVMF/OVMF_VARS-1024x768.fd" \
	-vga qxl \
	-usb -device usb-kbd -device usb-tablet \
	-netdev user,id=net0 \
	-device e1000-82545em,netdev=net0,id=net0,mac=52:54:00:0e:0d:20 \
	-device ich9-ahci,id=sata \
	-drive id=ESP,if=none,format=qcow2,file=ESP.qcow2 \
	-device ide-hd,bus=sata.2,drive=ESP \
	-drive id=InstallMedia,format=raw,if=none,file=BaseSystem.img \
	-device ide-hd,bus=sata.3,drive=InstallMedia \
	-drive id=SystemDisk,if=none,file="${SYSTEM_DISK}" \
	-device ide-hd,bus=sata.4,drive=SystemDisk \
	$ARGS
