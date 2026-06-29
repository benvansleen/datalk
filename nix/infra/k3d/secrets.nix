{
  flake.modules.infra.k3d-secrets =
    { pkgs, lib, ... }:
    {
      resource.terraform_data.local_secrets =
        let
          ## relative to .terraform/local/
          secretsFile = "../../.env.local.k8s";
          kubectl = lib.getExe pkgs.kubectl;
        in
        {
          input.env_file_sha = "\${filesha256(\"${secretsFile}\")}";
          triggers_replace.env_file_sha = "\${filesha256(\"${secretsFile}\")}";
          depends_on = [
            "terraform_data.k3d_cluster"
          ];
          provisioner.local-exec.command = /* sh */ ''
            set -euo pipefail

            if [ ! -f ${secretsFile} ]; then
              echo "missing ${secretsFile}" >&2
              exit 1
            fi

            ${kubectl} create namespace datalk \
              --dry-run=client \
              -o yaml \
              | ${kubectl} apply -f -
            ${kubectl} create secret generic datalk-runtime \
              -n datalk \
              --from-env-file=${secretsFile} \
              --dry-run=client \
              -o yaml \
              | ${kubectl} apply -f -
          '';
        };
    };
}
