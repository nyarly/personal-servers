let
  accessKeyId = "jdl";
  region = "us-west-2";


  ec2 = { resources, ... }:
  {
    deployment = {
      targetEnv = "ec2";
      ec2 = {
        inherit region accessKeyId;
        instanceType = "t2.micro";
        keyPair = resources.ec2KeyPairs.jdl;
        elasticIPv4 = "52.40.201.163";
        securityGroups = with resources.ec2SecurityGroups; [
          serveSSH.name
          serveDNS.name
          serveHTTP.name
          serveMisc.name
        ];
        blockDeviceMapping = {
          "/dev/xvdf" = {
            deleteOnTermination = false;
            size = 20;
          };
        };
      };
    };
  };
in
  {
    webserver = ec2;
    resources = {
      ec2KeyPairs.jdl = {
        inherit region accessKeyId;
      };

      /*
      Published in DNS. No longer NixOps' to delete.
      elasticIPs = {
        web = {
          inherit region accessKeyId;
        };
      };
      */

      ec2SecurityGroups = {
        serveSSH = {...}: {
          inherit region accessKeyId;
          rules = [{
            sourceIp = "0.0.0.0/0";
            fromPort = 0;
            toPort = 22;
          }];
        };

        serveDNS = {...}: {
          inherit region accessKeyId;
          rules = [
            {
              sourceIp = "0.0.0.0/0";
              fromPort = 0;
              protocol = "udp";
              toPort = 53;
            }
            {
              sourceIp = "0.0.0.0/0";
              fromPort = 0;
              protocol = "tcp";
              toPort = 53;
            }
          ];
        };

        serveHTTP = {...}: {
          inherit region accessKeyId;
          rules = [{
            sourceIp = "0.0.0.0/0";
            fromPort = 0;
            toPort = 80;
          }
          {
            sourceIp = "0.0.0.0/0";
            fromPort = 0;
            toPort = 443;
          }];
        };

        serveMisc = {...}: {
          inherit region accessKeyId;
          rules = [{
            sourceIp = "0.0.0.0/0";
            fromPort = 0;
            toPort = 5000;
          }
          {
            sourceIp = "0.0.0.0/0";
            fromPort = 0;
            toPort = 53589;
          }];
        };
      };
    };
  }
