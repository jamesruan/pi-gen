#!/bin/bash -e

install -m 755 files/resize2fs_once	"${ROOTFS_DIR}/etc/init.d/"

install -d				"${ROOTFS_DIR}/etc/systemd/system/rc-local.service.d"
install -m 644 files/ttyoutput.conf	"${ROOTFS_DIR}/etc/systemd/system/rc-local.service.d/"

install -m 644 files/50raspi		"${ROOTFS_DIR}/etc/apt/apt.conf.d/"

install -m 644 files/console-setup   	"${ROOTFS_DIR}/etc/default/"

install -m 755 files/rc.local		"${ROOTFS_DIR}/etc/"

install -m 644 files/gogs.service	"${ROOTFS_DIR}/etc/systemd/system/"

mkdir -p "${ROOTFS_DIR}/home/git"
unzip files/gogs_0.11.34.zip -d "${ROOTFS_DIR}/home/git/"

on_chroot << EOF
systemctl disable hwclock.sh
systemctl disable nfs-common
systemctl disable rpcbind
systemctl enable regenerate_ssh_host_keys
systemctl enable gogs
EOF

on_chroot << EOF
pip3 install PyBluez
EOF

on_chroot << EOF
ln -fs /usr/share/zoneinfo/Asia/Shanghai /etc/localtime
dpkg-reconfigure -f noninteractive tzdata
sed -i 's/XKBLAYOUT="gb"/XKBLAYOUT="us"/' /etc/default/keyboard
EOF

on_chroot << EOF
sed -i 's/^#NTP=$/NTP=leither.cn/' /etc/systemd/timesyncd.conf
sed -i 's/^#FallbackNTP.*$/FallbackNTP=ntp1.aliyun.com ntp2.aliyun.com ntp3.aliyun.com ntp4.aliyun.com/' /etc/systemd/timesyncd.conf
EOF

on_chroot << EOF
useradd -m git
chown -R git:git /home/git
EOF

if [ "${USE_QEMU}" = "1" ]; then
	echo "enter QEMU mode"
	install -m 644 files/90-qemu.rules "${ROOTFS_DIR}/etc/udev/rules.d/"
	on_chroot << EOF
systemctl disable resize2fs_once
EOF
	echo "leaving QEMU mode"
else
	on_chroot << EOF
systemctl enable resize2fs_once
EOF
fi

on_chroot << \EOF
for GRP in input spi i2c gpio; do
	groupadd -f -r "$GRP"
done
for GRP in adm dialout cdrom audio users sudo video games plugdev input gpio spi i2c netdev; do
  adduser pi $GRP
done
EOF

on_chroot << EOF
setupcon --force --save-only -v
EOF

on_chroot << EOF
usermod --pass='*' root
EOF

rm -f "${ROOTFS_DIR}/etc/ssh/"ssh_host_*_key*
