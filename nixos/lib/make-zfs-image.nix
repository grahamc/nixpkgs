{ lib, pkgs, ... }:
# Create a disk image with a GPT partition table and a ZFS pool

{
  # The NixOS configuration to be installed onto the disk image.
  config

, # The size of the disk, in megabytes.
  # if "auto" size is calculated based on the contents copied to it and
  #   additionalSpace is taken into account.
  diskSize ? "2048M"

, # size of the boot partition, is only used if partitionTableType is
  # either "efi" or "hybrid"
  bootSize ? "1024M"

, # The files and directories to be placed in the target file system.
  # This is a list of attribute sets {source, target} where `source'
  # is the file system object (regular file or directory) to be
  # grafted in the file system at path `target'.
  contents ? []

, # The initial NixOS configuration file to be copied to
  # /etc/nixos/configuration.nix.
  configFile ? null

, # Shell code executed after the VM has finished.
  postVM ? ""

, name ? "nixos-disk-image"

, # Disk image format, one of qcow2, qcow2-compressed, vdi, vpc, raw.
  format ? "raw"
}:

let
  poolName = config.zfs.poolName;

  channelSources = import ./make-channel.nix {
    inherit pkgs;
    inherit (config.system.nixos) version versionSuffix;
    nixpkgs = lib.cleanSource pkgs.path;
  };

  closureInfo = pkgs.closureInfo {
    rootPaths = [ config.system.build.toplevel channelSources ];
  };

  preVM = ''
    PATH=$PATH:${pkgs.qemu_kvm}/bin
    mkdir $out
    diskImage=nixos.raw
    qemu-img create -f qcow2 $diskImage ${toString diskSize}M
  '';

  postVM = ''
    qemu-img convert -f qcow2 -O vpc $diskImage $out/nixos.vhd
    ls -ltrhs $out/ $diskImage
    time sync $out/nixos.vhd
    ls -ltrhs $out/
  '';
  modulesTree =
    pkgs.aggregateModules (with config.boot.kernelPackages; [ kernel zfs ]);
  nixpkgs = lib.cleanSource pkgs.path;

  image = (
    pkgs.vmTools.override {
      rootModules =
        [ "zfs" "9p" "9pnet_virtio" "virtio_pci" "virtio_blk" "rtc_cmos" ];
      kernel = modulesTree;
    }
  ).runInLinuxVM (
    pkgs.runCommand "zfs-image" { inherit preVM postVM; } ''
      export PATH=${
    lib.makeBinPath (
      with pkgs; [
        nix
        e2fsprogs
        zfs
        utillinux
        config.system.build.nixos-enter
        config.system.build.nixos-install
      ]
    )
    }:$PATH

      cp -sv /dev/vda /dev/sda

      export NIX_STATE_DIR=$TMPDIR/state
      nix-store --load-db < ${closureInfo}/registration

      sfdisk /dev/vda <<EOF
      label: gpt
      device: /dev/vda
      unit: sectors
      1 : size=2048, type=21686148-6449-6E6F-744E-656564454649
      2 : size=${
    toString (bootSize * 2048)
    }, type=0FC63DAF-8483-4772-8E79-3D69D8477DE4
      3 : type=CA7D7CCB-63ED-4C53-861C-1742536059CC
      EOF

      mkfs.ext4 /dev/vda2 -L NIXOS_BOOT
      zpool create -o ashift=12 \
        -o altroot=/mnt \
        -o autoexpand=on \
        -O mountpoint=legacy \
        -O compression=on \
        -O xattr=sa \
        -O acltype=posixacl \
        -O atime=off \
        ${poolName} /dev/vda3

      zfs create -p ${poolName}/system/root
      zfs create -p ${poolName}/system/var
      zfs create -p ${poolName}/local/nix
      zfs create -p ${poolName}/user/home

      mkdir -p /mnt
      mount -t zfs ${poolName}/system/root /mnt
      mkdir /mnt/{var,nix,home,boot}
      mount -t zfs ${poolName}/system/var /mnt/var
      mount -t zfs ${poolName}/local/nix /mnt/nix
      mount -t zfs ${poolName}/user/home /mnt/home

      mount -t ext4 /dev/vda2 /mnt/boot
      echo copying toplevel
      time nix copy --no-check-sigs --to 'local?root=/mnt/' ${config.system.build.toplevel}
      ${lib.optionalString config.zfs.image.shipChannels ''
      echo copying channels
      time nix copy --no-check-sigs --to 'local?root=/mnt/' ${channelSources}
    ''}

      echo installing bootloader
      time nixos-install --root /mnt --no-root-passwd --system ${config.system.build.toplevel} ${
    lib.optionalString config.zfs.image.shipChannels
      "--channel ${channelSources}"
    } --substituters ""

      df -h
      umount /mnt/{home,nix,boot,var,}
      zpool export ${poolName}
    ''
  );
in
{
  imports = [ ./zfs-runtime.nix ];

  config = {
    nixpkgs.config.allowUnfree = true;
    boot = { blacklistedKernelModules = [ "nouveau" "xen_fbfront" ]; };
    networking = { hostId = "00000000"; };
    environment.systemPackages = [ pkgs.cryptsetup ];
    system.build.zfsImage = image;
    system.build.uploadAmi = import ./upload-ami.nix {
      inherit pkgs;
      image = "${config.system.build.zfsImage}/nixos.vhd";
      regions = config.zfs.regions;
      bucket = config.zfs.bucket;
    };
  };
}
