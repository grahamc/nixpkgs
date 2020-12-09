{ config, lib, pkgs, ... }:
{
  options = {
    ec2 = {
      zfsRoot = lib.mkOption {
        default = false;
        internal = true;
        description = ''
          Whether the EC2 instance uses a ZFS root.
        '';
      };
      hvm = lib.mkOption {
        default = lib.versionAtLeast config.system.stateVersion "17.03";
        internal = true;
        description = ''
          Whether the EC2 instance is a HVM instance.
        '';
      };
      efi = lib.mkOption {
        default = pkgs.stdenv.hostPlatform.isAarch64;
        internal = true;
        description = ''
          Whether the EC2 instance is using EFI.
        '';
      };
    };
  };
}
