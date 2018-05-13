let
  blog = import ./blog/default.nix {};
  acmeRoot = "/var/run/acme-challenges";
in
  {
    network.description = "Web server";

    webserver = {  pkgs, ... }:
    {
      imports = [ ./static-site.nix ];

      environment.systemPackages = with pkgs; [ neovim fish ];

      services.fail2ban.enable = true;

      services.httpd = {
        enable = true;
        adminAddr = "nyarly@gmail.com";
      };

      staticWeb = {
        inherit acmeRoot;
        sites = {
          "judsonlester.info" = { docRoot = blog; };
          "madhelm.net"       = { docRoot = blog; };
        };
      };

      networking.firewall.allowedTCPPorts = [ 22 80 443 ];
    };
  }
