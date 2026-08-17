_:

{
  flake.modules.infra.nixidy-kubectl =
    { config, lib, ... }:
    let
      inherit (builtins)
        attrNames
        attrValues
        filter
        isAttrs
        isList
        length
        ;
    in
    {
      options.nixidyKubectl = with lib; {
        env = mkOption {
          type = types.anything;
          description = "The nixidy environment (legacyPackages.nixidyEnvs.<system>.<env>) whose parsed objects become kubectl_manifest resources.";
        };
        wait = mkOption {
          type = types.bool;
          default = true;
          description = "Whether kubectl_manifest should wait for workloads to complete rollout (wait_for_rollout) before returning.";
        };
        serverSideApplyForCRDs = mkOption {
          type = types.bool;
          default = true;
          description = "Apply CustomResourceDefinition manifests with server-side apply and force-conflicts.";
        };
        extraDependsOn = mkOption {
          type = types.listOf types.str;
          default = [ ];
          description = "Additional Terraform resource references that every manifest depends on.";
        };
      };

      config =
        let
          cfg = config.nixidyKubectl;
          inherit (cfg) env;

          objSets = env.config.build._transformedObjects;
          appOfApps = env.config.nixidy.appOfApps.name;

          # Only the actual work apps are deployed by `nixidy apply`; internal
          # (__-prefixed) apps and the ArgoCD app-of-apps are control plane and
          # must not become kubectl_manifest resources.
          apps = filter (n: !(lib.hasPrefix "__" n) && n != appOfApps) (attrNames objSets);

          idOf =
            obj:
            "${obj.apiVersion or ""}/${obj.kind or ""}/${obj.metadata.namespace or ""}/${obj.metadata.name or ""}";

          # Collapse objects that share a Kubernetes identity (e.g. the `datalk`
          # Namespace created by several apps), asserting duplicates are byte-for-
          # byte identical so dropping them is safe.
          deduped = lib.foldl' (
            acc: app:
            lib.foldl' (
              acc': obj:
              let
                id = idOf obj;
                entry = { inherit app obj; };
              in
              if builtins.hasAttr id acc' then
                assert builtins.toJSON acc'.${id}.obj == builtins.toJSON obj;
                acc'
              else
                acc' // { ${id} = entry; }
            ) acc objSets.${app}
          ) { } apps;

          objects = attrValues deduped;

          isCrd = obj: obj.kind == "CustomResourceDefinition";
          isNamespace = obj: obj.kind == "Namespace";

          sanitize = s: lib.strings.toLower (lib.replaceStrings [ "." "/" ":" "_" ] [ "-" "-" "-" "-" ] s);
          keyOf =
            { app, obj }:
            "${app}-${obj.kind or ""}-${obj.metadata.name or ""}-${obj.metadata.namespace or "cluster"}";

          crdKeys = map (r: "kubectl_manifest.${sanitize (keyOf r)}") (filter (r: isCrd r.obj) objects);

          # name of a Namespace object -> its kubectl_manifest resource
          nsRefs = lib.listToAttrs (
            map (r: lib.nameValuePair r.obj.metadata.name "kubectl_manifest.${sanitize (keyOf r)}") (
              filter (r: isNamespace r.obj) objects
            )
          );

          nsDep =
            obj:
            let
              name = obj.metadata.namespace or null;
            in
            if name != null && builtins.hasAttr name nsRefs then [ nsRefs.${name} ] else [ ];

          dependsOn =
            obj: if (isCrd obj) || (isNamespace obj) then [ ] else (nsDep obj) ++ crdKeys ++ cfg.extraDependsOn;

          stripNulls =
            value:
            if isAttrs value then
              lib.filterAttrs (_: v: v != null) (lib.mapAttrs (_: stripNulls) value)
            else if isList value then
              map stripNulls value
            else
              value;

          mkResource =
            { obj, ... }:
            let
              flags = lib.optionalAttrs (cfg.serverSideApplyForCRDs && isCrd obj) {
                server_side_apply = true;
                force_conflicts = true;
              };
              deps = lib.optionalAttrs (!(isCrd obj) && !(isNamespace obj)) {
                depends_on = dependsOn obj;
              };
              # OpenTofu parses string values in .tf.json as HCL templates, so
              # escape template sequences to keep arbitrary YAML content
              # byte-for-byte (unused `${` would be read as a reference).
              yaml_body = lib.replaceStrings [ "\${" "%{" ] [ "\$\${" "%%{" ] (builtins.toJSON (stripNulls obj));
            in
            {
              inherit yaml_body;
              wait_for_rollout = cfg.wait;
            }
            // flags
            // deps;

          resources = lib.listToAttrs (
            map (r: lib.nameValuePair (sanitize (keyOf r)) (mkResource r)) objects
          );

          objCount = length objects;
          keyCount = length (attrNames resources);
          allNamespacesPresent = lib.all (
            r:
            (r.obj.metadata.namespace or null) == null
            || isNamespace r.obj
            || builtins.hasAttr r.obj.metadata.namespace nsRefs
          ) objects;

          # Kept lazy: forcing it only when `resource.kubectl_manifest` is
          # read, so reading `config.nixidyKubectl` never happens while the
          # `nixidyKubectl` option itself is being merged (which would recurse).
          manifests =
            lib.throwIfNot (keyCount == objCount)
              "nixidy-kubectl: kubectl_manifest resource keys are not unique (${toString objCount} objects, ${toString keyCount} keys)"
              (
                lib.throwIfNot allNamespacesPresent
                  "nixidy-kubectl: a namespaced resource has no matching Namespace object; set createNamespace for that application"
                  resources
              );
        in
        {
          resource.kubectl_manifest = manifests;
        };
    };
}
