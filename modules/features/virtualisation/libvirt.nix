{
  ray.features."virtualisation/libvirt" = {
    nixos =
      {
        pkgs,
        username,
        ...
      }:
      let
        windowsShare = "/home/${username}/公共/Windows";
      in
      {
        programs.virt-manager.enable = true;

        environment.systemPackages = [ pkgs.freerdp ];

        users.users.${username}.extraGroups = [ "libvirtd" ];

        systemd.tmpfiles.rules = [
          "d ${windowsShare} 0770 ${username} users -"
          "a+ /home/${username} - - - - u:qemu-libvirtd:--x"
          "a+ /home/${username}/公共 - - - - u:qemu-libvirtd:--x"
          "a+ ${windowsShare} - - - - u:qemu-libvirtd:rwx,d:u:${username}:rwx,d:u:qemu-libvirtd:rwx,d:m:rwx"
        ];

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
