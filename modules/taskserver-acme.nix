{ config, lib, ...}:
with lib;
let
  cfg = config.services.taskserverAcme;
  user = "taskd";
  group = "taskd";
  dataDir = "/var/lib/taskserver";
in
  {
  options = with types;
    {
      services.taskserverAcme = {
        enable = mkOption {
          type = types.bool;
          default = false;
          description = ''
                Whether to enable the Taskwarrior server.

                More instructions about NixOS in conjuction with Taskserver can be
                found in the NixOS manual at
                <olink targetdoc="manual" targetptr="module-taskserver"/>.
          '';
        };
      };
    };

  config = (mkIf cfg.enable ( let
    keyFile = src: {
      sops.secrets."taskserver/${src}" = {
        inherit group;
        owner = user;
        mode = "0600"; # the default
        path = "${dataDir}/keys/taskserver-${src}";

        restartUnits = [ "taskserver" ];
      };
    };
  in mkMerge [
      {
        services.taskserver = {
          inherit user group dataDir;
          enable = true;
          pki.auto = {};
          pki.manual = {
            ca.cert     = "${dataDir}/keys/taskserver-ca.pem";

            server.cert = "${dataDir}/keys/taskserver-cert.pem";
            server.key  = "${dataDir}/keys/taskserver-key.pem";
          };
        };
      }
      (keyFile "ca.pem")
      (keyFile "cert.pem")
      (keyFile "key.pem")
    ]));
}
