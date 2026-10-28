{
  ray.features."virtualisation/libvirt" = {
    nixos =
      _:
      {
        pkgs,
        username,
        ...
      }:
      {
        programs.virt-manager.enable = true;

        environment.systemPackages = [
          pkgs.freerdp
          pkgs.libvirt
        ];

        users.users.${username}.extraGroups = [ "libvirtd" ];

        virtualisation = {
          libvirtd = {
            enable = true;

            qemu = {
              package = pkgs.qemu_kvm;
              swtpm.enable = true;
              vhostUserPackages = [ pkgs.virtiofsd ];
            };
          };

          spiceUSBRedirection.enable = true;
        };
      };
  };
}
