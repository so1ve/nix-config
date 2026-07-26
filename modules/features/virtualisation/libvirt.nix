{
  ray.features."virtualisation/libvirt" = {
    nixos =
      {
        pkgs,
        username,
        ...
      }:
      {
        programs.virt-manager.enable = true;

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

        # Stable path for attaching the Windows VirtIO driver ISO in virt-manager.
        environment.etc."libvirt/virtio-win.iso".source = pkgs.virtio-win.src;
      };
  };
}
