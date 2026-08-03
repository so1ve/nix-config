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
      "system/base"
      "system/kernel/zen"
      "system/performance"
      "boot/systemd-boot"
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
      "ui/dark-mode"
      "ui/fonts"

      # Development
      "software/kitty"
      "software/tmux"
      "software/neovim"
      "software/zed"
      "software/codex"
      "software/development"
      "software/git"
      "software/tooling"

      # Virtualisation and compatibility
      "virtualisation/podman"
      "virtualisation/waydroid"
      "virtualisation/winboat"
      "software/wine"

      # Files and network
      "software/dolphin"
      "software/yazi"
      "software/firefox"
      "software/mihomo"
      "software/ab-download-manager"
      "software/qbittorrent"
      "software/kde-connect"

      # Gaming
      "software/gaming"
      "software/hmcl"
      "software/netease-cloud-game"

      # Media
      "software/swayimg"
      "software/mpv"
      "software/haruna"
      "software/celluloid"
      "software/vlc"
      "software/alger-music-player"
      "software/obs"

      # IM
      "software/cinny"
      "software/qq"
      "software/telegram-web"

      # Misc
      "software/wemeet"
      "software/wps"
    ];
  };
}
