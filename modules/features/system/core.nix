{
  ray.features."system/core" = {
    nixos =
      _:
      {
        hostname,
        stateVersion,
        user,
        username,
        ...
      }:
      {
        users.users.${username} = {
          isNormalUser = true;
          inherit (user) description;
        };

        networking.hostName = hostname;
        time.timeZone = "Asia/Shanghai";

        # Use zh_CN in desktop environments and en_US in terminals.
        i18n = {
          defaultLocale = "zh_CN.UTF-8";
          supportedLocales = [
            "en_US.UTF-8/UTF-8"
            "zh_CN.UTF-8/UTF-8"
          ];
        };

        system.stateVersion = stateVersion;
      };
  };
}
