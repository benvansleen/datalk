{ self, ... }:

{
  flake.modules.infra.k8s = {
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
        account_id = "datalk-gke-nodes";
      };

      google_artifact_registry_repository.datalk = {
        location = self.gcloud.region;
        repository_id = "datalk";
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

      google_container_cluster.datalk = {
        name = "datalk";
        location = self.gcloud.zone;

        # manage node pools separately
        remove_default_node_pool = true;
        initial_node_count = 1;

        deletion_protection = false;

        networking_mode = "VPC_NATIVE";

        release_channel.channel = "REGULAR";

        workload_identity_config.workload_pool = "datalk-499418.svc.id.goog";

        depends_on = [
          "google_project_service.compute"
          "google_project_service.container"
        ];
      };

      google_container_node_pool.datalk_spot = {
        name = "datalk-spot";
        location = self.gcloud.zone;
        cluster = "\${google_container_cluster.datalk.name}";

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
            workload = "datalk";
          };

          tags = [ "datalk-gke" ];
        };
      };
    };
  };
}
