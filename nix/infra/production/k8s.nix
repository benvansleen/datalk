{ self, ... }:

{
  flake.modules.infra.production-k8s =
    let
      inherit (self.gcloud) name;
    in
    {
      data.google_compute_network.default = {
        inherit (self.gcloud) project;
        name = "default";
      };
      resource = {
        google_project_service = {
          artifactregistry = {
            inherit (self.gcloud) project;
            service = "artifactregistry.googleapis.com";
          };
          compute = {
            inherit (self.gcloud) project;
            service = "compute.googleapis.com";
          };
          container = {
            inherit (self.gcloud) project;
            service = "container.googleapis.com";
          };
        };

        google_service_account.gke_nodes = {
          inherit (self.gcloud) project;
          account_id = "${name}-gke-nodes";
        };

        google_compute_subnetwork.datalk = {
          inherit (self.gcloud) project;
          name = "datalk";
          region = self.gcloud.region;
          network = /* terraform */ "\${data.google_compute_network.default.self_link}";
          ip_cidr_range = "10.0.0.0/20";
          private_ip_google_access = true;

          depends_on = [
            "google_project_service.compute"
          ];
        };

        google_artifact_registry_repository.${name} = {
          inherit (self.gcloud) project;
          location = self.gcloud.region;
          repository_id = "${name}";
          format = "DOCKER";

          depends_on = [
            "google_project_service.artifactregistry"
          ];
        };
        google_project_iam_member.gke_nodes_artifact_reader = {
          inherit (self.gcloud) project;
          role = "roles/artifactregistry.reader";
          member = /* terraform */ "serviceAccount:\${google_service_account.gke_nodes.email}";
        };

        google_container_cluster.${name} = {
          inherit name;
          inherit (self.gcloud) project;
          location = self.gcloud.zone;

          # manage node pools separately
          remove_default_node_pool = true;
          initial_node_count = 1;

          deletion_protection = false;

          networking_mode = "VPC_NATIVE";
          subnetwork = /* terraform */ "\${google_compute_subnetwork.datalk.name}";

          addons_config.gcs_fuse_csi_driver_config.enabled = true;

          release_channel.channel = "REGULAR";

          workload_identity_config.workload_pool = "${self.gcloud.project}.svc.id.goog";

          depends_on = [
            "google_project_service.compute"
            "google_project_service.container"
            "google_compute_subnetwork.datalk"
          ];
        };

        google_container_node_pool."${name}_spot" = {
          name = "${name}-spot";
          inherit (self.gcloud) project;
          location = self.gcloud.zone;
          cluster = "\${google_container_cluster.${name}.name}";

          node_count = 3;

          node_config = {
            machine_type = "e2-medium";
            spot = true;
            disk_size_gb = 20;
            disk_type = "pd-standard";

            service_account = "\${google_service_account.gke_nodes.email}";
            oauth_scopes = [
              "https://www.googleapis.com/auth/cloud-platform"
            ];

            workload_metadata_config.mode = "GKE_METADATA";

            labels = {
              workload = name;
            };

            tags = [ "${name}-gke" ];
          };
        };
      };
    };
}
