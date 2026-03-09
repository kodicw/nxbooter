{
  config,
  lib,
  pkgs,
  ...
}:

with lib;

let
  cfg = config.services.nxbooter;
in
{
  options.services.nxbooter = {
    enable = mkEnableOption "nxbooter service";

    package = mkOption {
      type = types.package;
      description = "The nxbooter package to use.";
    };

    openFirewall = mkOption {
      type = types.bool;
      default = false;
      description = "Whether to open the firewall for nxbooter.";
    };
  };

  config = mkMerge [
    (mkIf cfg.enable {
      systemd.services.nxbooter = {
        description = "nxbooter service";
        after = [ "network.target" ];
        wantedBy = [ "multi-user.target" ];
        serviceConfig = {
          ExecStart = "${cfg.package}/bin/run-pixiecore";
          Restart = "on-failure";
          User = "root";
        };
      };
    })

    (mkIf cfg.openFirewall {
      networking.firewall.allowedTCPPorts = [ 80 ];
      networking.firewall.allowedUDPPorts = [
        67
        69
        4011
      ];
    })
  ];
}
