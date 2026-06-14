{
  flake.modules.infra.k8s =
    let
      project = "datalk-499418";
      region = "us-east4";
      zone = "us-east4-a";
    in
    {

      # gcloud container clusters get-credentials datalk --zone us-east4-a
      provider.google = {
        inherit project region zone;
      };

      resource = {
        google_project_service = {
          artifactregistry = {
            inherit project;
            service = "artifactregistry.googleapis.com";
          };
          compute = {
            inherit project;
            service = "compute.googleapis.com";
          };
          container = {
            inherit project;
            service = "container.googleapis.com";
          };
        };

        google_service_account.gke_nodes = {
          account_id = "datalk-gke-nodes";
        };

        google_artifact_registry_repository.datalk = {
          location = region;
          repository_id = "datalk";
          format = "DOCKER";

          depends_on = [
            "google_project_service.artifactregistry"
          ];
        };

        google_container_cluster.datalk = {
          name = "datalk";
          location = zone;

          # manage node pools separately
          remove_default_node_pool = true;
          initial_node_count = 1;

          deletion_protection = false;

          networking_mode = "VPC_NATIVE";

          release_channel.channel = "REGULAR";

          depends_on = [
            "google_project_service.compute"
            "google_project_service.container"
          ];
        };

        google_container_node_pool.datalk_spot = {
          name = "datalk-spot";
          location = zone;
          cluster = "\${google_container_cluster.datalk.name}";

          node_count = 1;

          node_config = {
            machine_type = "e2-medium";
            spot = true;
            disk_size_gb = 20;
            disk_type = "pd-standard";

            service_account = "\${google_service_account.gke_nodes.email}";
            oauth_scopes = [
              "https://www.googleapis.com/auth/cloud-platform"
            ];

            labels = {
              workload = "datalk";
            };

            tags = [ "datalk-gke" ];
          };
        };
      };
    };
}
