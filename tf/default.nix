{ domain }:
{
  config,
  lib,
  ...
}:

{
  provider.aws = {
    shared_credentials_files = [ "./.aws/credentials" ];
    region = "us-east-1";
  };

  provider.cloudflare = { };

  data.aws_ami.nixos_arm64 = {
    owners = [ "427812963091" ];
    most_recent = true;
    filter = [
      {
        name = "name";
        values = [ "nixos/25.05*" ];
      }
      {
        name = "architecture";
        values = [ "x86_64" ];
      }
    ];
  };

  data.cloudflare_zone.personal = {
    filter = {
      name = "vansleen.dev";
    };
  };

  resource = {
    aws_key_pair.ssh_key = {
      key_name = "datalk";
      public_key = lib.fileContents ./aws.pub;
    };

    aws_instance.ui = {
      inherit (config.resource.aws_key_pair.ssh_key) key_name;
      ami = "\${data.aws_ami.nixos_arm64.id}";
      instance_type = "t2.micro";
      vpc_security_group_ids = [ "\${aws_security_group.ui.id}" ];
      associate_public_ip_address = true;

      root_block_device = {
        volume_size = 32;
        volume_type = "gp3";
        encrypted = true;
      };

      tags = {
        Name = "datalk ui";
        Terraform = "true";
        terranix = "true";
      };
    };

    aws_security_group.ui = {
      description = "Allow ssh, http, and https traffic";
    };

    aws_security_group_rule = {
      allow_ssh = {
        security_group_id = "\${aws_security_group.ui.id}";
        type = "ingress";
        from_port = 22;
        to_port = 22;
        protocol = "tcp";
        cidr_blocks = [ "0.0.0.0/0" ];
      };
      allow_http = {
        security_group_id = "\${aws_security_group.ui.id}";
        type = "ingress";
        from_port = 80;
        to_port = 80;
        protocol = "tcp";
        cidr_blocks = [ "0.0.0.0/0" ];
      };
      allow_https = {
        security_group_id = "\${aws_security_group.ui.id}";
        type = "ingress";
        from_port = 443;
        to_port = 443;
        protocol = "tcp";
        cidr_blocks = [ "0.0.0.0/0" ];
      };
      allow_pg = {
        security_group_id = "\${aws_security_group.ui.id}";
        type = "ingress";
        from_port = 5432;
        to_port = 5432;
        protocol = "tcp";
        cidr_blocks = [ "0.0.0.0/0" ];
      };
      allow_egress = {
        security_group_id = "\${aws_security_group.ui.id}";
        type = "egress";
        from_port = 0;
        to_port = 0;
        protocol = "-1";
        cidr_blocks = [ "0.0.0.0/0" ];
      };
    };

    cloudflare_dns_record.ui = {
      zone_id = "\${data.cloudflare_zone.personal.id}";
      name = domain;
      type = "A";
      content = "\${aws_instance.ui.public_ip}";
      ttl = 1;
      proxied = false; # TODO: probably should proxy this application
    };
  };

  output = {
    instance_ip = {
      description = "public ip of deployed instance";
      value = "\${aws_instance.ui.public_ip}";
    };
  };
}
