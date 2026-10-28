{ lib, ... }:

let
  choice =
    values: description:
    lib.mkOption {
      type = lib.types.nullOr (lib.types.enum values);
      default = null;
      inherit description;
    };

  mimeDefaults = mimeTypes: desktopFile: {
    enable = true;
    defaultApplications = lib.genAttrs mimeTypes (_: desktopFile);
  };
in
{
  ray.features.defaults = {
    options = {
      shell = choice [ "bash" "fish" ] "Login shell for the primary user.";
      terminal = choice [ "kitty" "ghostty" ] "Default terminal emulator.";
      editor = choice [ "neovim" ] "Default editor for interactive tools.";
      browser = choice [ "chrome" ] "Default browser for web links.";
      fileManager = choice [ "nautilus" ] "Default application for directories.";
      archiveManager = choice [ "peazip" ] "Default application for archives.";
      imageViewer = choice [ "swayimg" ] "Default application for images.";
      mediaPlayer = choice [ "mpv" ] "Default application for audio and video.";
    };

    requires = settings: {
      allOf =
        lib.optional (settings.shell != null) "software/shell"
        ++ map (application: "software/${application}") (
          lib.filter (application: application != null) [
            settings.terminal
            settings.editor
            settings.browser
            settings.fileManager
            settings.archiveManager
            settings.imageViewer
            settings.mediaPlayer
          ]
        );
    };

    nixos =
      settings:
      {
        config,
        pkgs,
        username,
        ...
      }:
      {
        config = lib.mkIf (settings.shell != null) {
          users.users.${username}.shell =
            if settings.shell == "fish" then config.programs.fish.package else pkgs.bashInteractive;
        };
      };

    home = settings: {
      config = lib.mkMerge [
        (lib.mkIf (settings.terminal != null) {
          home.sessionVariables.TERMINAL = settings.terminal;
        })

        (lib.mkIf (settings.editor == "neovim") {
          home.sessionVariables = {
            EDITOR = "nvim";
            MANPAGER = "nvim +Man!";
            SUDO_EDITOR = "nvim";
            VISUAL = "nvim";
          };

          programs = {
            git.settings = {
              core.editor = "nvim";
              diff.tool = "nvimdiff";
              merge.tool = "nvimdiff";
            };

            neovim = {
              defaultEditor = true;
              viAlias = true;
              vimAlias = true;
            };
          };
        })

        (lib.mkIf (settings.browser == "chrome") {
          home.sessionVariables.BROWSER = "google-chrome-stable";
          xdg.mimeApps = mimeDefaults [
            "application/xhtml+xml"
            "text/html"
            "x-scheme-handler/http"
            "x-scheme-handler/https"
          ] "open-in-google-chrome.desktop";
        })

        (lib.mkIf (settings.fileManager == "nautilus") {
          xdg.mimeApps = mimeDefaults [ "inode/directory" ] "org.gnome.Nautilus.desktop";
        })

        (lib.mkIf (settings.archiveManager == "peazip") {
          xdg.mimeApps = mimeDefaults [
            "application/bzip2"
            "application/gzip"
            "application/vnd.rar"
            "application/x-7z-compressed"
            "application/x-bzip-compressed-tar"
            "application/x-compressed-tar"
            "application/x-gzip"
            "application/x-rar"
            "application/x-rar-compressed"
            "application/x-tar"
            "application/x-xz"
            "application/x-xz-compressed-tar"
            "application/zip"
          ] "peazip.desktop";
        })

        (lib.mkIf (settings.imageViewer == "swayimg") {
          xdg.mimeApps = mimeDefaults [
            "image/avif"
            "image/bmp"
            "image/gif"
            "image/heic"
            "image/heif"
            "image/jpeg"
            "image/jxl"
            "image/png"
            "image/svg+xml"
            "image/tiff"
            "image/webp"
          ] "swayimg.desktop";
        })

        (lib.mkIf (settings.mediaPlayer == "mpv") {
          xdg.mimeApps = mimeDefaults [
            "application/ogg"
            "application/vnd.apple.mpegurl"
            "audio/aac"
            "audio/flac"
            "audio/mp4"
            "audio/mpeg"
            "audio/ogg"
            "audio/opus"
            "audio/x-matroska"
            "audio/x-mpegurl"
            "audio/x-wav"
            "video/3gpp"
            "video/3gpp2"
            "video/mp2t"
            "video/mp4"
            "video/mpeg"
            "video/ogg"
            "video/quicktime"
            "video/webm"
            "video/x-flv"
            "video/x-matroska"
            "video/x-msvideo"
          ] "mpv.desktop";
        })
      ];
    };
  };
}
