{ self, ... }:

{
  flake.modules.infra.production-datasets =
    { pkgs, ... }:
    let
      gsutil = "${pkgs.google-cloud-sdk}/bin/gsutil";

      ## relative to .terraform/production/
      datasetsDir = "../../datasets";

      ## TODO: don't hardcode these
      datasetFiles = [
        "cfbd/cfbd_2025_games.csv"
        "cfbd/cfbd_2025_lines.csv"
      ];
    in
    {
      resource = {
        google_project_service.storage = {
          inherit (self.gcloud) project;
          service = "storage.googleapis.com";
        };

        google_storage_bucket.datalk-datasets = {
          inherit (self.gcloud) project;
          name = "datalk-datasets";
          location = self.gcloud.region;
          uniform_bucket_level_access = true;
          depends_on = [
            "google_project_service.storage"
          ];
        };

        google_service_account.datasets = {
          inherit (self.gcloud) project;
          account_id = "datalk-datasets";
          depends_on = [
            "google_project_service.storage"
          ];
        };
        google_service_account_iam_member.datasets_workload_identity = {
          service_account_id = /* terraform */ "\${google_service_account.datasets.name}";
          role = "roles/iam.workloadIdentityUser";
          member = "serviceAccount:${self.gcloud.project}.svc.id.goog[datalk-execution/datalk-worker]";
          depends_on = [
            "google_container_cluster.${self.gcloud.name}"
            "google_service_account.datasets"
          ];
        };
        google_project_iam_member.datasets_object_viewer = {
          inherit (self.gcloud) project;
          role = "roles/storage.objectViewer";
          member = "serviceAccount:\${google_service_account.datasets.email}";
          depends_on = [
            "google_service_account.datasets"
          ];
        };

        terraform_data.push_datasets = {
          input.files_sha = map (f: "\${filesha256(\"${datasetsDir}/${f}\")}") datasetFiles;
          triggers_replace.files_sha = map (f: "\${filesha256(\"${datasetsDir}/${f}\")}") datasetFiles;
          depends_on = [
            "google_storage_bucket.datalk-datasets"
          ];
          provisioner.local-exec.command = /* sh */ ''
            set -euo pipefail
            if [ ! -d "${datasetsDir}" ]; then
              echo "missing ${datasetsDir}" >&2
              exit 1
            fi
            ${gsutil} -m rsync -r "${datasetsDir}/" gs://datalk-datasets/
          '';
        };
      };
    };
}
