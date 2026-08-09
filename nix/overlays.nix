{ inputs, ... }:

{
  perSystem =
    { system, ... }:
    {
      _module.args.pkgs = import inputs.nixpkgs {
        inherit system;
        overlays = [
          (final: prev: {
            lisette = prev.lisette.overrideAttrs (
              new: old: {
                version = "0.10.0";
                src = old.src.overrideAttrs {
                  tag = "lisette-v${new.version}";
                  hash = "sha256-WqvBONVy2/JMFAUTsnCEAE5c4qA/1vy+MsKkBQKJMpg=";
                };
                cargoDeps = final.rustPlatform.fetchCargoVendor {
                  inherit (new) src;
                  hash = "sha256-9TqoXzrUyb5AK/9EHw8H35N2LjoZWwCtwHp4Sp+gqsQ=";
                };
                checkFlags = (old.checkFlags or [ ]) ++ [
                  "--skip=e2e_learn"
                ];
              }
            );

            terraform-providers = prev.terraform-providers // {
              alekc_kubectl = prev.terraform-providers.mkProvider {
                owner = "alekc";
                repo = "terraform-provider-kubectl";
                rev = "v2.4.1";
                hash = "sha256-Lq17X+9TQbDNqZbT3OGooa9zwpRCip1gvWpyNmqPZ08=";
                vendorHash = "sha256-+i5snU9JvT8iQPdm61IHvV/Z/eFJiT5fbKldLNhaYsM=";
                homepage = "https://registry.terraform.io/providers/alekc/kubectl";
                spdx = "MPL-2.0";
              };
            };
          })
        ];
      };
    };
}
