{
  ray.features."virtualisation/waydroid" = {
    nixos =
      {
        config,
        inputs,
        pkgs,
        username,
        ...
      }:
      let
        homeDirectory = "/home/${username}";
        waydroidPackage = config.virtualisation.waydroid.package;
        waydroidExtras = inputs.waydroid-script.packages.${pkgs.stdenv.hostPlatform.system}.default;

        setupWaydroid = pkgs.writeShellApplication {
          name = "waydroid-setup";
          runtimeInputs = [
            waydroidPackage
            waydroidExtras
            pkgs.coreutils
            pkgs.crudini
            pkgs.systemd
          ];
          text = builtins.readFile ./waydroid/setup.sh;
        };

        refreshWaydroidGamepads = pkgs.writeShellApplication {
          name = "waydroid-gamepad-refresh";
          runtimeInputs = [
            waydroidPackage
            pkgs.coreutils
            pkgs.gnugrep
            pkgs.systemd
          ];
          text = builtins.readFile ./waydroid/refresh-gamepads.sh;
        };
      in
      {
        virtualisation.waydroid.enable = true;

        fileSystems."${homeDirectory}/Waydroid" = {
          device = "${homeDirectory}/.local/share/waydroid/data/media/0";
          fsType = "fuse.bindfs";
          options = [
            "mirror=${username}"
            "nofail"
            "x-systemd.automount"
          ];
        };

        /*
          NixOS can declare the Waydroid service and networking package, but
          Waydroid keeps its image type, overlays and Android properties in
          mutable state under /var/lib/waydroid and the user's Android data.

          Run `waydroid-setup` after the first rebuild, or after resetting
          Waydroid. It idempotently configures the state used on this host:

          - LineageOS Vanilla (no GApps)
          - Houdini ARM translation; libndk crashes Endfield
          - uevent input passthrough for the Xbox controller
          - fake_touch disabled, because it breaks controller axis events

          Installed APKs and Android application data intentionally remain
          outside the Nix store. If a controller was connected before the
          Waydroid session, run `waydroid-gamepad-refresh` instead of
          physically reconnecting it.
        */
        environment.systemPackages = [
          refreshWaydroidGamepads
          setupWaydroid
        ];
      };
  };
}
