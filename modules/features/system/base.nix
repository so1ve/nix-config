{
  ray.features."system/base" = {
    nixos =
      {
        hostname,
        stateVersion,
        ...
      }:
      {
        networking = {
          hostName = hostname;
          networkmanager.enable = true;
        };

        time.timeZone = "Asia/Shanghai";

        # use zh_CN in desktop environment and en_US in terminal
        i18n = {
          defaultLocale = "zh_CN.UTF-8";
          supportedLocales = [
            "en_US.UTF-8/UTF-8"
            "zh_CN.UTF-8/UTF-8"
          ];
        };

        services.fwupd.enable = true;
        services.printing.enable = true;

        system.stateVersion = stateVersion;
      };
  };
}
