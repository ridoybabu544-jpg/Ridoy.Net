#!/bin/sh

depmod_bin="/sbin/depmod"

# check env
if [ -z "${ROOTDIR}" ]; then
	echo "ROOTDIR is not set!"
	exit 1
fi

if [ -z "${KERNELRELEASE}" ]; then
	echo "KERNELRELEASE is not set!"
	exit 1
fi

if [ -z "${INSTALL_MOD_PATH}" ]; then
	echo "INSTALL_MOD_PATH is not set!"
	exit 1
fi

if [ ! -x "$depmod_bin" ]; then
	echo "$depmod_bin is not found! Please install package module-init-tools (kmod)"
	exit 1
fi

if [ "$CONFIG_FIRMWARE_INCLUDE_IPSET" = "y" ]; then
	ipset_dir="${ROOTDIR}/user/ipset/ipset-7.24/kernel/net/netfilter"
	# The package builds its own kernel modules; install those exact modules
	# rather than leaving the older in-tree ipset implementation in place.
	for module in "$ipset_dir/xt_set.ko" "$ipset_dir/ipset/ip_set.ko" "$ipset_dir/ipset/ip_set_hash_ip.ko"; do
		if [ ! -s "$module" ]; then
			echo "Required ipset kernel module is missing: $module"
			exit 1
		fi
	done
	mkdir -p "${INSTALL_MOD_PATH}/lib/modules/${KERNELRELEASE}/kernel/net/netfilter/ipset"
	cp -f "$ipset_dir/xt_set.ko" "${INSTALL_MOD_PATH}/lib/modules/${KERNELRELEASE}/kernel/net/netfilter/"
	cp -f "$ipset_dir/ipset/"*.ko "${INSTALL_MOD_PATH}/lib/modules/${KERNELRELEASE}/kernel/net/netfilter/ipset/"
fi

# call depmod
#sudo $depmod_bin -ae -F System.map -b "${INSTALL_MOD_PATH}" -r ${KERNELRELEASE}
${FAKEROOT} $depmod_bin -ae -F System.map -b "${INSTALL_MOD_PATH}" -r ${KERNELRELEASE}

# Keep text modules.dep for the firmware modprobe applet, and verify that
# the portal modules and their dependency metadata were installed.
if [ "$CONFIG_FIRMWARE_INCLUDE_IPSET" = "y" ]; then
	modules_dep="${INSTALL_MOD_PATH}/lib/modules/${KERNELRELEASE}/modules.dep"
	if [ ! -s "$modules_dep" ]; then
		echo "Kernel module dependency file is missing: $modules_dep"
		exit 1
	fi
	for module_path in \
		"kernel/net/netfilter/ipset/ip_set.ko" \
		"kernel/net/netfilter/ipset/ip_set_hash_ip.ko" \
		"kernel/net/netfilter/xt_set.ko"; do
		if ! grep -Fq "$module_path:" "$modules_dep"; then
			echo "Kernel module dependency entry is missing: $module_path"
			exit 1
		fi
	done
fi

# clear unneeded depmod files
rm -f "${INSTALL_MOD_PATH}/lib/modules/${KERNELRELEASE}/modules.alias"
rm -f "${INSTALL_MOD_PATH}/lib/modules/${KERNELRELEASE}/modules.alias.bin"
rm -f "${INSTALL_MOD_PATH}/lib/modules/${KERNELRELEASE}/modules.dep.bin"
rm -f "${INSTALL_MOD_PATH}/lib/modules/${KERNELRELEASE}/modules.devname"
rm -f "${INSTALL_MOD_PATH}/lib/modules/${KERNELRELEASE}/modules.softdep"
rm -f "${INSTALL_MOD_PATH}/lib/modules/${KERNELRELEASE}/modules.symbols"
rm -f "${INSTALL_MOD_PATH}/lib/modules/${KERNELRELEASE}/modules.symbols.bin"
rm -f "${INSTALL_MOD_PATH}/lib/modules/${KERNELRELEASE}/modules.builtin"
rm -f "${INSTALL_MOD_PATH}/lib/modules/${KERNELRELEASE}/modules.builtin.bin"
rm -f "${INSTALL_MOD_PATH}/lib/modules/${KERNELRELEASE}/modules.builtin.alias.bin"
rm -f "${INSTALL_MOD_PATH}/lib/modules/${KERNELRELEASE}/modules.order"
rm -f "${INSTALL_MOD_PATH}/lib/modules/${KERNELRELEASE}/build"
rm -f "${INSTALL_MOD_PATH}/lib/modules/${KERNELRELEASE}/source"

rm -rf "${INSTALL_MOD_PATH}/opt/lib"
if [ -z ${CONFIG_FIRMWARE_INCLUDE_BACKPORTED} ]&&[ -d ${INSTALL_MOD_PATH}/lib/modules/${KERNELRELEASE}/updates ]; then
	mkdir -p "${INSTALL_MOD_PATH}/opt/lib/modules/${KERNELRELEASE}/"
	mv -vf "${INSTALL_MOD_PATH}/lib/modules/${KERNELRELEASE}/updates" -t "${INSTALL_MOD_PATH}/opt/lib/modules/${KERNELRELEASE}"
	ln -st ${INSTALL_MOD_PATH}/lib/modules/${KERNELRELEASE} /opt/lib/modules/${KERNELRELEASE}/updates
fi
