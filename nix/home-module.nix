self:
{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.programs.okaeri;
  json = pkgs.formats.json { };
in
{
  options.programs.okaeri = {
    enable = lib.mkEnableOption "okaeri, a desktop shell for niri";

    package = lib.mkOption {
      type = lib.types.package;
      default = self.packages.${pkgs.stdenv.hostPlatform.system}.default;
      description = "The okaeri package.";
    };

    settings = lib.mkOption {
      inherit (json) type;
      default = { };
      description = "okaeri/settings.json; shell/settings.json has every key.";
    };

    theme = lib.mkOption {
      inherit (json) type;
      default = { };
      description = "okaeri/theme.json; shell/themes/dark.json has every key.";
    };
  };

  config = lib.mkIf cfg.enable {
    home.packages = [ cfg.package ];

    xdg.configFile = {
      "okaeri/settings.json" = lib.mkIf (cfg.settings != { }) {
        source = json.generate "okaeri-settings.json" cfg.settings;
      };
      "okaeri/theme.json" = lib.mkIf (cfg.theme != { }) {
        source = json.generate "okaeri-theme.json" cfg.theme;
      };
    };

    systemd.user.services.okaeri = {
      Unit = {
        Description = "okaeri desktop shell";
        PartOf = [ "graphical-session.target" ];
        After = [ "graphical-session.target" ];
      };
      Service = {
        ExecStart = lib.getExe cfg.package;
        Restart = "on-failure";
        RestartSec = 1;
      };
      Install.WantedBy = [ "graphical-session.target" ];
    };
  };
}
