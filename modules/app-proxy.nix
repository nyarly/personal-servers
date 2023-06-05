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
      vhosts = (mapAttrs' httpVHost config.appProxy.sites) // (mapAttrs' httpsVHost config.appProxy.sites);
      httpVHost = name: hcfg: nameValuePair "${name}-http" {
          hostName = name;
          serverAliases = [ "www.${name}" ];
          listen = [{ port = 80; }];

          documentRoot = hcfg.staticBase;
          extraConfig = "Redirect / https://${name}/";
        };

        httpsVHost = name: hcfg: nameValuePair "${name}-https" (let
          inherit (hcfg) staticBase;

          excludedLocations = map (loc: ''
          <Location /${loc}>
            ProxyPass !
          </Location>
          '') (hcfg.staticLocations ++ [ ".well-known/acme-challenge" ]);

          backend = "${hcfg.backendHost}:${toString hcfg.backendPort}";
        in {
          hostName = name;
          serverAliases = [ "www.${name}" ];

          documentRoot = staticBase;

          onlySSL = true;
          enableACME = true;

          extraConfig = ''
          RequestHeader set X-Forwarded-Proto "https"
          ProxyPass / http://${backend}/
          ProxyPassReverse / http://${backend}/
          ${toString excludedLocations}
          '';
        });
    in vhosts;


    services.nsd.zones.staticweb.children = mapAttrs (name: value:
      if value.zoneData == null then
        { }
      else
        { data = value.zoneData; }
      ) config.appProxy.sites;
  };
}
