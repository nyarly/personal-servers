{ options, config, lib, pkgs, ...}:
with lib;
let
  cfg = config.services.taskserverAcme;
  tscfg = config.services.taskserver;
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
        acmeTargetPath = "${cfg.acmeRoot}/${tscfg.fqdn}";
        keyFile = op: server: {
          deployment.keys."taskserver-${server}" = {
            inherit user group;
            permissions = "0600"; # the default
            text = builtins.readFile op;
          };

          systemd.services.taskserver-keys = {
            wants = [ "taskserver-${server}.service" ];
            after = [ "taskserver-${server}.service" ];
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

        systemd.services.taskserver-keys = {
          script = ''
            install -m 0600 -o ${user} -g ${group} /run/keys/taskserver-* ${dataDir}/keys/
          '';
        };

        systemd.services.taskserver-init = {
          wants = [ "taskserver-keys.service" ];
          after = [ "taskserver-keys.service" ];
        };
      }
      (keyFile ../certs/root-cert.pem "ca.pem")
      (keyFile ../certs/tasks.madhelm.net_cert.pem "cert.pem")
      (keyFile ../secrets/tasks.madhelm.net_key.pem "key.pem")


      ]));
  }
