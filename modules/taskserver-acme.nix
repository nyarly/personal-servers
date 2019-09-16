{ options, config, lib, pkgs, ...}:
with lib;
let
  cfg = config.services.taskserverAcme;
  tscfg = config.services.taskserver;
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

        acmeRoot = mkOption {
          type = path;
          description = "The path that ACME clients will use for challenges.";
        };

        email = mkOption {
          type = string;
          description = "The administrator's email (sent to LetEncrypt)";
        };
      };
    };

    config = (mkIf cfg.enable ( let
        acmeTargetPath = "${cfg.acmeRoot}/${tscfg.fqdn}";
      in
      {
        services.taskserver = {
          enable = true;
          pki.auto = {};
          pki.manual = {
            ca.cert = "/var/lib/acme/${tscfg.fqdn}/chain.pem";
            server.crl = "/var/lib/acme/${tscfg.fqdn}/server.crl";

            server.cert = "/var/lib/acme/${tscfg.fqdn}/cert.pem";

            server.key = "/var/lib/acme/${tscfg.fqdn}/key.pem";
          };
        };

        security.acme.certs.${tscfg.fqdn} = {
          webroot = acmeTargetPath;
          email = cfg.email;
          user = "taskd";
          group = "taskd";
          allowKeysForGroup = true;
          plugins = ["cert.pem" "key.pem" "chain.pem" "account_key.json"];
          postRun = "systemctl reload taskserver.service";
        };

        services.httpd.virtualHosts = [{
          hostName = tscfg.fqdn;
          listen = [{ port = 80; }];

          #documentRoot = staticBase;
          extraConfig = "Redirect / https://${tscfg.fqdn}/";
        }

        {
          hostName = tscfg.fqdn;
          listen = [{ port = 443; }];

          #documentRoot = staticBase;
          enableSSL = true;
          sslServerCert = "/var/lib/acme/${tscfg.fqdn}/full.pem";
          sslServerKey = "/var/lib/acme/${tscfg.fqdn}/key.pem";

          extraConfig = ''
          RequestHeader set X-Forwarded-Proto "https"
          Alias "/.well-known/acme-challenge" "${acmeTargetPath}/.well-known/acme-challenge"
          <Directory ${acmeTargetPath}>
          Require all granted
          </Directory>
          '';
        }];
      })
    );
  }
