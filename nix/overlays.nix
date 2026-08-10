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
                version = "0.1.0";
              in
              final.rustPlatform.buildRustPackage {
                pname = "celld";
                inherit version;
                src = final.fetchFromGitHub {
                  owner = "denoland";
                  repo = "celld";
                  rev = "v${version}";
                  hash = "sha256-Iew3/ugHftS1Ui6tiVRPj3FguYmGx9vwMfS6pY00CWQ=";
                };
                cargoHash = "sha256-g3b2gFeHkqlUVLydWs/HiieK2dtw7BC2o9eNwCGAHT0=";
                RUSTY_V8_ARCHIVE = final.fetchurl {
                  url = "https://github.com/denoland/rusty_v8/releases/download/v152.0.0/librusty_v8_release_x86_64-unknown-linux-gnu.a.gz";
                  hash = "sha256-nS++EYCa01QTDVw3gmNqE89YaNptLAAtqIJ7hT01x+w=";
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
