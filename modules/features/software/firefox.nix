{
  ray.features."software/firefox" = {
    home = {
      programs.firefox = {
        enable = true;
        languagePacks = [ "zh-CN" ];
        policies.RequestedLocales = [ "zh-CN" ];
      };

      xdg.dataFile."firefoxpwa/profiles/00000000000000000000000000/user.js".text = ''
        user_pref("firefoxpwa.dynamicWindowTitle", false);
        user_pref("firefoxpwa.launchType", 3);
        user_pref("firefoxpwa.openOutOfScopeInDefaultBrowser", true);
      '';
    };
  };
}
