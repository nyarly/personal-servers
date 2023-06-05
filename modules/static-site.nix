{ config, lib, pkgs, ...}:
with lib;
{
  options = {
    staticWeb = {
        acmeRoot = mkOption {
        type = with types; path;
        description = "The path that ACME clients will use for challenges.";
      };

      sites = mkOption {
        default = {};
        type = with types; attrsOf (submodule {
          options = {
            docRoot = mkOption { type = path; };
          };
        });
        description = ''
          Attribute set of static sites.
        '';

        example = literalExample ''
          judsonlester.info = {
            docRoot = blog;
          };
        '';
      };
    };
  };

  config = mkIf (builtins.length (builtins.attrNames config.staticWeb.sites) > 0) {
    services.httpd.virtualHosts = let
      vhosts = mapAttrs' vhost config.staticWeb.sites;

      vhost = name: hcfg: nameValuePair "${name}" {
          hostName = name;
          serverAliases = [ "www.${name}" ];

          documentRoot = hcfg.docRoot;

          forceSSL = true;
          enableACME = true;
        };
    in vhosts;

    services.nsd.zones.staticweb.children = mapAttrs (name: value: {}) config.staticWeb.sites;
  };
}
