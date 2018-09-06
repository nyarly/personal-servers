let
  blog = import ./packages/blog/default.nix {};
  acmeRoot = "/var/run/acme-challenges";

  buddyNSServers = [
    "173.244.206.26 NOKEY"
    "88.198.106.11 NOKEY"
    "108.61.224.67 NOKEY"
    "103.6.87.125 NOKEY"
    "185.136.176.247 NOKEY"

    "2607:f0d0:1001:d::100 NOKEY"
    "2a01:4f8:d12:d01::10:100 NOKEY"
    "2001:19f0:6400:8642::3 NOKEY"
    "2403:2500:4000::f3e NOKEY"
    "2a06:fdc0:fade:2f7::1 NOKEY"
  ];
in
  {
    network.description = "Web server";

    webserver = {  config, pkgs, ... }:
    let
      pubIP = config.networking.publicIPv4;
    in
    {
      imports = [ ./module/static-site.nix ];

      environment.systemPackages = with pkgs; [ neovim fish ];

      fileSystems = {
        "/var/lib" = {
          device = "/dev/xvdf";
          fsType = "ext4";
          # autoFormat = true;
          autoResize = true;
        };
      };

      services = {
        fail2ban = {
          enable = true;
          jails = {
            ssh-aggressive =
            ''
            filter   = sshd[mode=aggressive]
            action   = iptables[name=SSH, port=ssh, protocol=tcp]
            logpath  = /var/log/warn
            maxretry = 5
            '';
          };
        };

        postgresql = {
          enable = true;
          package = pkgs.postgresql100;
        };

        httpd = {
          enable = true;
          adminAddr = "nyarly@gmail.com";
        };

        nsd = {
          enable = true;

          interfaces = []; # wildcard interface (?)
          zones = {
            "staticweb" = {
              provideXFR = buddyNSServers;
              notify = buddyNSServers;
              # rrlWhitelist = ["all"];

              data = ''
                $TTL 18000  ; 5 hours
                @ IN SOA  ns1.lrdesign.com. nyarly.gmail.com. (
                    2018052701 ; serial
                    10800      ; refresh (3 hours)
                    3600       ; retry (1 hour)
                    18000      ; expire (5 hours)
                    18000      ; minimum (5 hours)
                )
                               NS       ns1.lrdesign.com.
                               NS       ns2.lrdesign.com.
                               NS       ns3.lrdesign.com.
                               NS       ns4.lrdesign.com.
                               NS       ns5.lrdesign.com.

                               A        ${pubIP}
                               RP     @ nyarly.gmail.com.
                blog           CNAME  @
                gems           CNAME  @
                repos          CNAME  @
                www            CNAME  @
              '';
            };
          };

        };
      };

      staticWeb = {
        inherit acmeRoot;
        sites = {
          "judsonlester.info" = { docRoot = blog; };
          "madhelm.net"       = { docRoot = blog; };
        };
      };

      networking.firewall = {
        allowedTCPPorts = [ 22 53 80 443 ];
        allowedUDPPorts = [ 53 ];
      };
    };
  }
