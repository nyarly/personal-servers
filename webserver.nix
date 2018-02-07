let
  jlWebroot = "/var/ww/webroot";
in
  {
    network.description = "Web server";

    webserver =
      {  pkgs, ... }:
      {
        environment.systemPackages = with pkgs; [
          neovim
          fish
        ];
        services.httpd = {
          enable = true;
          adminAddr = "nyarly@gmail.com";
          documentRoot = jlWebroot;
        };

        security.acme.certs = {
          "judsonlester.info" = {
            webroot = jlWebroot;
            email = "nyarly@gmail.com";
          };
        };

        networking.firewall.allowedTCPPorts = [ 22 80 443 ];
      };
  }
