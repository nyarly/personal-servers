let
  acmeRoot = "/var/run/acme-challenges";

  ports = {
    wagthepig = 3000;
  };

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
      keys = import ./webserver-keys.nix;
      pubIP = config.networking.publicIPv4;
      blog = pkgs.callPackage ./packages/blog/default.nix {};
      wagthepig = pkgs.callPackage ./packages/wagthepig/default.nix {
        masterKey = keys.wagthepig.text;
      };
    in
    {
      imports = [
        ./modules/static-site.nix
        ./modules/app-proxy.nix
        ./modules/rails-app.nix
      ];

      environment.systemPackages = with pkgs; [ neovim fish ];

      deployment.keys = keys;

      fileSystems = {
        "/var/lib" = {
          device = "/dev/xvdf";
          fsType = "ext4";
          # autoFormat = true;
          autoResize = true;
        };
      };

      services = {
        wagthepig = {
          enable = true;
          package = wagthepig;

          # Should come from a "appserver bridge" module
          protocol = "http";
          listenAddress = "localhost";
          listenPort = ports.wagthepig;

          database = {
            adapter = "postgresql";
            database = "wagthepig";
            host = "localhost";
            username = "wagthepig";
            password = ""; # local trust
            encoding = "utf8";
            pool = 5;
          };

          secretKeyBase = "testsecret";
        };

        exim = {
          enable = true;
          config = ''
            tls_advertise_hosts =
            acl_smtp_rcpt = local_relay

            begin acl
            local_relay:
              accept hosts = 127.0.0.1 : ::1 : localhost

            begin routers
            dnslookup:
              driver = dnslookup
              domains = ! localhost
              transport = remote_smtp
              ignore_target_hosts = 0.0.0.0 : 127.0.0.0/8
              no_more

            begin transports
            remote_smtp:
              driver = smtp
              hosts_try_prdr = *

            begin retry
            *   *   F,2h,15m; G,16h,1h,1.5; F,4d,6h
          '';
        };

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
          package = pkgs.postgresql_10;
          authentication = ''
            local   all             all                                     trust
            host    all             all             127.0.0.1/32            trust
            host    all             all             ::1/128                 trust
            # Allow replication connections from localhost, by a user with the
            # replication privilege.
            local   replication     all                                     trust
            host    replication     all             127.0.0.1/32            trust
            host    replication     all             ::1/128                 trust
          '';
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
                    2019042901 ; serial
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
                tasks          CNAME  @
                @          IN  TXT    "v=spf1 +a +mx ip4:${pubIP} -all"
                @          IN  TXT    "google-site-verification=PdMCpmcPxMhcuIeabkjGH2AcasilKqCatBs98MxkImk"
              '';
            };
          };

        };

        taskserver = {
          enable = true;
          fqdn = "tasks.madhelm.net";
          listenHost = "0.0.0.0";
          organisations = {
            madhelm.users = [ "judson" ];
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

      appProxy = {
        inherit acmeRoot;
        sites = {
          "wagthepig.com" = {
            backendPort = ports.wagthepig;
            staticBase = wagthepig + "/share/wagthepig/public";
            staticLocations = [ "assets" "system" ];
          };
        };
      };

      networking.firewall = {
        allowedTCPPorts = [ 22 53 80 443 ];
        allowedUDPPorts = [ 53 ];
      };

      users.users.root.openssh.authorizedKeys.keyFiles = [
        ssh-keys/root-1.pub
        ssh-keys/root-2.pub
      ];
    };
  }
