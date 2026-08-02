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
      "core/nix"
      "nixos/base"
      "nixos/desktop"
      # TODO: Update zen kernel to 7.1.5 to fix CIFS issue
      "nixos/kernel/zen"
      "nixos/performance"
      "hardware/graphics"
      "hardware/smartd"
      "hardware/uefi-systemd-boot"
      "home/base"
      "users/ray"
      "desktop/niri"
      "desktop/noctalia"
      "desktop/noctalia-greeter"
      "input/fcitx-rime"
      "ui/dark-mode"
      "ui/fonts"
      "storage/snapper"
      "storage/mount/nas"
      "virtualisation/podman"
      "virtualisation/waydroid"
      "software/ab-download-manager"
      "software/dolphin"
      "software/mihomo"
      "software/netease-cloud-game"
      "software/codex"
      "software/firefox"
      "software/gaming"
      "software/wine"
      "software/development"
      "software/git"
      "software/hmcl"
      "software/kde-connect"
      "software/kitty"
      "software/alger-music-player"
      "software/swayimg"
      "software/mpv"
      "software/haruna"
      "software/celluloid"
      "software/vlc"
      "software/neovim"
      "software/zed"
      "software/obs"
      "software/qq"
      "software/qbittorrent"
      "software/shell"
      "software/telegram-web"
      "software/tooling"
      "software/tmux"
      "software/wemeet"
      "software/winboat"
      "software/wps"
      "software/yazi"
      "security/agenix"
      "security/fingerprint"
      "security/sudo"
    ];
  };
}
