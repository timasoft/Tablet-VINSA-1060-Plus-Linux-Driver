{ config, lib, pkgs, ... }:

let
  cfg = config.services.vinsa-tablet;
  inherit (lib) types mkOption mkEnableOption mkIf mkMerge literalExpression;
in
{
  options.services.vinsa-tablet = {
    enable = mkEnableOption "VINSA 1060 Plus tablet driver";

    package = mkOption {
      type = types.nullOr types.package;
      default = null;
      example = literalExpression "inputs.vinsa-tablet.packages.${pkgs.system}.default";
      description = ''
        The v1060p driver package to use.

        This option is automatically populated when the module is imported
        from the vinsa-tablet flake via `nixosModules.vinsa-tablet`.
        Set manually only if you need to override the default package.
      '';
    };
  };

  config = mkIf cfg.enable (mkMerge [
    {
      assertions = [
        {
          assertion = cfg.package != null;
          message = ''
            services.vinsa-tablet.package must be set when enable = true.
            This is normally handled automatically when importing the module
            from the vinsa-tablet flake via `inputs.vinsa-tablet.nixosModules.vinsa-tablet`.
          '';
        }
      ];
    }

    {
      environment.systemPackages = lib.optional (cfg.package != null) cfg.package;

      systemd.services.vinsa-tablet = {
        description = "VINSA 1060 Plus tablet driver";
        wantedBy = [ "multi-user.target" ];
        after = [ "systemd-udev-settle.service" ];
        serviceConfig = {
          Type = "simple";
          ExecStart = "${cfg.package}/bin/v1060p";
          Restart = "on-failure";
          RestartSec = 5;
          StandardOutput = "journal";
          StandardError = "journal";
        };
      };
    }
  ]);
}
