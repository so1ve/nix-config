{
  ray.features."software/firefox" = {
    home = {
      programs.firefox = {
        enable = true;
        languagePacks = [ "zh-CN" ];
        policies.RequestedLocales = [ "zh-CN" ];
      };

      xdg.dataFile."firefoxpwa/profiles/00000000000000000000000000/user.js".text = ''
        user_pref("firefoxpwa.allowedDomains", "accounts.google.com,addons.mozilla.org,auth.zulipchat.com,github.com");
        user_pref("firefoxpwa.dynamicWindowTitle", false);
        user_pref("firefoxpwa.launchType", 3);
        user_pref("firefoxpwa.openOutOfScopeInDefaultBrowser", true);
      '';
    };
  };
}
