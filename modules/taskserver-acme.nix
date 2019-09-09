{ options, config, lib, pkgs, ...}:
with lib;
let
  cfg = config.taskserverAcme;
  opts = options;
in
  {
    options = with types;
    {
      taskserverAcme = (builtins.removeAttrs opts.services.taskserver [
        "enable"
        "auto"
        "manual"
      ]) //
      {
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

    config = mkIf (cfg.enable) (let
      acmeTargetPath = cfg.acmeRoot + "./${cfg.fqdn}";
      taskserverOpts = getAttrs (builtins.attrNames opts.services.taskserver) cfg;
    in
    {
      services.taskserver = taskserverOpts // {
        enable = true;
        manual = {
          #ca.cert = "";
          #server.crl = "";

          server.cert = acmeTargetPath + ./full.pem;

          server.key = acmeTargetPath + ./key.pem;
        };
      };

      security.acme.certs = [
        {
          name = cfg.fqdn;
          value = {
            webroot = acmeTargetPath;
            email = cfg.email;
            postRun = "systemctl reload taskserver.service";
          };
        }
      ];

      services.httpd.virtualHosts = [{
        hostName = cfg.fqdn;
        listen = [{ port = 80; }];

        documentRoot = staticBase;
        extraConfig = "Redirect / https://${cfg.fqdn}/";
      }

      {
        hostName = cfg.fqdn;
        listen = [{ port = 443; }];

        documentRoot = staticBase;
        enableSSL = true;
        sslServerCert = "/var/lib/acme/${cfg.fqdn}/full.pem";
        sslServerKey = "/var/lib/acme/${cfg.fqdn}/key.pem";

        extraConfig = ''
              RequestHeader set X-Forwarded-Proto "https"
              Alias "/.well-known/acme-challenge" "${acmeTargetPath}/.well-known/acme-challenge"
              <Directory ${acmeTargetPath}>
                Require all granted
              </Directory>
        '';
      }];
    });
  }
