{ inputs, ... }:

{
  imports = [ inputs.disko.nixosModules.disko ];

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
            mountpoint = "/";
            mountOptions = [ "compress=zstd:1" ];

            subvolumes = {
              home = {
                mountpoint = "/home";
                mountOptions = [ "compress=zstd:1" ];
              };

              nix = {
                mountpoint = "/nix";
                mountOptions = [ "compress=zstd:1" ];
              };

              # The top-level filesystem exposes this subvolume directly at
              # /tmp, matching the current installation without another mount.
              tmp = { };
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
