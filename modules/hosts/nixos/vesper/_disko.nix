{ inputs, ... }:

let
  btrfsMountOptions = [ "compress=zstd:1" ];
in
{
  imports = [ inputs.disko.nixosModules.disko ];

  # /home contains the agenix identity used during activation, while early
  # services may need /tmp before local-fs.target.  Both therefore have to
  # cover the inode-2 stubs left in a snapshot of the old top-level root
  # before initrd activation starts.
  fileSystems."/home".neededForBoot = true;
  fileSystems."/tmp".neededForBoot = true;

  disko.devices.disk.system = {
    type = "disk";
    device = "/dev/disk/by-id/nvme-eui.e8238fa6bf530001001b448b40953982";

    content = {
      type = "gpt";
      partitions = {
        ESP = {
          priority = 1;
          start = "1M";
          size = "8G";
          type = "EF00";
          uuid = "13230d0b-1be8-4dfe-a073-a372c14fe3e4";

          content = {
            type = "filesystem";
            format = "vfat";
            mountpoint = "/boot";
            mountOptions = [
              "fmask=0077"
              "dmask=0077"
            ];
          };
        };

        root = {
          priority = 2;
          end = "-40G";
          uuid = "eac4ab6a-917d-4a69-b037-b88c8a5aab7e";

          content = {
            type = "btrfs";
            extraArgs = [ "-f" ];

            subvolumes = {
              # The current installation still uses the top-level subvolume
              # (ID 5); migrate it before activating this mount layout.
              "@root" = {
                mountpoint = "/";
                mountOptions = btrfsMountOptions;
              };

              home = {
                mountpoint = "/home";
                mountOptions = btrfsMountOptions;
              };

              nix = {
                mountpoint = "/nix";
                mountOptions = btrfsMountOptions;
              };

              tmp = {
                mountpoint = "/tmp";
                mountOptions = btrfsMountOptions;
              };

              "@snapshots" = {
                mountpoint = "/.snapshots";
                mountOptions = btrfsMountOptions;
              };

              "@home-snapshots" = {
                mountpoint = "/home/.snapshots";
                mountOptions = btrfsMountOptions;
              };

              # Keep large, frequently modified runtime images outside the
              # root snapshot. Their configuration remains in @root.
              "@var-lib-containers" = {
                mountpoint = "/var/lib/containers";
                mountOptions = btrfsMountOptions;
              };

              "@var-lib-libvirt-images" = {
                mountpoint = "/var/lib/libvirt/images";
                mountOptions = btrfsMountOptions;
              };

              "@var-lib-waydroid" = {
                mountpoint = "/var/lib/waydroid";
                mountOptions = btrfsMountOptions;
              };
            };
          };
        };

        swap = {
          priority = 3;
          size = "100%";
          uuid = "f32b10b5-4f38-473c-a0ae-5829a81e2bce";
          content.type = "swap";
        };
      };
    };
  };
}
