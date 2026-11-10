{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.services.antigravity;
in
{
  options.services.antigravity = {
    enable = lib.mkEnableOption "Antigravity Hub user service";

    package = lib.mkPackageOption pkgs "antigravity-cli" { };

    port = lib.mkOption {
      type = lib.types.port;
      default = 4400;
      description = ''
        Port on which the Antigravity Hub web UI listens.
      '';
    };

    extraArgs = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      example = [ "--sandbox" ];
      description = ''
        Additional command-line arguments to pass to `agy`.
      '';
    };

    extraPackages = lib.mkOption {
      type = lib.types.listOf lib.types.package;
      default = [ ];
      example = lib.literalExpression "with pkgs; [ git ]";
      description = ''
        Extra packages to make available in the Antigravity Hub service {env}`PATH`.
      '';
    };

    environment = lib.mkOption {
      type =
        with lib.types;
        attrsOf (
          nullOr (oneOf [
            bool
            int
            str
          ])
        );
      default = { };
      example = {
        GEMINI_API_KEY = "your-api-key";
      };
      description = ''
        Additional environment variables to set for the Antigravity Hub user service.
      '';
    };

    environmentFile = lib.mkOption {
      type = lib.types.nullOr lib.types.path;
      default = null;
      example = "/run/secrets/antigravity.env";
      description = ''
        Additional environment file as defined in {manpage}`systemd.exec(5)`.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    systemd.user.services.antigravity = {
      description = "Antigravity Hub web UI server";
      after = [ "network.target" ];
      wantedBy = [ "default.target" ];
      path = [ pkgs.bash ] ++ cfg.extraPackages;
      environment =
        lib.mapAttrs (
          _: value: if lib.isBool value then lib.boolToString value else toString value
        ) cfg.environment
        // {
          AGY_ENABLE_HUB = "1";
        };
      serviceConfig = {
        ExecStart = lib.escapeShellArgs (
          [
            (lib.getExe cfg.package)
            "--hub"
            "--hub-port"
            (toString cfg.port)
          ]
          ++ cfg.extraArgs
        );
        EnvironmentFile = lib.mkIf (cfg.environmentFile != null) cfg.environmentFile;
        Restart = "on-failure";
        RestartSec = 5;
      };
    };

    environment.systemPackages = [ cfg.package ];
  };

  meta.maintainers = with lib.maintainers; [ seirl ];
}
