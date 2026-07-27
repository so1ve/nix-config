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
        windowsVmAddress = "192.168.122.209";
        windows11Rdp = pkgs.writeShellApplication {
          name = "win11";
          runtimeInputs = [
            pkgs.coreutils
            pkgs.freerdp
            pkgs.libvirt
            pkgs.netcat-openbsd
          ];
          text = ''
            if [ "$(${pkgs.libvirt}/bin/virsh -c qemu:///system domstate windows11 2>/dev/null)" != "running" ]; then
              echo "Starting Windows 11..."
              ${pkgs.libvirt}/bin/virsh -c qemu:///system start windows11 >/dev/null
            fi

            echo "Waiting for Remote Desktop..."
            for _ in $(${pkgs.coreutils}/bin/seq 1 90); do
              if ${pkgs.netcat-openbsd}/bin/nc -z -w 1 ${windowsVmAddress} 3389 2>/dev/null; then
                exec ${pkgs.freerdp}/bin/sdl-freerdp \
                  /v:${windowsVmAddress} \
                  /d:. \
                  /u:${username} \
                  /dynamic-resolution \
                  /clipboard \
                  /cert:tofu \
                  "$@"
              fi

              ${pkgs.coreutils}/bin/sleep 1
            done

            echo "Windows 11 did not expose RDP within 90 seconds." >&2
            exit 1
          '';
        };
        windows11RdpDesktop = pkgs.makeDesktopItem {
          name = "windows11-rdp";
          desktopName = "Windows 11";
          genericName = "Remote Desktop";
          comment = "Start and connect to the Windows 11 virtual machine";
          exec = "${windows11Rdp}/bin/win11";
          icon = "computer";
          terminal = true;
          categories = [
            "Network"
            "RemoteAccess"
          ];
        };
      in
      {
        programs.virt-manager.enable = true;

        environment.systemPackages = [
          pkgs.freerdp
          windows11Rdp
          windows11RdpDesktop
        ];

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
