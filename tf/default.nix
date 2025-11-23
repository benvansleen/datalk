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
    };
  };

  output = {
    instance_ip = {
      description = "public ip of deployed instance";
      value = "\${aws_instance.ui.public_ip}";
    };
  };
}
