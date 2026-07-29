{
  ray.hosts.nixos.vesper = {
    system = "x86_64-linux";
    username = "ray";
    stateVersion = "26.05";
    homeStateVersion = "26.05";
    hardware = ./_hardware.nix;

    features = [
      "core/nix"
      "nixos/base"
      "nixos/desktop"
      "nixos/kernel/zen"
      "nixos/performance"
      "hardware/graphics"
      "hardware/uefi-systemd-boot"
      "home/base"
      "users/ray"
      "desktop/niri"
      "desktop/noctalia"
      "desktop/noctalia-greeter"
      "input/fcitx-rime"
      "ui/dark-mode"
      "ui/fonts"
      "virtualisation/libvirt"
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
      "software/kitty"
      "software/alger-music-player"
      "software/neovim"
      "software/obs"
      "software/qq"
      "software/qbittorrent"
      "software/shell"
      "software/telegram-web"
      "software/tooling"
      "software/tmux"
      "software/wemeet"
      "software/wps"
      "security/agenix"
      "security/fingerprint"
      "security/sudo"
    ];
  };
}
