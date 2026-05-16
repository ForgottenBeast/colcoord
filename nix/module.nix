{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.services.colcoord;
in
{
  options.services.colcoord = {
    enable = lib.mkEnableOption "Colcoord colonist.io game finder";

    package = lib.mkOption {
      type = lib.types.package;
      description = "The colcoord package to use";
    };

    port = lib.mkOption {
      type = lib.types.port;
      default = 4000;
      description = "HTTP port";
    };

    dataDir = lib.mkOption {
      type = lib.types.path;
      default = "/var/lib/colcoord";
      description = "Directory for persistent data";
    };

    secretKeyBaseFile = lib.mkOption {
      type = lib.types.path;
      description = "Path to file containing SECRET_KEY_BASE";
    };

    host = lib.mkOption {
      type = lib.types.str;
      default = "localhost";
      description = "Hostname for the Phoenix endpoint";
    };
  };

  config = lib.mkIf cfg.enable {
    systemd.services.colcoord = {
      description = "Colcoord Game Finder";
      after = [ "network.target" ];
      wantedBy = [ "multi-user.target" ];
      environment = {
        PORT = toString cfg.port;
        DATABASE_PATH = "${cfg.dataDir}/colcoord.db";
        RELEASE_TMP = "${cfg.dataDir}/tmp";
        PHX_HOST = cfg.host;
      };
      serviceConfig = {
        Type = "exec";
        ExecStart = "${cfg.package}/bin/colcoord start";
        ExecStop = "${cfg.package}/bin/colcoord stop";
        DynamicUser = true;
        StateDirectory = "colcoord";
        RuntimeDirectory = "colcoord";
        EnvironmentFile = cfg.secretKeyBaseFile;
      };
    };
  };
}
