#!/bin/bash -x
# make_arm64_rpi_kernel_debs.sh
# Builds arm64 debian packages from the master branch of rpi-firmware repository kernel which is installed by:
# sudo BRANCH=master rpi-update
# This runs on an arm64 host with arm64 compilation tools...
# or with some sort of cross-compilation setup.
# Debs are put in $workdir/build
#
# This will NOT work in Raspbian unless you have an arm64 compilation
# environment setup. Appears to work on
# Raspberry Pi OS (64 bit) beta test version
#
#
#
# Install packages you should probably have if you are needing to install kernel headers.
sudo apt install -f -y build-essential flex gawk bison libssl-dev bc dkms autoconf libtool   || (sudo apt install -f -y || true)
workdir="${HOME}/workdir"
[[ ! -d "$workdir" ]] && ( mkdir -p "$workdir" || exit 1)
[[ ! -d "$workdir"/tmp ]] && ( mkdir -p "$workdir"/tmp || exit 1)
[[ ! -d "$workdir"/build ]] && ( mkdir -p "$workdir"/build || exit 1)
echo "workdir is ${workdir}"

tmpdir=$(mktemp -d deb_XXXX -p "$workdir"/tmp)
echo "tmpdir is ${tmpdir}"
dhpath="$tmpdir/headers"
dipath="$tmpdir/image"
src_temp=$(mktemp -d rpi_src_XXXi -p "$workdir"/tmp)

git_base="https://github.com/raspberrypi/rpi-firmware"
git_branch="master"

FIRMWARE_REV=$(git ls-remote "https://github.com/raspberrypi/rpi-firmware" refs/heads/$git_branch | awk '{print $1}')
cd "$src_temp" && curl -OLf https://github.com/raspberrypi/rpi-firmware/raw/$git_branch/git_hash
KERNEL_REV=$(cat "$src_temp"/git_hash)
SHORT_HASH=$(echo ${KERNEL_REV:0:7})

setup_git_fw() {
if [[ -d "$workdir/rpi-firmware" ]]; then
    (  sudo rm -rf "$workdir"/rpi-firmware.old || true )
    (  sudo mv "$workdir"/rpi-firmware "$workdir"/rpi-firmware.old || true )
    (  sudo rm -rf "$workdir"/rpi-firmware.old || true )
fi
    cd "$workdir" && git clone --depth=1 -b $git_branch $git_base
}

update_git_fw() {
[[ ! -d "$workdir/rpi-firmware" ]] && setup_git_fw

( cd "$workdir"/rpi-firmware && git fetch && git reset --hard origin/$git_branch ) || setup_git_fw
    cd "$workdir"/rpi-firmware && git pull
    #cd "$workdir"/rpi-firmware && git_hash=$(git rev-parse origin/$git_branch)
}

check_zfs() {
        sudo apt install -f -y  autoconf libtool  uuid-dev libudev-dev \
    libssl-dev zlib1g-dev libaio-dev libattr1-dev python3 python3-dev \
    python3-setuptools autoconf automake libtool gawk dkms libblkid-dev \
    uuid-dev libudev-dev libssl-dev libelf-dev python3-cffi libffi-dev || true

cat <<-EOFF | sudo dd status=none of=/etc/dkms/zfs.conf
POST_ADD=../../../../../../usr/local/bin/zfs-gpl.sh
EOFF
cat <<-EOFF | sudo dd status=none of=/usr/local/bin/zfs-gpl.sh
#!/bin/bash
[[ -f /etc/environment ]] &&  . /etc/environment
if ! ls /usr/src | grep -q zfs ; then return 0; fi
if [ -v IGNORECDDL ] ; then
    sed -i 's/CDDL/GPL/g' /usr/src/zfs-*/META
    cd /usr/src/\$(ls /usr/src | grep zfs | tail -n 1) || exit
    ./autogen.sh || true
fi
EOFF
sudo chmod +x /usr/local/bin/zfs-gpl.sh
}

make_headers_deb_files() {
installed_size_headers=$(du -a "$dhpath" | tail -n 1 | awk '{print $1}')
mkdir -p "$dhpath"/DEBIAN
chmod 777 "$dhpath"/DEBIAN
cat <<-EOF | dd status=none of="$dhpath"/DEBIAN/control
Source: linux-$kver
Section: kernel
Priority: optional
Maintainer: root <root@$SHORT_HASH>
Standards-Version: 4.1.3
Homepage: http://www.kernel.org/
Package: linux-headers-$kver
Architecture: arm64
Version: $kver-1
Depends: build-essential, flex, bison, bc
Installed-Size: $installed_size_headers
Description: Linux kernel headers for $kver on arm64
 This package provides kernel header files for $kver on arm64
 built from:
 https://github.com/raspberrypi/linux/tree/$FIRMWARE_REV
 This is useful for people who need to build external modules
EOF
cat <<-EOF | dd status=none of="$dhpath"/DEBIAN/preinst
#!/bin/sh
set -e
version=$kver
if [ "\$1" = abort-upgrade ]; then
    exit 0
fi
if [ "\$1" = install ]; then
    mkdir -p /lib/modules/\$version
    mkdir -p /usr/src/linux-headers-\$version || true
    cd /lib/modules/\$version && ln -snrvf /usr/src/linux-headers-\$version build || true
fi
if [ -d /etc/kernel/header_preinst.d ]; then
    DEB_MAINT_PARAMS="\$*" run-parts --report --exit-on-error --arg=\$version \\
          --arg=\$image_path /etc/kernel/header_preinst.d
fi
exit 0
EOF
chmod +x "$dhpath"/DEBIAN/preinst
cat <<-EOF | dd status=none of="$dhpath"/DEBIAN/postinst
#!/bin/bash
set -e
version=$kver
[[ -f /etc/environment ]] && . /etc/environment
if [ "\$1" != configure ]; then
    exit 0
fi
check_zfs() {
cat <<-EOFF | dd status=none of=/etc/dkms/zfs.conf
POST_ADD=../../../../../../usr/local/bin/zfs-gpl.sh
EOFF
cat <<-EOFF | dd status=none of=/usr/local/bin/zfs-gpl.sh
#!/bin/bash
[[ -f /etc/environment ]] &&  . /etc/environment
if ! ls /usr/src | grep -q zfs ; then return 0; fi
if [ -v IGNORECDDL ] ; then
sed -i 's/CDDL/GPL/g' /usr/src/zfs-*/META
cd /usr/src/\\\$(ls /usr/src | grep zfs | tail -n 1) || exit
./autogen.sh || true
fi
EOFF
chmod +x /usr/local/bin/zfs-gpl.sh
}
if [ -d /etc/kernel/header_postinst.d ]; then
    DEB_MAINT_PARAMS="\$*" run-parts --report --exit-on-error --arg=\$version \\
                /etc/kernel/header_postinst.d
fi
# [[ -v IGNORECDDL ]] && check_zfs
exit 0
EOF
chmod +x "$dhpath"/DEBIAN/postinst
chmod -R 0755 "$dhpath"/DEBIAN
cd "$tmpdir" && sudo dpkg-deb -b headers/
sudo mv "$tmpdir"/headers.deb "$workdir"/build/linux-headers-"${kver}"_arm64.deb
}

make_image_deb_files() {
installed_size_image=$(du -a "$dipath" | tail -n 1 | awk '{print $1}')
mkdir -p "$dipath"/DEBIAN
chmod 777 "$dipath"/DEBIAN
cat <<-EOF | dd status=none of="$dipath"/DEBIAN/control
Package: linux-image-$kver
Source: linux-$kver
Version: $kver-1
Architecture: arm64
Maintainer: root <root@$SHORT_HASH>
Installed-Size: $installed_size_image
Section: kernel
Priority: optional
Homepage: http://www.kernel.org/
Description: Linux kernel, version $kver
 This package contains the Linux kernel, modules and corresponding other
 files, version: $kver.
EOF
cat <<-EOFF | dd status=none of="$dipath"/DEBIAN/postinst
#!/bin/sh
set -e
version=$kver
image_path=/boot/vmlinuz-\$version
# Install kernel (This avoids an issue if /boot is fat32.)
mount -o remount,rw /boot 2>/dev/null || true
cp /usr/share/rpikernelhack/vmlinuz-"$kver" \$image_path || true
# If custom kernel= line is being used don't replace kernel8.img,
# overlays, or dtb files.
if ! vcgencmd get_config str | grep -q kernel ; then
    cp /usr/share/rpikernelhack/vmlinuz-"$kver" /boot/kernel8.img
    cp /usr/lib/linux-image-"$kver"/broadcom/*.dtb /boot/
    cp /usr/lib/linux-image-"$kver"/overlays/* /boot/overlays/
fi
#
# When we install linux-image we have to run kernel postinst.d support to
# generate the initramfs, create links etc.  Should it have an associated
# linux-image-extra package and we install that we also need to run kernel
# postinst.d, to regenerate the initramfs.  If we are installing both at the
# same time, we necessarily trigger kernel postinst.d twice. As this includes
# rebuilding the initramfs and reconfiguring the boot loader this is very time
# consuming.
#
# Similarly for removal when we remove the linux-image-extra package we need to
# run kernel postinst.d handling in order to pare down the initramfs to
# linux-image contents only.  When we remove the linux-image need to remove the
# now redundant initramfs.  If we are removing both at the same time, then
# we will rebuilt the initramfs and then immediatly remove it.
#
# Switches to using a trigger against the linux-image package for all
# postinst.d and postrm.d handling.  On installation postinst.d gets triggered
# twice once by linux-image and once by linux-image-extra.  As triggers are
# non-cumulative we will only run this processing once.  When removing both
# packages we will trigger postinst.d from linux-image-extra and then in
# linux-image postrm.d we effectivly ignore the pending trigger and simply run
# the postrm.d.  This prevents us from rebuilding the initramfs.
#
if [ "\$1" = triggered ]; then
    trigger=/usr/lib/linux/triggers/\$version
    if [ -f "\$trigger" ]; then
    sh "\$trigger"
    rm -f "\$trigger"
    fi
    exit 0
fi
if [ "\$1" != configure ]; then
    exit 0
fi
depmod \$version
if [ -f /lib/modules/\$version/.fresh-install ]; then
    change=install
else
    change=upgrade
fi
# linux-update-symlinks \$change \$version \$image_path
rm -f /lib/modules/\$version/.fresh-install
if [ -d /etc/kernel/postinst.d ]; then
    mkdir -p /usr/lib/linux/triggers
    cat - >/usr/lib/linux/triggers/\$version <<EOF
DEB_MAINT_PARAMS="\$*" run-parts --report --exit-on-error --arg=\$version \\
      --arg=\$image_path /etc/kernel/postinst.d
EOF
    dpkg-trigger --no-await linux-update-\$version
fi
exit 0
EOFF
chmod +x "$dipath"/DEBIAN/postinst

cat <<-EOF | dd status=none of="$dipath"/DEBIAN/triggers
interest linux-update-$kver
EOF

cat <<-EOF | dd status=none of="$dipath"/DEBIAN/postrm
#!/bin/sh
set -e
version=$kver
image_path=/boot/vmlinuz-\$version
rm -f /lib/modules/\$version/.fresh-install
#if [ "\$1" != upgrade ] && command -v linux-update-symlinks >/dev/null; then
#    linux-update-symlinks remove \$version \$image_path
#fi
if [ -d /etc/kernel/postrm.d ]; then
    # We cannot trigger ourselves as at the end of this we will no longer
    # exist and can no longer respond to the trigger.  The trigger would
    # then become lost.  Therefore we clear any pending trigger and apply
    # postrm directly.
    if [ -f /usr/lib/linux/triggers/\$version ]; then
    echo "\$0 ... removing pending trigger"
    rm -f /usr/lib/linux/triggers/\$version
    fi
    DEB_MAINT_PARAMS="\$*" run-parts --report --exit-on-error --arg=\$version \\
          --arg=\$image_path /etc/kernel/postrm.d
fi
if [ "\$1" = purge ]; then
    for extra_file in modules.dep modules.isapnpmap modules.pcimap \\
                      modules.usbmap modules.parportmap \\
                      modules.generic_string modules.ieee1394map \\
                      modules.ieee1394map modules.pnpbiosmap \\
                      modules.alias modules.ccwmap modules.inputmap \\
                      modules.symbols modules.ofmap \\
                      modules.seriomap modules.\\*.bin \\
              modules.softdep modules.devname; do
    eval rm -f /lib/modules/\$version/\$extra_file
    done
    rmdir /lib/modules/\$version || true
fi
exit 0
EOF
chmod +x "$dipath"/DEBIAN/postrm
cat <<-EOF | dd status=none of="$dipath"/DEBIAN/preinst
#!/bin/sh
set -e
version=$kver
image_path=/boot/vmlinuz-\$version
if [ "\$1" = abort-upgrade ]; then
    exit 0
fi
if [ "\$1" = install ]; then
    # Create a flag file for postinst
    mkdir -p /lib/modules/\$version
    touch /lib/modules/\$version/.fresh-install
fi
if [ -d /etc/kernel/preinst.d ]; then
    DEB_MAINT_PARAMS="\$*" run-parts --report --exit-on-error --arg=\$version \\
          --arg=\$image_path /etc/kernel/preinst.d
fi
if [ ! -e /lib/modules/\$version/build ]; then
    mkdir -p /usr/src/linux-headers-\$version || true
    cd /lib/modules/\$version && ln -snrvf /usr/src/linux-headers-\$version build || true
fi
exit 0
EOF
chmod +x "$dipath"/DEBIAN/preinst
cat <<-EOF | dd status=none of="$dipath"/DEBIAN/prerm
#!/bin/sh
set -e
version=$kver
image_path=/boot/vmlinuz-\$version
if [ "\$1" != remove ]; then
    exit 0
fi
linux-check-removal \$version
if [ -d /etc/kernel/prerm.d ]; then
    DEB_MAINT_PARAMS="\$*" run-parts --report --exit-on-error --arg=\$version \\
          --arg=\$image_path /etc/kernel/prerm.d
fi
exit 0
EOF
chmod +x "$dipath"/DEBIAN/prerm
chmod -R 0755 "$dipath"/DEBIAN
cd "$tmpdir" && sudo dpkg-deb -b image/
sudo mv "$tmpdir"/image.deb "$workdir"/build/linux-image-"${kver}"_arm64.deb
}
make_debs() {
    cd "$src_temp" && curl -L https://github.com/raspberrypi/linux/archive/"${KERNEL_REV}".tar.gz >rpi-linux.tar.gz
    cd "$src_temp" && curl -OLf https://github.com/raspberrypi/rpi-firmware/raw/"${FIRMWARE_REV}"/Module8.symvers
    mv $src_temp/Module8.symvers $src_temp/Module.symvers

    kver=$(find "$workdir"/rpi-firmware/modules/ -type d -name '*v8+' -printf "%P\n")
    l=$kver

    # Build kernel header package
    # Adapted from scripts/package/builddeb
    mkdir -p $src_temp/header_tmp/debian
    cd $src_temp/header_tmp && tar --strip-components 1 -xf "${src_temp}"/rpi-linux.tar.gz
    SRCARCH=arm64
    (cd $src_temp/header_tmp; cp $src_temp/header_tmp/arch/arm64/configs/bcm2711_defconfig $src_temp/header_tmp/.config) # copy .config manually to be where it's expected to be
    cd "$src_temp/header_tmp" && (yes "" | make modules_prepare)
    (cd $src_temp/header_tmp; find . -name Makefile\* -o -name Kconfig\* -o -name \*.pl) > "$src_temp/header_tmp/debian/hdrsrcfiles"
    (cd $src_temp/header_tmp; find arch/*/include include scripts -type f -o -type l) >> "$src_temp/header_tmp/debian/hdrsrcfiles"
    (cd $src_temp/header_tmp; find arch/$SRCARCH -name module.lds -o -name Kbuild.platforms -o -name Platform) >> "$src_temp/header_tmp/debian/hdrsrcfiles"
    (cd $src_temp/header_tmp; find $(find arch/$SRCARCH -name include -o -name scripts -type d) -type f) >> "$src_temp/header_tmp/debian/hdrsrcfiles"
    (cd $src_temp/header_tmp; find tools/objtool -type f -executable) >> "$src_temp/header_tmp/debian/hdrobjfiles"

    (cd $src_temp/header_tmp; find arch/$SRCARCH/include Module.symvers include scripts -type f) >> "$src_temp/header_tmp/debian/hdrobjfiles"
    (cd $src_temp/header_tmp; find scripts/gcc-plugins -name \*.so -o -name gcc-common.h) >> "$src_temp/header_tmp/debian/hdrobjfiles"
    destdir="$dhpath"/usr/src/linux-headers-$kver
    mkdir -p "$destdir"
    (cd $src_temp/header_tmp; tar -c -f - -T -) < "$src_temp/header_tmp/debian/hdrsrcfiles" | (cd $destdir; tar -xf -)
    (cd $src_temp/header_tmp; tar -c -f - -T -) < "$src_temp/header_tmp/debian/hdrobjfiles" | (cd $destdir; tar -xf -)
    (cd $src_temp/header_tmp; cp $src_temp/header_tmp/arch/arm64/configs/bcm2711_defconfig $destdir/.config) # copy .config manually to be where it's expected to be
    rm -rf "$src_temp/header_tmp/debian/hdrsrcfiles" "$src_temp/header_tmp/debian/hdrobjfiles"
    cp "$src_temp"/Module.symvers "$destdir"/Module.symvers

    make_headers_deb_files

    mkdir -p "$dipath"/usr/share/rpikernelhack/
    cp "$workdir"/rpi-firmware/kernel8.img "$dipath"/usr/share/rpikernelhack/vmlinuz-"$l"
    mkdir -p "$dipath"/lib/modules/
    cp -r "$workdir"/rpi-firmware/modules/"$l" "$dipath"/lib/modules/
    mkdir -p "$dipath"/usr/lib/linux-image-"$l"/broadcom && mkdir -p "$dipath"/usr/lib/linux-image-"$l"/overlays
    cp -f "$workdir"/rpi-firmware/*.dtb "$dipath"/usr/lib/linux-image-"$l"/broadcom/
    cp -f "$workdir"/rpi-firmware/overlays/* "$dipath"/usr/lib/linux-image-"$l"/overlays/
    [[ ! -e "$dipath/lib/firmware/$l/device-tree" ]] && mkdir -p "$dipath"/lib/firmware/"$l"/device-tree

    make_image_deb_files

    # Clean up.
    cd "$workdir"
    sudo rm -rf "$src_temp"
    sudo rm -rf "$tmpdir"
}

install_headers() {
sudo dpkg -i "$workdir"/build/linux-headers-"${kver}"_arm64.deb || sudo apt install -f -y
}

# if ls /usr/src | grep -q zfs ; then check_zfs; fi
update_git_fw
make_debs
install_headers
echo "done."