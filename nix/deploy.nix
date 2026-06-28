{ self, ... }:

{
  perSystem =
    {
      self',
      pkgs,
      lib,
      ...
    }:
    {
      apps = {
        deploy = {
          type = "app";
          program =
            with self'.apps;
            (pkgs.writeShellScript "deploy" /* sh */ ''
              ${tf-apply.program} --auto-approve
              ${populate-prod-secrets.program}
              ${push-images.program}
              ${lib.getExe pkgs.google-cloud-sdk} container clusters \
                get-credentials ${self.gcloud.name} \
                --zone ${self.gcloud.zone}
              ${lib.getExe self'.packages.nixidy} apply .#default
            '').outPath;
        };

        deploy-local = {
          type = "app";
          program =
            with self'.apps;
            (pkgs.writeShellScript "deploy-local" /* sh */ ''
              ${tf-apply-local.program} --auto-approve
              ${push-images-local.program}
              ${lib.getExe pkgs.kubectl} config use-config k3d-${self.gcloud.name}-local
              ${lib.getExe self'.packages.nixidy} apply .#local
            '').outPath;
        };
      };
    };
}
