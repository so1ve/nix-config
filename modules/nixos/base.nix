{ pkgs, ... }:

{
  networking.networkmanager.enable = true;

  time.timeZone = "Asia/Shanghai";

  i18n = {
    defaultLocale = "zh_CN.UTF-8";
    supportedLocales = [
      "en_US.UTF-8/UTF-8"
      "zh_CN.UTF-8/UTF-8"
    ];
  };

  services.fwupd.enable = true;
  services.printing.enable = true;

  services.pulseaudio.enable = false;
  security.rtkit.enable = true;
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
  };

  programs.fish.enable = true;

  nix.settings.experimental-features = [
    "nix-command"
    "flakes"
  ];

  nixpkgs.config.allowUnfree = true;

  fonts.packages = with pkgs; [
    nerd-fonts.jetbrains-mono
  ];
}
