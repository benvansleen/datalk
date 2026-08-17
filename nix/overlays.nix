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

            celld =
              let
                version = "0.2.1";
              in
              final.rustPlatform.buildRustPackage {
                pname = "celld";
                inherit version;
                src = final.fetchFromGitHub {
                  owner = "denoland";
                  repo = "celld";
                  rev = "v${version}";
                  hash = "sha256-BJo5TbRrHvmJKf4iBIcNsYf8M9us50/Tr3rMtu08M1o=";
                };
                cargoHash = "sha256-ov1Cvi6LzJDqeZ8kUUNsYY5dEQ84/D1uXWH0yT/Vz+o=";
                RUSTY_V8_ARCHIVE = final.fetchurl {
                  url = "https://github.com/denoland/rusty_v8/releases/download/v152.1.0/librusty_v8_release_x86_64-unknown-linux-gnu.a.gz";
                  hash = "sha256-VrPZwer2AINF3rP3yWqtIhfpHGXYt4v+VQ9Sw6jbtQ8=";
                };

                nativeBuildInputs = with final; [
                  curl
                  pkg-config
                  python3
                ];
                buildInputs = with final; [ openssl ];
                cargoBuildFlags = [
                  "-p"
                  "celld"
                ];

                installPhase = /* sh */ ''
                  install -Dm755 target/*/release/celld $out/bin/celld
                '';
              };

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
