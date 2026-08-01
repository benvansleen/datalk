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
          })
        ];
      };
    };
}
