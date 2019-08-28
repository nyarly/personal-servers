let
  acmeRoot = "/var/run/acme-challenges";

  ports = {
    wagthepig = 3000;
  };

  buddyNSServers = [
    "108.61.224.67 NOKEY"
    "116.203.6.3 NOKEY"
    "107.191.99.111 NOKEY"
    "185.22.172.112 NOKEY"
    "103.6.87.125 NOKEY"
    "192.184.93.99 NOKEY"
    "119.252.20.56 NOKEY"
    "31.220.30.73 NOKEY"
    "185.34.136.178 NOKEY"
    "185.136.176.247 NOKEY"
    "45.77.29.133 NOKEY"
    "116.203.0.64 NOKEY"
    "167.88.161.228 NOKEY"
    "199.195.249.208 NOKEY"
    "104.244.78.122 NOKEY"
    "2001:19f0:6400:8642::3 NOKEY"
    "2a01:4f8:1c0c:8115::3 NOKEY"
    "2604:180:2:4cf::3 NOKEY"
    "2a00:1838:20:2::cd5e:68e9 NOKEY"
    "2403:2500:4000::f3e NOKEY"
    "2604:180:1:92a::3 NOKEY"
    "2401:1400:1:1201::1:7853:1a5 NOKEY"
    "2a04:bdc7:100:1b::3 NOKEY"
    "2a00:dcc7:d3ff:88b2::1 NOKEY"
    "2a06:fdc0:fade:2f7::1 NOKEY"
    "2001:19f0:7001:381::3 NOKEY"
    "2a01:4f8:1c0c:8122::3 NOKEY"
    "2605:6400:20:d5e::3 NOKEY"
    "2605:6400:10:65::3 NOKEY"
    "2605:6400:30:fd6e::3 NOKEY"
  ];
in
  {
    network.description = "Web server";

    webserver = { lib, config, pkgs, ... }:
    let
      keys = import ./secrets/webserver-keys.nix;
      pubIP = config.networking.publicIPv4;
      blog = pkgs.callPackage ./packages/blog/default.nix {};
      wagthepig = pkgs.callPackage ./packages/wagthepig/default.nix {
        masterKey = keys.wagthepig.text;
      };
      wrapQuotes = str: ''"${str}"'';
      dnsLines = path: lib.strings.concatStringsSep "\n" (map wrapQuotes (lib.strings.splitString "\n" (builtins.readFile path)));
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
            keep_environment = # suppress warning about purged environment
            # use set_environment if there are vars we want

            tls_advertise_hosts =
            acl_smtp_rcpt = local_relay

            domainlist local_domains = <; 127.0.0.1 ; ::1 ; localhost
            hostlist local_hosts = <; 127.0.0.1 ; ::1 ; localhost

            trusted_users = wagthepig

            begin acl
            local_relay:
              accept hosts = +local_hosts

            begin routers
            dnslookup:
              driver = dnslookup
              domains = ! +local_domains
              transport = remote_smtp
              ignore_target_hosts = <; 0.0.0.0 ; 127.0.0.0/8 ; ::1
              no_more

            begin transports
            remote_smtp:
              driver = smtp
              hosts_try_prdr = *
              dkim_domain = ''${lc:''${domain:''$h_from:}}
              dkim_selector = dkim
              dkim_private_key = /var/spool/exim/dkim.key
              dkim_strict = true
              dkim_timestamps = 1209600

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
                    2019052003 ; serial
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
                _domainkey IN  TXT    "o=-\;"
                dkim._domainkey IN  TXT ("v=DKIM1\; t=y\; k=rsa\; p="
                  ${dnsLines secrets/dkim.cert.bare}
                  )
                @          IN  TXT    "v=DMARC1;p=reject;sp=reject;ruf=mailto:nyarly@gmail.com"
                _dmarc     IN  TXT    "v=DMARC1;p=reject;sp=reject;ruf=mailto:nyarly@gmail.com"
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

      systemd.services.exim = {
        after = ["dkim-key.service"];
        wants = ["dkim-key.service"];
        preStart = ''
          install -o exim -g exim -m 0400 /run/keys/dkim /var/spool/exim/dkim.key
          '';
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

      users.users = {
        wagthepig.extraGroups = [ "exim" ];

        root.openssh.authorizedKeys.keyFiles = [
          ssh-keys/root-1.pub
          ssh-keys/root-2.pub
        ];
      };
    };
  }
