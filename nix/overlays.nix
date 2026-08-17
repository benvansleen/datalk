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
                version = "0.11.3";
                src = old.src.overrideAttrs {
                  tag = "lisette-v${new.version}";
                  hash = "sha256-zoYvrr9h0XvfXudVaf++LhKhTXz1KfaOHq+dy+EAyyU=";
                };
                cargoDeps = final.rustPlatform.fetchCargoVendor {
                  inherit (new) src;
                  hash = "sha256-Zgu3/VJRciwvufL+iwEwVL9h5hCLssVr1oT4H/7PQ0c=";
                };
                patches = (old.patches or [ ]) ++ [ ./patches/lisette-otel-zero-safe.patch ];
                nativeBuildInputs = (old.nativeBuildInputs or [ ]) ++ [ final.makeWrapper ];
                postInstall = (old.postInstall or "") + /* sh */ ''
                  mkdir -p "$out/share/lisette"
                  cp bindgen/bindgen.external.json "$out/share/lisette/bindgen.external.json"
                  wrapProgram "$out/bin/lis" \
                    --set LISETTE_BINDGEN_CONFIG "$out/share/lisette/bindgen.external.json"
                '';
                checkFlags = final.lib.flatten [
                  (old.checkFlags or [ ])
                  (map (test: "--skip=${test}") [
                    "e2e_learn"
                    "an_executable_script_runs_through_its_shebang"
                  ])
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
