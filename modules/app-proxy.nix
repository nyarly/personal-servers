{ config, lib, pkgs, ...}:
with lib;
{
  options = {
    appProxy = {
      acmeRoot = mkOption {
        type = with types; path;
        description = "The path that ACME clients will use for challenges.";
      };

      sites = mkOption {
        default = {};
        type = with types; attrsOf (submodule {
          options = {
            backendHost = mkOption {
              type = str;
              default = "localhost";
            };

            backendPort = mkOption {
              type = ints.between 1 65535;
            };

            staticBase = mkOption {
              type = path;
            };

            staticLocations = mkOption {
              type = listOf str;
            };

            acmeEnabled = mkOption {
              type = bool;
              default = true;
            };

            zoneData = mkOption {
              type = nullOr str;
              default = null;
            };
          };
        });
        description = ''
          Attribute set of static sites.
        '';

        example = literalExample ''
          wagthepig.com = {
            staticBase = "${wagthepig.package}/public";
            staticLocations = [ "assets" "system" ];
            backendPort = 3000;
          };
        '';
      };
    };
  };

  config = mkIf (builtins.length (builtins.attrNames config.appProxy.sites) > 0) {
    services.httpd.virtualHosts = let
      httpVHost = name: hcfg: nameValuePair "${name}-http" {
          hostName = name;
          serverAliases = [ "www.${name}" ];
          listen = [{ port = 80; }];

          documentRoot = hcfg.staticBase;
          extraConfig = "Redirect / https://${name}/";
        };

      httpsVHost = name: hcfg: let
          inherit (hcfg) staticBase;
          acmeConfig = if hcfg.acmeEnabled then ''
            <Location /.well-known/acme-challenge>
              ProxyPass !
            </Location>
            Alias "/.well-known/acme-challenge" "${config.appProxy.acmeRoot}/${name}/.well-known/acme-challenge"
            <Directory ${config.appProxy.acmeRoot}/${name}>
              Require all granted
            </Directory>
          '' else "";

          excludedLocations = map (loc: ''
            <Location /${loc}>
              ProxyPass !
            </Location>
          '') hcfg.staticLocations;

          backend = "${hcfg.backendHost}:${toString hcfg.backendPort}";
      in nameValuePair "${name}-https" {
            hostName = name;
            serverAliases = [ "www.${name}" ];

            documentRoot = staticBase;

            onlySSL = true;

            sslServerCert = "/var/lib/acme/${name}/full.pem";
            sslServerKey = "/var/lib/acme/${name}/key.pem";

            extraConfig = ''
              RequestHeader set X-Forwarded-Proto "https"
              ProxyPass / http://${backend}/
              ProxyPassReverse / http://${backend}/
              ${toString excludedLocations}
              ${acmeConfig}
            '';
          };
    in (mapAttrs' httpVHost config.appProxy.sites) // (mapAttrs' httpsVHost config.appProxy.sites);

    services.nsd.zones.staticweb.children = mapAttrs (name: value:
    if value.zoneData == null then
      { }
    else
      { data = value.zoneData; }
    ) config.appProxy.sites;

    security.acme = {
      acceptTerms = true;
      email = "nyarly@gmail.com";
      certs = let
        certs = mapAttrs siteToCertCfg config.appProxy.sites;
        siteToCertCfg = domain: {...}: {
          webroot = config.appProxy.acmeRoot + "/${domain}";
          email = "nyarly@gmail.com";
          postRun = "systemctl reload httpd.service";
          extraDomainNames = [ "www.${domain}" ];
        };
      in certs;
    };

    systemd.services.httpd = {
      after = [ "acme-selfsigned-certificates.target" ];
      wants = [ "acme-selfsigned-certificates.target" "acme-certificates.target" ];
    };
  };
}
