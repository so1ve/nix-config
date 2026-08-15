{
  ray.hosts.nixos.vesper = {
    system = "x86_64-linux";
    username = "ray";
    stateVersion = "26.05";
    homeStateVersion = "26.05";
    modules = [
      ./_hardware.nix
      ./_disko.nix
    ];

    features = [
      # System
      "system/nix"
      "system/core"
      "system/workstation"
      "system/kernel/cachyos-lto-zen4"
      "system/performance"
      "boot/systemd-boot"
      "hardware/battery"
      "hardware/graphics"
      "hardware/smartd"
      "storage/snapper"
      "storage/mount/nas"
      "security/agenix"
      "security/fingerprint"
      "security/sudo"

      # User and desktop
      "home/base"
      "software/shell"
      "users/ray"
      "desktop/audio"
      "desktop/niri"
      "desktop/noctalia"
      "desktop/noctalia-greeter"
      "input/fcitx-rime"
      "ui/core"
      "ui/fonts"

      # Development
      "software/kitty"
      "software/tmux"
      "software/neovim"
      "software/zed"
      "software/codex"
      "software/codex-desktop"
      "software/pi"
      "software/dsh"
      "software/development"
      "software/git"
      "software/git/github"
      "software/comma"
      "software/tooling"

      # Virtualisation and compatibility
      "virtualisation/podman"
      "virtualisation/waydroid"
      "virtualisation/winboat"
      "software/wine"

      # Files and network
      "software/nautilus"
      "software/peazip"
      "software/yazi"
      "software/chrome"
      "software/mihomo"
      "software/tailscale"
      "software/ab-download-manager"
      "software/qbittorrent"
      "software/kde-connect"
      "software/pairdrop"

      # Gaming
      "software/gaming"
      "software/hmcl"
      "software/netease-cloud-game"

      # Media
      "software/swayimg"
      "software/mpv"
      "software/alger-music-player"
      "software/obs"
      "software/yanhekt-autoslides"

      # IM
      "software/cinny"
      "software/discord"
      "software/oopz"
      "software/qq"
      "software/rust-zulip"
      "software/telegram-web"
      "software/xwayclip"

      # Misc
      "software/mission-center"
      "software/wemeet"
      "software/wps"
    ];
  };
}
