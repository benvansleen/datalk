{ self, ... }:

{
  flake.gcloud = {
    project = "datalk-499418";
    region = "us-east4";
    zone = "us-east4-a";
  };

  flake.modules.infra.providers = {
    # gcloud container clusters get-credentials datalk --zone us-east4-a
    provider.google = {
      inherit (self.gcloud) project region zone;
    };
  };
}
