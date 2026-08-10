# This file was generated with nixidy resource generator, do not edit.
{
  lib,
  options,
  config,
  ...
}:

with lib;

let
  hasAttrNotNull = attr: set: hasAttr attr set && set.${attr} != null;

  attrsToList =
    values:
    if values != null then
      sort (
        a: b:
        if (hasAttrNotNull "_priority" a && hasAttrNotNull "_priority" b) then
          a._priority < b._priority
        else
          false
      ) (mapAttrsToList (n: v: v) values)
    else
      values;

  getDefaults =
    resource: group: version: kind:
    catAttrs "default" (
      filter (
        default:
        (default.resource == null || default.resource == resource)
        && (default.group == null || default.group == group)
        && (default.version == null || default.version == version)
        && (default.kind == null || default.kind == kind)
      ) config.defaults
    );

  types = lib.types // rec {
    str = mkOptionType {
      name = "str";
      description = "string";
      check = isString;
      merge = mergeEqualOption;
    };

    # Either value of type `finalType` or `coercedType`, the latter is
    # converted to `finalType` using `coerceFunc`.
    coercedTo =
      coercedType: coerceFunc: finalType:
      mkOptionType rec {
        inherit (finalType) getSubOptions getSubModules;

        name = "coercedTo";
        description = "${finalType.description} or ${coercedType.description}";
        check = x: finalType.check x || coercedType.check x;
        merge =
          loc: defs:
          let
            coerceVal =
              val:
              if finalType.check val then
                val
              else
                let
                  coerced = coerceFunc val;
                in
                assert finalType.check coerced;
                coerced;

          in
          finalType.merge loc (map (def: def // { value = coerceVal def.value; }) defs);
        substSubModules = m: coercedTo coercedType coerceFunc (finalType.substSubModules m);
        typeMerge = t1: t2: null;
        functor = (defaultFunctor name) // {
          wrapped = finalType;
        };
      };
  };

  mkOptionDefault = mkOverride 1001;

  mergeValuesByKey =
    attrMergeKey: listMergeKeys: values:
    listToAttrs (
      imap0 (
        i: value:
        nameValuePair (
          if hasAttr attrMergeKey value then
            if isAttrs value.${attrMergeKey} then
              toString value.${attrMergeKey}.content
            else
              (toString value.${attrMergeKey})
          else
            # generate merge key for list elements if it's not present
            "__kubenix_list_merge_key_"
            + (concatStringsSep "" (
              map (
                key: if isAttrs value.${key} then toString value.${key}.content else (toString value.${key})
              ) listMergeKeys
            ))
        ) (value // { _priority = i; })
      ) values
    );

  submoduleOf =
    ref:
    types.submodule (
      { name, ... }: {
        options = definitions."${ref}".options or { };
        config = definitions."${ref}".config or { };
      }
    );

  globalSubmoduleOf =
    ref:
    types.submodule (
      { name, ... }: {
        options = config.definitions."${ref}".options or { };
        config = config.definitions."${ref}".config or { };
      }
    );

  submoduleWithMergeOf =
    ref: mergeKey:
    types.submodule (
      { name, ... }:
      let
        convertName =
          name: if definitions."${ref}".options.${mergeKey}.type == types.int then toInt name else name;
      in
      {
        options = definitions."${ref}".options // {
          # position in original array
          _priority = mkOption {
            type = types.nullOr types.int;
            default = null;
            internal = true;
          };
        };
        config = definitions."${ref}".config // {
          ${mergeKey} = mkOverride 1002 (
            # use name as mergeKey only if it is not coming from mergeValuesByKey
            if (!hasPrefix "__kubenix_list_merge_key_" name) then convertName name else null
          );
        };
      }
    );

  submoduleForDefinition =
    ref: resource: kind: group: version:
    let
      apiVersion = if group == "core" then version else "${group}/${version}";
    in
    types.submodule (
      { name, ... }: {
        inherit (definitions."${ref}") options;

        imports = getDefaults resource group version kind;
        config = mkMerge [
          definitions."${ref}".config
          {
            kind = mkOptionDefault kind;
            apiVersion = mkOptionDefault apiVersion;

            # metdata.name cannot use option default, due deep config
            metadata.name = mkOptionDefault name;
          }
        ];
      }
    );

  coerceAttrsOfSubmodulesToListByKey =
    ref: attrMergeKey: listMergeKeys:
    (types.coercedTo (types.listOf (submoduleOf ref)) (mergeValuesByKey attrMergeKey listMergeKeys) (
      types.attrsOf (submoduleWithMergeOf ref attrMergeKey)
    ));

  definitions = {
    "seaweed.seaweedfs.com.v1.AdminScript" = {

      options = {
        "apiVersion" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "kind" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "metadata" = mkOption {
          description = "Standard object's metadata. More info: https://git.k8s.io/community/contributors/devel/sig-architecture/api-conventions.md#metadata";
          type = types.nullOr (globalSubmoduleOf "io.k8s.apimachinery.pkg.apis.meta.v1.ObjectMeta");
        };
        "spec" = mkOption {
          description = "";
          type = types.nullOr (submoduleOf "seaweed.seaweedfs.com.v1.AdminScriptSpec");
        };
        "status" = mkOption {
          description = "";
          type = types.nullOr (submoduleOf "seaweed.seaweedfs.com.v1.AdminScriptStatus");
        };
      };

      config = {
        "apiVersion" = mkOverride 1002 null;
        "kind" = mkOverride 1002 null;
        "metadata" = mkOverride 1002 null;
        "spec" = mkOverride 1002 null;
        "status" = mkOverride 1002 null;
      };

    };
    "seaweed.seaweedfs.com.v1.AdminScriptSpec" = {

      options = {
        "activeDeadlineSeconds" = mkOption {
          description = "";
          type = types.nullOr types.int;
        };
        "affinity" = mkOption {
          description = "";
          type = types.nullOr (submoduleOf "seaweed.seaweedfs.com.v1.AdminScriptSpecAffinity");
        };
        "backoffLimit" = mkOption {
          description = "";
          type = types.nullOr types.int;
        };
        "clusterRef" = mkOption {
          description = "";
          type = submoduleOf "seaweed.seaweedfs.com.v1.AdminScriptSpecClusterRef";
        };
        "concurrencyPolicy" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "credentialsSecret" = mkOption {
          description = "";
          type = types.nullOr (submoduleOf "seaweed.seaweedfs.com.v1.AdminScriptSpecCredentialsSecret");
        };
        "failedJobsHistoryLimit" = mkOption {
          description = "";
          type = types.nullOr types.int;
        };
        "image" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "imagePullSecrets" = mkOption {
          description = "";
          type = types.nullOr (
            coerceAttrsOfSubmodulesToListByKey "seaweed.seaweedfs.com.v1.AdminScriptSpecImagePullSecrets" "name"
              [ ]
          );
          apply = attrsToList;
        };
        "nodeSelector" = mkOption {
          description = "";
          type = types.nullOr (types.attrsOf types.str);
        };
        "resources" = mkOption {
          description = "";
          type = types.nullOr (submoduleOf "seaweed.seaweedfs.com.v1.AdminScriptSpecResources");
        };
        "restartPolicy" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "schedule" = mkOption {
          description = "";
          type = types.str;
        };
        "script" = mkOption {
          description = "";
          type = types.str;
        };
        "serviceAccountName" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "startingDeadlineSeconds" = mkOption {
          description = "";
          type = types.nullOr types.int;
        };
        "successfulJobsHistoryLimit" = mkOption {
          description = "";
          type = types.nullOr types.int;
        };
        "suspend" = mkOption {
          description = "";
          type = types.nullOr types.bool;
        };
        "timeZone" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "tolerations" = mkOption {
          description = "";
          type = types.nullOr (
            types.listOf (submoduleOf "seaweed.seaweedfs.com.v1.AdminScriptSpecTolerations")
          );
        };
      };

      config = {
        "activeDeadlineSeconds" = mkOverride 1002 null;
        "affinity" = mkOverride 1002 null;
        "backoffLimit" = mkOverride 1002 null;
        "concurrencyPolicy" = mkOverride 1002 null;
        "credentialsSecret" = mkOverride 1002 null;
        "failedJobsHistoryLimit" = mkOverride 1002 null;
        "image" = mkOverride 1002 null;
        "imagePullSecrets" = mkOverride 1002 null;
        "nodeSelector" = mkOverride 1002 null;
        "resources" = mkOverride 1002 null;
        "restartPolicy" = mkOverride 1002 null;
        "serviceAccountName" = mkOverride 1002 null;
        "startingDeadlineSeconds" = mkOverride 1002 null;
        "successfulJobsHistoryLimit" = mkOverride 1002 null;
        "suspend" = mkOverride 1002 null;
        "timeZone" = mkOverride 1002 null;
        "tolerations" = mkOverride 1002 null;
      };

    };
    "seaweed.seaweedfs.com.v1.AdminScriptSpecAffinity" = {

      options = {
        "nodeAffinity" = mkOption {
          description = "";
          type = types.nullOr (submoduleOf "seaweed.seaweedfs.com.v1.AdminScriptSpecAffinityNodeAffinity");
        };
        "podAffinity" = mkOption {
          description = "";
          type = types.nullOr (submoduleOf "seaweed.seaweedfs.com.v1.AdminScriptSpecAffinityPodAffinity");
        };
        "podAntiAffinity" = mkOption {
          description = "";
          type = types.nullOr (submoduleOf "seaweed.seaweedfs.com.v1.AdminScriptSpecAffinityPodAntiAffinity");
        };
      };

      config = {
        "nodeAffinity" = mkOverride 1002 null;
        "podAffinity" = mkOverride 1002 null;
        "podAntiAffinity" = mkOverride 1002 null;
      };

    };
    "seaweed.seaweedfs.com.v1.AdminScriptSpecAffinityNodeAffinity" = {

      options = {
        "preferredDuringSchedulingIgnoredDuringExecution" = mkOption {
          description = "";
          type = types.nullOr (
            types.listOf (
              submoduleOf "seaweed.seaweedfs.com.v1.AdminScriptSpecAffinityNodeAffinityPreferredDuringSchedulingIgnoredDuringExecution"
            )
          );
        };
        "requiredDuringSchedulingIgnoredDuringExecution" = mkOption {
          description = "";
          type = types.nullOr (
            submoduleOf "seaweed.seaweedfs.com.v1.AdminScriptSpecAffinityNodeAffinityRequiredDuringSchedulingIgnoredDuringExecution"
          );
        };
      };

      config = {
        "preferredDuringSchedulingIgnoredDuringExecution" = mkOverride 1002 null;
        "requiredDuringSchedulingIgnoredDuringExecution" = mkOverride 1002 null;
      };

    };
    "seaweed.seaweedfs.com.v1.AdminScriptSpecAffinityNodeAffinityPreferredDuringSchedulingIgnoredDuringExecution" =
      {

        options = {
          "preference" = mkOption {
            description = "";
            type = submoduleOf "seaweed.seaweedfs.com.v1.AdminScriptSpecAffinityNodeAffinityPreferredDuringSchedulingIgnoredDuringExecutionPreference";
          };
          "weight" = mkOption {
            description = "";
            type = types.int;
          };
        };

        config = { };

      };
    "seaweed.seaweedfs.com.v1.AdminScriptSpecAffinityNodeAffinityPreferredDuringSchedulingIgnoredDuringExecutionPreference" =
      {

        options = {
          "matchExpressions" = mkOption {
            description = "";
            type = types.nullOr (
              types.listOf (
                submoduleOf "seaweed.seaweedfs.com.v1.AdminScriptSpecAffinityNodeAffinityPreferredDuringSchedulingIgnoredDuringExecutionPreferenceMatchExpressions"
              )
            );
          };
          "matchFields" = mkOption {
            description = "";
            type = types.nullOr (
              types.listOf (
                submoduleOf "seaweed.seaweedfs.com.v1.AdminScriptSpecAffinityNodeAffinityPreferredDuringSchedulingIgnoredDuringExecutionPreferenceMatchFields"
              )
            );
          };
        };

        config = {
          "matchExpressions" = mkOverride 1002 null;
          "matchFields" = mkOverride 1002 null;
        };

      };
    "seaweed.seaweedfs.com.v1.AdminScriptSpecAffinityNodeAffinityPreferredDuringSchedulingIgnoredDuringExecutionPreferenceMatchExpressions" =
      {

        options = {
          "key" = mkOption {
            description = "";
            type = types.str;
          };
          "operator" = mkOption {
            description = "";
            type = types.str;
          };
          "values" = mkOption {
            description = "";
            type = types.nullOr (types.listOf types.str);
          };
        };

        config = {
          "values" = mkOverride 1002 null;
        };

      };
    "seaweed.seaweedfs.com.v1.AdminScriptSpecAffinityNodeAffinityPreferredDuringSchedulingIgnoredDuringExecutionPreferenceMatchFields" =
      {

        options = {
          "key" = mkOption {
            description = "";
            type = types.str;
          };
          "operator" = mkOption {
            description = "";
            type = types.str;
          };
          "values" = mkOption {
            description = "";
            type = types.nullOr (types.listOf types.str);
          };
        };

        config = {
          "values" = mkOverride 1002 null;
        };

      };
    "seaweed.seaweedfs.com.v1.AdminScriptSpecAffinityNodeAffinityRequiredDuringSchedulingIgnoredDuringExecution" =
      {

        options = {
          "nodeSelectorTerms" = mkOption {
            description = "";
            type = types.listOf (
              submoduleOf "seaweed.seaweedfs.com.v1.AdminScriptSpecAffinityNodeAffinityRequiredDuringSchedulingIgnoredDuringExecutionNodeSelectorTerms"
            );
          };
        };

        config = { };

      };
    "seaweed.seaweedfs.com.v1.AdminScriptSpecAffinityNodeAffinityRequiredDuringSchedulingIgnoredDuringExecutionNodeSelectorTerms" =
      {

        options = {
          "matchExpressions" = mkOption {
            description = "";
            type = types.nullOr (
              types.listOf (
                submoduleOf "seaweed.seaweedfs.com.v1.AdminScriptSpecAffinityNodeAffinityRequiredDuringSchedulingIgnoredDuringExecutionNodeSelectorTermsMatchExpressions"
              )
            );
          };
          "matchFields" = mkOption {
            description = "";
            type = types.nullOr (
              types.listOf (
                submoduleOf "seaweed.seaweedfs.com.v1.AdminScriptSpecAffinityNodeAffinityRequiredDuringSchedulingIgnoredDuringExecutionNodeSelectorTermsMatchFields"
              )
            );
          };
        };

        config = {
          "matchExpressions" = mkOverride 1002 null;
          "matchFields" = mkOverride 1002 null;
        };

      };
    "seaweed.seaweedfs.com.v1.AdminScriptSpecAffinityNodeAffinityRequiredDuringSchedulingIgnoredDuringExecutionNodeSelectorTermsMatchExpressions" =
      {

        options = {
          "key" = mkOption {
            description = "";
            type = types.str;
          };
          "operator" = mkOption {
            description = "";
            type = types.str;
          };
          "values" = mkOption {
            description = "";
            type = types.nullOr (types.listOf types.str);
          };
        };

        config = {
          "values" = mkOverride 1002 null;
        };

      };
    "seaweed.seaweedfs.com.v1.AdminScriptSpecAffinityNodeAffinityRequiredDuringSchedulingIgnoredDuringExecutionNodeSelectorTermsMatchFields" =
      {

        options = {
          "key" = mkOption {
            description = "";
            type = types.str;
          };
          "operator" = mkOption {
            description = "";
            type = types.str;
          };
          "values" = mkOption {
            description = "";
            type = types.nullOr (types.listOf types.str);
          };
        };

        config = {
          "values" = mkOverride 1002 null;
        };

      };
    "seaweed.seaweedfs.com.v1.AdminScriptSpecAffinityPodAffinity" = {

      options = {
        "preferredDuringSchedulingIgnoredDuringExecution" = mkOption {
          description = "";
          type = types.nullOr (
            types.listOf (
              submoduleOf "seaweed.seaweedfs.com.v1.AdminScriptSpecAffinityPodAffinityPreferredDuringSchedulingIgnoredDuringExecution"
            )
          );
        };
        "requiredDuringSchedulingIgnoredDuringExecution" = mkOption {
          description = "";
          type = types.nullOr (
            types.listOf (
              submoduleOf "seaweed.seaweedfs.com.v1.AdminScriptSpecAffinityPodAffinityRequiredDuringSchedulingIgnoredDuringExecution"
            )
          );
        };
      };

      config = {
        "preferredDuringSchedulingIgnoredDuringExecution" = mkOverride 1002 null;
        "requiredDuringSchedulingIgnoredDuringExecution" = mkOverride 1002 null;
      };

    };
    "seaweed.seaweedfs.com.v1.AdminScriptSpecAffinityPodAffinityPreferredDuringSchedulingIgnoredDuringExecution" =
      {

        options = {
          "podAffinityTerm" = mkOption {
            description = "";
            type = submoduleOf "seaweed.seaweedfs.com.v1.AdminScriptSpecAffinityPodAffinityPreferredDuringSchedulingIgnoredDuringExecutionPodAffinityTerm";
          };
          "weight" = mkOption {
            description = "";
            type = types.int;
          };
        };

        config = { };

      };
    "seaweed.seaweedfs.com.v1.AdminScriptSpecAffinityPodAffinityPreferredDuringSchedulingIgnoredDuringExecutionPodAffinityTerm" =
      {

        options = {
          "labelSelector" = mkOption {
            description = "";
            type = types.nullOr (
              submoduleOf "seaweed.seaweedfs.com.v1.AdminScriptSpecAffinityPodAffinityPreferredDuringSchedulingIgnoredDuringExecutionPodAffinityTermLabelSelector"
            );
          };
          "matchLabelKeys" = mkOption {
            description = "";
            type = types.nullOr (types.listOf types.str);
          };
          "mismatchLabelKeys" = mkOption {
            description = "";
            type = types.nullOr (types.listOf types.str);
          };
          "namespaceSelector" = mkOption {
            description = "";
            type = types.nullOr (
              submoduleOf "seaweed.seaweedfs.com.v1.AdminScriptSpecAffinityPodAffinityPreferredDuringSchedulingIgnoredDuringExecutionPodAffinityTermNamespaceSelector"
            );
          };
          "namespaces" = mkOption {
            description = "";
            type = types.nullOr (types.listOf types.str);
          };
          "topologyKey" = mkOption {
            description = "";
            type = types.str;
          };
        };

        config = {
          "labelSelector" = mkOverride 1002 null;
          "matchLabelKeys" = mkOverride 1002 null;
          "mismatchLabelKeys" = mkOverride 1002 null;
          "namespaceSelector" = mkOverride 1002 null;
          "namespaces" = mkOverride 1002 null;
        };

      };
    "seaweed.seaweedfs.com.v1.AdminScriptSpecAffinityPodAffinityPreferredDuringSchedulingIgnoredDuringExecutionPodAffinityTermLabelSelector" =
      {

        options = {
          "matchExpressions" = mkOption {
            description = "";
            type = types.nullOr (
              types.listOf (
                submoduleOf "seaweed.seaweedfs.com.v1.AdminScriptSpecAffinityPodAffinityPreferredDuringSchedulingIgnoredDuringExecutionPodAffinityTermLabelSelectorMatchExpressions"
              )
            );
          };
          "matchLabels" = mkOption {
            description = "";
            type = types.nullOr (types.attrsOf types.str);
          };
        };

        config = {
          "matchExpressions" = mkOverride 1002 null;
          "matchLabels" = mkOverride 1002 null;
        };

      };
    "seaweed.seaweedfs.com.v1.AdminScriptSpecAffinityPodAffinityPreferredDuringSchedulingIgnoredDuringExecutionPodAffinityTermLabelSelectorMatchExpressions" =
      {

        options = {
          "key" = mkOption {
            description = "";
            type = types.str;
          };
          "operator" = mkOption {
            description = "";
            type = types.str;
          };
          "values" = mkOption {
            description = "";
            type = types.nullOr (types.listOf types.str);
          };
        };

        config = {
          "values" = mkOverride 1002 null;
        };

      };
    "seaweed.seaweedfs.com.v1.AdminScriptSpecAffinityPodAffinityPreferredDuringSchedulingIgnoredDuringExecutionPodAffinityTermNamespaceSelector" =
      {

        options = {
          "matchExpressions" = mkOption {
            description = "";
            type = types.nullOr (
              types.listOf (
                submoduleOf "seaweed.seaweedfs.com.v1.AdminScriptSpecAffinityPodAffinityPreferredDuringSchedulingIgnoredDuringExecutionPodAffinityTermNamespaceSelectorMatchExpressions"
              )
            );
          };
          "matchLabels" = mkOption {
            description = "";
            type = types.nullOr (types.attrsOf types.str);
          };
        };

        config = {
          "matchExpressions" = mkOverride 1002 null;
          "matchLabels" = mkOverride 1002 null;
        };

      };
    "seaweed.seaweedfs.com.v1.AdminScriptSpecAffinityPodAffinityPreferredDuringSchedulingIgnoredDuringExecutionPodAffinityTermNamespaceSelectorMatchExpressions" =
      {

        options = {
          "key" = mkOption {
            description = "";
            type = types.str;
          };
          "operator" = mkOption {
            description = "";
            type = types.str;
          };
          "values" = mkOption {
            description = "";
            type = types.nullOr (types.listOf types.str);
          };
        };

        config = {
          "values" = mkOverride 1002 null;
        };

      };
    "seaweed.seaweedfs.com.v1.AdminScriptSpecAffinityPodAffinityRequiredDuringSchedulingIgnoredDuringExecution" =
      {

        options = {
          "labelSelector" = mkOption {
            description = "";
            type = types.nullOr (
              submoduleOf "seaweed.seaweedfs.com.v1.AdminScriptSpecAffinityPodAffinityRequiredDuringSchedulingIgnoredDuringExecutionLabelSelector"
            );
          };
          "matchLabelKeys" = mkOption {
            description = "";
            type = types.nullOr (types.listOf types.str);
          };
          "mismatchLabelKeys" = mkOption {
            description = "";
            type = types.nullOr (types.listOf types.str);
          };
          "namespaceSelector" = mkOption {
            description = "";
            type = types.nullOr (
              submoduleOf "seaweed.seaweedfs.com.v1.AdminScriptSpecAffinityPodAffinityRequiredDuringSchedulingIgnoredDuringExecutionNamespaceSelector"
            );
          };
          "namespaces" = mkOption {
            description = "";
            type = types.nullOr (types.listOf types.str);
          };
          "topologyKey" = mkOption {
            description = "";
            type = types.str;
          };
        };

        config = {
          "labelSelector" = mkOverride 1002 null;
          "matchLabelKeys" = mkOverride 1002 null;
          "mismatchLabelKeys" = mkOverride 1002 null;
          "namespaceSelector" = mkOverride 1002 null;
          "namespaces" = mkOverride 1002 null;
        };

      };
    "seaweed.seaweedfs.com.v1.AdminScriptSpecAffinityPodAffinityRequiredDuringSchedulingIgnoredDuringExecutionLabelSelector" =
      {

        options = {
          "matchExpressions" = mkOption {
            description = "";
            type = types.nullOr (
              types.listOf (
                submoduleOf "seaweed.seaweedfs.com.v1.AdminScriptSpecAffinityPodAffinityRequiredDuringSchedulingIgnoredDuringExecutionLabelSelectorMatchExpressions"
              )
            );
          };
          "matchLabels" = mkOption {
            description = "";
            type = types.nullOr (types.attrsOf types.str);
          };
        };

        config = {
          "matchExpressions" = mkOverride 1002 null;
          "matchLabels" = mkOverride 1002 null;
        };

      };
    "seaweed.seaweedfs.com.v1.AdminScriptSpecAffinityPodAffinityRequiredDuringSchedulingIgnoredDuringExecutionLabelSelectorMatchExpressions" =
      {

        options = {
          "key" = mkOption {
            description = "";
            type = types.str;
          };
          "operator" = mkOption {
            description = "";
            type = types.str;
          };
          "values" = mkOption {
            description = "";
            type = types.nullOr (types.listOf types.str);
          };
        };

        config = {
          "values" = mkOverride 1002 null;
        };

      };
    "seaweed.seaweedfs.com.v1.AdminScriptSpecAffinityPodAffinityRequiredDuringSchedulingIgnoredDuringExecutionNamespaceSelector" =
      {

        options = {
          "matchExpressions" = mkOption {
            description = "";
            type = types.nullOr (
              types.listOf (
                submoduleOf "seaweed.seaweedfs.com.v1.AdminScriptSpecAffinityPodAffinityRequiredDuringSchedulingIgnoredDuringExecutionNamespaceSelectorMatchExpressions"
              )
            );
          };
          "matchLabels" = mkOption {
            description = "";
            type = types.nullOr (types.attrsOf types.str);
          };
        };

        config = {
          "matchExpressions" = mkOverride 1002 null;
          "matchLabels" = mkOverride 1002 null;
        };

      };
    "seaweed.seaweedfs.com.v1.AdminScriptSpecAffinityPodAffinityRequiredDuringSchedulingIgnoredDuringExecutionNamespaceSelectorMatchExpressions" =
      {

        options = {
          "key" = mkOption {
            description = "";
            type = types.str;
          };
          "operator" = mkOption {
            description = "";
            type = types.str;
          };
          "values" = mkOption {
            description = "";
            type = types.nullOr (types.listOf types.str);
          };
        };

        config = {
          "values" = mkOverride 1002 null;
        };

      };
    "seaweed.seaweedfs.com.v1.AdminScriptSpecAffinityPodAntiAffinity" = {

      options = {
        "preferredDuringSchedulingIgnoredDuringExecution" = mkOption {
          description = "";
          type = types.nullOr (
            types.listOf (
              submoduleOf "seaweed.seaweedfs.com.v1.AdminScriptSpecAffinityPodAntiAffinityPreferredDuringSchedulingIgnoredDuringExecution"
            )
          );
        };
        "requiredDuringSchedulingIgnoredDuringExecution" = mkOption {
          description = "";
          type = types.nullOr (
            types.listOf (
              submoduleOf "seaweed.seaweedfs.com.v1.AdminScriptSpecAffinityPodAntiAffinityRequiredDuringSchedulingIgnoredDuringExecution"
            )
          );
        };
      };

      config = {
        "preferredDuringSchedulingIgnoredDuringExecution" = mkOverride 1002 null;
        "requiredDuringSchedulingIgnoredDuringExecution" = mkOverride 1002 null;
      };

    };
    "seaweed.seaweedfs.com.v1.AdminScriptSpecAffinityPodAntiAffinityPreferredDuringSchedulingIgnoredDuringExecution" =
      {

        options = {
          "podAffinityTerm" = mkOption {
            description = "";
            type = submoduleOf "seaweed.seaweedfs.com.v1.AdminScriptSpecAffinityPodAntiAffinityPreferredDuringSchedulingIgnoredDuringExecutionPodAffinityTerm";
          };
          "weight" = mkOption {
            description = "";
            type = types.int;
          };
        };

        config = { };

      };
    "seaweed.seaweedfs.com.v1.AdminScriptSpecAffinityPodAntiAffinityPreferredDuringSchedulingIgnoredDuringExecutionPodAffinityTerm" =
      {

        options = {
          "labelSelector" = mkOption {
            description = "";
            type = types.nullOr (
              submoduleOf "seaweed.seaweedfs.com.v1.AdminScriptSpecAffinityPodAntiAffinityPreferredDuringSchedulingIgnoredDuringExecutionPodAffinityTermLabelSelector"
            );
          };
          "matchLabelKeys" = mkOption {
            description = "";
            type = types.nullOr (types.listOf types.str);
          };
          "mismatchLabelKeys" = mkOption {
            description = "";
            type = types.nullOr (types.listOf types.str);
          };
          "namespaceSelector" = mkOption {
            description = "";
            type = types.nullOr (
              submoduleOf "seaweed.seaweedfs.com.v1.AdminScriptSpecAffinityPodAntiAffinityPreferredDuringSchedulingIgnoredDuringExecutionPodAffinityTermNamespaceSelector"
            );
          };
          "namespaces" = mkOption {
            description = "";
            type = types.nullOr (types.listOf types.str);
          };
          "topologyKey" = mkOption {
            description = "";
            type = types.str;
          };
        };

        config = {
          "labelSelector" = mkOverride 1002 null;
          "matchLabelKeys" = mkOverride 1002 null;
          "mismatchLabelKeys" = mkOverride 1002 null;
          "namespaceSelector" = mkOverride 1002 null;
          "namespaces" = mkOverride 1002 null;
        };

      };
    "seaweed.seaweedfs.com.v1.AdminScriptSpecAffinityPodAntiAffinityPreferredDuringSchedulingIgnoredDuringExecutionPodAffinityTermLabelSelector" =
      {

        options = {
          "matchExpressions" = mkOption {
            description = "";
            type = types.nullOr (
              types.listOf (
                submoduleOf "seaweed.seaweedfs.com.v1.AdminScriptSpecAffinityPodAntiAffinityPreferredDuringSchedulingIgnoredDuringExecutionPodAffinityTermLabelSelectorMatchExpressions"
              )
            );
          };
          "matchLabels" = mkOption {
            description = "";
            type = types.nullOr (types.attrsOf types.str);
          };
        };

        config = {
          "matchExpressions" = mkOverride 1002 null;
          "matchLabels" = mkOverride 1002 null;
        };

      };
    "seaweed.seaweedfs.com.v1.AdminScriptSpecAffinityPodAntiAffinityPreferredDuringSchedulingIgnoredDuringExecutionPodAffinityTermLabelSelectorMatchExpressions" =
      {

        options = {
          "key" = mkOption {
            description = "";
            type = types.str;
          };
          "operator" = mkOption {
            description = "";
            type = types.str;
          };
          "values" = mkOption {
            description = "";
            type = types.nullOr (types.listOf types.str);
          };
        };

        config = {
          "values" = mkOverride 1002 null;
        };

      };
    "seaweed.seaweedfs.com.v1.AdminScriptSpecAffinityPodAntiAffinityPreferredDuringSchedulingIgnoredDuringExecutionPodAffinityTermNamespaceSelector" =
      {

        options = {
          "matchExpressions" = mkOption {
            description = "";
            type = types.nullOr (
              types.listOf (
                submoduleOf "seaweed.seaweedfs.com.v1.AdminScriptSpecAffinityPodAntiAffinityPreferredDuringSchedulingIgnoredDuringExecutionPodAffinityTermNamespaceSelectorMatchExpressions"
              )
            );
          };
          "matchLabels" = mkOption {
            description = "";
            type = types.nullOr (types.attrsOf types.str);
          };
        };

        config = {
          "matchExpressions" = mkOverride 1002 null;
          "matchLabels" = mkOverride 1002 null;
        };

      };
    "seaweed.seaweedfs.com.v1.AdminScriptSpecAffinityPodAntiAffinityPreferredDuringSchedulingIgnoredDuringExecutionPodAffinityTermNamespaceSelectorMatchExpressions" =
      {

        options = {
          "key" = mkOption {
            description = "";
            type = types.str;
          };
          "operator" = mkOption {
            description = "";
            type = types.str;
          };
          "values" = mkOption {
            description = "";
            type = types.nullOr (types.listOf types.str);
          };
        };

        config = {
          "values" = mkOverride 1002 null;
        };

      };
    "seaweed.seaweedfs.com.v1.AdminScriptSpecAffinityPodAntiAffinityRequiredDuringSchedulingIgnoredDuringExecution" =
      {

        options = {
          "labelSelector" = mkOption {
            description = "";
            type = types.nullOr (
              submoduleOf "seaweed.seaweedfs.com.v1.AdminScriptSpecAffinityPodAntiAffinityRequiredDuringSchedulingIgnoredDuringExecutionLabelSelector"
            );
          };
          "matchLabelKeys" = mkOption {
            description = "";
            type = types.nullOr (types.listOf types.str);
          };
          "mismatchLabelKeys" = mkOption {
            description = "";
            type = types.nullOr (types.listOf types.str);
          };
          "namespaceSelector" = mkOption {
            description = "";
            type = types.nullOr (
              submoduleOf "seaweed.seaweedfs.com.v1.AdminScriptSpecAffinityPodAntiAffinityRequiredDuringSchedulingIgnoredDuringExecutionNamespaceSelector"
            );
          };
          "namespaces" = mkOption {
            description = "";
            type = types.nullOr (types.listOf types.str);
          };
          "topologyKey" = mkOption {
            description = "";
            type = types.str;
          };
        };

        config = {
          "labelSelector" = mkOverride 1002 null;
          "matchLabelKeys" = mkOverride 1002 null;
          "mismatchLabelKeys" = mkOverride 1002 null;
          "namespaceSelector" = mkOverride 1002 null;
          "namespaces" = mkOverride 1002 null;
        };

      };
    "seaweed.seaweedfs.com.v1.AdminScriptSpecAffinityPodAntiAffinityRequiredDuringSchedulingIgnoredDuringExecutionLabelSelector" =
      {

        options = {
          "matchExpressions" = mkOption {
            description = "";
            type = types.nullOr (
              types.listOf (
                submoduleOf "seaweed.seaweedfs.com.v1.AdminScriptSpecAffinityPodAntiAffinityRequiredDuringSchedulingIgnoredDuringExecutionLabelSelectorMatchExpressions"
              )
            );
          };
          "matchLabels" = mkOption {
            description = "";
            type = types.nullOr (types.attrsOf types.str);
          };
        };

        config = {
          "matchExpressions" = mkOverride 1002 null;
          "matchLabels" = mkOverride 1002 null;
        };

      };
    "seaweed.seaweedfs.com.v1.AdminScriptSpecAffinityPodAntiAffinityRequiredDuringSchedulingIgnoredDuringExecutionLabelSelectorMatchExpressions" =
      {

        options = {
          "key" = mkOption {
            description = "";
            type = types.str;
          };
          "operator" = mkOption {
            description = "";
            type = types.str;
          };
          "values" = mkOption {
            description = "";
            type = types.nullOr (types.listOf types.str);
          };
        };

        config = {
          "values" = mkOverride 1002 null;
        };

      };
    "seaweed.seaweedfs.com.v1.AdminScriptSpecAffinityPodAntiAffinityRequiredDuringSchedulingIgnoredDuringExecutionNamespaceSelector" =
      {

        options = {
          "matchExpressions" = mkOption {
            description = "";
            type = types.nullOr (
              types.listOf (
                submoduleOf "seaweed.seaweedfs.com.v1.AdminScriptSpecAffinityPodAntiAffinityRequiredDuringSchedulingIgnoredDuringExecutionNamespaceSelectorMatchExpressions"
              )
            );
          };
          "matchLabels" = mkOption {
            description = "";
            type = types.nullOr (types.attrsOf types.str);
          };
        };

        config = {
          "matchExpressions" = mkOverride 1002 null;
          "matchLabels" = mkOverride 1002 null;
        };

      };
    "seaweed.seaweedfs.com.v1.AdminScriptSpecAffinityPodAntiAffinityRequiredDuringSchedulingIgnoredDuringExecutionNamespaceSelectorMatchExpressions" =
      {

        options = {
          "key" = mkOption {
            description = "";
            type = types.str;
          };
          "operator" = mkOption {
            description = "";
            type = types.str;
          };
          "values" = mkOption {
            description = "";
            type = types.nullOr (types.listOf types.str);
          };
        };

        config = {
          "values" = mkOverride 1002 null;
        };

      };
    "seaweed.seaweedfs.com.v1.AdminScriptSpecClusterRef" = {

      options = {
        "name" = mkOption {
          description = "";
          type = types.str;
        };
      };

      config = { };

    };
    "seaweed.seaweedfs.com.v1.AdminScriptSpecCredentialsSecret" = {

      options = {
        "name" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
      };

      config = {
        "name" = mkOverride 1002 null;
      };

    };
    "seaweed.seaweedfs.com.v1.AdminScriptSpecImagePullSecrets" = {

      options = {
        "name" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
      };

      config = {
        "name" = mkOverride 1002 null;
      };

    };
    "seaweed.seaweedfs.com.v1.AdminScriptSpecResources" = {

      options = {
        "claims" = mkOption {
          description = "";
          type = types.nullOr (
            coerceAttrsOfSubmodulesToListByKey "seaweed.seaweedfs.com.v1.AdminScriptSpecResourcesClaims" "name"
              [ "name" ]
          );
          apply = attrsToList;
        };
        "limits" = mkOption {
          description = "";
          type = types.nullOr (types.attrsOf (types.either types.int types.str));
        };
        "requests" = mkOption {
          description = "";
          type = types.nullOr (types.attrsOf (types.either types.int types.str));
        };
      };

      config = {
        "claims" = mkOverride 1002 null;
        "limits" = mkOverride 1002 null;
        "requests" = mkOverride 1002 null;
      };

    };
    "seaweed.seaweedfs.com.v1.AdminScriptSpecResourcesClaims" = {

      options = {
        "name" = mkOption {
          description = "";
          type = types.str;
        };
        "request" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
      };

      config = {
        "request" = mkOverride 1002 null;
      };

    };
    "seaweed.seaweedfs.com.v1.AdminScriptSpecTolerations" = {

      options = {
        "effect" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "key" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "operator" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "tolerationSeconds" = mkOption {
          description = "";
          type = types.nullOr types.int;
        };
        "value" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
      };

      config = {
        "effect" = mkOverride 1002 null;
        "key" = mkOverride 1002 null;
        "operator" = mkOverride 1002 null;
        "tolerationSeconds" = mkOverride 1002 null;
        "value" = mkOverride 1002 null;
      };

    };
    "seaweed.seaweedfs.com.v1.AdminScriptStatus" = {

      options = {
        "active" = mkOption {
          description = "";
          type = types.nullOr types.int;
        };
        "conditions" = mkOption {
          description = "";
          type = types.nullOr (
            types.listOf (submoduleOf "seaweed.seaweedfs.com.v1.AdminScriptStatusConditions")
          );
        };
        "cronJobName" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "lastScheduleTime" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "lastSuccessfulTime" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "observedGeneration" = mkOption {
          description = "";
          type = types.nullOr types.int;
        };
        "phase" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
      };

      config = {
        "active" = mkOverride 1002 null;
        "conditions" = mkOverride 1002 null;
        "cronJobName" = mkOverride 1002 null;
        "lastScheduleTime" = mkOverride 1002 null;
        "lastSuccessfulTime" = mkOverride 1002 null;
        "observedGeneration" = mkOverride 1002 null;
        "phase" = mkOverride 1002 null;
      };

    };
    "seaweed.seaweedfs.com.v1.AdminScriptStatusConditions" = {

      options = {
        "lastTransitionTime" = mkOption {
          description = "";
          type = types.str;
        };
        "message" = mkOption {
          description = "";
          type = types.str;
        };
        "observedGeneration" = mkOption {
          description = "";
          type = types.nullOr types.int;
        };
        "reason" = mkOption {
          description = "";
          type = types.str;
        };
        "status" = mkOption {
          description = "";
          type = types.str;
        };
        "type" = mkOption {
          description = "";
          type = types.str;
        };
      };

      config = {
        "observedGeneration" = mkOverride 1002 null;
      };

    };
    "seaweed.seaweedfs.com.v1.Bucket" = {

      options = {
        "apiVersion" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "kind" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "metadata" = mkOption {
          description = "Standard object's metadata. More info: https://git.k8s.io/community/contributors/devel/sig-architecture/api-conventions.md#metadata";
          type = types.nullOr (globalSubmoduleOf "io.k8s.apimachinery.pkg.apis.meta.v1.ObjectMeta");
        };
        "spec" = mkOption {
          description = "";
          type = types.nullOr (submoduleOf "seaweed.seaweedfs.com.v1.BucketSpec");
        };
        "status" = mkOption {
          description = "";
          type = types.nullOr (submoduleOf "seaweed.seaweedfs.com.v1.BucketStatus");
        };
      };

      config = {
        "apiVersion" = mkOverride 1002 null;
        "kind" = mkOverride 1002 null;
        "metadata" = mkOverride 1002 null;
        "spec" = mkOverride 1002 null;
        "status" = mkOverride 1002 null;
      };

    };
    "seaweed.seaweedfs.com.v1.BucketLifecyclePolicy" = {

      options = {
        "apiVersion" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "kind" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "metadata" = mkOption {
          description = "Standard object's metadata. More info: https://git.k8s.io/community/contributors/devel/sig-architecture/api-conventions.md#metadata";
          type = types.nullOr (globalSubmoduleOf "io.k8s.apimachinery.pkg.apis.meta.v1.ObjectMeta");
        };
        "spec" = mkOption {
          description = "";
          type = types.nullOr (submoduleOf "seaweed.seaweedfs.com.v1.BucketLifecyclePolicySpec");
        };
        "status" = mkOption {
          description = "";
          type = types.nullOr (submoduleOf "seaweed.seaweedfs.com.v1.BucketLifecyclePolicyStatus");
        };
      };

      config = {
        "apiVersion" = mkOverride 1002 null;
        "kind" = mkOverride 1002 null;
        "metadata" = mkOverride 1002 null;
        "spec" = mkOverride 1002 null;
        "status" = mkOverride 1002 null;
      };

    };
    "seaweed.seaweedfs.com.v1.BucketLifecyclePolicySpec" = {

      options = {
        "bucketRef" = mkOption {
          description = "";
          type = submoduleOf "seaweed.seaweedfs.com.v1.BucketLifecyclePolicySpecBucketRef";
        };
        "reclaimPolicy" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "rules" = mkOption {
          description = "";
          type = types.listOf (submoduleOf "seaweed.seaweedfs.com.v1.BucketLifecyclePolicySpecRules");
        };
      };

      config = {
        "reclaimPolicy" = mkOverride 1002 null;
      };

    };
    "seaweed.seaweedfs.com.v1.BucketLifecyclePolicySpecBucketRef" = {

      options = {
        "name" = mkOption {
          description = "";
          type = types.str;
        };
      };

      config = { };

    };
    "seaweed.seaweedfs.com.v1.BucketLifecyclePolicySpecRules" = {

      options = {
        "abortIncompleteMultipartUpload" = mkOption {
          description = "";
          type = types.nullOr (
            submoduleOf "seaweed.seaweedfs.com.v1.BucketLifecyclePolicySpecRulesAbortIncompleteMultipartUpload"
          );
        };
        "expiration" = mkOption {
          description = "";
          type = types.nullOr (
            submoduleOf "seaweed.seaweedfs.com.v1.BucketLifecyclePolicySpecRulesExpiration"
          );
        };
        "id" = mkOption {
          description = "";
          type = types.str;
        };
        "noncurrentVersionExpiration" = mkOption {
          description = "";
          type = types.nullOr (
            submoduleOf "seaweed.seaweedfs.com.v1.BucketLifecyclePolicySpecRulesNoncurrentVersionExpiration"
          );
        };
        "prefix" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "status" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
      };

      config = {
        "abortIncompleteMultipartUpload" = mkOverride 1002 null;
        "expiration" = mkOverride 1002 null;
        "noncurrentVersionExpiration" = mkOverride 1002 null;
        "prefix" = mkOverride 1002 null;
        "status" = mkOverride 1002 null;
      };

    };
    "seaweed.seaweedfs.com.v1.BucketLifecyclePolicySpecRulesAbortIncompleteMultipartUpload" = {

      options = {
        "daysAfterInitiation" = mkOption {
          description = "";
          type = types.int;
        };
      };

      config = { };

    };
    "seaweed.seaweedfs.com.v1.BucketLifecyclePolicySpecRulesExpiration" = {

      options = {
        "days" = mkOption {
          description = "";
          type = types.nullOr types.int;
        };
        "expiredObjectDeleteMarker" = mkOption {
          description = "";
          type = types.nullOr types.bool;
        };
      };

      config = {
        "days" = mkOverride 1002 null;
        "expiredObjectDeleteMarker" = mkOverride 1002 null;
      };

    };
    "seaweed.seaweedfs.com.v1.BucketLifecyclePolicySpecRulesNoncurrentVersionExpiration" = {

      options = {
        "newerNoncurrentVersions" = mkOption {
          description = "";
          type = types.nullOr types.int;
        };
        "noncurrentDays" = mkOption {
          description = "";
          type = types.int;
        };
      };

      config = {
        "newerNoncurrentVersions" = mkOverride 1002 null;
      };

    };
    "seaweed.seaweedfs.com.v1.BucketLifecyclePolicyStatus" = {

      options = {
        "appliedRules" = mkOption {
          description = "";
          type = types.nullOr types.int;
        };
        "bucketName" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "clusterName" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "clusterNamespace" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "conditions" = mkOption {
          description = "";
          type = types.nullOr (
            types.listOf (submoduleOf "seaweed.seaweedfs.com.v1.BucketLifecyclePolicyStatusConditions")
          );
        };
        "observedGeneration" = mkOption {
          description = "";
          type = types.nullOr types.int;
        };
        "phase" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
      };

      config = {
        "appliedRules" = mkOverride 1002 null;
        "bucketName" = mkOverride 1002 null;
        "clusterName" = mkOverride 1002 null;
        "clusterNamespace" = mkOverride 1002 null;
        "conditions" = mkOverride 1002 null;
        "observedGeneration" = mkOverride 1002 null;
        "phase" = mkOverride 1002 null;
      };

    };
    "seaweed.seaweedfs.com.v1.BucketLifecyclePolicyStatusConditions" = {

      options = {
        "lastTransitionTime" = mkOption {
          description = "";
          type = types.str;
        };
        "message" = mkOption {
          description = "";
          type = types.str;
        };
        "observedGeneration" = mkOption {
          description = "";
          type = types.nullOr types.int;
        };
        "reason" = mkOption {
          description = "";
          type = types.str;
        };
        "status" = mkOption {
          description = "";
          type = types.str;
        };
        "type" = mkOption {
          description = "";
          type = types.str;
        };
      };

      config = {
        "observedGeneration" = mkOverride 1002 null;
      };

    };
    "seaweed.seaweedfs.com.v1.BucketSpec" = {

      options = {
        "access" = mkOption {
          description = "";
          type = types.nullOr (types.listOf (submoduleOf "seaweed.seaweedfs.com.v1.BucketSpecAccess"));
        };
        "adoptExisting" = mkOption {
          description = "";
          type = types.nullOr types.bool;
        };
        "anonymousRead" = mkOption {
          description = "";
          type = types.nullOr types.bool;
        };
        "clusterRef" = mkOption {
          description = "";
          type = submoduleOf "seaweed.seaweedfs.com.v1.BucketSpecClusterRef";
        };
        "name" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "objectLock" = mkOption {
          description = "";
          type = types.nullOr types.bool;
        };
        "owner" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "placement" = mkOption {
          description = "";
          type = types.nullOr (submoduleOf "seaweed.seaweedfs.com.v1.BucketSpecPlacement");
        };
        "quota" = mkOption {
          description = "";
          type = types.nullOr (submoduleOf "seaweed.seaweedfs.com.v1.BucketSpecQuota");
        };
        "reclaimPolicy" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "versioning" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
      };

      config = {
        "access" = mkOverride 1002 null;
        "adoptExisting" = mkOverride 1002 null;
        "anonymousRead" = mkOverride 1002 null;
        "name" = mkOverride 1002 null;
        "objectLock" = mkOverride 1002 null;
        "owner" = mkOverride 1002 null;
        "placement" = mkOverride 1002 null;
        "quota" = mkOverride 1002 null;
        "reclaimPolicy" = mkOverride 1002 null;
        "versioning" = mkOverride 1002 null;
      };

    };
    "seaweed.seaweedfs.com.v1.BucketSpecAccess" = {

      options = {
        "actions" = mkOption {
          description = "";
          type = types.listOf types.str;
        };
        "user" = mkOption {
          description = "";
          type = types.str;
        };
      };

      config = { };

    };
    "seaweed.seaweedfs.com.v1.BucketSpecClusterRef" = {

      options = {
        "name" = mkOption {
          description = "";
          type = types.str;
        };
        "namespace" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
      };

      config = {
        "namespace" = mkOverride 1002 null;
      };

    };
    "seaweed.seaweedfs.com.v1.BucketSpecPlacement" = {

      options = {
        "dataCenter" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "dataNode" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "diskType" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "fsync" = mkOption {
          description = "";
          type = types.nullOr types.bool;
        };
        "rack" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "readOnly" = mkOption {
          description = "";
          type = types.nullOr types.bool;
        };
        "replication" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "ttl" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "volumeGrowthCount" = mkOption {
          description = "";
          type = types.nullOr types.int;
        };
        "worm" = mkOption {
          description = "";
          type = types.nullOr types.bool;
        };
      };

      config = {
        "dataCenter" = mkOverride 1002 null;
        "dataNode" = mkOverride 1002 null;
        "diskType" = mkOverride 1002 null;
        "fsync" = mkOverride 1002 null;
        "rack" = mkOverride 1002 null;
        "readOnly" = mkOverride 1002 null;
        "replication" = mkOverride 1002 null;
        "ttl" = mkOverride 1002 null;
        "volumeGrowthCount" = mkOverride 1002 null;
        "worm" = mkOverride 1002 null;
      };

    };
    "seaweed.seaweedfs.com.v1.BucketSpecQuota" = {

      options = {
        "enforce" = mkOption {
          description = "";
          type = types.nullOr types.bool;
        };
        "size" = mkOption {
          description = "";
          type = types.either types.int types.str;
        };
      };

      config = {
        "enforce" = mkOverride 1002 null;
      };

    };
    "seaweed.seaweedfs.com.v1.BucketStatus" = {

      options = {
        "bucketName" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "conditions" = mkOption {
          description = "";
          type = types.nullOr (types.listOf (submoduleOf "seaweed.seaweedfs.com.v1.BucketStatusConditions"));
        };
        "objectLockEnabled" = mkOption {
          description = "";
          type = types.nullOr types.bool;
        };
        "observedGeneration" = mkOption {
          description = "";
          type = types.nullOr types.int;
        };
        "ownerIdentity" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "phase" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "quota" = mkOption {
          description = "";
          type = types.nullOr (submoduleOf "seaweed.seaweedfs.com.v1.BucketStatusQuota");
        };
        "usage" = mkOption {
          description = "";
          type = types.nullOr (submoduleOf "seaweed.seaweedfs.com.v1.BucketStatusUsage");
        };
        "versioning" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
      };

      config = {
        "bucketName" = mkOverride 1002 null;
        "conditions" = mkOverride 1002 null;
        "objectLockEnabled" = mkOverride 1002 null;
        "observedGeneration" = mkOverride 1002 null;
        "ownerIdentity" = mkOverride 1002 null;
        "phase" = mkOverride 1002 null;
        "quota" = mkOverride 1002 null;
        "usage" = mkOverride 1002 null;
        "versioning" = mkOverride 1002 null;
      };

    };
    "seaweed.seaweedfs.com.v1.BucketStatusConditions" = {

      options = {
        "lastTransitionTime" = mkOption {
          description = "";
          type = types.str;
        };
        "message" = mkOption {
          description = "";
          type = types.str;
        };
        "observedGeneration" = mkOption {
          description = "";
          type = types.nullOr types.int;
        };
        "reason" = mkOption {
          description = "";
          type = types.str;
        };
        "status" = mkOption {
          description = "";
          type = types.str;
        };
        "type" = mkOption {
          description = "";
          type = types.str;
        };
      };

      config = {
        "observedGeneration" = mkOverride 1002 null;
      };

    };
    "seaweed.seaweedfs.com.v1.BucketStatusQuota" = {

      options = {
        "enforced" = mkOption {
          description = "";
          type = types.nullOr types.bool;
        };
        "sizeBytes" = mkOption {
          description = "";
          type = types.nullOr types.int;
        };
      };

      config = {
        "enforced" = mkOverride 1002 null;
        "sizeBytes" = mkOverride 1002 null;
      };

    };
    "seaweed.seaweedfs.com.v1.BucketStatusUsage" = {

      options = {
        "lastUpdated" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "objectCount" = mkOption {
          description = "";
          type = types.nullOr types.int;
        };
        "sizeBytes" = mkOption {
          description = "";
          type = types.nullOr types.int;
        };
      };

      config = {
        "lastUpdated" = mkOverride 1002 null;
        "objectCount" = mkOverride 1002 null;
        "sizeBytes" = mkOverride 1002 null;
      };

    };
    "seaweed.seaweedfs.com.v1.ResourceReferenceGrant" = {

      options = {
        "apiVersion" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "kind" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "metadata" = mkOption {
          description = "Standard object's metadata. More info: https://git.k8s.io/community/contributors/devel/sig-architecture/api-conventions.md#metadata";
          type = types.nullOr (globalSubmoduleOf "io.k8s.apimachinery.pkg.apis.meta.v1.ObjectMeta");
        };
        "spec" = mkOption {
          description = "";
          type = types.nullOr (submoduleOf "seaweed.seaweedfs.com.v1.ResourceReferenceGrantSpec");
        };
      };

      config = {
        "apiVersion" = mkOverride 1002 null;
        "kind" = mkOverride 1002 null;
        "metadata" = mkOverride 1002 null;
        "spec" = mkOverride 1002 null;
      };

    };
    "seaweed.seaweedfs.com.v1.ResourceReferenceGrantSpec" = {

      options = {
        "from" = mkOption {
          description = "";
          type = types.listOf (submoduleOf "seaweed.seaweedfs.com.v1.ResourceReferenceGrantSpecFrom");
        };
        "to" = mkOption {
          description = "";
          type =
            coerceAttrsOfSubmodulesToListByKey "seaweed.seaweedfs.com.v1.ResourceReferenceGrantSpecTo" "name"
              [ ];
          apply = attrsToList;
        };
      };

      config = { };

    };
    "seaweed.seaweedfs.com.v1.ResourceReferenceGrantSpecFrom" = {

      options = {
        "group" = mkOption {
          description = "";
          type = types.str;
        };
        "kind" = mkOption {
          description = "";
          type = types.str;
        };
        "namespace" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "namespaceSelector" = mkOption {
          description = "";
          type = types.nullOr (
            submoduleOf "seaweed.seaweedfs.com.v1.ResourceReferenceGrantSpecFromNamespaceSelector"
          );
        };
      };

      config = {
        "namespace" = mkOverride 1002 null;
        "namespaceSelector" = mkOverride 1002 null;
      };

    };
    "seaweed.seaweedfs.com.v1.ResourceReferenceGrantSpecFromNamespaceSelector" = {

      options = {
        "matchExpressions" = mkOption {
          description = "";
          type = types.nullOr (
            types.listOf (
              submoduleOf "seaweed.seaweedfs.com.v1.ResourceReferenceGrantSpecFromNamespaceSelectorMatchExpressions"
            )
          );
        };
        "matchLabels" = mkOption {
          description = "";
          type = types.nullOr (types.attrsOf types.str);
        };
      };

      config = {
        "matchExpressions" = mkOverride 1002 null;
        "matchLabels" = mkOverride 1002 null;
      };

    };
    "seaweed.seaweedfs.com.v1.ResourceReferenceGrantSpecFromNamespaceSelectorMatchExpressions" = {

      options = {
        "key" = mkOption {
          description = "";
          type = types.str;
        };
        "operator" = mkOption {
          description = "";
          type = types.str;
        };
        "values" = mkOption {
          description = "";
          type = types.nullOr (types.listOf types.str);
        };
      };

      config = {
        "values" = mkOverride 1002 null;
      };

    };
    "seaweed.seaweedfs.com.v1.ResourceReferenceGrantSpecTo" = {

      options = {
        "group" = mkOption {
          description = "";
          type = types.str;
        };
        "kind" = mkOption {
          description = "";
          type = types.str;
        };
        "name" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
      };

      config = {
        "name" = mkOverride 1002 null;
      };

    };
    "seaweed.seaweedfs.com.v1.S3Credentials" = {

      options = {
        "apiVersion" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "kind" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "metadata" = mkOption {
          description = "Standard object's metadata. More info: https://git.k8s.io/community/contributors/devel/sig-architecture/api-conventions.md#metadata";
          type = types.nullOr (globalSubmoduleOf "io.k8s.apimachinery.pkg.apis.meta.v1.ObjectMeta");
        };
        "spec" = mkOption {
          description = "";
          type = types.nullOr (submoduleOf "seaweed.seaweedfs.com.v1.S3CredentialsSpec");
        };
        "status" = mkOption {
          description = "";
          type = types.nullOr (submoduleOf "seaweed.seaweedfs.com.v1.S3CredentialsStatus");
        };
      };

      config = {
        "apiVersion" = mkOverride 1002 null;
        "kind" = mkOverride 1002 null;
        "metadata" = mkOverride 1002 null;
        "spec" = mkOverride 1002 null;
        "status" = mkOverride 1002 null;
      };

    };
    "seaweed.seaweedfs.com.v1.S3CredentialsSpec" = {

      options = {
        "identityRef" = mkOption {
          description = "";
          type = submoduleOf "seaweed.seaweedfs.com.v1.S3CredentialsSpecIdentityRef";
        };
        "reclaimPolicy" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "seaweedRef" = mkOption {
          description = "";
          type = submoduleOf "seaweed.seaweedfs.com.v1.S3CredentialsSpecSeaweedRef";
        };
        "secretRef" = mkOption {
          description = "";
          type = types.nullOr (submoduleOf "seaweed.seaweedfs.com.v1.S3CredentialsSpecSecretRef");
        };
      };

      config = {
        "reclaimPolicy" = mkOverride 1002 null;
        "secretRef" = mkOverride 1002 null;
      };

    };
    "seaweed.seaweedfs.com.v1.S3CredentialsSpecIdentityRef" = {

      options = {
        "name" = mkOption {
          description = "";
          type = types.str;
        };
      };

      config = { };

    };
    "seaweed.seaweedfs.com.v1.S3CredentialsSpecSeaweedRef" = {

      options = {
        "name" = mkOption {
          description = "";
          type = types.str;
        };
        "namespace" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
      };

      config = {
        "namespace" = mkOverride 1002 null;
      };

    };
    "seaweed.seaweedfs.com.v1.S3CredentialsSpecSecretRef" = {

      options = {
        "accessKeyField" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "name" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "namespace" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "secretKeyField" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
      };

      config = {
        "accessKeyField" = mkOverride 1002 null;
        "name" = mkOverride 1002 null;
        "namespace" = mkOverride 1002 null;
        "secretKeyField" = mkOverride 1002 null;
      };

    };
    "seaweed.seaweedfs.com.v1.S3CredentialsStatus" = {

      options = {
        "accessKey" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "conditions" = mkOption {
          description = "";
          type = types.nullOr (
            types.listOf (submoduleOf "seaweed.seaweedfs.com.v1.S3CredentialsStatusConditions")
          );
        };
        "identityName" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "observedGeneration" = mkOption {
          description = "";
          type = types.nullOr types.int;
        };
        "phase" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "secretName" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
      };

      config = {
        "accessKey" = mkOverride 1002 null;
        "conditions" = mkOverride 1002 null;
        "identityName" = mkOverride 1002 null;
        "observedGeneration" = mkOverride 1002 null;
        "phase" = mkOverride 1002 null;
        "secretName" = mkOverride 1002 null;
      };

    };
    "seaweed.seaweedfs.com.v1.S3CredentialsStatusConditions" = {

      options = {
        "lastTransitionTime" = mkOption {
          description = "";
          type = types.str;
        };
        "message" = mkOption {
          description = "";
          type = types.str;
        };
        "observedGeneration" = mkOption {
          description = "";
          type = types.nullOr types.int;
        };
        "reason" = mkOption {
          description = "";
          type = types.str;
        };
        "status" = mkOption {
          description = "";
          type = types.str;
        };
        "type" = mkOption {
          description = "";
          type = types.str;
        };
      };

      config = {
        "observedGeneration" = mkOverride 1002 null;
      };

    };
    "seaweed.seaweedfs.com.v1.S3Identity" = {

      options = {
        "apiVersion" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "kind" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "metadata" = mkOption {
          description = "Standard object's metadata. More info: https://git.k8s.io/community/contributors/devel/sig-architecture/api-conventions.md#metadata";
          type = types.nullOr (globalSubmoduleOf "io.k8s.apimachinery.pkg.apis.meta.v1.ObjectMeta");
        };
        "spec" = mkOption {
          description = "";
          type = types.nullOr (submoduleOf "seaweed.seaweedfs.com.v1.S3IdentitySpec");
        };
        "status" = mkOption {
          description = "";
          type = types.nullOr (submoduleOf "seaweed.seaweedfs.com.v1.S3IdentityStatus");
        };
      };

      config = {
        "apiVersion" = mkOverride 1002 null;
        "kind" = mkOverride 1002 null;
        "metadata" = mkOverride 1002 null;
        "spec" = mkOverride 1002 null;
        "status" = mkOverride 1002 null;
      };

    };
    "seaweed.seaweedfs.com.v1.S3IdentitySpec" = {

      options = {
        "account" = mkOption {
          description = "";
          type = types.nullOr (submoduleOf "seaweed.seaweedfs.com.v1.S3IdentitySpecAccount");
        };
        "disabled" = mkOption {
          description = "";
          type = types.nullOr types.bool;
        };
        "name" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "reclaimPolicy" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "seaweedRef" = mkOption {
          description = "";
          type = submoduleOf "seaweed.seaweedfs.com.v1.S3IdentitySpecSeaweedRef";
        };
      };

      config = {
        "account" = mkOverride 1002 null;
        "disabled" = mkOverride 1002 null;
        "name" = mkOverride 1002 null;
        "reclaimPolicy" = mkOverride 1002 null;
      };

    };
    "seaweed.seaweedfs.com.v1.S3IdentitySpecAccount" = {

      options = {
        "displayName" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "email" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
      };

      config = {
        "displayName" = mkOverride 1002 null;
        "email" = mkOverride 1002 null;
      };

    };
    "seaweed.seaweedfs.com.v1.S3IdentitySpecSeaweedRef" = {

      options = {
        "name" = mkOption {
          description = "";
          type = types.str;
        };
        "namespace" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
      };

      config = {
        "namespace" = mkOverride 1002 null;
      };

    };
    "seaweed.seaweedfs.com.v1.S3IdentityStatus" = {

      options = {
        "conditions" = mkOption {
          description = "";
          type = types.nullOr (
            types.listOf (submoduleOf "seaweed.seaweedfs.com.v1.S3IdentityStatusConditions")
          );
        };
        "identityName" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "observedGeneration" = mkOption {
          description = "";
          type = types.nullOr types.int;
        };
        "phase" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
      };

      config = {
        "conditions" = mkOverride 1002 null;
        "identityName" = mkOverride 1002 null;
        "observedGeneration" = mkOverride 1002 null;
        "phase" = mkOverride 1002 null;
      };

    };
    "seaweed.seaweedfs.com.v1.S3IdentityStatusConditions" = {

      options = {
        "lastTransitionTime" = mkOption {
          description = "";
          type = types.str;
        };
        "message" = mkOption {
          description = "";
          type = types.str;
        };
        "observedGeneration" = mkOption {
          description = "";
          type = types.nullOr types.int;
        };
        "reason" = mkOption {
          description = "";
          type = types.str;
        };
        "status" = mkOption {
          description = "";
          type = types.str;
        };
        "type" = mkOption {
          description = "";
          type = types.str;
        };
      };

      config = {
        "observedGeneration" = mkOverride 1002 null;
      };

    };
    "seaweed.seaweedfs.com.v1.S3OIDCProvider" = {

      options = {
        "apiVersion" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "kind" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "metadata" = mkOption {
          description = "Standard object's metadata. More info: https://git.k8s.io/community/contributors/devel/sig-architecture/api-conventions.md#metadata";
          type = types.nullOr (globalSubmoduleOf "io.k8s.apimachinery.pkg.apis.meta.v1.ObjectMeta");
        };
        "spec" = mkOption {
          description = "";
          type = types.nullOr (submoduleOf "seaweed.seaweedfs.com.v1.S3OIDCProviderSpec");
        };
        "status" = mkOption {
          description = "";
          type = types.nullOr (submoduleOf "seaweed.seaweedfs.com.v1.S3OIDCProviderStatus");
        };
      };

      config = {
        "apiVersion" = mkOverride 1002 null;
        "kind" = mkOverride 1002 null;
        "metadata" = mkOverride 1002 null;
        "spec" = mkOverride 1002 null;
        "status" = mkOverride 1002 null;
      };

    };
    "seaweed.seaweedfs.com.v1.S3OIDCProviderSpec" = {

      options = {
        "clientIDs" = mkOption {
          description = "";
          type = types.listOf types.str;
        };
        "issuerURL" = mkOption {
          description = "";
          type = types.str;
        };
        "reclaimPolicy" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "seaweedRef" = mkOption {
          description = "";
          type = submoduleOf "seaweed.seaweedfs.com.v1.S3OIDCProviderSpecSeaweedRef";
        };
        "thumbprints" = mkOption {
          description = "";
          type = types.nullOr (types.listOf types.str);
        };
      };

      config = {
        "reclaimPolicy" = mkOverride 1002 null;
        "thumbprints" = mkOverride 1002 null;
      };

    };
    "seaweed.seaweedfs.com.v1.S3OIDCProviderSpecSeaweedRef" = {

      options = {
        "name" = mkOption {
          description = "";
          type = types.str;
        };
        "namespace" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
      };

      config = {
        "namespace" = mkOverride 1002 null;
      };

    };
    "seaweed.seaweedfs.com.v1.S3OIDCProviderStatus" = {

      options = {
        "conditions" = mkOption {
          description = "";
          type = types.nullOr (
            types.listOf (submoduleOf "seaweed.seaweedfs.com.v1.S3OIDCProviderStatusConditions")
          );
        };
        "observedGeneration" = mkOption {
          description = "";
          type = types.nullOr types.int;
        };
        "phase" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "providerArn" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
      };

      config = {
        "conditions" = mkOverride 1002 null;
        "observedGeneration" = mkOverride 1002 null;
        "phase" = mkOverride 1002 null;
        "providerArn" = mkOverride 1002 null;
      };

    };
    "seaweed.seaweedfs.com.v1.S3OIDCProviderStatusConditions" = {

      options = {
        "lastTransitionTime" = mkOption {
          description = "";
          type = types.str;
        };
        "message" = mkOption {
          description = "";
          type = types.str;
        };
        "observedGeneration" = mkOption {
          description = "";
          type = types.nullOr types.int;
        };
        "reason" = mkOption {
          description = "";
          type = types.str;
        };
        "status" = mkOption {
          description = "";
          type = types.str;
        };
        "type" = mkOption {
          description = "";
          type = types.str;
        };
      };

      config = {
        "observedGeneration" = mkOverride 1002 null;
      };

    };
    "seaweed.seaweedfs.com.v1.S3Policy" = {

      options = {
        "apiVersion" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "kind" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "metadata" = mkOption {
          description = "Standard object's metadata. More info: https://git.k8s.io/community/contributors/devel/sig-architecture/api-conventions.md#metadata";
          type = types.nullOr (globalSubmoduleOf "io.k8s.apimachinery.pkg.apis.meta.v1.ObjectMeta");
        };
        "spec" = mkOption {
          description = "";
          type = types.nullOr (submoduleOf "seaweed.seaweedfs.com.v1.S3PolicySpec");
        };
        "status" = mkOption {
          description = "";
          type = types.nullOr (submoduleOf "seaweed.seaweedfs.com.v1.S3PolicyStatus");
        };
      };

      config = {
        "apiVersion" = mkOverride 1002 null;
        "kind" = mkOverride 1002 null;
        "metadata" = mkOverride 1002 null;
        "spec" = mkOverride 1002 null;
        "status" = mkOverride 1002 null;
      };

    };
    "seaweed.seaweedfs.com.v1.S3PolicyBinding" = {

      options = {
        "apiVersion" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "kind" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "metadata" = mkOption {
          description = "Standard object's metadata. More info: https://git.k8s.io/community/contributors/devel/sig-architecture/api-conventions.md#metadata";
          type = types.nullOr (globalSubmoduleOf "io.k8s.apimachinery.pkg.apis.meta.v1.ObjectMeta");
        };
        "spec" = mkOption {
          description = "";
          type = types.nullOr (submoduleOf "seaweed.seaweedfs.com.v1.S3PolicyBindingSpec");
        };
        "status" = mkOption {
          description = "";
          type = types.nullOr (submoduleOf "seaweed.seaweedfs.com.v1.S3PolicyBindingStatus");
        };
      };

      config = {
        "apiVersion" = mkOverride 1002 null;
        "kind" = mkOverride 1002 null;
        "metadata" = mkOverride 1002 null;
        "spec" = mkOverride 1002 null;
        "status" = mkOverride 1002 null;
      };

    };
    "seaweed.seaweedfs.com.v1.S3PolicyBindingSpec" = {

      options = {
        "policyRef" = mkOption {
          description = "";
          type = submoduleOf "seaweed.seaweedfs.com.v1.S3PolicyBindingSpecPolicyRef";
        };
        "reclaimPolicy" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "seaweedRef" = mkOption {
          description = "";
          type = submoduleOf "seaweed.seaweedfs.com.v1.S3PolicyBindingSpecSeaweedRef";
        };
        "subjects" = mkOption {
          description = "";
          type =
            coerceAttrsOfSubmodulesToListByKey "seaweed.seaweedfs.com.v1.S3PolicyBindingSpecSubjects" "name"
              [
                "name"
              ];
          apply = attrsToList;
        };
      };

      config = {
        "reclaimPolicy" = mkOverride 1002 null;
      };

    };
    "seaweed.seaweedfs.com.v1.S3PolicyBindingSpecPolicyRef" = {

      options = {
        "name" = mkOption {
          description = "";
          type = types.str;
        };
      };

      config = { };

    };
    "seaweed.seaweedfs.com.v1.S3PolicyBindingSpecSeaweedRef" = {

      options = {
        "name" = mkOption {
          description = "";
          type = types.str;
        };
        "namespace" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
      };

      config = {
        "namespace" = mkOverride 1002 null;
      };

    };
    "seaweed.seaweedfs.com.v1.S3PolicyBindingSpecSubjects" = {

      options = {
        "kind" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "name" = mkOption {
          description = "";
          type = types.str;
        };
      };

      config = {
        "kind" = mkOverride 1002 null;
      };

    };
    "seaweed.seaweedfs.com.v1.S3PolicyBindingStatus" = {

      options = {
        "attachedSubjects" = mkOption {
          description = "";
          type = types.nullOr (types.listOf types.str);
        };
        "conditions" = mkOption {
          description = "";
          type = types.nullOr (
            types.listOf (submoduleOf "seaweed.seaweedfs.com.v1.S3PolicyBindingStatusConditions")
          );
        };
        "observedGeneration" = mkOption {
          description = "";
          type = types.nullOr types.int;
        };
        "phase" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "policyName" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
      };

      config = {
        "attachedSubjects" = mkOverride 1002 null;
        "conditions" = mkOverride 1002 null;
        "observedGeneration" = mkOverride 1002 null;
        "phase" = mkOverride 1002 null;
        "policyName" = mkOverride 1002 null;
      };

    };
    "seaweed.seaweedfs.com.v1.S3PolicyBindingStatusConditions" = {

      options = {
        "lastTransitionTime" = mkOption {
          description = "";
          type = types.str;
        };
        "message" = mkOption {
          description = "";
          type = types.str;
        };
        "observedGeneration" = mkOption {
          description = "";
          type = types.nullOr types.int;
        };
        "reason" = mkOption {
          description = "";
          type = types.str;
        };
        "status" = mkOption {
          description = "";
          type = types.str;
        };
        "type" = mkOption {
          description = "";
          type = types.str;
        };
      };

      config = {
        "observedGeneration" = mkOverride 1002 null;
      };

    };
    "seaweed.seaweedfs.com.v1.S3PolicySpec" = {

      options = {
        "name" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "policyDocument" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "reclaimPolicy" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "seaweedRef" = mkOption {
          description = "";
          type = submoduleOf "seaweed.seaweedfs.com.v1.S3PolicySpecSeaweedRef";
        };
        "statements" = mkOption {
          description = "";
          type = types.nullOr (types.listOf (submoduleOf "seaweed.seaweedfs.com.v1.S3PolicySpecStatements"));
        };
      };

      config = {
        "name" = mkOverride 1002 null;
        "policyDocument" = mkOverride 1002 null;
        "reclaimPolicy" = mkOverride 1002 null;
        "statements" = mkOverride 1002 null;
      };

    };
    "seaweed.seaweedfs.com.v1.S3PolicySpecSeaweedRef" = {

      options = {
        "name" = mkOption {
          description = "";
          type = types.str;
        };
        "namespace" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
      };

      config = {
        "namespace" = mkOverride 1002 null;
      };

    };
    "seaweed.seaweedfs.com.v1.S3PolicySpecStatements" = {

      options = {
        "actions" = mkOption {
          description = "";
          type = types.listOf types.str;
        };
        "effect" = mkOption {
          description = "";
          type = types.str;
        };
        "resources" = mkOption {
          description = "";
          type = types.listOf types.str;
        };
        "sid" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
      };

      config = {
        "sid" = mkOverride 1002 null;
      };

    };
    "seaweed.seaweedfs.com.v1.S3PolicyStatus" = {

      options = {
        "conditions" = mkOption {
          description = "";
          type = types.nullOr (
            types.listOf (submoduleOf "seaweed.seaweedfs.com.v1.S3PolicyStatusConditions")
          );
        };
        "observedGeneration" = mkOption {
          description = "";
          type = types.nullOr types.int;
        };
        "phase" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "policyName" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
      };

      config = {
        "conditions" = mkOverride 1002 null;
        "observedGeneration" = mkOverride 1002 null;
        "phase" = mkOverride 1002 null;
        "policyName" = mkOverride 1002 null;
      };

    };
    "seaweed.seaweedfs.com.v1.S3PolicyStatusConditions" = {

      options = {
        "lastTransitionTime" = mkOption {
          description = "";
          type = types.str;
        };
        "message" = mkOption {
          description = "";
          type = types.str;
        };
        "observedGeneration" = mkOption {
          description = "";
          type = types.nullOr types.int;
        };
        "reason" = mkOption {
          description = "";
          type = types.str;
        };
        "status" = mkOption {
          description = "";
          type = types.str;
        };
        "type" = mkOption {
          description = "";
          type = types.str;
        };
      };

      config = {
        "observedGeneration" = mkOverride 1002 null;
      };

    };
    "seaweed.seaweedfs.com.v1.Seaweed" = {

      options = {
        "apiVersion" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "kind" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "metadata" = mkOption {
          description = "Standard object's metadata. More info: https://git.k8s.io/community/contributors/devel/sig-architecture/api-conventions.md#metadata";
          type = types.nullOr (globalSubmoduleOf "io.k8s.apimachinery.pkg.apis.meta.v1.ObjectMeta");
        };
        "spec" = mkOption {
          description = "";
          type = types.nullOr (submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpec");
        };
        "status" = mkOption {
          description = "";
          type = types.nullOr (submoduleOf "seaweed.seaweedfs.com.v1.SeaweedStatus");
        };
      };

      config = {
        "apiVersion" = mkOverride 1002 null;
        "kind" = mkOverride 1002 null;
        "metadata" = mkOverride 1002 null;
        "spec" = mkOverride 1002 null;
        "status" = mkOverride 1002 null;
      };

    };
    "seaweed.seaweedfs.com.v1.SeaweedBackup" = {

      options = {
        "apiVersion" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "kind" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "metadata" = mkOption {
          description = "Standard object's metadata. More info: https://git.k8s.io/community/contributors/devel/sig-architecture/api-conventions.md#metadata";
          type = types.nullOr (globalSubmoduleOf "io.k8s.apimachinery.pkg.apis.meta.v1.ObjectMeta");
        };
        "spec" = mkOption {
          description = "";
          type = types.nullOr (submoduleOf "seaweed.seaweedfs.com.v1.SeaweedBackupSpec");
        };
        "status" = mkOption {
          description = "";
          type = types.nullOr (submoduleOf "seaweed.seaweedfs.com.v1.SeaweedBackupStatus");
        };
      };

      config = {
        "apiVersion" = mkOverride 1002 null;
        "kind" = mkOverride 1002 null;
        "metadata" = mkOverride 1002 null;
        "spec" = mkOverride 1002 null;
        "status" = mkOverride 1002 null;
      };

    };
    "seaweed.seaweedfs.com.v1.SeaweedBackupSpec" = {

      options = {
        "clusterName" = mkOption {
          description = "";
          type = types.str;
        };
        "filerPath" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "storageName" = mkOption {
          description = "";
          type = types.str;
        };
      };

      config = {
        "filerPath" = mkOverride 1002 null;
      };

    };
    "seaweed.seaweedfs.com.v1.SeaweedBackupStatus" = {

      options = {
        "completionTime" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "conditions" = mkOption {
          description = "";
          type = types.nullOr (
            types.listOf (submoduleOf "seaweed.seaweedfs.com.v1.SeaweedBackupStatusConditions")
          );
        };
        "destination" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "jobName" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "observedGeneration" = mkOption {
          description = "";
          type = types.nullOr types.int;
        };
        "phase" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "startTime" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
      };

      config = {
        "completionTime" = mkOverride 1002 null;
        "conditions" = mkOverride 1002 null;
        "destination" = mkOverride 1002 null;
        "jobName" = mkOverride 1002 null;
        "observedGeneration" = mkOverride 1002 null;
        "phase" = mkOverride 1002 null;
        "startTime" = mkOverride 1002 null;
      };

    };
    "seaweed.seaweedfs.com.v1.SeaweedBackupStatusConditions" = {

      options = {
        "lastTransitionTime" = mkOption {
          description = "";
          type = types.str;
        };
        "message" = mkOption {
          description = "";
          type = types.str;
        };
        "observedGeneration" = mkOption {
          description = "";
          type = types.nullOr types.int;
        };
        "reason" = mkOption {
          description = "";
          type = types.str;
        };
        "status" = mkOption {
          description = "";
          type = types.str;
        };
        "type" = mkOption {
          description = "";
          type = types.str;
        };
      };

      config = {
        "observedGeneration" = mkOverride 1002 null;
      };

    };
    "seaweed.seaweedfs.com.v1.SeaweedCSIDriver" = {

      options = {
        "apiVersion" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "kind" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "metadata" = mkOption {
          description = "Standard object's metadata. More info: https://git.k8s.io/community/contributors/devel/sig-architecture/api-conventions.md#metadata";
          type = types.nullOr (globalSubmoduleOf "io.k8s.apimachinery.pkg.apis.meta.v1.ObjectMeta");
        };
        "spec" = mkOption {
          description = "";
          type = types.nullOr (submoduleOf "seaweed.seaweedfs.com.v1.SeaweedCSIDriverSpec");
        };
        "status" = mkOption {
          description = "";
          type = types.nullOr (submoduleOf "seaweed.seaweedfs.com.v1.SeaweedCSIDriverStatus");
        };
      };

      config = {
        "apiVersion" = mkOverride 1002 null;
        "kind" = mkOverride 1002 null;
        "metadata" = mkOverride 1002 null;
        "spec" = mkOverride 1002 null;
        "status" = mkOverride 1002 null;
      };

    };
    "seaweed.seaweedfs.com.v1.SeaweedCSIDriverSpec" = {

      options = {
        "cacheCapacityMB" = mkOption {
          description = "";
          type = types.nullOr types.int;
        };
        "concurrentReaders" = mkOption {
          description = "";
          type = types.nullOr types.int;
        };
        "concurrentWriters" = mkOption {
          description = "";
          type = types.nullOr types.int;
        };
        "controller" = mkOption {
          description = "";
          type = types.nullOr (submoduleOf "seaweed.seaweedfs.com.v1.SeaweedCSIDriverSpecController");
        };
        "driverName" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "filerAddress" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "image" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "imagePullPolicy" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "imagePullSecrets" = mkOption {
          description = "";
          type = types.nullOr (
            coerceAttrsOfSubmodulesToListByKey "seaweed.seaweedfs.com.v1.SeaweedCSIDriverSpecImagePullSecrets"
              "name"
              [ ]
          );
          apply = attrsToList;
        };
        "logVerbosity" = mkOption {
          description = "";
          type = types.nullOr types.int;
        };
        "mountService" = mkOption {
          description = "";
          type = types.nullOr (submoduleOf "seaweed.seaweedfs.com.v1.SeaweedCSIDriverSpecMountService");
        };
        "node" = mkOption {
          description = "";
          type = types.nullOr (submoduleOf "seaweed.seaweedfs.com.v1.SeaweedCSIDriverSpecNode");
        };
        "seaweedRef" = mkOption {
          description = "";
          type = types.nullOr (submoduleOf "seaweed.seaweedfs.com.v1.SeaweedCSIDriverSpecSeaweedRef");
        };
        "sidecars" = mkOption {
          description = "";
          type = types.nullOr (submoduleOf "seaweed.seaweedfs.com.v1.SeaweedCSIDriverSpecSidecars");
        };
        "storageClass" = mkOption {
          description = "";
          type = types.nullOr (submoduleOf "seaweed.seaweedfs.com.v1.SeaweedCSIDriverSpecStorageClass");
        };
      };

      config = {
        "cacheCapacityMB" = mkOverride 1002 null;
        "concurrentReaders" = mkOverride 1002 null;
        "concurrentWriters" = mkOverride 1002 null;
        "controller" = mkOverride 1002 null;
        "driverName" = mkOverride 1002 null;
        "filerAddress" = mkOverride 1002 null;
        "image" = mkOverride 1002 null;
        "imagePullPolicy" = mkOverride 1002 null;
        "imagePullSecrets" = mkOverride 1002 null;
        "logVerbosity" = mkOverride 1002 null;
        "mountService" = mkOverride 1002 null;
        "node" = mkOverride 1002 null;
        "seaweedRef" = mkOverride 1002 null;
        "sidecars" = mkOverride 1002 null;
        "storageClass" = mkOverride 1002 null;
      };

    };
    "seaweed.seaweedfs.com.v1.SeaweedCSIDriverSpecController" = {

      options = {
        "affinity" = mkOption {
          description = "";
          type = types.nullOr (submoduleOf "seaweed.seaweedfs.com.v1.SeaweedCSIDriverSpecControllerAffinity");
        };
        "attacherEnabled" = mkOption {
          description = "";
          type = types.nullOr types.bool;
        };
        "nodeSelector" = mkOption {
          description = "";
          type = types.nullOr (types.attrsOf types.str);
        };
        "replicas" = mkOption {
          description = "";
          type = types.nullOr types.int;
        };
        "resources" = mkOption {
          description = "";
          type = types.nullOr (
            submoduleOf "seaweed.seaweedfs.com.v1.SeaweedCSIDriverSpecControllerResources"
          );
        };
        "tolerations" = mkOption {
          description = "";
          type = types.nullOr (
            types.listOf (submoduleOf "seaweed.seaweedfs.com.v1.SeaweedCSIDriverSpecControllerTolerations")
          );
        };
      };

      config = {
        "affinity" = mkOverride 1002 null;
        "attacherEnabled" = mkOverride 1002 null;
        "nodeSelector" = mkOverride 1002 null;
        "replicas" = mkOverride 1002 null;
        "resources" = mkOverride 1002 null;
        "tolerations" = mkOverride 1002 null;
      };

    };
    "seaweed.seaweedfs.com.v1.SeaweedCSIDriverSpecControllerAffinity" = {

      options = {
        "nodeAffinity" = mkOption {
          description = "";
          type = types.nullOr (
            submoduleOf "seaweed.seaweedfs.com.v1.SeaweedCSIDriverSpecControllerAffinityNodeAffinity"
          );
        };
        "podAffinity" = mkOption {
          description = "";
          type = types.nullOr (
            submoduleOf "seaweed.seaweedfs.com.v1.SeaweedCSIDriverSpecControllerAffinityPodAffinity"
          );
        };
        "podAntiAffinity" = mkOption {
          description = "";
          type = types.nullOr (
            submoduleOf "seaweed.seaweedfs.com.v1.SeaweedCSIDriverSpecControllerAffinityPodAntiAffinity"
          );
        };
      };

      config = {
        "nodeAffinity" = mkOverride 1002 null;
        "podAffinity" = mkOverride 1002 null;
        "podAntiAffinity" = mkOverride 1002 null;
      };

    };
    "seaweed.seaweedfs.com.v1.SeaweedCSIDriverSpecControllerAffinityNodeAffinity" = {

      options = {
        "preferredDuringSchedulingIgnoredDuringExecution" = mkOption {
          description = "";
          type = types.nullOr (
            types.listOf (
              submoduleOf "seaweed.seaweedfs.com.v1.SeaweedCSIDriverSpecControllerAffinityNodeAffinityPreferredDuringSchedulingIgnoredDuringExecution"
            )
          );
        };
        "requiredDuringSchedulingIgnoredDuringExecution" = mkOption {
          description = "";
          type = types.nullOr (
            submoduleOf "seaweed.seaweedfs.com.v1.SeaweedCSIDriverSpecControllerAffinityNodeAffinityRequiredDuringSchedulingIgnoredDuringExecution"
          );
        };
      };

      config = {
        "preferredDuringSchedulingIgnoredDuringExecution" = mkOverride 1002 null;
        "requiredDuringSchedulingIgnoredDuringExecution" = mkOverride 1002 null;
      };

    };
    "seaweed.seaweedfs.com.v1.SeaweedCSIDriverSpecControllerAffinityNodeAffinityPreferredDuringSchedulingIgnoredDuringExecution" =
      {

        options = {
          "preference" = mkOption {
            description = "";
            type = submoduleOf "seaweed.seaweedfs.com.v1.SeaweedCSIDriverSpecControllerAffinityNodeAffinityPreferredDuringSchedulingIgnoredDuringExecutionPreference";
          };
          "weight" = mkOption {
            description = "";
            type = types.int;
          };
        };

        config = { };

      };
    "seaweed.seaweedfs.com.v1.SeaweedCSIDriverSpecControllerAffinityNodeAffinityPreferredDuringSchedulingIgnoredDuringExecutionPreference" =
      {

        options = {
          "matchExpressions" = mkOption {
            description = "";
            type = types.nullOr (
              types.listOf (
                submoduleOf "seaweed.seaweedfs.com.v1.SeaweedCSIDriverSpecControllerAffinityNodeAffinityPreferredDuringSchedulingIgnoredDuringExecutionPreferenceMatchExpressions"
              )
            );
          };
          "matchFields" = mkOption {
            description = "";
            type = types.nullOr (
              types.listOf (
                submoduleOf "seaweed.seaweedfs.com.v1.SeaweedCSIDriverSpecControllerAffinityNodeAffinityPreferredDuringSchedulingIgnoredDuringExecutionPreferenceMatchFields"
              )
            );
          };
        };

        config = {
          "matchExpressions" = mkOverride 1002 null;
          "matchFields" = mkOverride 1002 null;
        };

      };
    "seaweed.seaweedfs.com.v1.SeaweedCSIDriverSpecControllerAffinityNodeAffinityPreferredDuringSchedulingIgnoredDuringExecutionPreferenceMatchExpressions" =
      {

        options = {
          "key" = mkOption {
            description = "";
            type = types.str;
          };
          "operator" = mkOption {
            description = "";
            type = types.str;
          };
          "values" = mkOption {
            description = "";
            type = types.nullOr (types.listOf types.str);
          };
        };

        config = {
          "values" = mkOverride 1002 null;
        };

      };
    "seaweed.seaweedfs.com.v1.SeaweedCSIDriverSpecControllerAffinityNodeAffinityPreferredDuringSchedulingIgnoredDuringExecutionPreferenceMatchFields" =
      {

        options = {
          "key" = mkOption {
            description = "";
            type = types.str;
          };
          "operator" = mkOption {
            description = "";
            type = types.str;
          };
          "values" = mkOption {
            description = "";
            type = types.nullOr (types.listOf types.str);
          };
        };

        config = {
          "values" = mkOverride 1002 null;
        };

      };
    "seaweed.seaweedfs.com.v1.SeaweedCSIDriverSpecControllerAffinityNodeAffinityRequiredDuringSchedulingIgnoredDuringExecution" =
      {

        options = {
          "nodeSelectorTerms" = mkOption {
            description = "";
            type = types.listOf (
              submoduleOf "seaweed.seaweedfs.com.v1.SeaweedCSIDriverSpecControllerAffinityNodeAffinityRequiredDuringSchedulingIgnoredDuringExecutionNodeSelectorTerms"
            );
          };
        };

        config = { };

      };
    "seaweed.seaweedfs.com.v1.SeaweedCSIDriverSpecControllerAffinityNodeAffinityRequiredDuringSchedulingIgnoredDuringExecutionNodeSelectorTerms" =
      {

        options = {
          "matchExpressions" = mkOption {
            description = "";
            type = types.nullOr (
              types.listOf (
                submoduleOf "seaweed.seaweedfs.com.v1.SeaweedCSIDriverSpecControllerAffinityNodeAffinityRequiredDuringSchedulingIgnoredDuringExecutionNodeSelectorTermsMatchExpressions"
              )
            );
          };
          "matchFields" = mkOption {
            description = "";
            type = types.nullOr (
              types.listOf (
                submoduleOf "seaweed.seaweedfs.com.v1.SeaweedCSIDriverSpecControllerAffinityNodeAffinityRequiredDuringSchedulingIgnoredDuringExecutionNodeSelectorTermsMatchFields"
              )
            );
          };
        };

        config = {
          "matchExpressions" = mkOverride 1002 null;
          "matchFields" = mkOverride 1002 null;
        };

      };
    "seaweed.seaweedfs.com.v1.SeaweedCSIDriverSpecControllerAffinityNodeAffinityRequiredDuringSchedulingIgnoredDuringExecutionNodeSelectorTermsMatchExpressions" =
      {

        options = {
          "key" = mkOption {
            description = "";
            type = types.str;
          };
          "operator" = mkOption {
            description = "";
            type = types.str;
          };
          "values" = mkOption {
            description = "";
            type = types.nullOr (types.listOf types.str);
          };
        };

        config = {
          "values" = mkOverride 1002 null;
        };

      };
    "seaweed.seaweedfs.com.v1.SeaweedCSIDriverSpecControllerAffinityNodeAffinityRequiredDuringSchedulingIgnoredDuringExecutionNodeSelectorTermsMatchFields" =
      {

        options = {
          "key" = mkOption {
            description = "";
            type = types.str;
          };
          "operator" = mkOption {
            description = "";
            type = types.str;
          };
          "values" = mkOption {
            description = "";
            type = types.nullOr (types.listOf types.str);
          };
        };

        config = {
          "values" = mkOverride 1002 null;
        };

      };
    "seaweed.seaweedfs.com.v1.SeaweedCSIDriverSpecControllerAffinityPodAffinity" = {

      options = {
        "preferredDuringSchedulingIgnoredDuringExecution" = mkOption {
          description = "";
          type = types.nullOr (
            types.listOf (
              submoduleOf "seaweed.seaweedfs.com.v1.SeaweedCSIDriverSpecControllerAffinityPodAffinityPreferredDuringSchedulingIgnoredDuringExecution"
            )
          );
        };
        "requiredDuringSchedulingIgnoredDuringExecution" = mkOption {
          description = "";
          type = types.nullOr (
            types.listOf (
              submoduleOf "seaweed.seaweedfs.com.v1.SeaweedCSIDriverSpecControllerAffinityPodAffinityRequiredDuringSchedulingIgnoredDuringExecution"
            )
          );
        };
      };

      config = {
        "preferredDuringSchedulingIgnoredDuringExecution" = mkOverride 1002 null;
        "requiredDuringSchedulingIgnoredDuringExecution" = mkOverride 1002 null;
      };

    };
    "seaweed.seaweedfs.com.v1.SeaweedCSIDriverSpecControllerAffinityPodAffinityPreferredDuringSchedulingIgnoredDuringExecution" =
      {

        options = {
          "podAffinityTerm" = mkOption {
            description = "";
            type = submoduleOf "seaweed.seaweedfs.com.v1.SeaweedCSIDriverSpecControllerAffinityPodAffinityPreferredDuringSchedulingIgnoredDuringExecutionPodAffinityTerm";
          };
          "weight" = mkOption {
            description = "";
            type = types.int;
          };
        };

        config = { };

      };
    "seaweed.seaweedfs.com.v1.SeaweedCSIDriverSpecControllerAffinityPodAffinityPreferredDuringSchedulingIgnoredDuringExecutionPodAffinityTerm" =
      {

        options = {
          "labelSelector" = mkOption {
            description = "";
            type = types.nullOr (
              submoduleOf "seaweed.seaweedfs.com.v1.SeaweedCSIDriverSpecControllerAffinityPodAffinityPreferredDuringSchedulingIgnoredDuringExecutionPodAffinityTermLabelSelector"
            );
          };
          "matchLabelKeys" = mkOption {
            description = "";
            type = types.nullOr (types.listOf types.str);
          };
          "mismatchLabelKeys" = mkOption {
            description = "";
            type = types.nullOr (types.listOf types.str);
          };
          "namespaceSelector" = mkOption {
            description = "";
            type = types.nullOr (
              submoduleOf "seaweed.seaweedfs.com.v1.SeaweedCSIDriverSpecControllerAffinityPodAffinityPreferredDuringSchedulingIgnoredDuringExecutionPodAffinityTermNamespaceSelector"
            );
          };
          "namespaces" = mkOption {
            description = "";
            type = types.nullOr (types.listOf types.str);
          };
          "topologyKey" = mkOption {
            description = "";
            type = types.str;
          };
        };

        config = {
          "labelSelector" = mkOverride 1002 null;
          "matchLabelKeys" = mkOverride 1002 null;
          "mismatchLabelKeys" = mkOverride 1002 null;
          "namespaceSelector" = mkOverride 1002 null;
          "namespaces" = mkOverride 1002 null;
        };

      };
    "seaweed.seaweedfs.com.v1.SeaweedCSIDriverSpecControllerAffinityPodAffinityPreferredDuringSchedulingIgnoredDuringExecutionPodAffinityTermLabelSelector" =
      {

        options = {
          "matchExpressions" = mkOption {
            description = "";
            type = types.nullOr (
              types.listOf (
                submoduleOf "seaweed.seaweedfs.com.v1.SeaweedCSIDriverSpecControllerAffinityPodAffinityPreferredDuringSchedulingIgnoredDuringExecutionPodAffinityTermLabelSelectorMatchExpressions"
              )
            );
          };
          "matchLabels" = mkOption {
            description = "";
            type = types.nullOr (types.attrsOf types.str);
          };
        };

        config = {
          "matchExpressions" = mkOverride 1002 null;
          "matchLabels" = mkOverride 1002 null;
        };

      };
    "seaweed.seaweedfs.com.v1.SeaweedCSIDriverSpecControllerAffinityPodAffinityPreferredDuringSchedulingIgnoredDuringExecutionPodAffinityTermLabelSelectorMatchExpressions" =
      {

        options = {
          "key" = mkOption {
            description = "";
            type = types.str;
          };
          "operator" = mkOption {
            description = "";
            type = types.str;
          };
          "values" = mkOption {
            description = "";
            type = types.nullOr (types.listOf types.str);
          };
        };

        config = {
          "values" = mkOverride 1002 null;
        };

      };
    "seaweed.seaweedfs.com.v1.SeaweedCSIDriverSpecControllerAffinityPodAffinityPreferredDuringSchedulingIgnoredDuringExecutionPodAffinityTermNamespaceSelector" =
      {

        options = {
          "matchExpressions" = mkOption {
            description = "";
            type = types.nullOr (
              types.listOf (
                submoduleOf "seaweed.seaweedfs.com.v1.SeaweedCSIDriverSpecControllerAffinityPodAffinityPreferredDuringSchedulingIgnoredDuringExecutionPodAffinityTermNamespaceSelectorMatchExpressions"
              )
            );
          };
          "matchLabels" = mkOption {
            description = "";
            type = types.nullOr (types.attrsOf types.str);
          };
        };

        config = {
          "matchExpressions" = mkOverride 1002 null;
          "matchLabels" = mkOverride 1002 null;
        };

      };
    "seaweed.seaweedfs.com.v1.SeaweedCSIDriverSpecControllerAffinityPodAffinityPreferredDuringSchedulingIgnoredDuringExecutionPodAffinityTermNamespaceSelectorMatchExpressions" =
      {

        options = {
          "key" = mkOption {
            description = "";
            type = types.str;
          };
          "operator" = mkOption {
            description = "";
            type = types.str;
          };
          "values" = mkOption {
            description = "";
            type = types.nullOr (types.listOf types.str);
          };
        };

        config = {
          "values" = mkOverride 1002 null;
        };

      };
    "seaweed.seaweedfs.com.v1.SeaweedCSIDriverSpecControllerAffinityPodAffinityRequiredDuringSchedulingIgnoredDuringExecution" =
      {

        options = {
          "labelSelector" = mkOption {
            description = "";
            type = types.nullOr (
              submoduleOf "seaweed.seaweedfs.com.v1.SeaweedCSIDriverSpecControllerAffinityPodAffinityRequiredDuringSchedulingIgnoredDuringExecutionLabelSelector"
            );
          };
          "matchLabelKeys" = mkOption {
            description = "";
            type = types.nullOr (types.listOf types.str);
          };
          "mismatchLabelKeys" = mkOption {
            description = "";
            type = types.nullOr (types.listOf types.str);
          };
          "namespaceSelector" = mkOption {
            description = "";
            type = types.nullOr (
              submoduleOf "seaweed.seaweedfs.com.v1.SeaweedCSIDriverSpecControllerAffinityPodAffinityRequiredDuringSchedulingIgnoredDuringExecutionNamespaceSelector"
            );
          };
          "namespaces" = mkOption {
            description = "";
            type = types.nullOr (types.listOf types.str);
          };
          "topologyKey" = mkOption {
            description = "";
            type = types.str;
          };
        };

        config = {
          "labelSelector" = mkOverride 1002 null;
          "matchLabelKeys" = mkOverride 1002 null;
          "mismatchLabelKeys" = mkOverride 1002 null;
          "namespaceSelector" = mkOverride 1002 null;
          "namespaces" = mkOverride 1002 null;
        };

      };
    "seaweed.seaweedfs.com.v1.SeaweedCSIDriverSpecControllerAffinityPodAffinityRequiredDuringSchedulingIgnoredDuringExecutionLabelSelector" =
      {

        options = {
          "matchExpressions" = mkOption {
            description = "";
            type = types.nullOr (
              types.listOf (
                submoduleOf "seaweed.seaweedfs.com.v1.SeaweedCSIDriverSpecControllerAffinityPodAffinityRequiredDuringSchedulingIgnoredDuringExecutionLabelSelectorMatchExpressions"
              )
            );
          };
          "matchLabels" = mkOption {
            description = "";
            type = types.nullOr (types.attrsOf types.str);
          };
        };

        config = {
          "matchExpressions" = mkOverride 1002 null;
          "matchLabels" = mkOverride 1002 null;
        };

      };
    "seaweed.seaweedfs.com.v1.SeaweedCSIDriverSpecControllerAffinityPodAffinityRequiredDuringSchedulingIgnoredDuringExecutionLabelSelectorMatchExpressions" =
      {

        options = {
          "key" = mkOption {
            description = "";
            type = types.str;
          };
          "operator" = mkOption {
            description = "";
            type = types.str;
          };
          "values" = mkOption {
            description = "";
            type = types.nullOr (types.listOf types.str);
          };
        };

        config = {
          "values" = mkOverride 1002 null;
        };

      };
    "seaweed.seaweedfs.com.v1.SeaweedCSIDriverSpecControllerAffinityPodAffinityRequiredDuringSchedulingIgnoredDuringExecutionNamespaceSelector" =
      {

        options = {
          "matchExpressions" = mkOption {
            description = "";
            type = types.nullOr (
              types.listOf (
                submoduleOf "seaweed.seaweedfs.com.v1.SeaweedCSIDriverSpecControllerAffinityPodAffinityRequiredDuringSchedulingIgnoredDuringExecutionNamespaceSelectorMatchExpressions"
              )
            );
          };
          "matchLabels" = mkOption {
            description = "";
            type = types.nullOr (types.attrsOf types.str);
          };
        };

        config = {
          "matchExpressions" = mkOverride 1002 null;
          "matchLabels" = mkOverride 1002 null;
        };

      };
    "seaweed.seaweedfs.com.v1.SeaweedCSIDriverSpecControllerAffinityPodAffinityRequiredDuringSchedulingIgnoredDuringExecutionNamespaceSelectorMatchExpressions" =
      {

        options = {
          "key" = mkOption {
            description = "";
            type = types.str;
          };
          "operator" = mkOption {
            description = "";
            type = types.str;
          };
          "values" = mkOption {
            description = "";
            type = types.nullOr (types.listOf types.str);
          };
        };

        config = {
          "values" = mkOverride 1002 null;
        };

      };
    "seaweed.seaweedfs.com.v1.SeaweedCSIDriverSpecControllerAffinityPodAntiAffinity" = {

      options = {
        "preferredDuringSchedulingIgnoredDuringExecution" = mkOption {
          description = "";
          type = types.nullOr (
            types.listOf (
              submoduleOf "seaweed.seaweedfs.com.v1.SeaweedCSIDriverSpecControllerAffinityPodAntiAffinityPreferredDuringSchedulingIgnoredDuringExecution"
            )
          );
        };
        "requiredDuringSchedulingIgnoredDuringExecution" = mkOption {
          description = "";
          type = types.nullOr (
            types.listOf (
              submoduleOf "seaweed.seaweedfs.com.v1.SeaweedCSIDriverSpecControllerAffinityPodAntiAffinityRequiredDuringSchedulingIgnoredDuringExecution"
            )
          );
        };
      };

      config = {
        "preferredDuringSchedulingIgnoredDuringExecution" = mkOverride 1002 null;
        "requiredDuringSchedulingIgnoredDuringExecution" = mkOverride 1002 null;
      };

    };
    "seaweed.seaweedfs.com.v1.SeaweedCSIDriverSpecControllerAffinityPodAntiAffinityPreferredDuringSchedulingIgnoredDuringExecution" =
      {

        options = {
          "podAffinityTerm" = mkOption {
            description = "";
            type = submoduleOf "seaweed.seaweedfs.com.v1.SeaweedCSIDriverSpecControllerAffinityPodAntiAffinityPreferredDuringSchedulingIgnoredDuringExecutionPodAffinityTerm";
          };
          "weight" = mkOption {
            description = "";
            type = types.int;
          };
        };

        config = { };

      };
    "seaweed.seaweedfs.com.v1.SeaweedCSIDriverSpecControllerAffinityPodAntiAffinityPreferredDuringSchedulingIgnoredDuringExecutionPodAffinityTerm" =
      {

        options = {
          "labelSelector" = mkOption {
            description = "";
            type = types.nullOr (
              submoduleOf "seaweed.seaweedfs.com.v1.SeaweedCSIDriverSpecControllerAffinityPodAntiAffinityPreferredDuringSchedulingIgnoredDuringExecutionPodAffinityTermLabelSelector"
            );
          };
          "matchLabelKeys" = mkOption {
            description = "";
            type = types.nullOr (types.listOf types.str);
          };
          "mismatchLabelKeys" = mkOption {
            description = "";
            type = types.nullOr (types.listOf types.str);
          };
          "namespaceSelector" = mkOption {
            description = "";
            type = types.nullOr (
              submoduleOf "seaweed.seaweedfs.com.v1.SeaweedCSIDriverSpecControllerAffinityPodAntiAffinityPreferredDuringSchedulingIgnoredDuringExecutionPodAffinityTermNamespaceSelector"
            );
          };
          "namespaces" = mkOption {
            description = "";
            type = types.nullOr (types.listOf types.str);
          };
          "topologyKey" = mkOption {
            description = "";
            type = types.str;
          };
        };

        config = {
          "labelSelector" = mkOverride 1002 null;
          "matchLabelKeys" = mkOverride 1002 null;
          "mismatchLabelKeys" = mkOverride 1002 null;
          "namespaceSelector" = mkOverride 1002 null;
          "namespaces" = mkOverride 1002 null;
        };

      };
    "seaweed.seaweedfs.com.v1.SeaweedCSIDriverSpecControllerAffinityPodAntiAffinityPreferredDuringSchedulingIgnoredDuringExecutionPodAffinityTermLabelSelector" =
      {

        options = {
          "matchExpressions" = mkOption {
            description = "";
            type = types.nullOr (
              types.listOf (
                submoduleOf "seaweed.seaweedfs.com.v1.SeaweedCSIDriverSpecControllerAffinityPodAntiAffinityPreferredDuringSchedulingIgnoredDuringExecutionPodAffinityTermLabelSelectorMatchExpressions"
              )
            );
          };
          "matchLabels" = mkOption {
            description = "";
            type = types.nullOr (types.attrsOf types.str);
          };
        };

        config = {
          "matchExpressions" = mkOverride 1002 null;
          "matchLabels" = mkOverride 1002 null;
        };

      };
    "seaweed.seaweedfs.com.v1.SeaweedCSIDriverSpecControllerAffinityPodAntiAffinityPreferredDuringSchedulingIgnoredDuringExecutionPodAffinityTermLabelSelectorMatchExpressions" =
      {

        options = {
          "key" = mkOption {
            description = "";
            type = types.str;
          };
          "operator" = mkOption {
            description = "";
            type = types.str;
          };
          "values" = mkOption {
            description = "";
            type = types.nullOr (types.listOf types.str);
          };
        };

        config = {
          "values" = mkOverride 1002 null;
        };

      };
    "seaweed.seaweedfs.com.v1.SeaweedCSIDriverSpecControllerAffinityPodAntiAffinityPreferredDuringSchedulingIgnoredDuringExecutionPodAffinityTermNamespaceSelector" =
      {

        options = {
          "matchExpressions" = mkOption {
            description = "";
            type = types.nullOr (
              types.listOf (
                submoduleOf "seaweed.seaweedfs.com.v1.SeaweedCSIDriverSpecControllerAffinityPodAntiAffinityPreferredDuringSchedulingIgnoredDuringExecutionPodAffinityTermNamespaceSelectorMatchExpressions"
              )
            );
          };
          "matchLabels" = mkOption {
            description = "";
            type = types.nullOr (types.attrsOf types.str);
          };
        };

        config = {
          "matchExpressions" = mkOverride 1002 null;
          "matchLabels" = mkOverride 1002 null;
        };

      };
    "seaweed.seaweedfs.com.v1.SeaweedCSIDriverSpecControllerAffinityPodAntiAffinityPreferredDuringSchedulingIgnoredDuringExecutionPodAffinityTermNamespaceSelectorMatchExpressions" =
      {

        options = {
          "key" = mkOption {
            description = "";
            type = types.str;
          };
          "operator" = mkOption {
            description = "";
            type = types.str;
          };
          "values" = mkOption {
            description = "";
            type = types.nullOr (types.listOf types.str);
          };
        };

        config = {
          "values" = mkOverride 1002 null;
        };

      };
    "seaweed.seaweedfs.com.v1.SeaweedCSIDriverSpecControllerAffinityPodAntiAffinityRequiredDuringSchedulingIgnoredDuringExecution" =
      {

        options = {
          "labelSelector" = mkOption {
            description = "";
            type = types.nullOr (
              submoduleOf "seaweed.seaweedfs.com.v1.SeaweedCSIDriverSpecControllerAffinityPodAntiAffinityRequiredDuringSchedulingIgnoredDuringExecutionLabelSelector"
            );
          };
          "matchLabelKeys" = mkOption {
            description = "";
            type = types.nullOr (types.listOf types.str);
          };
          "mismatchLabelKeys" = mkOption {
            description = "";
            type = types.nullOr (types.listOf types.str);
          };
          "namespaceSelector" = mkOption {
            description = "";
            type = types.nullOr (
              submoduleOf "seaweed.seaweedfs.com.v1.SeaweedCSIDriverSpecControllerAffinityPodAntiAffinityRequiredDuringSchedulingIgnoredDuringExecutionNamespaceSelector"
            );
          };
          "namespaces" = mkOption {
            description = "";
            type = types.nullOr (types.listOf types.str);
          };
          "topologyKey" = mkOption {
            description = "";
            type = types.str;
          };
        };

        config = {
          "labelSelector" = mkOverride 1002 null;
          "matchLabelKeys" = mkOverride 1002 null;
          "mismatchLabelKeys" = mkOverride 1002 null;
          "namespaceSelector" = mkOverride 1002 null;
          "namespaces" = mkOverride 1002 null;
        };

      };
    "seaweed.seaweedfs.com.v1.SeaweedCSIDriverSpecControllerAffinityPodAntiAffinityRequiredDuringSchedulingIgnoredDuringExecutionLabelSelector" =
      {

        options = {
          "matchExpressions" = mkOption {
            description = "";
            type = types.nullOr (
              types.listOf (
                submoduleOf "seaweed.seaweedfs.com.v1.SeaweedCSIDriverSpecControllerAffinityPodAntiAffinityRequiredDuringSchedulingIgnoredDuringExecutionLabelSelectorMatchExpressions"
              )
            );
          };
          "matchLabels" = mkOption {
            description = "";
            type = types.nullOr (types.attrsOf types.str);
          };
        };

        config = {
          "matchExpressions" = mkOverride 1002 null;
          "matchLabels" = mkOverride 1002 null;
        };

      };
    "seaweed.seaweedfs.com.v1.SeaweedCSIDriverSpecControllerAffinityPodAntiAffinityRequiredDuringSchedulingIgnoredDuringExecutionLabelSelectorMatchExpressions" =
      {

        options = {
          "key" = mkOption {
            description = "";
            type = types.str;
          };
          "operator" = mkOption {
            description = "";
            type = types.str;
          };
          "values" = mkOption {
            description = "";
            type = types.nullOr (types.listOf types.str);
          };
        };

        config = {
          "values" = mkOverride 1002 null;
        };

      };
    "seaweed.seaweedfs.com.v1.SeaweedCSIDriverSpecControllerAffinityPodAntiAffinityRequiredDuringSchedulingIgnoredDuringExecutionNamespaceSelector" =
      {

        options = {
          "matchExpressions" = mkOption {
            description = "";
            type = types.nullOr (
              types.listOf (
                submoduleOf "seaweed.seaweedfs.com.v1.SeaweedCSIDriverSpecControllerAffinityPodAntiAffinityRequiredDuringSchedulingIgnoredDuringExecutionNamespaceSelectorMatchExpressions"
              )
            );
          };
          "matchLabels" = mkOption {
            description = "";
            type = types.nullOr (types.attrsOf types.str);
          };
        };

        config = {
          "matchExpressions" = mkOverride 1002 null;
          "matchLabels" = mkOverride 1002 null;
        };

      };
    "seaweed.seaweedfs.com.v1.SeaweedCSIDriverSpecControllerAffinityPodAntiAffinityRequiredDuringSchedulingIgnoredDuringExecutionNamespaceSelectorMatchExpressions" =
      {

        options = {
          "key" = mkOption {
            description = "";
            type = types.str;
          };
          "operator" = mkOption {
            description = "";
            type = types.str;
          };
          "values" = mkOption {
            description = "";
            type = types.nullOr (types.listOf types.str);
          };
        };

        config = {
          "values" = mkOverride 1002 null;
        };

      };
    "seaweed.seaweedfs.com.v1.SeaweedCSIDriverSpecControllerResources" = {

      options = {
        "claims" = mkOption {
          description = "";
          type = types.nullOr (
            coerceAttrsOfSubmodulesToListByKey
              "seaweed.seaweedfs.com.v1.SeaweedCSIDriverSpecControllerResourcesClaims"
              "name"
              [ "name" ]
          );
          apply = attrsToList;
        };
        "limits" = mkOption {
          description = "";
          type = types.nullOr (types.attrsOf (types.either types.int types.str));
        };
        "requests" = mkOption {
          description = "";
          type = types.nullOr (types.attrsOf (types.either types.int types.str));
        };
      };

      config = {
        "claims" = mkOverride 1002 null;
        "limits" = mkOverride 1002 null;
        "requests" = mkOverride 1002 null;
      };

    };
    "seaweed.seaweedfs.com.v1.SeaweedCSIDriverSpecControllerResourcesClaims" = {

      options = {
        "name" = mkOption {
          description = "";
          type = types.str;
        };
        "request" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
      };

      config = {
        "request" = mkOverride 1002 null;
      };

    };
    "seaweed.seaweedfs.com.v1.SeaweedCSIDriverSpecControllerTolerations" = {

      options = {
        "effect" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "key" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "operator" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "tolerationSeconds" = mkOption {
          description = "";
          type = types.nullOr types.int;
        };
        "value" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
      };

      config = {
        "effect" = mkOverride 1002 null;
        "key" = mkOverride 1002 null;
        "operator" = mkOverride 1002 null;
        "tolerationSeconds" = mkOverride 1002 null;
        "value" = mkOverride 1002 null;
      };

    };
    "seaweed.seaweedfs.com.v1.SeaweedCSIDriverSpecImagePullSecrets" = {

      options = {
        "name" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
      };

      config = {
        "name" = mkOverride 1002 null;
      };

    };
    "seaweed.seaweedfs.com.v1.SeaweedCSIDriverSpecMountService" = {

      options = {
        "enabled" = mkOption {
          description = "";
          type = types.nullOr types.bool;
        };
        "image" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "nodeSelector" = mkOption {
          description = "";
          type = types.nullOr (types.attrsOf types.str);
        };
        "resources" = mkOption {
          description = "";
          type = types.nullOr (
            submoduleOf "seaweed.seaweedfs.com.v1.SeaweedCSIDriverSpecMountServiceResources"
          );
        };
        "socketDir" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "tolerations" = mkOption {
          description = "";
          type = types.nullOr (
            types.listOf (submoduleOf "seaweed.seaweedfs.com.v1.SeaweedCSIDriverSpecMountServiceTolerations")
          );
        };
        "updateStrategy" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
      };

      config = {
        "enabled" = mkOverride 1002 null;
        "image" = mkOverride 1002 null;
        "nodeSelector" = mkOverride 1002 null;
        "resources" = mkOverride 1002 null;
        "socketDir" = mkOverride 1002 null;
        "tolerations" = mkOverride 1002 null;
        "updateStrategy" = mkOverride 1002 null;
      };

    };
    "seaweed.seaweedfs.com.v1.SeaweedCSIDriverSpecMountServiceResources" = {

      options = {
        "claims" = mkOption {
          description = "";
          type = types.nullOr (
            coerceAttrsOfSubmodulesToListByKey
              "seaweed.seaweedfs.com.v1.SeaweedCSIDriverSpecMountServiceResourcesClaims"
              "name"
              [ "name" ]
          );
          apply = attrsToList;
        };
        "limits" = mkOption {
          description = "";
          type = types.nullOr (types.attrsOf (types.either types.int types.str));
        };
        "requests" = mkOption {
          description = "";
          type = types.nullOr (types.attrsOf (types.either types.int types.str));
        };
      };

      config = {
        "claims" = mkOverride 1002 null;
        "limits" = mkOverride 1002 null;
        "requests" = mkOverride 1002 null;
      };

    };
    "seaweed.seaweedfs.com.v1.SeaweedCSIDriverSpecMountServiceResourcesClaims" = {

      options = {
        "name" = mkOption {
          description = "";
          type = types.str;
        };
        "request" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
      };

      config = {
        "request" = mkOverride 1002 null;
      };

    };
    "seaweed.seaweedfs.com.v1.SeaweedCSIDriverSpecMountServiceTolerations" = {

      options = {
        "effect" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "key" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "operator" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "tolerationSeconds" = mkOption {
          description = "";
          type = types.nullOr types.int;
        };
        "value" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
      };

      config = {
        "effect" = mkOverride 1002 null;
        "key" = mkOverride 1002 null;
        "operator" = mkOverride 1002 null;
        "tolerationSeconds" = mkOverride 1002 null;
        "value" = mkOverride 1002 null;
      };

    };
    "seaweed.seaweedfs.com.v1.SeaweedCSIDriverSpecNode" = {

      options = {
        "hostPID" = mkOption {
          description = "";
          type = types.nullOr types.bool;
        };
        "kubeletPath" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "nodeSelector" = mkOption {
          description = "";
          type = types.nullOr (types.attrsOf types.str);
        };
        "resources" = mkOption {
          description = "";
          type = types.nullOr (submoduleOf "seaweed.seaweedfs.com.v1.SeaweedCSIDriverSpecNodeResources");
        };
        "tolerations" = mkOption {
          description = "";
          type = types.nullOr (
            types.listOf (submoduleOf "seaweed.seaweedfs.com.v1.SeaweedCSIDriverSpecNodeTolerations")
          );
        };
        "updateStrategy" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
      };

      config = {
        "hostPID" = mkOverride 1002 null;
        "kubeletPath" = mkOverride 1002 null;
        "nodeSelector" = mkOverride 1002 null;
        "resources" = mkOverride 1002 null;
        "tolerations" = mkOverride 1002 null;
        "updateStrategy" = mkOverride 1002 null;
      };

    };
    "seaweed.seaweedfs.com.v1.SeaweedCSIDriverSpecNodeResources" = {

      options = {
        "claims" = mkOption {
          description = "";
          type = types.nullOr (
            coerceAttrsOfSubmodulesToListByKey
              "seaweed.seaweedfs.com.v1.SeaweedCSIDriverSpecNodeResourcesClaims"
              "name"
              [ "name" ]
          );
          apply = attrsToList;
        };
        "limits" = mkOption {
          description = "";
          type = types.nullOr (types.attrsOf (types.either types.int types.str));
        };
        "requests" = mkOption {
          description = "";
          type = types.nullOr (types.attrsOf (types.either types.int types.str));
        };
      };

      config = {
        "claims" = mkOverride 1002 null;
        "limits" = mkOverride 1002 null;
        "requests" = mkOverride 1002 null;
      };

    };
    "seaweed.seaweedfs.com.v1.SeaweedCSIDriverSpecNodeResourcesClaims" = {

      options = {
        "name" = mkOption {
          description = "";
          type = types.str;
        };
        "request" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
      };

      config = {
        "request" = mkOverride 1002 null;
      };

    };
    "seaweed.seaweedfs.com.v1.SeaweedCSIDriverSpecNodeTolerations" = {

      options = {
        "effect" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "key" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "operator" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "tolerationSeconds" = mkOption {
          description = "";
          type = types.nullOr types.int;
        };
        "value" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
      };

      config = {
        "effect" = mkOverride 1002 null;
        "key" = mkOverride 1002 null;
        "operator" = mkOverride 1002 null;
        "tolerationSeconds" = mkOverride 1002 null;
        "value" = mkOverride 1002 null;
      };

    };
    "seaweed.seaweedfs.com.v1.SeaweedCSIDriverSpecSeaweedRef" = {

      options = {
        "name" = mkOption {
          description = "";
          type = types.str;
        };
        "namespace" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
      };

      config = {
        "namespace" = mkOverride 1002 null;
      };

    };
    "seaweed.seaweedfs.com.v1.SeaweedCSIDriverSpecSidecars" = {

      options = {
        "attacher" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "livenessProbe" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "nodeDriverRegistrar" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "provisioner" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "resizer" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
      };

      config = {
        "attacher" = mkOverride 1002 null;
        "livenessProbe" = mkOverride 1002 null;
        "nodeDriverRegistrar" = mkOverride 1002 null;
        "provisioner" = mkOverride 1002 null;
        "resizer" = mkOverride 1002 null;
      };

    };
    "seaweed.seaweedfs.com.v1.SeaweedCSIDriverSpecStorageClass" = {

      options = {
        "allowVolumeExpansion" = mkOption {
          description = "";
          type = types.nullOr types.bool;
        };
        "isDefaultClass" = mkOption {
          description = "";
          type = types.nullOr types.bool;
        };
        "mountOptions" = mkOption {
          description = "";
          type = types.nullOr (types.listOf types.str);
        };
        "name" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "parameters" = mkOption {
          description = "";
          type = types.nullOr (types.attrsOf types.str);
        };
        "reclaimPolicy" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "volumeBindingMode" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
      };

      config = {
        "allowVolumeExpansion" = mkOverride 1002 null;
        "isDefaultClass" = mkOverride 1002 null;
        "mountOptions" = mkOverride 1002 null;
        "name" = mkOverride 1002 null;
        "parameters" = mkOverride 1002 null;
        "reclaimPolicy" = mkOverride 1002 null;
        "volumeBindingMode" = mkOverride 1002 null;
      };

    };
    "seaweed.seaweedfs.com.v1.SeaweedCSIDriverStatus" = {

      options = {
        "conditions" = mkOption {
          description = "";
          type = types.nullOr (
            types.listOf (submoduleOf "seaweed.seaweedfs.com.v1.SeaweedCSIDriverStatusConditions")
          );
        };
        "controller" = mkOption {
          description = "";
          type = types.nullOr (submoduleOf "seaweed.seaweedfs.com.v1.SeaweedCSIDriverStatusController");
        };
        "driverName" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "node" = mkOption {
          description = "";
          type = types.nullOr (submoduleOf "seaweed.seaweedfs.com.v1.SeaweedCSIDriverStatusNode");
        };
        "observedGeneration" = mkOption {
          description = "";
          type = types.nullOr types.int;
        };
        "phase" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "resolvedFilerAddress" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
      };

      config = {
        "conditions" = mkOverride 1002 null;
        "controller" = mkOverride 1002 null;
        "driverName" = mkOverride 1002 null;
        "node" = mkOverride 1002 null;
        "observedGeneration" = mkOverride 1002 null;
        "phase" = mkOverride 1002 null;
        "resolvedFilerAddress" = mkOverride 1002 null;
      };

    };
    "seaweed.seaweedfs.com.v1.SeaweedCSIDriverStatusConditions" = {

      options = {
        "lastTransitionTime" = mkOption {
          description = "";
          type = types.str;
        };
        "message" = mkOption {
          description = "";
          type = types.str;
        };
        "observedGeneration" = mkOption {
          description = "";
          type = types.nullOr types.int;
        };
        "reason" = mkOption {
          description = "";
          type = types.str;
        };
        "status" = mkOption {
          description = "";
          type = types.str;
        };
        "type" = mkOption {
          description = "";
          type = types.str;
        };
      };

      config = {
        "observedGeneration" = mkOverride 1002 null;
      };

    };
    "seaweed.seaweedfs.com.v1.SeaweedCSIDriverStatusController" = {

      options = {
        "desired" = mkOption {
          description = "";
          type = types.nullOr types.int;
        };
        "ready" = mkOption {
          description = "";
          type = types.nullOr types.int;
        };
      };

      config = {
        "desired" = mkOverride 1002 null;
        "ready" = mkOverride 1002 null;
      };

    };
    "seaweed.seaweedfs.com.v1.SeaweedCSIDriverStatusNode" = {

      options = {
        "desired" = mkOption {
          description = "";
          type = types.nullOr types.int;
        };
        "ready" = mkOption {
          description = "";
          type = types.nullOr types.int;
        };
      };

      config = {
        "desired" = mkOverride 1002 null;
        "ready" = mkOverride 1002 null;
      };

    };
    "seaweed.seaweedfs.com.v1.SeaweedRestore" = {

      options = {
        "apiVersion" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "kind" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "metadata" = mkOption {
          description = "Standard object's metadata. More info: https://git.k8s.io/community/contributors/devel/sig-architecture/api-conventions.md#metadata";
          type = types.nullOr (globalSubmoduleOf "io.k8s.apimachinery.pkg.apis.meta.v1.ObjectMeta");
        };
        "spec" = mkOption {
          description = "";
          type = types.nullOr (submoduleOf "seaweed.seaweedfs.com.v1.SeaweedRestoreSpec");
        };
        "status" = mkOption {
          description = "";
          type = types.nullOr (submoduleOf "seaweed.seaweedfs.com.v1.SeaweedRestoreStatus");
        };
      };

      config = {
        "apiVersion" = mkOverride 1002 null;
        "kind" = mkOverride 1002 null;
        "metadata" = mkOverride 1002 null;
        "spec" = mkOverride 1002 null;
        "status" = mkOverride 1002 null;
      };

    };
    "seaweed.seaweedfs.com.v1.SeaweedRestoreSpec" = {

      options = {
        "backupName" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "backupSource" = mkOption {
          description = "";
          type = types.nullOr (submoduleOf "seaweed.seaweedfs.com.v1.SeaweedRestoreSpecBackupSource");
        };
        "clusterName" = mkOption {
          description = "";
          type = types.str;
        };
        "filerPath" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
      };

      config = {
        "backupName" = mkOverride 1002 null;
        "backupSource" = mkOverride 1002 null;
        "filerPath" = mkOverride 1002 null;
      };

    };
    "seaweed.seaweedfs.com.v1.SeaweedRestoreSpecBackupSource" = {

      options = {
        "metaPath" = mkOption {
          description = "";
          type = types.str;
        };
        "storageName" = mkOption {
          description = "";
          type = types.str;
        };
      };

      config = { };

    };
    "seaweed.seaweedfs.com.v1.SeaweedRestoreStatus" = {

      options = {
        "completionTime" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "conditions" = mkOption {
          description = "";
          type = types.nullOr (
            types.listOf (submoduleOf "seaweed.seaweedfs.com.v1.SeaweedRestoreStatusConditions")
          );
        };
        "jobName" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "observedGeneration" = mkOption {
          description = "";
          type = types.nullOr types.int;
        };
        "phase" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "startTime" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
      };

      config = {
        "completionTime" = mkOverride 1002 null;
        "conditions" = mkOverride 1002 null;
        "jobName" = mkOverride 1002 null;
        "observedGeneration" = mkOverride 1002 null;
        "phase" = mkOverride 1002 null;
        "startTime" = mkOverride 1002 null;
      };

    };
    "seaweed.seaweedfs.com.v1.SeaweedRestoreStatusConditions" = {

      options = {
        "lastTransitionTime" = mkOption {
          description = "";
          type = types.str;
        };
        "message" = mkOption {
          description = "";
          type = types.str;
        };
        "observedGeneration" = mkOption {
          description = "";
          type = types.nullOr types.int;
        };
        "reason" = mkOption {
          description = "";
          type = types.str;
        };
        "status" = mkOption {
          description = "";
          type = types.str;
        };
        "type" = mkOption {
          description = "";
          type = types.str;
        };
      };

      config = {
        "observedGeneration" = mkOverride 1002 null;
      };

    };
    "seaweed.seaweedfs.com.v1.SeaweedSpec" = {

      options = {
        "admin" = mkOption {
          description = "";
          type = types.nullOr (submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecAdmin");
        };
        "affinity" = mkOption {
          description = "";
          type = types.nullOr (submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecAffinity");
        };
        "annotations" = mkOption {
          description = "";
          type = types.nullOr (types.attrsOf types.str);
        };
        "backup" = mkOption {
          description = "";
          type = types.nullOr (submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecBackup");
        };
        "enablePVReclaim" = mkOption {
          description = "";
          type = types.nullOr types.bool;
        };
        "filer" = mkOption {
          description = "";
          type = types.nullOr (submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecFiler");
        };
        "hostNetwork" = mkOption {
          description = "";
          type = types.nullOr types.bool;
        };
        "hostSuffix" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "image" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "imagePullPolicy" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "imagePullSecrets" = mkOption {
          description = "";
          type = types.nullOr (
            coerceAttrsOfSubmodulesToListByKey "seaweed.seaweedfs.com.v1.SeaweedSpecImagePullSecrets" "name" [ ]
          );
          apply = attrsToList;
        };
        "labels" = mkOption {
          description = "";
          type = types.nullOr (types.attrsOf types.str);
        };
        "loggingArgs" = mkOption {
          description = "";
          type = types.nullOr (types.listOf types.str);
        };
        "master" = mkOption {
          description = "";
          type = types.nullOr (submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecMaster");
        };
        "metricsAddress" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "nodeSelector" = mkOption {
          description = "";
          type = types.nullOr (types.attrsOf types.str);
        };
        "pvReclaimPolicy" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "s3" = mkOption {
          description = "";
          type = types.nullOr (submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecS3");
        };
        "schedulerName" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "sftp" = mkOption {
          description = "";
          type = types.nullOr (submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecSftp");
        };
        "statefulSetUpdateStrategy" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "tls" = mkOption {
          description = "";
          type = types.nullOr (submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecTls");
        };
        "tolerations" = mkOption {
          description = "";
          type = types.nullOr (types.listOf (submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecTolerations"));
        };
        "version" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "volume" = mkOption {
          description = "";
          type = types.nullOr (submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecVolume");
        };
        "volumeServerDiskCount" = mkOption {
          description = "";
          type = types.nullOr types.int;
        };
        "volumeTopology" = mkOption {
          description = "";
          type = types.nullOr (types.attrsOf types.attrs);
        };
        "worker" = mkOption {
          description = "";
          type = types.nullOr (submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecWorker");
        };
      };

      config = {
        "admin" = mkOverride 1002 null;
        "affinity" = mkOverride 1002 null;
        "annotations" = mkOverride 1002 null;
        "backup" = mkOverride 1002 null;
        "enablePVReclaim" = mkOverride 1002 null;
        "filer" = mkOverride 1002 null;
        "hostNetwork" = mkOverride 1002 null;
        "hostSuffix" = mkOverride 1002 null;
        "image" = mkOverride 1002 null;
        "imagePullPolicy" = mkOverride 1002 null;
        "imagePullSecrets" = mkOverride 1002 null;
        "labels" = mkOverride 1002 null;
        "loggingArgs" = mkOverride 1002 null;
        "master" = mkOverride 1002 null;
        "metricsAddress" = mkOverride 1002 null;
        "nodeSelector" = mkOverride 1002 null;
        "pvReclaimPolicy" = mkOverride 1002 null;
        "s3" = mkOverride 1002 null;
        "schedulerName" = mkOverride 1002 null;
        "sftp" = mkOverride 1002 null;
        "statefulSetUpdateStrategy" = mkOverride 1002 null;
        "tls" = mkOverride 1002 null;
        "tolerations" = mkOverride 1002 null;
        "version" = mkOverride 1002 null;
        "volume" = mkOverride 1002 null;
        "volumeServerDiskCount" = mkOverride 1002 null;
        "volumeTopology" = mkOverride 1002 null;
        "worker" = mkOverride 1002 null;
      };

    };
    "seaweed.seaweedfs.com.v1.SeaweedSpecAdmin" = {

      options = {
        "affinity" = mkOption {
          description = "";
          type = types.nullOr (submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecAdminAffinity");
        };
        "annotations" = mkOption {
          description = "";
          type = types.nullOr (types.attrsOf types.str);
        };
        "claims" = mkOption {
          description = "";
          type = types.nullOr (
            coerceAttrsOfSubmodulesToListByKey "seaweed.seaweedfs.com.v1.SeaweedSpecAdminClaims" "name" [
              "name"
            ]
          );
          apply = attrsToList;
        };
        "containerSecurityContext" = mkOption {
          description = "";
          type = types.nullOr (
            submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecAdminContainerSecurityContext"
          );
        };
        "credentialsSecret" = mkOption {
          description = "";
          type = types.nullOr (submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecAdminCredentialsSecret");
        };
        "env" = mkOption {
          description = "";
          type = types.nullOr (
            coerceAttrsOfSubmodulesToListByKey "seaweed.seaweedfs.com.v1.SeaweedSpecAdminEnv" "name" [ ]
          );
          apply = attrsToList;
        };
        "extraArgs" = mkOption {
          description = "";
          type = types.nullOr (types.listOf types.str);
        };
        "hostNetwork" = mkOption {
          description = "";
          type = types.nullOr types.bool;
        };
        "imagePullPolicy" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "imagePullSecrets" = mkOption {
          description = "";
          type = types.nullOr (
            coerceAttrsOfSubmodulesToListByKey "seaweed.seaweedfs.com.v1.SeaweedSpecAdminImagePullSecrets"
              "name"
              [ ]
          );
          apply = attrsToList;
        };
        "ingress" = mkOption {
          description = "";
          type = types.nullOr (submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecAdminIngress");
        };
        "initContainers" = mkOption {
          description = "";
          type = types.nullOr types.unspecified;
        };
        "labels" = mkOption {
          description = "";
          type = types.nullOr (types.attrsOf types.str);
        };
        "limits" = mkOption {
          description = "";
          type = types.nullOr (types.attrsOf (types.either types.int types.str));
        };
        "livenessProbe" = mkOption {
          description = "";
          type = types.nullOr (submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecAdminLivenessProbe");
        };
        "loggingArgs" = mkOption {
          description = "";
          type = types.nullOr (types.listOf types.str);
        };
        "metricsPort" = mkOption {
          description = "";
          type = types.nullOr types.int;
        };
        "nodeSelector" = mkOption {
          description = "";
          type = types.nullOr (types.attrsOf types.str);
        };
        "podSecurityContext" = mkOption {
          description = "";
          type = types.nullOr (submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecAdminPodSecurityContext");
        };
        "priorityClassName" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "readinessProbe" = mkOption {
          description = "";
          type = types.nullOr (submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecAdminReadinessProbe");
        };
        "requests" = mkOption {
          description = "";
          type = types.nullOr (types.attrsOf (types.either types.int types.str));
        };
        "schedulerName" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "service" = mkOption {
          description = "";
          type = types.nullOr (submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecAdminService");
        };
        "serviceAccountName" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "sidecars" = mkOption {
          description = "";
          type = types.nullOr types.unspecified;
        };
        "statefulSetUpdateStrategy" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "terminationGracePeriodSeconds" = mkOption {
          description = "";
          type = types.nullOr types.int;
        };
        "tolerations" = mkOption {
          description = "";
          type = types.nullOr (
            types.listOf (submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecAdminTolerations")
          );
        };
        "version" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "volumeMounts" = mkOption {
          description = "";
          type = types.nullOr (
            coerceAttrsOfSubmodulesToListByKey "seaweed.seaweedfs.com.v1.SeaweedSpecAdminVolumeMounts" "name"
              [ ]
          );
          apply = attrsToList;
        };
        "volumes" = mkOption {
          description = "";
          type = types.nullOr (
            coerceAttrsOfSubmodulesToListByKey "seaweed.seaweedfs.com.v1.SeaweedSpecAdminVolumes" "name" [ ]
          );
          apply = attrsToList;
        };
      };

      config = {
        "affinity" = mkOverride 1002 null;
        "annotations" = mkOverride 1002 null;
        "claims" = mkOverride 1002 null;
        "containerSecurityContext" = mkOverride 1002 null;
        "credentialsSecret" = mkOverride 1002 null;
        "env" = mkOverride 1002 null;
        "extraArgs" = mkOverride 1002 null;
        "hostNetwork" = mkOverride 1002 null;
        "imagePullPolicy" = mkOverride 1002 null;
        "imagePullSecrets" = mkOverride 1002 null;
        "ingress" = mkOverride 1002 null;
        "initContainers" = mkOverride 1002 null;
        "labels" = mkOverride 1002 null;
        "limits" = mkOverride 1002 null;
        "livenessProbe" = mkOverride 1002 null;
        "loggingArgs" = mkOverride 1002 null;
        "metricsPort" = mkOverride 1002 null;
        "nodeSelector" = mkOverride 1002 null;
        "podSecurityContext" = mkOverride 1002 null;
        "priorityClassName" = mkOverride 1002 null;
        "readinessProbe" = mkOverride 1002 null;
        "requests" = mkOverride 1002 null;
        "schedulerName" = mkOverride 1002 null;
        "service" = mkOverride 1002 null;
        "serviceAccountName" = mkOverride 1002 null;
        "sidecars" = mkOverride 1002 null;
        "statefulSetUpdateStrategy" = mkOverride 1002 null;
        "terminationGracePeriodSeconds" = mkOverride 1002 null;
        "tolerations" = mkOverride 1002 null;
        "version" = mkOverride 1002 null;
        "volumeMounts" = mkOverride 1002 null;
        "volumes" = mkOverride 1002 null;
      };

    };
    "seaweed.seaweedfs.com.v1.SeaweedSpecAdminAffinity" = {

      options = {
        "nodeAffinity" = mkOption {
          description = "";
          type = types.nullOr (submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecAdminAffinityNodeAffinity");
        };
        "podAffinity" = mkOption {
          description = "";
          type = types.nullOr (submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecAdminAffinityPodAffinity");
        };
        "podAntiAffinity" = mkOption {
          description = "";
          type = types.nullOr (
            submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecAdminAffinityPodAntiAffinity"
          );
        };
      };

      config = {
        "nodeAffinity" = mkOverride 1002 null;
        "podAffinity" = mkOverride 1002 null;
        "podAntiAffinity" = mkOverride 1002 null;
      };

    };
    "seaweed.seaweedfs.com.v1.SeaweedSpecAdminAffinityNodeAffinity" = {

      options = {
        "preferredDuringSchedulingIgnoredDuringExecution" = mkOption {
          description = "";
          type = types.nullOr (
            types.listOf (
              submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecAdminAffinityNodeAffinityPreferredDuringSchedulingIgnoredDuringExecution"
            )
          );
        };
        "requiredDuringSchedulingIgnoredDuringExecution" = mkOption {
          description = "";
          type = types.nullOr (
            submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecAdminAffinityNodeAffinityRequiredDuringSchedulingIgnoredDuringExecution"
          );
        };
      };

      config = {
        "preferredDuringSchedulingIgnoredDuringExecution" = mkOverride 1002 null;
        "requiredDuringSchedulingIgnoredDuringExecution" = mkOverride 1002 null;
      };

    };
    "seaweed.seaweedfs.com.v1.SeaweedSpecAdminAffinityNodeAffinityPreferredDuringSchedulingIgnoredDuringExecution" =
      {

        options = {
          "preference" = mkOption {
            description = "";
            type = submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecAdminAffinityNodeAffinityPreferredDuringSchedulingIgnoredDuringExecutionPreference";
          };
          "weight" = mkOption {
            description = "";
            type = types.int;
          };
        };

        config = { };

      };
    "seaweed.seaweedfs.com.v1.SeaweedSpecAdminAffinityNodeAffinityPreferredDuringSchedulingIgnoredDuringExecutionPreference" =
      {

        options = {
          "matchExpressions" = mkOption {
            description = "";
            type = types.nullOr (
              types.listOf (
                submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecAdminAffinityNodeAffinityPreferredDuringSchedulingIgnoredDuringExecutionPreferenceMatchExpressions"
              )
            );
          };
          "matchFields" = mkOption {
            description = "";
            type = types.nullOr (
              types.listOf (
                submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecAdminAffinityNodeAffinityPreferredDuringSchedulingIgnoredDuringExecutionPreferenceMatchFields"
              )
            );
          };
        };

        config = {
          "matchExpressions" = mkOverride 1002 null;
          "matchFields" = mkOverride 1002 null;
        };

      };
    "seaweed.seaweedfs.com.v1.SeaweedSpecAdminAffinityNodeAffinityPreferredDuringSchedulingIgnoredDuringExecutionPreferenceMatchExpressions" =
      {

        options = {
          "key" = mkOption {
            description = "";
            type = types.str;
          };
          "operator" = mkOption {
            description = "";
            type = types.str;
          };
          "values" = mkOption {
            description = "";
            type = types.nullOr (types.listOf types.str);
          };
        };

        config = {
          "values" = mkOverride 1002 null;
        };

      };
    "seaweed.seaweedfs.com.v1.SeaweedSpecAdminAffinityNodeAffinityPreferredDuringSchedulingIgnoredDuringExecutionPreferenceMatchFields" =
      {

        options = {
          "key" = mkOption {
            description = "";
            type = types.str;
          };
          "operator" = mkOption {
            description = "";
            type = types.str;
          };
          "values" = mkOption {
            description = "";
            type = types.nullOr (types.listOf types.str);
          };
        };

        config = {
          "values" = mkOverride 1002 null;
        };

      };
    "seaweed.seaweedfs.com.v1.SeaweedSpecAdminAffinityNodeAffinityRequiredDuringSchedulingIgnoredDuringExecution" =
      {

        options = {
          "nodeSelectorTerms" = mkOption {
            description = "";
            type = types.listOf (
              submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecAdminAffinityNodeAffinityRequiredDuringSchedulingIgnoredDuringExecutionNodeSelectorTerms"
            );
          };
        };

        config = { };

      };
    "seaweed.seaweedfs.com.v1.SeaweedSpecAdminAffinityNodeAffinityRequiredDuringSchedulingIgnoredDuringExecutionNodeSelectorTerms" =
      {

        options = {
          "matchExpressions" = mkOption {
            description = "";
            type = types.nullOr (
              types.listOf (
                submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecAdminAffinityNodeAffinityRequiredDuringSchedulingIgnoredDuringExecutionNodeSelectorTermsMatchExpressions"
              )
            );
          };
          "matchFields" = mkOption {
            description = "";
            type = types.nullOr (
              types.listOf (
                submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecAdminAffinityNodeAffinityRequiredDuringSchedulingIgnoredDuringExecutionNodeSelectorTermsMatchFields"
              )
            );
          };
        };

        config = {
          "matchExpressions" = mkOverride 1002 null;
          "matchFields" = mkOverride 1002 null;
        };

      };
    "seaweed.seaweedfs.com.v1.SeaweedSpecAdminAffinityNodeAffinityRequiredDuringSchedulingIgnoredDuringExecutionNodeSelectorTermsMatchExpressions" =
      {

        options = {
          "key" = mkOption {
            description = "";
            type = types.str;
          };
          "operator" = mkOption {
            description = "";
            type = types.str;
          };
          "values" = mkOption {
            description = "";
            type = types.nullOr (types.listOf types.str);
          };
        };

        config = {
          "values" = mkOverride 1002 null;
        };

      };
    "seaweed.seaweedfs.com.v1.SeaweedSpecAdminAffinityNodeAffinityRequiredDuringSchedulingIgnoredDuringExecutionNodeSelectorTermsMatchFields" =
      {

        options = {
          "key" = mkOption {
            description = "";
            type = types.str;
          };
          "operator" = mkOption {
            description = "";
            type = types.str;
          };
          "values" = mkOption {
            description = "";
            type = types.nullOr (types.listOf types.str);
          };
        };

        config = {
          "values" = mkOverride 1002 null;
        };

      };
    "seaweed.seaweedfs.com.v1.SeaweedSpecAdminAffinityPodAffinity" = {

      options = {
        "preferredDuringSchedulingIgnoredDuringExecution" = mkOption {
          description = "";
          type = types.nullOr (
            types.listOf (
              submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecAdminAffinityPodAffinityPreferredDuringSchedulingIgnoredDuringExecution"
            )
          );
        };
        "requiredDuringSchedulingIgnoredDuringExecution" = mkOption {
          description = "";
          type = types.nullOr (
            types.listOf (
              submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecAdminAffinityPodAffinityRequiredDuringSchedulingIgnoredDuringExecution"
            )
          );
        };
      };

      config = {
        "preferredDuringSchedulingIgnoredDuringExecution" = mkOverride 1002 null;
        "requiredDuringSchedulingIgnoredDuringExecution" = mkOverride 1002 null;
      };

    };
    "seaweed.seaweedfs.com.v1.SeaweedSpecAdminAffinityPodAffinityPreferredDuringSchedulingIgnoredDuringExecution" =
      {

        options = {
          "podAffinityTerm" = mkOption {
            description = "";
            type = submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecAdminAffinityPodAffinityPreferredDuringSchedulingIgnoredDuringExecutionPodAffinityTerm";
          };
          "weight" = mkOption {
            description = "";
            type = types.int;
          };
        };

        config = { };

      };
    "seaweed.seaweedfs.com.v1.SeaweedSpecAdminAffinityPodAffinityPreferredDuringSchedulingIgnoredDuringExecutionPodAffinityTerm" =
      {

        options = {
          "labelSelector" = mkOption {
            description = "";
            type = types.nullOr (
              submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecAdminAffinityPodAffinityPreferredDuringSchedulingIgnoredDuringExecutionPodAffinityTermLabelSelector"
            );
          };
          "matchLabelKeys" = mkOption {
            description = "";
            type = types.nullOr (types.listOf types.str);
          };
          "mismatchLabelKeys" = mkOption {
            description = "";
            type = types.nullOr (types.listOf types.str);
          };
          "namespaceSelector" = mkOption {
            description = "";
            type = types.nullOr (
              submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecAdminAffinityPodAffinityPreferredDuringSchedulingIgnoredDuringExecutionPodAffinityTermNamespaceSelector"
            );
          };
          "namespaces" = mkOption {
            description = "";
            type = types.nullOr (types.listOf types.str);
          };
          "topologyKey" = mkOption {
            description = "";
            type = types.str;
          };
        };

        config = {
          "labelSelector" = mkOverride 1002 null;
          "matchLabelKeys" = mkOverride 1002 null;
          "mismatchLabelKeys" = mkOverride 1002 null;
          "namespaceSelector" = mkOverride 1002 null;
          "namespaces" = mkOverride 1002 null;
        };

      };
    "seaweed.seaweedfs.com.v1.SeaweedSpecAdminAffinityPodAffinityPreferredDuringSchedulingIgnoredDuringExecutionPodAffinityTermLabelSelector" =
      {

        options = {
          "matchExpressions" = mkOption {
            description = "";
            type = types.nullOr (
              types.listOf (
                submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecAdminAffinityPodAffinityPreferredDuringSchedulingIgnoredDuringExecutionPodAffinityTermLabelSelectorMatchExpressions"
              )
            );
          };
          "matchLabels" = mkOption {
            description = "";
            type = types.nullOr (types.attrsOf types.str);
          };
        };

        config = {
          "matchExpressions" = mkOverride 1002 null;
          "matchLabels" = mkOverride 1002 null;
        };

      };
    "seaweed.seaweedfs.com.v1.SeaweedSpecAdminAffinityPodAffinityPreferredDuringSchedulingIgnoredDuringExecutionPodAffinityTermLabelSelectorMatchExpressions" =
      {

        options = {
          "key" = mkOption {
            description = "";
            type = types.str;
          };
          "operator" = mkOption {
            description = "";
            type = types.str;
          };
          "values" = mkOption {
            description = "";
            type = types.nullOr (types.listOf types.str);
          };
        };

        config = {
          "values" = mkOverride 1002 null;
        };

      };
    "seaweed.seaweedfs.com.v1.SeaweedSpecAdminAffinityPodAffinityPreferredDuringSchedulingIgnoredDuringExecutionPodAffinityTermNamespaceSelector" =
      {

        options = {
          "matchExpressions" = mkOption {
            description = "";
            type = types.nullOr (
              types.listOf (
                submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecAdminAffinityPodAffinityPreferredDuringSchedulingIgnoredDuringExecutionPodAffinityTermNamespaceSelectorMatchExpressions"
              )
            );
          };
          "matchLabels" = mkOption {
            description = "";
            type = types.nullOr (types.attrsOf types.str);
          };
        };

        config = {
          "matchExpressions" = mkOverride 1002 null;
          "matchLabels" = mkOverride 1002 null;
        };

      };
    "seaweed.seaweedfs.com.v1.SeaweedSpecAdminAffinityPodAffinityPreferredDuringSchedulingIgnoredDuringExecutionPodAffinityTermNamespaceSelectorMatchExpressions" =
      {

        options = {
          "key" = mkOption {
            description = "";
            type = types.str;
          };
          "operator" = mkOption {
            description = "";
            type = types.str;
          };
          "values" = mkOption {
            description = "";
            type = types.nullOr (types.listOf types.str);
          };
        };

        config = {
          "values" = mkOverride 1002 null;
        };

      };
    "seaweed.seaweedfs.com.v1.SeaweedSpecAdminAffinityPodAffinityRequiredDuringSchedulingIgnoredDuringExecution" =
      {

        options = {
          "labelSelector" = mkOption {
            description = "";
            type = types.nullOr (
              submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecAdminAffinityPodAffinityRequiredDuringSchedulingIgnoredDuringExecutionLabelSelector"
            );
          };
          "matchLabelKeys" = mkOption {
            description = "";
            type = types.nullOr (types.listOf types.str);
          };
          "mismatchLabelKeys" = mkOption {
            description = "";
            type = types.nullOr (types.listOf types.str);
          };
          "namespaceSelector" = mkOption {
            description = "";
            type = types.nullOr (
              submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecAdminAffinityPodAffinityRequiredDuringSchedulingIgnoredDuringExecutionNamespaceSelector"
            );
          };
          "namespaces" = mkOption {
            description = "";
            type = types.nullOr (types.listOf types.str);
          };
          "topologyKey" = mkOption {
            description = "";
            type = types.str;
          };
        };

        config = {
          "labelSelector" = mkOverride 1002 null;
          "matchLabelKeys" = mkOverride 1002 null;
          "mismatchLabelKeys" = mkOverride 1002 null;
          "namespaceSelector" = mkOverride 1002 null;
          "namespaces" = mkOverride 1002 null;
        };

      };
    "seaweed.seaweedfs.com.v1.SeaweedSpecAdminAffinityPodAffinityRequiredDuringSchedulingIgnoredDuringExecutionLabelSelector" =
      {

        options = {
          "matchExpressions" = mkOption {
            description = "";
            type = types.nullOr (
              types.listOf (
                submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecAdminAffinityPodAffinityRequiredDuringSchedulingIgnoredDuringExecutionLabelSelectorMatchExpressions"
              )
            );
          };
          "matchLabels" = mkOption {
            description = "";
            type = types.nullOr (types.attrsOf types.str);
          };
        };

        config = {
          "matchExpressions" = mkOverride 1002 null;
          "matchLabels" = mkOverride 1002 null;
        };

      };
    "seaweed.seaweedfs.com.v1.SeaweedSpecAdminAffinityPodAffinityRequiredDuringSchedulingIgnoredDuringExecutionLabelSelectorMatchExpressions" =
      {

        options = {
          "key" = mkOption {
            description = "";
            type = types.str;
          };
          "operator" = mkOption {
            description = "";
            type = types.str;
          };
          "values" = mkOption {
            description = "";
            type = types.nullOr (types.listOf types.str);
          };
        };

        config = {
          "values" = mkOverride 1002 null;
        };

      };
    "seaweed.seaweedfs.com.v1.SeaweedSpecAdminAffinityPodAffinityRequiredDuringSchedulingIgnoredDuringExecutionNamespaceSelector" =
      {

        options = {
          "matchExpressions" = mkOption {
            description = "";
            type = types.nullOr (
              types.listOf (
                submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecAdminAffinityPodAffinityRequiredDuringSchedulingIgnoredDuringExecutionNamespaceSelectorMatchExpressions"
              )
            );
          };
          "matchLabels" = mkOption {
            description = "";
            type = types.nullOr (types.attrsOf types.str);
          };
        };

        config = {
          "matchExpressions" = mkOverride 1002 null;
          "matchLabels" = mkOverride 1002 null;
        };

      };
    "seaweed.seaweedfs.com.v1.SeaweedSpecAdminAffinityPodAffinityRequiredDuringSchedulingIgnoredDuringExecutionNamespaceSelectorMatchExpressions" =
      {

        options = {
          "key" = mkOption {
            description = "";
            type = types.str;
          };
          "operator" = mkOption {
            description = "";
            type = types.str;
          };
          "values" = mkOption {
            description = "";
            type = types.nullOr (types.listOf types.str);
          };
        };

        config = {
          "values" = mkOverride 1002 null;
        };

      };
    "seaweed.seaweedfs.com.v1.SeaweedSpecAdminAffinityPodAntiAffinity" = {

      options = {
        "preferredDuringSchedulingIgnoredDuringExecution" = mkOption {
          description = "";
          type = types.nullOr (
            types.listOf (
              submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecAdminAffinityPodAntiAffinityPreferredDuringSchedulingIgnoredDuringExecution"
            )
          );
        };
        "requiredDuringSchedulingIgnoredDuringExecution" = mkOption {
          description = "";
          type = types.nullOr (
            types.listOf (
              submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecAdminAffinityPodAntiAffinityRequiredDuringSchedulingIgnoredDuringExecution"
            )
          );
        };
      };

      config = {
        "preferredDuringSchedulingIgnoredDuringExecution" = mkOverride 1002 null;
        "requiredDuringSchedulingIgnoredDuringExecution" = mkOverride 1002 null;
      };

    };
    "seaweed.seaweedfs.com.v1.SeaweedSpecAdminAffinityPodAntiAffinityPreferredDuringSchedulingIgnoredDuringExecution" =
      {

        options = {
          "podAffinityTerm" = mkOption {
            description = "";
            type = submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecAdminAffinityPodAntiAffinityPreferredDuringSchedulingIgnoredDuringExecutionPodAffinityTerm";
          };
          "weight" = mkOption {
            description = "";
            type = types.int;
          };
        };

        config = { };

      };
    "seaweed.seaweedfs.com.v1.SeaweedSpecAdminAffinityPodAntiAffinityPreferredDuringSchedulingIgnoredDuringExecutionPodAffinityTerm" =
      {

        options = {
          "labelSelector" = mkOption {
            description = "";
            type = types.nullOr (
              submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecAdminAffinityPodAntiAffinityPreferredDuringSchedulingIgnoredDuringExecutionPodAffinityTermLabelSelector"
            );
          };
          "matchLabelKeys" = mkOption {
            description = "";
            type = types.nullOr (types.listOf types.str);
          };
          "mismatchLabelKeys" = mkOption {
            description = "";
            type = types.nullOr (types.listOf types.str);
          };
          "namespaceSelector" = mkOption {
            description = "";
            type = types.nullOr (
              submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecAdminAffinityPodAntiAffinityPreferredDuringSchedulingIgnoredDuringExecutionPodAffinityTermNamespaceSelector"
            );
          };
          "namespaces" = mkOption {
            description = "";
            type = types.nullOr (types.listOf types.str);
          };
          "topologyKey" = mkOption {
            description = "";
            type = types.str;
          };
        };

        config = {
          "labelSelector" = mkOverride 1002 null;
          "matchLabelKeys" = mkOverride 1002 null;
          "mismatchLabelKeys" = mkOverride 1002 null;
          "namespaceSelector" = mkOverride 1002 null;
          "namespaces" = mkOverride 1002 null;
        };

      };
    "seaweed.seaweedfs.com.v1.SeaweedSpecAdminAffinityPodAntiAffinityPreferredDuringSchedulingIgnoredDuringExecutionPodAffinityTermLabelSelector" =
      {

        options = {
          "matchExpressions" = mkOption {
            description = "";
            type = types.nullOr (
              types.listOf (
                submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecAdminAffinityPodAntiAffinityPreferredDuringSchedulingIgnoredDuringExecutionPodAffinityTermLabelSelectorMatchExpressions"
              )
            );
          };
          "matchLabels" = mkOption {
            description = "";
            type = types.nullOr (types.attrsOf types.str);
          };
        };

        config = {
          "matchExpressions" = mkOverride 1002 null;
          "matchLabels" = mkOverride 1002 null;
        };

      };
    "seaweed.seaweedfs.com.v1.SeaweedSpecAdminAffinityPodAntiAffinityPreferredDuringSchedulingIgnoredDuringExecutionPodAffinityTermLabelSelectorMatchExpressions" =
      {

        options = {
          "key" = mkOption {
            description = "";
            type = types.str;
          };
          "operator" = mkOption {
            description = "";
            type = types.str;
          };
          "values" = mkOption {
            description = "";
            type = types.nullOr (types.listOf types.str);
          };
        };

        config = {
          "values" = mkOverride 1002 null;
        };

      };
    "seaweed.seaweedfs.com.v1.SeaweedSpecAdminAffinityPodAntiAffinityPreferredDuringSchedulingIgnoredDuringExecutionPodAffinityTermNamespaceSelector" =
      {

        options = {
          "matchExpressions" = mkOption {
            description = "";
            type = types.nullOr (
              types.listOf (
                submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecAdminAffinityPodAntiAffinityPreferredDuringSchedulingIgnoredDuringExecutionPodAffinityTermNamespaceSelectorMatchExpressions"
              )
            );
          };
          "matchLabels" = mkOption {
            description = "";
            type = types.nullOr (types.attrsOf types.str);
          };
        };

        config = {
          "matchExpressions" = mkOverride 1002 null;
          "matchLabels" = mkOverride 1002 null;
        };

      };
    "seaweed.seaweedfs.com.v1.SeaweedSpecAdminAffinityPodAntiAffinityPreferredDuringSchedulingIgnoredDuringExecutionPodAffinityTermNamespaceSelectorMatchExpressions" =
      {

        options = {
          "key" = mkOption {
            description = "";
            type = types.str;
          };
          "operator" = mkOption {
            description = "";
            type = types.str;
          };
          "values" = mkOption {
            description = "";
            type = types.nullOr (types.listOf types.str);
          };
        };

        config = {
          "values" = mkOverride 1002 null;
        };

      };
    "seaweed.seaweedfs.com.v1.SeaweedSpecAdminAffinityPodAntiAffinityRequiredDuringSchedulingIgnoredDuringExecution" =
      {

        options = {
          "labelSelector" = mkOption {
            description = "";
            type = types.nullOr (
              submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecAdminAffinityPodAntiAffinityRequiredDuringSchedulingIgnoredDuringExecutionLabelSelector"
            );
          };
          "matchLabelKeys" = mkOption {
            description = "";
            type = types.nullOr (types.listOf types.str);
          };
          "mismatchLabelKeys" = mkOption {
            description = "";
            type = types.nullOr (types.listOf types.str);
          };
          "namespaceSelector" = mkOption {
            description = "";
            type = types.nullOr (
              submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecAdminAffinityPodAntiAffinityRequiredDuringSchedulingIgnoredDuringExecutionNamespaceSelector"
            );
          };
          "namespaces" = mkOption {
            description = "";
            type = types.nullOr (types.listOf types.str);
          };
          "topologyKey" = mkOption {
            description = "";
            type = types.str;
          };
        };

        config = {
          "labelSelector" = mkOverride 1002 null;
          "matchLabelKeys" = mkOverride 1002 null;
          "mismatchLabelKeys" = mkOverride 1002 null;
          "namespaceSelector" = mkOverride 1002 null;
          "namespaces" = mkOverride 1002 null;
        };

      };
    "seaweed.seaweedfs.com.v1.SeaweedSpecAdminAffinityPodAntiAffinityRequiredDuringSchedulingIgnoredDuringExecutionLabelSelector" =
      {

        options = {
          "matchExpressions" = mkOption {
            description = "";
            type = types.nullOr (
              types.listOf (
                submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecAdminAffinityPodAntiAffinityRequiredDuringSchedulingIgnoredDuringExecutionLabelSelectorMatchExpressions"
              )
            );
          };
          "matchLabels" = mkOption {
            description = "";
            type = types.nullOr (types.attrsOf types.str);
          };
        };

        config = {
          "matchExpressions" = mkOverride 1002 null;
          "matchLabels" = mkOverride 1002 null;
        };

      };
    "seaweed.seaweedfs.com.v1.SeaweedSpecAdminAffinityPodAntiAffinityRequiredDuringSchedulingIgnoredDuringExecutionLabelSelectorMatchExpressions" =
      {

        options = {
          "key" = mkOption {
            description = "";
            type = types.str;
          };
          "operator" = mkOption {
            description = "";
            type = types.str;
          };
          "values" = mkOption {
            description = "";
            type = types.nullOr (types.listOf types.str);
          };
        };

        config = {
          "values" = mkOverride 1002 null;
        };

      };
    "seaweed.seaweedfs.com.v1.SeaweedSpecAdminAffinityPodAntiAffinityRequiredDuringSchedulingIgnoredDuringExecutionNamespaceSelector" =
      {

        options = {
          "matchExpressions" = mkOption {
            description = "";
            type = types.nullOr (
              types.listOf (
                submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecAdminAffinityPodAntiAffinityRequiredDuringSchedulingIgnoredDuringExecutionNamespaceSelectorMatchExpressions"
              )
            );
          };
          "matchLabels" = mkOption {
            description = "";
            type = types.nullOr (types.attrsOf types.str);
          };
        };

        config = {
          "matchExpressions" = mkOverride 1002 null;
          "matchLabels" = mkOverride 1002 null;
        };

      };
    "seaweed.seaweedfs.com.v1.SeaweedSpecAdminAffinityPodAntiAffinityRequiredDuringSchedulingIgnoredDuringExecutionNamespaceSelectorMatchExpressions" =
      {

        options = {
          "key" = mkOption {
            description = "";
            type = types.str;
          };
          "operator" = mkOption {
            description = "";
            type = types.str;
          };
          "values" = mkOption {
            description = "";
            type = types.nullOr (types.listOf types.str);
          };
        };

        config = {
          "values" = mkOverride 1002 null;
        };

      };
    "seaweed.seaweedfs.com.v1.SeaweedSpecAdminClaims" = {

      options = {
        "name" = mkOption {
          description = "";
          type = types.str;
        };
        "request" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
      };

      config = {
        "request" = mkOverride 1002 null;
      };

    };
    "seaweed.seaweedfs.com.v1.SeaweedSpecAdminContainerSecurityContext" = {

      options = {
        "allowPrivilegeEscalation" = mkOption {
          description = "";
          type = types.nullOr types.bool;
        };
        "appArmorProfile" = mkOption {
          description = "";
          type = types.nullOr (
            submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecAdminContainerSecurityContextAppArmorProfile"
          );
        };
        "capabilities" = mkOption {
          description = "";
          type = types.nullOr (
            submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecAdminContainerSecurityContextCapabilities"
          );
        };
        "privileged" = mkOption {
          description = "";
          type = types.nullOr types.bool;
        };
        "procMount" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "readOnlyRootFilesystem" = mkOption {
          description = "";
          type = types.nullOr types.bool;
        };
        "runAsGroup" = mkOption {
          description = "";
          type = types.nullOr types.int;
        };
        "runAsNonRoot" = mkOption {
          description = "";
          type = types.nullOr types.bool;
        };
        "runAsUser" = mkOption {
          description = "";
          type = types.nullOr types.int;
        };
        "seLinuxOptions" = mkOption {
          description = "";
          type = types.nullOr (
            submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecAdminContainerSecurityContextSeLinuxOptions"
          );
        };
        "seccompProfile" = mkOption {
          description = "";
          type = types.nullOr (
            submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecAdminContainerSecurityContextSeccompProfile"
          );
        };
        "windowsOptions" = mkOption {
          description = "";
          type = types.nullOr (
            submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecAdminContainerSecurityContextWindowsOptions"
          );
        };
      };

      config = {
        "allowPrivilegeEscalation" = mkOverride 1002 null;
        "appArmorProfile" = mkOverride 1002 null;
        "capabilities" = mkOverride 1002 null;
        "privileged" = mkOverride 1002 null;
        "procMount" = mkOverride 1002 null;
        "readOnlyRootFilesystem" = mkOverride 1002 null;
        "runAsGroup" = mkOverride 1002 null;
        "runAsNonRoot" = mkOverride 1002 null;
        "runAsUser" = mkOverride 1002 null;
        "seLinuxOptions" = mkOverride 1002 null;
        "seccompProfile" = mkOverride 1002 null;
        "windowsOptions" = mkOverride 1002 null;
      };

    };
    "seaweed.seaweedfs.com.v1.SeaweedSpecAdminContainerSecurityContextAppArmorProfile" = {

      options = {
        "localhostProfile" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "type" = mkOption {
          description = "";
          type = types.str;
        };
      };

      config = {
        "localhostProfile" = mkOverride 1002 null;
      };

    };
    "seaweed.seaweedfs.com.v1.SeaweedSpecAdminContainerSecurityContextCapabilities" = {

      options = {
        "add" = mkOption {
          description = "";
          type = types.nullOr (types.listOf types.str);
        };
        "drop" = mkOption {
          description = "";
          type = types.nullOr (types.listOf types.str);
        };
      };

      config = {
        "add" = mkOverride 1002 null;
        "drop" = mkOverride 1002 null;
      };

    };
    "seaweed.seaweedfs.com.v1.SeaweedSpecAdminContainerSecurityContextSeLinuxOptions" = {

      options = {
        "level" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "role" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "type" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "user" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
      };

      config = {
        "level" = mkOverride 1002 null;
        "role" = mkOverride 1002 null;
        "type" = mkOverride 1002 null;
        "user" = mkOverride 1002 null;
      };

    };
    "seaweed.seaweedfs.com.v1.SeaweedSpecAdminContainerSecurityContextSeccompProfile" = {

      options = {
        "localhostProfile" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "type" = mkOption {
          description = "";
          type = types.str;
        };
      };

      config = {
        "localhostProfile" = mkOverride 1002 null;
      };

    };
    "seaweed.seaweedfs.com.v1.SeaweedSpecAdminContainerSecurityContextWindowsOptions" = {

      options = {
        "gmsaCredentialSpec" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "gmsaCredentialSpecName" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "hostProcess" = mkOption {
          description = "";
          type = types.nullOr types.bool;
        };
        "runAsUserName" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
      };

      config = {
        "gmsaCredentialSpec" = mkOverride 1002 null;
        "gmsaCredentialSpecName" = mkOverride 1002 null;
        "hostProcess" = mkOverride 1002 null;
        "runAsUserName" = mkOverride 1002 null;
      };

    };
    "seaweed.seaweedfs.com.v1.SeaweedSpecAdminCredentialsSecret" = {

      options = {
        "name" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
      };

      config = {
        "name" = mkOverride 1002 null;
      };

    };
    "seaweed.seaweedfs.com.v1.SeaweedSpecAdminEnv" = {

      options = {
        "name" = mkOption {
          description = "";
          type = types.str;
        };
        "value" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "valueFrom" = mkOption {
          description = "";
          type = types.nullOr (submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecAdminEnvValueFrom");
        };
      };

      config = {
        "value" = mkOverride 1002 null;
        "valueFrom" = mkOverride 1002 null;
      };

    };
    "seaweed.seaweedfs.com.v1.SeaweedSpecAdminEnvValueFrom" = {

      options = {
        "configMapKeyRef" = mkOption {
          description = "";
          type = types.nullOr (
            submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecAdminEnvValueFromConfigMapKeyRef"
          );
        };
        "fieldRef" = mkOption {
          description = "";
          type = types.nullOr (submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecAdminEnvValueFromFieldRef");
        };
        "fileKeyRef" = mkOption {
          description = "";
          type = types.nullOr (submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecAdminEnvValueFromFileKeyRef");
        };
        "resourceFieldRef" = mkOption {
          description = "";
          type = types.nullOr (
            submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecAdminEnvValueFromResourceFieldRef"
          );
        };
        "secretKeyRef" = mkOption {
          description = "";
          type = types.nullOr (
            submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecAdminEnvValueFromSecretKeyRef"
          );
        };
      };

      config = {
        "configMapKeyRef" = mkOverride 1002 null;
        "fieldRef" = mkOverride 1002 null;
        "fileKeyRef" = mkOverride 1002 null;
        "resourceFieldRef" = mkOverride 1002 null;
        "secretKeyRef" = mkOverride 1002 null;
      };

    };
    "seaweed.seaweedfs.com.v1.SeaweedSpecAdminEnvValueFromConfigMapKeyRef" = {

      options = {
        "key" = mkOption {
          description = "";
          type = types.str;
        };
        "name" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "optional" = mkOption {
          description = "";
          type = types.nullOr types.bool;
        };
      };

      config = {
        "name" = mkOverride 1002 null;
        "optional" = mkOverride 1002 null;
      };

    };
    "seaweed.seaweedfs.com.v1.SeaweedSpecAdminEnvValueFromFieldRef" = {

      options = {
        "apiVersion" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "fieldPath" = mkOption {
          description = "";
          type = types.str;
        };
      };

      config = {
        "apiVersion" = mkOverride 1002 null;
      };

    };
    "seaweed.seaweedfs.com.v1.SeaweedSpecAdminEnvValueFromFileKeyRef" = {

      options = {
        "key" = mkOption {
          description = "";
          type = types.str;
        };
        "optional" = mkOption {
          description = "";
          type = types.nullOr types.bool;
        };
        "path" = mkOption {
          description = "";
          type = types.str;
        };
        "volumeName" = mkOption {
          description = "";
          type = types.str;
        };
      };

      config = {
        "optional" = mkOverride 1002 null;
      };

    };
    "seaweed.seaweedfs.com.v1.SeaweedSpecAdminEnvValueFromResourceFieldRef" = {

      options = {
        "containerName" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "divisor" = mkOption {
          description = "";
          type = types.nullOr (types.either types.int types.str);
        };
        "resource" = mkOption {
          description = "";
          type = types.str;
        };
      };

      config = {
        "containerName" = mkOverride 1002 null;
        "divisor" = mkOverride 1002 null;
      };

    };
    "seaweed.seaweedfs.com.v1.SeaweedSpecAdminEnvValueFromSecretKeyRef" = {

      options = {
        "key" = mkOption {
          description = "";
          type = types.str;
        };
        "name" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "optional" = mkOption {
          description = "";
          type = types.nullOr types.bool;
        };
      };

      config = {
        "name" = mkOverride 1002 null;
        "optional" = mkOverride 1002 null;
      };

    };
    "seaweed.seaweedfs.com.v1.SeaweedSpecAdminImagePullSecrets" = {

      options = {
        "name" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
      };

      config = {
        "name" = mkOverride 1002 null;
      };

    };
    "seaweed.seaweedfs.com.v1.SeaweedSpecAdminIngress" = {

      options = {
        "annotations" = mkOption {
          description = "";
          type = types.nullOr (types.attrsOf types.str);
        };
        "className" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "enabled" = mkOption {
          description = "";
          type = types.nullOr types.bool;
        };
        "host" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "path" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "tls" = mkOption {
          description = "";
          type = types.nullOr (
            types.listOf (submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecAdminIngressTls")
          );
        };
      };

      config = {
        "annotations" = mkOverride 1002 null;
        "className" = mkOverride 1002 null;
        "enabled" = mkOverride 1002 null;
        "host" = mkOverride 1002 null;
        "path" = mkOverride 1002 null;
        "tls" = mkOverride 1002 null;
      };

    };
    "seaweed.seaweedfs.com.v1.SeaweedSpecAdminIngressTls" = {

      options = {
        "hosts" = mkOption {
          description = "";
          type = types.nullOr (types.listOf types.str);
        };
        "secretName" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
      };

      config = {
        "hosts" = mkOverride 1002 null;
        "secretName" = mkOverride 1002 null;
      };

    };
    "seaweed.seaweedfs.com.v1.SeaweedSpecAdminLivenessProbe" = {

      options = {
        "failureThreshold" = mkOption {
          description = "";
          type = types.nullOr types.int;
        };
        "initialDelaySeconds" = mkOption {
          description = "";
          type = types.nullOr types.int;
        };
        "periodSeconds" = mkOption {
          description = "";
          type = types.nullOr types.int;
        };
        "timeoutSeconds" = mkOption {
          description = "";
          type = types.nullOr types.int;
        };
      };

      config = {
        "failureThreshold" = mkOverride 1002 null;
        "initialDelaySeconds" = mkOverride 1002 null;
        "periodSeconds" = mkOverride 1002 null;
        "timeoutSeconds" = mkOverride 1002 null;
      };

    };
    "seaweed.seaweedfs.com.v1.SeaweedSpecAdminPodSecurityContext" = {

      options = {
        "appArmorProfile" = mkOption {
          description = "";
          type = types.nullOr (
            submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecAdminPodSecurityContextAppArmorProfile"
          );
        };
        "fsGroup" = mkOption {
          description = "";
          type = types.nullOr types.int;
        };
        "fsGroupChangePolicy" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "runAsGroup" = mkOption {
          description = "";
          type = types.nullOr types.int;
        };
        "runAsNonRoot" = mkOption {
          description = "";
          type = types.nullOr types.bool;
        };
        "runAsUser" = mkOption {
          description = "";
          type = types.nullOr types.int;
        };
        "seLinuxChangePolicy" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "seLinuxOptions" = mkOption {
          description = "";
          type = types.nullOr (
            submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecAdminPodSecurityContextSeLinuxOptions"
          );
        };
        "seccompProfile" = mkOption {
          description = "";
          type = types.nullOr (
            submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecAdminPodSecurityContextSeccompProfile"
          );
        };
        "supplementalGroups" = mkOption {
          description = "";
          type = types.nullOr (types.listOf types.int);
        };
        "supplementalGroupsPolicy" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "sysctls" = mkOption {
          description = "";
          type = types.nullOr (
            coerceAttrsOfSubmodulesToListByKey
              "seaweed.seaweedfs.com.v1.SeaweedSpecAdminPodSecurityContextSysctls"
              "name"
              [ ]
          );
          apply = attrsToList;
        };
        "windowsOptions" = mkOption {
          description = "";
          type = types.nullOr (
            submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecAdminPodSecurityContextWindowsOptions"
          );
        };
      };

      config = {
        "appArmorProfile" = mkOverride 1002 null;
        "fsGroup" = mkOverride 1002 null;
        "fsGroupChangePolicy" = mkOverride 1002 null;
        "runAsGroup" = mkOverride 1002 null;
        "runAsNonRoot" = mkOverride 1002 null;
        "runAsUser" = mkOverride 1002 null;
        "seLinuxChangePolicy" = mkOverride 1002 null;
        "seLinuxOptions" = mkOverride 1002 null;
        "seccompProfile" = mkOverride 1002 null;
        "supplementalGroups" = mkOverride 1002 null;
        "supplementalGroupsPolicy" = mkOverride 1002 null;
        "sysctls" = mkOverride 1002 null;
        "windowsOptions" = mkOverride 1002 null;
      };

    };
    "seaweed.seaweedfs.com.v1.SeaweedSpecAdminPodSecurityContextAppArmorProfile" = {

      options = {
        "localhostProfile" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "type" = mkOption {
          description = "";
          type = types.str;
        };
      };

      config = {
        "localhostProfile" = mkOverride 1002 null;
      };

    };
    "seaweed.seaweedfs.com.v1.SeaweedSpecAdminPodSecurityContextSeLinuxOptions" = {

      options = {
        "level" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "role" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "type" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "user" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
      };

      config = {
        "level" = mkOverride 1002 null;
        "role" = mkOverride 1002 null;
        "type" = mkOverride 1002 null;
        "user" = mkOverride 1002 null;
      };

    };
    "seaweed.seaweedfs.com.v1.SeaweedSpecAdminPodSecurityContextSeccompProfile" = {

      options = {
        "localhostProfile" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "type" = mkOption {
          description = "";
          type = types.str;
        };
      };

      config = {
        "localhostProfile" = mkOverride 1002 null;
      };

    };
    "seaweed.seaweedfs.com.v1.SeaweedSpecAdminPodSecurityContextSysctls" = {

      options = {
        "name" = mkOption {
          description = "";
          type = types.str;
        };
        "value" = mkOption {
          description = "";
          type = types.str;
        };
      };

      config = { };

    };
    "seaweed.seaweedfs.com.v1.SeaweedSpecAdminPodSecurityContextWindowsOptions" = {

      options = {
        "gmsaCredentialSpec" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "gmsaCredentialSpecName" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "hostProcess" = mkOption {
          description = "";
          type = types.nullOr types.bool;
        };
        "runAsUserName" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
      };

      config = {
        "gmsaCredentialSpec" = mkOverride 1002 null;
        "gmsaCredentialSpecName" = mkOverride 1002 null;
        "hostProcess" = mkOverride 1002 null;
        "runAsUserName" = mkOverride 1002 null;
      };

    };
    "seaweed.seaweedfs.com.v1.SeaweedSpecAdminReadinessProbe" = {

      options = {
        "failureThreshold" = mkOption {
          description = "";
          type = types.nullOr types.int;
        };
        "initialDelaySeconds" = mkOption {
          description = "";
          type = types.nullOr types.int;
        };
        "periodSeconds" = mkOption {
          description = "";
          type = types.nullOr types.int;
        };
        "successThreshold" = mkOption {
          description = "";
          type = types.nullOr types.int;
        };
        "timeoutSeconds" = mkOption {
          description = "";
          type = types.nullOr types.int;
        };
      };

      config = {
        "failureThreshold" = mkOverride 1002 null;
        "initialDelaySeconds" = mkOverride 1002 null;
        "periodSeconds" = mkOverride 1002 null;
        "successThreshold" = mkOverride 1002 null;
        "timeoutSeconds" = mkOverride 1002 null;
      };

    };
    "seaweed.seaweedfs.com.v1.SeaweedSpecAdminService" = {

      options = {
        "annotations" = mkOption {
          description = "";
          type = types.nullOr (types.attrsOf types.str);
        };
        "clusterIP" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "loadBalancerIP" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "type" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
      };

      config = {
        "annotations" = mkOverride 1002 null;
        "clusterIP" = mkOverride 1002 null;
        "loadBalancerIP" = mkOverride 1002 null;
        "type" = mkOverride 1002 null;
      };

    };
    "seaweed.seaweedfs.com.v1.SeaweedSpecAdminTolerations" = {

      options = {
        "effect" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "key" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "operator" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "tolerationSeconds" = mkOption {
          description = "";
          type = types.nullOr types.int;
        };
        "value" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
      };

      config = {
        "effect" = mkOverride 1002 null;
        "key" = mkOverride 1002 null;
        "operator" = mkOverride 1002 null;
        "tolerationSeconds" = mkOverride 1002 null;
        "value" = mkOverride 1002 null;
      };

    };
    "seaweed.seaweedfs.com.v1.SeaweedSpecAdminVolumeMounts" = {

      options = {
        "mountPath" = mkOption {
          description = "";
          type = types.str;
        };
        "mountPropagation" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "name" = mkOption {
          description = "";
          type = types.str;
        };
        "readOnly" = mkOption {
          description = "";
          type = types.nullOr types.bool;
        };
        "recursiveReadOnly" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "subPath" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "subPathExpr" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
      };

      config = {
        "mountPropagation" = mkOverride 1002 null;
        "readOnly" = mkOverride 1002 null;
        "recursiveReadOnly" = mkOverride 1002 null;
        "subPath" = mkOverride 1002 null;
        "subPathExpr" = mkOverride 1002 null;
      };

    };
    "seaweed.seaweedfs.com.v1.SeaweedSpecAdminVolumes" = {

      options = {
        "awsElasticBlockStore" = mkOption {
          description = "";
          type = types.nullOr (
            submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecAdminVolumesAwsElasticBlockStore"
          );
        };
        "azureDisk" = mkOption {
          description = "";
          type = types.nullOr (submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecAdminVolumesAzureDisk");
        };
        "azureFile" = mkOption {
          description = "";
          type = types.nullOr (submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecAdminVolumesAzureFile");
        };
        "cephfs" = mkOption {
          description = "";
          type = types.nullOr (submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecAdminVolumesCephfs");
        };
        "cinder" = mkOption {
          description = "";
          type = types.nullOr (submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecAdminVolumesCinder");
        };
        "configMap" = mkOption {
          description = "";
          type = types.nullOr (submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecAdminVolumesConfigMap");
        };
        "csi" = mkOption {
          description = "";
          type = types.nullOr (submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecAdminVolumesCsi");
        };
        "downwardAPI" = mkOption {
          description = "";
          type = types.nullOr (submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecAdminVolumesDownwardAPI");
        };
        "emptyDir" = mkOption {
          description = "";
          type = types.nullOr (submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecAdminVolumesEmptyDir");
        };
        "ephemeral" = mkOption {
          description = "";
          type = types.nullOr (submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecAdminVolumesEphemeral");
        };
        "fc" = mkOption {
          description = "";
          type = types.nullOr (submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecAdminVolumesFc");
        };
        "flexVolume" = mkOption {
          description = "";
          type = types.nullOr (submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecAdminVolumesFlexVolume");
        };
        "flocker" = mkOption {
          description = "";
          type = types.nullOr (submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecAdminVolumesFlocker");
        };
        "gcePersistentDisk" = mkOption {
          description = "";
          type = types.nullOr (
            submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecAdminVolumesGcePersistentDisk"
          );
        };
        "gitRepo" = mkOption {
          description = "";
          type = types.nullOr (submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecAdminVolumesGitRepo");
        };
        "glusterfs" = mkOption {
          description = "";
          type = types.nullOr (submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecAdminVolumesGlusterfs");
        };
        "hostPath" = mkOption {
          description = "";
          type = types.nullOr (submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecAdminVolumesHostPath");
        };
        "image" = mkOption {
          description = "";
          type = types.nullOr (submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecAdminVolumesImage");
        };
        "iscsi" = mkOption {
          description = "";
          type = types.nullOr (submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecAdminVolumesIscsi");
        };
        "name" = mkOption {
          description = "";
          type = types.str;
        };
        "nfs" = mkOption {
          description = "";
          type = types.nullOr (submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecAdminVolumesNfs");
        };
        "persistentVolumeClaim" = mkOption {
          description = "";
          type = types.nullOr (
            submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecAdminVolumesPersistentVolumeClaim"
          );
        };
        "photonPersistentDisk" = mkOption {
          description = "";
          type = types.nullOr (
            submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecAdminVolumesPhotonPersistentDisk"
          );
        };
        "portworxVolume" = mkOption {
          description = "";
          type = types.nullOr (submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecAdminVolumesPortworxVolume");
        };
        "projected" = mkOption {
          description = "";
          type = types.nullOr (submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecAdminVolumesProjected");
        };
        "quobyte" = mkOption {
          description = "";
          type = types.nullOr (submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecAdminVolumesQuobyte");
        };
        "rbd" = mkOption {
          description = "";
          type = types.nullOr (submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecAdminVolumesRbd");
        };
        "scaleIO" = mkOption {
          description = "";
          type = types.nullOr (submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecAdminVolumesScaleIO");
        };
        "secret" = mkOption {
          description = "";
          type = types.nullOr (submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecAdminVolumesSecret");
        };
        "storageos" = mkOption {
          description = "";
          type = types.nullOr (submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecAdminVolumesStorageos");
        };
        "vsphereVolume" = mkOption {
          description = "";
          type = types.nullOr (submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecAdminVolumesVsphereVolume");
        };
      };

      config = {
        "awsElasticBlockStore" = mkOverride 1002 null;
        "azureDisk" = mkOverride 1002 null;
        "azureFile" = mkOverride 1002 null;
        "cephfs" = mkOverride 1002 null;
        "cinder" = mkOverride 1002 null;
        "configMap" = mkOverride 1002 null;
        "csi" = mkOverride 1002 null;
        "downwardAPI" = mkOverride 1002 null;
        "emptyDir" = mkOverride 1002 null;
        "ephemeral" = mkOverride 1002 null;
        "fc" = mkOverride 1002 null;
        "flexVolume" = mkOverride 1002 null;
        "flocker" = mkOverride 1002 null;
        "gcePersistentDisk" = mkOverride 1002 null;
        "gitRepo" = mkOverride 1002 null;
        "glusterfs" = mkOverride 1002 null;
        "hostPath" = mkOverride 1002 null;
        "image" = mkOverride 1002 null;
        "iscsi" = mkOverride 1002 null;
        "nfs" = mkOverride 1002 null;
        "persistentVolumeClaim" = mkOverride 1002 null;
        "photonPersistentDisk" = mkOverride 1002 null;
        "portworxVolume" = mkOverride 1002 null;
        "projected" = mkOverride 1002 null;
        "quobyte" = mkOverride 1002 null;
        "rbd" = mkOverride 1002 null;
        "scaleIO" = mkOverride 1002 null;
        "secret" = mkOverride 1002 null;
        "storageos" = mkOverride 1002 null;
        "vsphereVolume" = mkOverride 1002 null;
      };

    };
    "seaweed.seaweedfs.com.v1.SeaweedSpecAdminVolumesAwsElasticBlockStore" = {

      options = {
        "fsType" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "partition" = mkOption {
          description = "";
          type = types.nullOr types.int;
        };
        "readOnly" = mkOption {
          description = "";
          type = types.nullOr types.bool;
        };
        "volumeID" = mkOption {
          description = "";
          type = types.str;
        };
      };

      config = {
        "fsType" = mkOverride 1002 null;
        "partition" = mkOverride 1002 null;
        "readOnly" = mkOverride 1002 null;
      };

    };
    "seaweed.seaweedfs.com.v1.SeaweedSpecAdminVolumesAzureDisk" = {

      options = {
        "cachingMode" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "diskName" = mkOption {
          description = "";
          type = types.str;
        };
        "diskURI" = mkOption {
          description = "";
          type = types.str;
        };
        "fsType" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "kind" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "readOnly" = mkOption {
          description = "";
          type = types.nullOr types.bool;
        };
      };

      config = {
        "cachingMode" = mkOverride 1002 null;
        "fsType" = mkOverride 1002 null;
        "kind" = mkOverride 1002 null;
        "readOnly" = mkOverride 1002 null;
      };

    };
    "seaweed.seaweedfs.com.v1.SeaweedSpecAdminVolumesAzureFile" = {

      options = {
        "readOnly" = mkOption {
          description = "";
          type = types.nullOr types.bool;
        };
        "secretName" = mkOption {
          description = "";
          type = types.str;
        };
        "shareName" = mkOption {
          description = "";
          type = types.str;
        };
      };

      config = {
        "readOnly" = mkOverride 1002 null;
      };

    };
    "seaweed.seaweedfs.com.v1.SeaweedSpecAdminVolumesCephfs" = {

      options = {
        "monitors" = mkOption {
          description = "";
          type = types.listOf types.str;
        };
        "path" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "readOnly" = mkOption {
          description = "";
          type = types.nullOr types.bool;
        };
        "secretFile" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "secretRef" = mkOption {
          description = "";
          type = types.nullOr (submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecAdminVolumesCephfsSecretRef");
        };
        "user" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
      };

      config = {
        "path" = mkOverride 1002 null;
        "readOnly" = mkOverride 1002 null;
        "secretFile" = mkOverride 1002 null;
        "secretRef" = mkOverride 1002 null;
        "user" = mkOverride 1002 null;
      };

    };
    "seaweed.seaweedfs.com.v1.SeaweedSpecAdminVolumesCephfsSecretRef" = {

      options = {
        "name" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
      };

      config = {
        "name" = mkOverride 1002 null;
      };

    };
    "seaweed.seaweedfs.com.v1.SeaweedSpecAdminVolumesCinder" = {

      options = {
        "fsType" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "readOnly" = mkOption {
          description = "";
          type = types.nullOr types.bool;
        };
        "secretRef" = mkOption {
          description = "";
          type = types.nullOr (submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecAdminVolumesCinderSecretRef");
        };
        "volumeID" = mkOption {
          description = "";
          type = types.str;
        };
      };

      config = {
        "fsType" = mkOverride 1002 null;
        "readOnly" = mkOverride 1002 null;
        "secretRef" = mkOverride 1002 null;
      };

    };
    "seaweed.seaweedfs.com.v1.SeaweedSpecAdminVolumesCinderSecretRef" = {

      options = {
        "name" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
      };

      config = {
        "name" = mkOverride 1002 null;
      };

    };
    "seaweed.seaweedfs.com.v1.SeaweedSpecAdminVolumesConfigMap" = {

      options = {
        "defaultMode" = mkOption {
          description = "";
          type = types.nullOr types.int;
        };
        "items" = mkOption {
          description = "";
          type = types.nullOr (
            types.listOf (submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecAdminVolumesConfigMapItems")
          );
        };
        "name" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "optional" = mkOption {
          description = "";
          type = types.nullOr types.bool;
        };
      };

      config = {
        "defaultMode" = mkOverride 1002 null;
        "items" = mkOverride 1002 null;
        "name" = mkOverride 1002 null;
        "optional" = mkOverride 1002 null;
      };

    };
    "seaweed.seaweedfs.com.v1.SeaweedSpecAdminVolumesConfigMapItems" = {

      options = {
        "key" = mkOption {
          description = "";
          type = types.str;
        };
        "mode" = mkOption {
          description = "";
          type = types.nullOr types.int;
        };
        "path" = mkOption {
          description = "";
          type = types.str;
        };
      };

      config = {
        "mode" = mkOverride 1002 null;
      };

    };
    "seaweed.seaweedfs.com.v1.SeaweedSpecAdminVolumesCsi" = {

      options = {
        "driver" = mkOption {
          description = "";
          type = types.str;
        };
        "fsType" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "nodePublishSecretRef" = mkOption {
          description = "";
          type = types.nullOr (
            submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecAdminVolumesCsiNodePublishSecretRef"
          );
        };
        "readOnly" = mkOption {
          description = "";
          type = types.nullOr types.bool;
        };
        "volumeAttributes" = mkOption {
          description = "";
          type = types.nullOr (types.attrsOf types.str);
        };
      };

      config = {
        "fsType" = mkOverride 1002 null;
        "nodePublishSecretRef" = mkOverride 1002 null;
        "readOnly" = mkOverride 1002 null;
        "volumeAttributes" = mkOverride 1002 null;
      };

    };
    "seaweed.seaweedfs.com.v1.SeaweedSpecAdminVolumesCsiNodePublishSecretRef" = {

      options = {
        "name" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
      };

      config = {
        "name" = mkOverride 1002 null;
      };

    };
    "seaweed.seaweedfs.com.v1.SeaweedSpecAdminVolumesDownwardAPI" = {

      options = {
        "defaultMode" = mkOption {
          description = "";
          type = types.nullOr types.int;
        };
        "items" = mkOption {
          description = "";
          type = types.nullOr (
            types.listOf (submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecAdminVolumesDownwardAPIItems")
          );
        };
      };

      config = {
        "defaultMode" = mkOverride 1002 null;
        "items" = mkOverride 1002 null;
      };

    };
    "seaweed.seaweedfs.com.v1.SeaweedSpecAdminVolumesDownwardAPIItems" = {

      options = {
        "fieldRef" = mkOption {
          description = "";
          type = types.nullOr (
            submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecAdminVolumesDownwardAPIItemsFieldRef"
          );
        };
        "mode" = mkOption {
          description = "";
          type = types.nullOr types.int;
        };
        "path" = mkOption {
          description = "";
          type = types.str;
        };
        "resourceFieldRef" = mkOption {
          description = "";
          type = types.nullOr (
            submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecAdminVolumesDownwardAPIItemsResourceFieldRef"
          );
        };
      };

      config = {
        "fieldRef" = mkOverride 1002 null;
        "mode" = mkOverride 1002 null;
        "resourceFieldRef" = mkOverride 1002 null;
      };

    };
    "seaweed.seaweedfs.com.v1.SeaweedSpecAdminVolumesDownwardAPIItemsFieldRef" = {

      options = {
        "apiVersion" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "fieldPath" = mkOption {
          description = "";
          type = types.str;
        };
      };

      config = {
        "apiVersion" = mkOverride 1002 null;
      };

    };
    "seaweed.seaweedfs.com.v1.SeaweedSpecAdminVolumesDownwardAPIItemsResourceFieldRef" = {

      options = {
        "containerName" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "divisor" = mkOption {
          description = "";
          type = types.nullOr (types.either types.int types.str);
        };
        "resource" = mkOption {
          description = "";
          type = types.str;
        };
      };

      config = {
        "containerName" = mkOverride 1002 null;
        "divisor" = mkOverride 1002 null;
      };

    };
    "seaweed.seaweedfs.com.v1.SeaweedSpecAdminVolumesEmptyDir" = {

      options = {
        "medium" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "sizeLimit" = mkOption {
          description = "";
          type = types.nullOr (types.either types.int types.str);
        };
      };

      config = {
        "medium" = mkOverride 1002 null;
        "sizeLimit" = mkOverride 1002 null;
      };

    };
    "seaweed.seaweedfs.com.v1.SeaweedSpecAdminVolumesEphemeral" = {

      options = {
        "volumeClaimTemplate" = mkOption {
          description = "";
          type = types.nullOr (
            submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecAdminVolumesEphemeralVolumeClaimTemplate"
          );
        };
      };

      config = {
        "volumeClaimTemplate" = mkOverride 1002 null;
      };

    };
    "seaweed.seaweedfs.com.v1.SeaweedSpecAdminVolumesEphemeralVolumeClaimTemplate" = {

      options = {
        "metadata" = mkOption {
          description = "";
          type = types.nullOr types.attrs;
        };
        "spec" = mkOption {
          description = "";
          type = submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecAdminVolumesEphemeralVolumeClaimTemplateSpec";
        };
      };

      config = {
        "metadata" = mkOverride 1002 null;
      };

    };
    "seaweed.seaweedfs.com.v1.SeaweedSpecAdminVolumesEphemeralVolumeClaimTemplateSpec" = {

      options = {
        "accessModes" = mkOption {
          description = "";
          type = types.nullOr (types.listOf types.str);
        };
        "dataSource" = mkOption {
          description = "";
          type = types.nullOr (
            submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecAdminVolumesEphemeralVolumeClaimTemplateSpecDataSource"
          );
        };
        "dataSourceRef" = mkOption {
          description = "";
          type = types.nullOr (
            submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecAdminVolumesEphemeralVolumeClaimTemplateSpecDataSourceRef"
          );
        };
        "resources" = mkOption {
          description = "";
          type = types.nullOr (
            submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecAdminVolumesEphemeralVolumeClaimTemplateSpecResources"
          );
        };
        "selector" = mkOption {
          description = "";
          type = types.nullOr (
            submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecAdminVolumesEphemeralVolumeClaimTemplateSpecSelector"
          );
        };
        "storageClassName" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "volumeAttributesClassName" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "volumeMode" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "volumeName" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
      };

      config = {
        "accessModes" = mkOverride 1002 null;
        "dataSource" = mkOverride 1002 null;
        "dataSourceRef" = mkOverride 1002 null;
        "resources" = mkOverride 1002 null;
        "selector" = mkOverride 1002 null;
        "storageClassName" = mkOverride 1002 null;
        "volumeAttributesClassName" = mkOverride 1002 null;
        "volumeMode" = mkOverride 1002 null;
        "volumeName" = mkOverride 1002 null;
      };

    };
    "seaweed.seaweedfs.com.v1.SeaweedSpecAdminVolumesEphemeralVolumeClaimTemplateSpecDataSource" = {

      options = {
        "apiGroup" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "kind" = mkOption {
          description = "";
          type = types.str;
        };
        "name" = mkOption {
          description = "";
          type = types.str;
        };
      };

      config = {
        "apiGroup" = mkOverride 1002 null;
      };

    };
    "seaweed.seaweedfs.com.v1.SeaweedSpecAdminVolumesEphemeralVolumeClaimTemplateSpecDataSourceRef" = {

      options = {
        "apiGroup" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "kind" = mkOption {
          description = "";
          type = types.str;
        };
        "name" = mkOption {
          description = "";
          type = types.str;
        };
        "namespace" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
      };

      config = {
        "apiGroup" = mkOverride 1002 null;
        "namespace" = mkOverride 1002 null;
      };

    };
    "seaweed.seaweedfs.com.v1.SeaweedSpecAdminVolumesEphemeralVolumeClaimTemplateSpecResources" = {

      options = {
        "limits" = mkOption {
          description = "";
          type = types.nullOr (types.attrsOf (types.either types.int types.str));
        };
        "requests" = mkOption {
          description = "";
          type = types.nullOr (types.attrsOf (types.either types.int types.str));
        };
      };

      config = {
        "limits" = mkOverride 1002 null;
        "requests" = mkOverride 1002 null;
      };

    };
    "seaweed.seaweedfs.com.v1.SeaweedSpecAdminVolumesEphemeralVolumeClaimTemplateSpecSelector" = {

      options = {
        "matchExpressions" = mkOption {
          description = "";
          type = types.nullOr (
            types.listOf (
              submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecAdminVolumesEphemeralVolumeClaimTemplateSpecSelectorMatchExpressions"
            )
          );
        };
        "matchLabels" = mkOption {
          description = "";
          type = types.nullOr (types.attrsOf types.str);
        };
      };

      config = {
        "matchExpressions" = mkOverride 1002 null;
        "matchLabels" = mkOverride 1002 null;
      };

    };
    "seaweed.seaweedfs.com.v1.SeaweedSpecAdminVolumesEphemeralVolumeClaimTemplateSpecSelectorMatchExpressions" =
      {

        options = {
          "key" = mkOption {
            description = "";
            type = types.str;
          };
          "operator" = mkOption {
            description = "";
            type = types.str;
          };
          "values" = mkOption {
            description = "";
            type = types.nullOr (types.listOf types.str);
          };
        };

        config = {
          "values" = mkOverride 1002 null;
        };

      };
    "seaweed.seaweedfs.com.v1.SeaweedSpecAdminVolumesFc" = {

      options = {
        "fsType" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "lun" = mkOption {
          description = "";
          type = types.nullOr types.int;
        };
        "readOnly" = mkOption {
          description = "";
          type = types.nullOr types.bool;
        };
        "targetWWNs" = mkOption {
          description = "";
          type = types.nullOr (types.listOf types.str);
        };
        "wwids" = mkOption {
          description = "";
          type = types.nullOr (types.listOf types.str);
        };
      };

      config = {
        "fsType" = mkOverride 1002 null;
        "lun" = mkOverride 1002 null;
        "readOnly" = mkOverride 1002 null;
        "targetWWNs" = mkOverride 1002 null;
        "wwids" = mkOverride 1002 null;
      };

    };
    "seaweed.seaweedfs.com.v1.SeaweedSpecAdminVolumesFlexVolume" = {

      options = {
        "driver" = mkOption {
          description = "";
          type = types.str;
        };
        "fsType" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "options" = mkOption {
          description = "";
          type = types.nullOr (types.attrsOf types.str);
        };
        "readOnly" = mkOption {
          description = "";
          type = types.nullOr types.bool;
        };
        "secretRef" = mkOption {
          description = "";
          type = types.nullOr (
            submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecAdminVolumesFlexVolumeSecretRef"
          );
        };
      };

      config = {
        "fsType" = mkOverride 1002 null;
        "options" = mkOverride 1002 null;
        "readOnly" = mkOverride 1002 null;
        "secretRef" = mkOverride 1002 null;
      };

    };
    "seaweed.seaweedfs.com.v1.SeaweedSpecAdminVolumesFlexVolumeSecretRef" = {

      options = {
        "name" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
      };

      config = {
        "name" = mkOverride 1002 null;
      };

    };
    "seaweed.seaweedfs.com.v1.SeaweedSpecAdminVolumesFlocker" = {

      options = {
        "datasetName" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "datasetUUID" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
      };

      config = {
        "datasetName" = mkOverride 1002 null;
        "datasetUUID" = mkOverride 1002 null;
      };

    };
    "seaweed.seaweedfs.com.v1.SeaweedSpecAdminVolumesGcePersistentDisk" = {

      options = {
        "fsType" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "partition" = mkOption {
          description = "";
          type = types.nullOr types.int;
        };
        "pdName" = mkOption {
          description = "";
          type = types.str;
        };
        "readOnly" = mkOption {
          description = "";
          type = types.nullOr types.bool;
        };
      };

      config = {
        "fsType" = mkOverride 1002 null;
        "partition" = mkOverride 1002 null;
        "readOnly" = mkOverride 1002 null;
      };

    };
    "seaweed.seaweedfs.com.v1.SeaweedSpecAdminVolumesGitRepo" = {

      options = {
        "directory" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "repository" = mkOption {
          description = "";
          type = types.str;
        };
        "revision" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
      };

      config = {
        "directory" = mkOverride 1002 null;
        "revision" = mkOverride 1002 null;
      };

    };
    "seaweed.seaweedfs.com.v1.SeaweedSpecAdminVolumesGlusterfs" = {

      options = {
        "endpoints" = mkOption {
          description = "";
          type = types.str;
        };
        "path" = mkOption {
          description = "";
          type = types.str;
        };
        "readOnly" = mkOption {
          description = "";
          type = types.nullOr types.bool;
        };
      };

      config = {
        "readOnly" = mkOverride 1002 null;
      };

    };
    "seaweed.seaweedfs.com.v1.SeaweedSpecAdminVolumesHostPath" = {

      options = {
        "path" = mkOption {
          description = "";
          type = types.str;
        };
        "type" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
      };

      config = {
        "type" = mkOverride 1002 null;
      };

    };
    "seaweed.seaweedfs.com.v1.SeaweedSpecAdminVolumesImage" = {

      options = {
        "pullPolicy" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "reference" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
      };

      config = {
        "pullPolicy" = mkOverride 1002 null;
        "reference" = mkOverride 1002 null;
      };

    };
    "seaweed.seaweedfs.com.v1.SeaweedSpecAdminVolumesIscsi" = {

      options = {
        "chapAuthDiscovery" = mkOption {
          description = "";
          type = types.nullOr types.bool;
        };
        "chapAuthSession" = mkOption {
          description = "";
          type = types.nullOr types.bool;
        };
        "fsType" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "initiatorName" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "iqn" = mkOption {
          description = "";
          type = types.str;
        };
        "iscsiInterface" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "lun" = mkOption {
          description = "";
          type = types.int;
        };
        "portals" = mkOption {
          description = "";
          type = types.nullOr (types.listOf types.str);
        };
        "readOnly" = mkOption {
          description = "";
          type = types.nullOr types.bool;
        };
        "secretRef" = mkOption {
          description = "";
          type = types.nullOr (submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecAdminVolumesIscsiSecretRef");
        };
        "targetPortal" = mkOption {
          description = "";
          type = types.str;
        };
      };

      config = {
        "chapAuthDiscovery" = mkOverride 1002 null;
        "chapAuthSession" = mkOverride 1002 null;
        "fsType" = mkOverride 1002 null;
        "initiatorName" = mkOverride 1002 null;
        "iscsiInterface" = mkOverride 1002 null;
        "portals" = mkOverride 1002 null;
        "readOnly" = mkOverride 1002 null;
        "secretRef" = mkOverride 1002 null;
      };

    };
    "seaweed.seaweedfs.com.v1.SeaweedSpecAdminVolumesIscsiSecretRef" = {

      options = {
        "name" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
      };

      config = {
        "name" = mkOverride 1002 null;
      };

    };
    "seaweed.seaweedfs.com.v1.SeaweedSpecAdminVolumesNfs" = {

      options = {
        "path" = mkOption {
          description = "";
          type = types.str;
        };
        "readOnly" = mkOption {
          description = "";
          type = types.nullOr types.bool;
        };
        "server" = mkOption {
          description = "";
          type = types.str;
        };
      };

      config = {
        "readOnly" = mkOverride 1002 null;
      };

    };
    "seaweed.seaweedfs.com.v1.SeaweedSpecAdminVolumesPersistentVolumeClaim" = {

      options = {
        "claimName" = mkOption {
          description = "";
          type = types.str;
        };
        "readOnly" = mkOption {
          description = "";
          type = types.nullOr types.bool;
        };
      };

      config = {
        "readOnly" = mkOverride 1002 null;
      };

    };
    "seaweed.seaweedfs.com.v1.SeaweedSpecAdminVolumesPhotonPersistentDisk" = {

      options = {
        "fsType" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "pdID" = mkOption {
          description = "";
          type = types.str;
        };
      };

      config = {
        "fsType" = mkOverride 1002 null;
      };

    };
    "seaweed.seaweedfs.com.v1.SeaweedSpecAdminVolumesPortworxVolume" = {

      options = {
        "fsType" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "readOnly" = mkOption {
          description = "";
          type = types.nullOr types.bool;
        };
        "volumeID" = mkOption {
          description = "";
          type = types.str;
        };
      };

      config = {
        "fsType" = mkOverride 1002 null;
        "readOnly" = mkOverride 1002 null;
      };

    };
    "seaweed.seaweedfs.com.v1.SeaweedSpecAdminVolumesProjected" = {

      options = {
        "defaultMode" = mkOption {
          description = "";
          type = types.nullOr types.int;
        };
        "sources" = mkOption {
          description = "";
          type = types.nullOr (
            types.listOf (submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecAdminVolumesProjectedSources")
          );
        };
      };

      config = {
        "defaultMode" = mkOverride 1002 null;
        "sources" = mkOverride 1002 null;
      };

    };
    "seaweed.seaweedfs.com.v1.SeaweedSpecAdminVolumesProjectedSources" = {

      options = {
        "clusterTrustBundle" = mkOption {
          description = "";
          type = types.nullOr (
            submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecAdminVolumesProjectedSourcesClusterTrustBundle"
          );
        };
        "configMap" = mkOption {
          description = "";
          type = types.nullOr (
            submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecAdminVolumesProjectedSourcesConfigMap"
          );
        };
        "downwardAPI" = mkOption {
          description = "";
          type = types.nullOr (
            submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecAdminVolumesProjectedSourcesDownwardAPI"
          );
        };
        "podCertificate" = mkOption {
          description = "";
          type = types.nullOr (
            submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecAdminVolumesProjectedSourcesPodCertificate"
          );
        };
        "secret" = mkOption {
          description = "";
          type = types.nullOr (
            submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecAdminVolumesProjectedSourcesSecret"
          );
        };
        "serviceAccountToken" = mkOption {
          description = "";
          type = types.nullOr (
            submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecAdminVolumesProjectedSourcesServiceAccountToken"
          );
        };
      };

      config = {
        "clusterTrustBundle" = mkOverride 1002 null;
        "configMap" = mkOverride 1002 null;
        "downwardAPI" = mkOverride 1002 null;
        "podCertificate" = mkOverride 1002 null;
        "secret" = mkOverride 1002 null;
        "serviceAccountToken" = mkOverride 1002 null;
      };

    };
    "seaweed.seaweedfs.com.v1.SeaweedSpecAdminVolumesProjectedSourcesClusterTrustBundle" = {

      options = {
        "labelSelector" = mkOption {
          description = "";
          type = types.nullOr (
            submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecAdminVolumesProjectedSourcesClusterTrustBundleLabelSelector"
          );
        };
        "name" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "optional" = mkOption {
          description = "";
          type = types.nullOr types.bool;
        };
        "path" = mkOption {
          description = "";
          type = types.str;
        };
        "signerName" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
      };

      config = {
        "labelSelector" = mkOverride 1002 null;
        "name" = mkOverride 1002 null;
        "optional" = mkOverride 1002 null;
        "signerName" = mkOverride 1002 null;
      };

    };
    "seaweed.seaweedfs.com.v1.SeaweedSpecAdminVolumesProjectedSourcesClusterTrustBundleLabelSelector" =
      {

        options = {
          "matchExpressions" = mkOption {
            description = "";
            type = types.nullOr (
              types.listOf (
                submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecAdminVolumesProjectedSourcesClusterTrustBundleLabelSelectorMatchExpressions"
              )
            );
          };
          "matchLabels" = mkOption {
            description = "";
            type = types.nullOr (types.attrsOf types.str);
          };
        };

        config = {
          "matchExpressions" = mkOverride 1002 null;
          "matchLabels" = mkOverride 1002 null;
        };

      };
    "seaweed.seaweedfs.com.v1.SeaweedSpecAdminVolumesProjectedSourcesClusterTrustBundleLabelSelectorMatchExpressions" =
      {

        options = {
          "key" = mkOption {
            description = "";
            type = types.str;
          };
          "operator" = mkOption {
            description = "";
            type = types.str;
          };
          "values" = mkOption {
            description = "";
            type = types.nullOr (types.listOf types.str);
          };
        };

        config = {
          "values" = mkOverride 1002 null;
        };

      };
    "seaweed.seaweedfs.com.v1.SeaweedSpecAdminVolumesProjectedSourcesConfigMap" = {

      options = {
        "items" = mkOption {
          description = "";
          type = types.nullOr (
            types.listOf (
              submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecAdminVolumesProjectedSourcesConfigMapItems"
            )
          );
        };
        "name" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "optional" = mkOption {
          description = "";
          type = types.nullOr types.bool;
        };
      };

      config = {
        "items" = mkOverride 1002 null;
        "name" = mkOverride 1002 null;
        "optional" = mkOverride 1002 null;
      };

    };
    "seaweed.seaweedfs.com.v1.SeaweedSpecAdminVolumesProjectedSourcesConfigMapItems" = {

      options = {
        "key" = mkOption {
          description = "";
          type = types.str;
        };
        "mode" = mkOption {
          description = "";
          type = types.nullOr types.int;
        };
        "path" = mkOption {
          description = "";
          type = types.str;
        };
      };

      config = {
        "mode" = mkOverride 1002 null;
      };

    };
    "seaweed.seaweedfs.com.v1.SeaweedSpecAdminVolumesProjectedSourcesDownwardAPI" = {

      options = {
        "items" = mkOption {
          description = "";
          type = types.nullOr (
            types.listOf (
              submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecAdminVolumesProjectedSourcesDownwardAPIItems"
            )
          );
        };
      };

      config = {
        "items" = mkOverride 1002 null;
      };

    };
    "seaweed.seaweedfs.com.v1.SeaweedSpecAdminVolumesProjectedSourcesDownwardAPIItems" = {

      options = {
        "fieldRef" = mkOption {
          description = "";
          type = types.nullOr (
            submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecAdminVolumesProjectedSourcesDownwardAPIItemsFieldRef"
          );
        };
        "mode" = mkOption {
          description = "";
          type = types.nullOr types.int;
        };
        "path" = mkOption {
          description = "";
          type = types.str;
        };
        "resourceFieldRef" = mkOption {
          description = "";
          type = types.nullOr (
            submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecAdminVolumesProjectedSourcesDownwardAPIItemsResourceFieldRef"
          );
        };
      };

      config = {
        "fieldRef" = mkOverride 1002 null;
        "mode" = mkOverride 1002 null;
        "resourceFieldRef" = mkOverride 1002 null;
      };

    };
    "seaweed.seaweedfs.com.v1.SeaweedSpecAdminVolumesProjectedSourcesDownwardAPIItemsFieldRef" = {

      options = {
        "apiVersion" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "fieldPath" = mkOption {
          description = "";
          type = types.str;
        };
      };

      config = {
        "apiVersion" = mkOverride 1002 null;
      };

    };
    "seaweed.seaweedfs.com.v1.SeaweedSpecAdminVolumesProjectedSourcesDownwardAPIItemsResourceFieldRef" =
      {

        options = {
          "containerName" = mkOption {
            description = "";
            type = types.nullOr types.str;
          };
          "divisor" = mkOption {
            description = "";
            type = types.nullOr (types.either types.int types.str);
          };
          "resource" = mkOption {
            description = "";
            type = types.str;
          };
        };

        config = {
          "containerName" = mkOverride 1002 null;
          "divisor" = mkOverride 1002 null;
        };

      };
    "seaweed.seaweedfs.com.v1.SeaweedSpecAdminVolumesProjectedSourcesPodCertificate" = {

      options = {
        "certificateChainPath" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "credentialBundlePath" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "keyPath" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "keyType" = mkOption {
          description = "";
          type = types.str;
        };
        "maxExpirationSeconds" = mkOption {
          description = "";
          type = types.nullOr types.int;
        };
        "signerName" = mkOption {
          description = "";
          type = types.str;
        };
        "userAnnotations" = mkOption {
          description = "";
          type = types.nullOr (types.attrsOf types.str);
        };
      };

      config = {
        "certificateChainPath" = mkOverride 1002 null;
        "credentialBundlePath" = mkOverride 1002 null;
        "keyPath" = mkOverride 1002 null;
        "maxExpirationSeconds" = mkOverride 1002 null;
        "userAnnotations" = mkOverride 1002 null;
      };

    };
    "seaweed.seaweedfs.com.v1.SeaweedSpecAdminVolumesProjectedSourcesSecret" = {

      options = {
        "items" = mkOption {
          description = "";
          type = types.nullOr (
            types.listOf (
              submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecAdminVolumesProjectedSourcesSecretItems"
            )
          );
        };
        "name" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "optional" = mkOption {
          description = "";
          type = types.nullOr types.bool;
        };
      };

      config = {
        "items" = mkOverride 1002 null;
        "name" = mkOverride 1002 null;
        "optional" = mkOverride 1002 null;
      };

    };
    "seaweed.seaweedfs.com.v1.SeaweedSpecAdminVolumesProjectedSourcesSecretItems" = {

      options = {
        "key" = mkOption {
          description = "";
          type = types.str;
        };
        "mode" = mkOption {
          description = "";
          type = types.nullOr types.int;
        };
        "path" = mkOption {
          description = "";
          type = types.str;
        };
      };

      config = {
        "mode" = mkOverride 1002 null;
      };

    };
    "seaweed.seaweedfs.com.v1.SeaweedSpecAdminVolumesProjectedSourcesServiceAccountToken" = {

      options = {
        "audience" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "expirationSeconds" = mkOption {
          description = "";
          type = types.nullOr types.int;
        };
        "path" = mkOption {
          description = "";
          type = types.str;
        };
      };

      config = {
        "audience" = mkOverride 1002 null;
        "expirationSeconds" = mkOverride 1002 null;
      };

    };
    "seaweed.seaweedfs.com.v1.SeaweedSpecAdminVolumesQuobyte" = {

      options = {
        "group" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "readOnly" = mkOption {
          description = "";
          type = types.nullOr types.bool;
        };
        "registry" = mkOption {
          description = "";
          type = types.str;
        };
        "tenant" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "user" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "volume" = mkOption {
          description = "";
          type = types.str;
        };
      };

      config = {
        "group" = mkOverride 1002 null;
        "readOnly" = mkOverride 1002 null;
        "tenant" = mkOverride 1002 null;
        "user" = mkOverride 1002 null;
      };

    };
    "seaweed.seaweedfs.com.v1.SeaweedSpecAdminVolumesRbd" = {

      options = {
        "fsType" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "image" = mkOption {
          description = "";
          type = types.str;
        };
        "keyring" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "monitors" = mkOption {
          description = "";
          type = types.listOf types.str;
        };
        "pool" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "readOnly" = mkOption {
          description = "";
          type = types.nullOr types.bool;
        };
        "secretRef" = mkOption {
          description = "";
          type = types.nullOr (submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecAdminVolumesRbdSecretRef");
        };
        "user" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
      };

      config = {
        "fsType" = mkOverride 1002 null;
        "keyring" = mkOverride 1002 null;
        "pool" = mkOverride 1002 null;
        "readOnly" = mkOverride 1002 null;
        "secretRef" = mkOverride 1002 null;
        "user" = mkOverride 1002 null;
      };

    };
    "seaweed.seaweedfs.com.v1.SeaweedSpecAdminVolumesRbdSecretRef" = {

      options = {
        "name" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
      };

      config = {
        "name" = mkOverride 1002 null;
      };

    };
    "seaweed.seaweedfs.com.v1.SeaweedSpecAdminVolumesScaleIO" = {

      options = {
        "fsType" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "gateway" = mkOption {
          description = "";
          type = types.str;
        };
        "protectionDomain" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "readOnly" = mkOption {
          description = "";
          type = types.nullOr types.bool;
        };
        "secretRef" = mkOption {
          description = "";
          type = submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecAdminVolumesScaleIOSecretRef";
        };
        "sslEnabled" = mkOption {
          description = "";
          type = types.nullOr types.bool;
        };
        "storageMode" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "storagePool" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "system" = mkOption {
          description = "";
          type = types.str;
        };
        "volumeName" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
      };

      config = {
        "fsType" = mkOverride 1002 null;
        "protectionDomain" = mkOverride 1002 null;
        "readOnly" = mkOverride 1002 null;
        "sslEnabled" = mkOverride 1002 null;
        "storageMode" = mkOverride 1002 null;
        "storagePool" = mkOverride 1002 null;
        "volumeName" = mkOverride 1002 null;
      };

    };
    "seaweed.seaweedfs.com.v1.SeaweedSpecAdminVolumesScaleIOSecretRef" = {

      options = {
        "name" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
      };

      config = {
        "name" = mkOverride 1002 null;
      };

    };
    "seaweed.seaweedfs.com.v1.SeaweedSpecAdminVolumesSecret" = {

      options = {
        "defaultMode" = mkOption {
          description = "";
          type = types.nullOr types.int;
        };
        "items" = mkOption {
          description = "";
          type = types.nullOr (
            types.listOf (submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecAdminVolumesSecretItems")
          );
        };
        "optional" = mkOption {
          description = "";
          type = types.nullOr types.bool;
        };
        "secretName" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
      };

      config = {
        "defaultMode" = mkOverride 1002 null;
        "items" = mkOverride 1002 null;
        "optional" = mkOverride 1002 null;
        "secretName" = mkOverride 1002 null;
      };

    };
    "seaweed.seaweedfs.com.v1.SeaweedSpecAdminVolumesSecretItems" = {

      options = {
        "key" = mkOption {
          description = "";
          type = types.str;
        };
        "mode" = mkOption {
          description = "";
          type = types.nullOr types.int;
        };
        "path" = mkOption {
          description = "";
          type = types.str;
        };
      };

      config = {
        "mode" = mkOverride 1002 null;
      };

    };
    "seaweed.seaweedfs.com.v1.SeaweedSpecAdminVolumesStorageos" = {

      options = {
        "fsType" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "readOnly" = mkOption {
          description = "";
          type = types.nullOr types.bool;
        };
        "secretRef" = mkOption {
          description = "";
          type = types.nullOr (
            submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecAdminVolumesStorageosSecretRef"
          );
        };
        "volumeName" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "volumeNamespace" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
      };

      config = {
        "fsType" = mkOverride 1002 null;
        "readOnly" = mkOverride 1002 null;
        "secretRef" = mkOverride 1002 null;
        "volumeName" = mkOverride 1002 null;
        "volumeNamespace" = mkOverride 1002 null;
      };

    };
    "seaweed.seaweedfs.com.v1.SeaweedSpecAdminVolumesStorageosSecretRef" = {

      options = {
        "name" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
      };

      config = {
        "name" = mkOverride 1002 null;
      };

    };
    "seaweed.seaweedfs.com.v1.SeaweedSpecAdminVolumesVsphereVolume" = {

      options = {
        "fsType" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "storagePolicyID" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "storagePolicyName" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "volumePath" = mkOption {
          description = "";
          type = types.str;
        };
      };

      config = {
        "fsType" = mkOverride 1002 null;
        "storagePolicyID" = mkOverride 1002 null;
        "storagePolicyName" = mkOverride 1002 null;
      };

    };
    "seaweed.seaweedfs.com.v1.SeaweedSpecAffinity" = {

      options = {
        "nodeAffinity" = mkOption {
          description = "";
          type = types.nullOr (submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecAffinityNodeAffinity");
        };
        "podAffinity" = mkOption {
          description = "";
          type = types.nullOr (submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecAffinityPodAffinity");
        };
        "podAntiAffinity" = mkOption {
          description = "";
          type = types.nullOr (submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecAffinityPodAntiAffinity");
        };
      };

      config = {
        "nodeAffinity" = mkOverride 1002 null;
        "podAffinity" = mkOverride 1002 null;
        "podAntiAffinity" = mkOverride 1002 null;
      };

    };
    "seaweed.seaweedfs.com.v1.SeaweedSpecAffinityNodeAffinity" = {

      options = {
        "preferredDuringSchedulingIgnoredDuringExecution" = mkOption {
          description = "";
          type = types.nullOr (
            types.listOf (
              submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecAffinityNodeAffinityPreferredDuringSchedulingIgnoredDuringExecution"
            )
          );
        };
        "requiredDuringSchedulingIgnoredDuringExecution" = mkOption {
          description = "";
          type = types.nullOr (
            submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecAffinityNodeAffinityRequiredDuringSchedulingIgnoredDuringExecution"
          );
        };
      };

      config = {
        "preferredDuringSchedulingIgnoredDuringExecution" = mkOverride 1002 null;
        "requiredDuringSchedulingIgnoredDuringExecution" = mkOverride 1002 null;
      };

    };
    "seaweed.seaweedfs.com.v1.SeaweedSpecAffinityNodeAffinityPreferredDuringSchedulingIgnoredDuringExecution" =
      {

        options = {
          "preference" = mkOption {
            description = "";
            type = submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecAffinityNodeAffinityPreferredDuringSchedulingIgnoredDuringExecutionPreference";
          };
          "weight" = mkOption {
            description = "";
            type = types.int;
          };
        };

        config = { };

      };
    "seaweed.seaweedfs.com.v1.SeaweedSpecAffinityNodeAffinityPreferredDuringSchedulingIgnoredDuringExecutionPreference" =
      {

        options = {
          "matchExpressions" = mkOption {
            description = "";
            type = types.nullOr (
              types.listOf (
                submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecAffinityNodeAffinityPreferredDuringSchedulingIgnoredDuringExecutionPreferenceMatchExpressions"
              )
            );
          };
          "matchFields" = mkOption {
            description = "";
            type = types.nullOr (
              types.listOf (
                submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecAffinityNodeAffinityPreferredDuringSchedulingIgnoredDuringExecutionPreferenceMatchFields"
              )
            );
          };
        };

        config = {
          "matchExpressions" = mkOverride 1002 null;
          "matchFields" = mkOverride 1002 null;
        };

      };
    "seaweed.seaweedfs.com.v1.SeaweedSpecAffinityNodeAffinityPreferredDuringSchedulingIgnoredDuringExecutionPreferenceMatchExpressions" =
      {

        options = {
          "key" = mkOption {
            description = "";
            type = types.str;
          };
          "operator" = mkOption {
            description = "";
            type = types.str;
          };
          "values" = mkOption {
            description = "";
            type = types.nullOr (types.listOf types.str);
          };
        };

        config = {
          "values" = mkOverride 1002 null;
        };

      };
    "seaweed.seaweedfs.com.v1.SeaweedSpecAffinityNodeAffinityPreferredDuringSchedulingIgnoredDuringExecutionPreferenceMatchFields" =
      {

        options = {
          "key" = mkOption {
            description = "";
            type = types.str;
          };
          "operator" = mkOption {
            description = "";
            type = types.str;
          };
          "values" = mkOption {
            description = "";
            type = types.nullOr (types.listOf types.str);
          };
        };

        config = {
          "values" = mkOverride 1002 null;
        };

      };
    "seaweed.seaweedfs.com.v1.SeaweedSpecAffinityNodeAffinityRequiredDuringSchedulingIgnoredDuringExecution" =
      {

        options = {
          "nodeSelectorTerms" = mkOption {
            description = "";
            type = types.listOf (
              submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecAffinityNodeAffinityRequiredDuringSchedulingIgnoredDuringExecutionNodeSelectorTerms"
            );
          };
        };

        config = { };

      };
    "seaweed.seaweedfs.com.v1.SeaweedSpecAffinityNodeAffinityRequiredDuringSchedulingIgnoredDuringExecutionNodeSelectorTerms" =
      {

        options = {
          "matchExpressions" = mkOption {
            description = "";
            type = types.nullOr (
              types.listOf (
                submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecAffinityNodeAffinityRequiredDuringSchedulingIgnoredDuringExecutionNodeSelectorTermsMatchExpressions"
              )
            );
          };
          "matchFields" = mkOption {
            description = "";
            type = types.nullOr (
              types.listOf (
                submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecAffinityNodeAffinityRequiredDuringSchedulingIgnoredDuringExecutionNodeSelectorTermsMatchFields"
              )
            );
          };
        };

        config = {
          "matchExpressions" = mkOverride 1002 null;
          "matchFields" = mkOverride 1002 null;
        };

      };
    "seaweed.seaweedfs.com.v1.SeaweedSpecAffinityNodeAffinityRequiredDuringSchedulingIgnoredDuringExecutionNodeSelectorTermsMatchExpressions" =
      {

        options = {
          "key" = mkOption {
            description = "";
            type = types.str;
          };
          "operator" = mkOption {
            description = "";
            type = types.str;
          };
          "values" = mkOption {
            description = "";
            type = types.nullOr (types.listOf types.str);
          };
        };

        config = {
          "values" = mkOverride 1002 null;
        };

      };
    "seaweed.seaweedfs.com.v1.SeaweedSpecAffinityNodeAffinityRequiredDuringSchedulingIgnoredDuringExecutionNodeSelectorTermsMatchFields" =
      {

        options = {
          "key" = mkOption {
            description = "";
            type = types.str;
          };
          "operator" = mkOption {
            description = "";
            type = types.str;
          };
          "values" = mkOption {
            description = "";
            type = types.nullOr (types.listOf types.str);
          };
        };

        config = {
          "values" = mkOverride 1002 null;
        };

      };
    "seaweed.seaweedfs.com.v1.SeaweedSpecAffinityPodAffinity" = {

      options = {
        "preferredDuringSchedulingIgnoredDuringExecution" = mkOption {
          description = "";
          type = types.nullOr (
            types.listOf (
              submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecAffinityPodAffinityPreferredDuringSchedulingIgnoredDuringExecution"
            )
          );
        };
        "requiredDuringSchedulingIgnoredDuringExecution" = mkOption {
          description = "";
          type = types.nullOr (
            types.listOf (
              submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecAffinityPodAffinityRequiredDuringSchedulingIgnoredDuringExecution"
            )
          );
        };
      };

      config = {
        "preferredDuringSchedulingIgnoredDuringExecution" = mkOverride 1002 null;
        "requiredDuringSchedulingIgnoredDuringExecution" = mkOverride 1002 null;
      };

    };
    "seaweed.seaweedfs.com.v1.SeaweedSpecAffinityPodAffinityPreferredDuringSchedulingIgnoredDuringExecution" =
      {

        options = {
          "podAffinityTerm" = mkOption {
            description = "";
            type = submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecAffinityPodAffinityPreferredDuringSchedulingIgnoredDuringExecutionPodAffinityTerm";
          };
          "weight" = mkOption {
            description = "";
            type = types.int;
          };
        };

        config = { };

      };
    "seaweed.seaweedfs.com.v1.SeaweedSpecAffinityPodAffinityPreferredDuringSchedulingIgnoredDuringExecutionPodAffinityTerm" =
      {

        options = {
          "labelSelector" = mkOption {
            description = "";
            type = types.nullOr (
              submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecAffinityPodAffinityPreferredDuringSchedulingIgnoredDuringExecutionPodAffinityTermLabelSelector"
            );
          };
          "matchLabelKeys" = mkOption {
            description = "";
            type = types.nullOr (types.listOf types.str);
          };
          "mismatchLabelKeys" = mkOption {
            description = "";
            type = types.nullOr (types.listOf types.str);
          };
          "namespaceSelector" = mkOption {
            description = "";
            type = types.nullOr (
              submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecAffinityPodAffinityPreferredDuringSchedulingIgnoredDuringExecutionPodAffinityTermNamespaceSelector"
            );
          };
          "namespaces" = mkOption {
            description = "";
            type = types.nullOr (types.listOf types.str);
          };
          "topologyKey" = mkOption {
            description = "";
            type = types.str;
          };
        };

        config = {
          "labelSelector" = mkOverride 1002 null;
          "matchLabelKeys" = mkOverride 1002 null;
          "mismatchLabelKeys" = mkOverride 1002 null;
          "namespaceSelector" = mkOverride 1002 null;
          "namespaces" = mkOverride 1002 null;
        };

      };
    "seaweed.seaweedfs.com.v1.SeaweedSpecAffinityPodAffinityPreferredDuringSchedulingIgnoredDuringExecutionPodAffinityTermLabelSelector" =
      {

        options = {
          "matchExpressions" = mkOption {
            description = "";
            type = types.nullOr (
              types.listOf (
                submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecAffinityPodAffinityPreferredDuringSchedulingIgnoredDuringExecutionPodAffinityTermLabelSelectorMatchExpressions"
              )
            );
          };
          "matchLabels" = mkOption {
            description = "";
            type = types.nullOr (types.attrsOf types.str);
          };
        };

        config = {
          "matchExpressions" = mkOverride 1002 null;
          "matchLabels" = mkOverride 1002 null;
        };

      };
    "seaweed.seaweedfs.com.v1.SeaweedSpecAffinityPodAffinityPreferredDuringSchedulingIgnoredDuringExecutionPodAffinityTermLabelSelectorMatchExpressions" =
      {

        options = {
          "key" = mkOption {
            description = "";
            type = types.str;
          };
          "operator" = mkOption {
            description = "";
            type = types.str;
          };
          "values" = mkOption {
            description = "";
            type = types.nullOr (types.listOf types.str);
          };
        };

        config = {
          "values" = mkOverride 1002 null;
        };

      };
    "seaweed.seaweedfs.com.v1.SeaweedSpecAffinityPodAffinityPreferredDuringSchedulingIgnoredDuringExecutionPodAffinityTermNamespaceSelector" =
      {

        options = {
          "matchExpressions" = mkOption {
            description = "";
            type = types.nullOr (
              types.listOf (
                submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecAffinityPodAffinityPreferredDuringSchedulingIgnoredDuringExecutionPodAffinityTermNamespaceSelectorMatchExpressions"
              )
            );
          };
          "matchLabels" = mkOption {
            description = "";
            type = types.nullOr (types.attrsOf types.str);
          };
        };

        config = {
          "matchExpressions" = mkOverride 1002 null;
          "matchLabels" = mkOverride 1002 null;
        };

      };
    "seaweed.seaweedfs.com.v1.SeaweedSpecAffinityPodAffinityPreferredDuringSchedulingIgnoredDuringExecutionPodAffinityTermNamespaceSelectorMatchExpressions" =
      {

        options = {
          "key" = mkOption {
            description = "";
            type = types.str;
          };
          "operator" = mkOption {
            description = "";
            type = types.str;
          };
          "values" = mkOption {
            description = "";
            type = types.nullOr (types.listOf types.str);
          };
        };

        config = {
          "values" = mkOverride 1002 null;
        };

      };
    "seaweed.seaweedfs.com.v1.SeaweedSpecAffinityPodAffinityRequiredDuringSchedulingIgnoredDuringExecution" =
      {

        options = {
          "labelSelector" = mkOption {
            description = "";
            type = types.nullOr (
              submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecAffinityPodAffinityRequiredDuringSchedulingIgnoredDuringExecutionLabelSelector"
            );
          };
          "matchLabelKeys" = mkOption {
            description = "";
            type = types.nullOr (types.listOf types.str);
          };
          "mismatchLabelKeys" = mkOption {
            description = "";
            type = types.nullOr (types.listOf types.str);
          };
          "namespaceSelector" = mkOption {
            description = "";
            type = types.nullOr (
              submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecAffinityPodAffinityRequiredDuringSchedulingIgnoredDuringExecutionNamespaceSelector"
            );
          };
          "namespaces" = mkOption {
            description = "";
            type = types.nullOr (types.listOf types.str);
          };
          "topologyKey" = mkOption {
            description = "";
            type = types.str;
          };
        };

        config = {
          "labelSelector" = mkOverride 1002 null;
          "matchLabelKeys" = mkOverride 1002 null;
          "mismatchLabelKeys" = mkOverride 1002 null;
          "namespaceSelector" = mkOverride 1002 null;
          "namespaces" = mkOverride 1002 null;
        };

      };
    "seaweed.seaweedfs.com.v1.SeaweedSpecAffinityPodAffinityRequiredDuringSchedulingIgnoredDuringExecutionLabelSelector" =
      {

        options = {
          "matchExpressions" = mkOption {
            description = "";
            type = types.nullOr (
              types.listOf (
                submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecAffinityPodAffinityRequiredDuringSchedulingIgnoredDuringExecutionLabelSelectorMatchExpressions"
              )
            );
          };
          "matchLabels" = mkOption {
            description = "";
            type = types.nullOr (types.attrsOf types.str);
          };
        };

        config = {
          "matchExpressions" = mkOverride 1002 null;
          "matchLabels" = mkOverride 1002 null;
        };

      };
    "seaweed.seaweedfs.com.v1.SeaweedSpecAffinityPodAffinityRequiredDuringSchedulingIgnoredDuringExecutionLabelSelectorMatchExpressions" =
      {

        options = {
          "key" = mkOption {
            description = "";
            type = types.str;
          };
          "operator" = mkOption {
            description = "";
            type = types.str;
          };
          "values" = mkOption {
            description = "";
            type = types.nullOr (types.listOf types.str);
          };
        };

        config = {
          "values" = mkOverride 1002 null;
        };

      };
    "seaweed.seaweedfs.com.v1.SeaweedSpecAffinityPodAffinityRequiredDuringSchedulingIgnoredDuringExecutionNamespaceSelector" =
      {

        options = {
          "matchExpressions" = mkOption {
            description = "";
            type = types.nullOr (
              types.listOf (
                submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecAffinityPodAffinityRequiredDuringSchedulingIgnoredDuringExecutionNamespaceSelectorMatchExpressions"
              )
            );
          };
          "matchLabels" = mkOption {
            description = "";
            type = types.nullOr (types.attrsOf types.str);
          };
        };

        config = {
          "matchExpressions" = mkOverride 1002 null;
          "matchLabels" = mkOverride 1002 null;
        };

      };
    "seaweed.seaweedfs.com.v1.SeaweedSpecAffinityPodAffinityRequiredDuringSchedulingIgnoredDuringExecutionNamespaceSelectorMatchExpressions" =
      {

        options = {
          "key" = mkOption {
            description = "";
            type = types.str;
          };
          "operator" = mkOption {
            description = "";
            type = types.str;
          };
          "values" = mkOption {
            description = "";
            type = types.nullOr (types.listOf types.str);
          };
        };

        config = {
          "values" = mkOverride 1002 null;
        };

      };
    "seaweed.seaweedfs.com.v1.SeaweedSpecAffinityPodAntiAffinity" = {

      options = {
        "preferredDuringSchedulingIgnoredDuringExecution" = mkOption {
          description = "";
          type = types.nullOr (
            types.listOf (
              submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecAffinityPodAntiAffinityPreferredDuringSchedulingIgnoredDuringExecution"
            )
          );
        };
        "requiredDuringSchedulingIgnoredDuringExecution" = mkOption {
          description = "";
          type = types.nullOr (
            types.listOf (
              submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecAffinityPodAntiAffinityRequiredDuringSchedulingIgnoredDuringExecution"
            )
          );
        };
      };

      config = {
        "preferredDuringSchedulingIgnoredDuringExecution" = mkOverride 1002 null;
        "requiredDuringSchedulingIgnoredDuringExecution" = mkOverride 1002 null;
      };

    };
    "seaweed.seaweedfs.com.v1.SeaweedSpecAffinityPodAntiAffinityPreferredDuringSchedulingIgnoredDuringExecution" =
      {

        options = {
          "podAffinityTerm" = mkOption {
            description = "";
            type = submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecAffinityPodAntiAffinityPreferredDuringSchedulingIgnoredDuringExecutionPodAffinityTerm";
          };
          "weight" = mkOption {
            description = "";
            type = types.int;
          };
        };

        config = { };

      };
    "seaweed.seaweedfs.com.v1.SeaweedSpecAffinityPodAntiAffinityPreferredDuringSchedulingIgnoredDuringExecutionPodAffinityTerm" =
      {

        options = {
          "labelSelector" = mkOption {
            description = "";
            type = types.nullOr (
              submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecAffinityPodAntiAffinityPreferredDuringSchedulingIgnoredDuringExecutionPodAffinityTermLabelSelector"
            );
          };
          "matchLabelKeys" = mkOption {
            description = "";
            type = types.nullOr (types.listOf types.str);
          };
          "mismatchLabelKeys" = mkOption {
            description = "";
            type = types.nullOr (types.listOf types.str);
          };
          "namespaceSelector" = mkOption {
            description = "";
            type = types.nullOr (
              submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecAffinityPodAntiAffinityPreferredDuringSchedulingIgnoredDuringExecutionPodAffinityTermNamespaceSelector"
            );
          };
          "namespaces" = mkOption {
            description = "";
            type = types.nullOr (types.listOf types.str);
          };
          "topologyKey" = mkOption {
            description = "";
            type = types.str;
          };
        };

        config = {
          "labelSelector" = mkOverride 1002 null;
          "matchLabelKeys" = mkOverride 1002 null;
          "mismatchLabelKeys" = mkOverride 1002 null;
          "namespaceSelector" = mkOverride 1002 null;
          "namespaces" = mkOverride 1002 null;
        };

      };
    "seaweed.seaweedfs.com.v1.SeaweedSpecAffinityPodAntiAffinityPreferredDuringSchedulingIgnoredDuringExecutionPodAffinityTermLabelSelector" =
      {

        options = {
          "matchExpressions" = mkOption {
            description = "";
            type = types.nullOr (
              types.listOf (
                submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecAffinityPodAntiAffinityPreferredDuringSchedulingIgnoredDuringExecutionPodAffinityTermLabelSelectorMatchExpressions"
              )
            );
          };
          "matchLabels" = mkOption {
            description = "";
            type = types.nullOr (types.attrsOf types.str);
          };
        };

        config = {
          "matchExpressions" = mkOverride 1002 null;
          "matchLabels" = mkOverride 1002 null;
        };

      };
    "seaweed.seaweedfs.com.v1.SeaweedSpecAffinityPodAntiAffinityPreferredDuringSchedulingIgnoredDuringExecutionPodAffinityTermLabelSelectorMatchExpressions" =
      {

        options = {
          "key" = mkOption {
            description = "";
            type = types.str;
          };
          "operator" = mkOption {
            description = "";
            type = types.str;
          };
          "values" = mkOption {
            description = "";
            type = types.nullOr (types.listOf types.str);
          };
        };

        config = {
          "values" = mkOverride 1002 null;
        };

      };
    "seaweed.seaweedfs.com.v1.SeaweedSpecAffinityPodAntiAffinityPreferredDuringSchedulingIgnoredDuringExecutionPodAffinityTermNamespaceSelector" =
      {

        options = {
          "matchExpressions" = mkOption {
            description = "";
            type = types.nullOr (
              types.listOf (
                submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecAffinityPodAntiAffinityPreferredDuringSchedulingIgnoredDuringExecutionPodAffinityTermNamespaceSelectorMatchExpressions"
              )
            );
          };
          "matchLabels" = mkOption {
            description = "";
            type = types.nullOr (types.attrsOf types.str);
          };
        };

        config = {
          "matchExpressions" = mkOverride 1002 null;
          "matchLabels" = mkOverride 1002 null;
        };

      };
    "seaweed.seaweedfs.com.v1.SeaweedSpecAffinityPodAntiAffinityPreferredDuringSchedulingIgnoredDuringExecutionPodAffinityTermNamespaceSelectorMatchExpressions" =
      {

        options = {
          "key" = mkOption {
            description = "";
            type = types.str;
          };
          "operator" = mkOption {
            description = "";
            type = types.str;
          };
          "values" = mkOption {
            description = "";
            type = types.nullOr (types.listOf types.str);
          };
        };

        config = {
          "values" = mkOverride 1002 null;
        };

      };
    "seaweed.seaweedfs.com.v1.SeaweedSpecAffinityPodAntiAffinityRequiredDuringSchedulingIgnoredDuringExecution" =
      {

        options = {
          "labelSelector" = mkOption {
            description = "";
            type = types.nullOr (
              submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecAffinityPodAntiAffinityRequiredDuringSchedulingIgnoredDuringExecutionLabelSelector"
            );
          };
          "matchLabelKeys" = mkOption {
            description = "";
            type = types.nullOr (types.listOf types.str);
          };
          "mismatchLabelKeys" = mkOption {
            description = "";
            type = types.nullOr (types.listOf types.str);
          };
          "namespaceSelector" = mkOption {
            description = "";
            type = types.nullOr (
              submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecAffinityPodAntiAffinityRequiredDuringSchedulingIgnoredDuringExecutionNamespaceSelector"
            );
          };
          "namespaces" = mkOption {
            description = "";
            type = types.nullOr (types.listOf types.str);
          };
          "topologyKey" = mkOption {
            description = "";
            type = types.str;
          };
        };

        config = {
          "labelSelector" = mkOverride 1002 null;
          "matchLabelKeys" = mkOverride 1002 null;
          "mismatchLabelKeys" = mkOverride 1002 null;
          "namespaceSelector" = mkOverride 1002 null;
          "namespaces" = mkOverride 1002 null;
        };

      };
    "seaweed.seaweedfs.com.v1.SeaweedSpecAffinityPodAntiAffinityRequiredDuringSchedulingIgnoredDuringExecutionLabelSelector" =
      {

        options = {
          "matchExpressions" = mkOption {
            description = "";
            type = types.nullOr (
              types.listOf (
                submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecAffinityPodAntiAffinityRequiredDuringSchedulingIgnoredDuringExecutionLabelSelectorMatchExpressions"
              )
            );
          };
          "matchLabels" = mkOption {
            description = "";
            type = types.nullOr (types.attrsOf types.str);
          };
        };

        config = {
          "matchExpressions" = mkOverride 1002 null;
          "matchLabels" = mkOverride 1002 null;
        };

      };
    "seaweed.seaweedfs.com.v1.SeaweedSpecAffinityPodAntiAffinityRequiredDuringSchedulingIgnoredDuringExecutionLabelSelectorMatchExpressions" =
      {

        options = {
          "key" = mkOption {
            description = "";
            type = types.str;
          };
          "operator" = mkOption {
            description = "";
            type = types.str;
          };
          "values" = mkOption {
            description = "";
            type = types.nullOr (types.listOf types.str);
          };
        };

        config = {
          "values" = mkOverride 1002 null;
        };

      };
    "seaweed.seaweedfs.com.v1.SeaweedSpecAffinityPodAntiAffinityRequiredDuringSchedulingIgnoredDuringExecutionNamespaceSelector" =
      {

        options = {
          "matchExpressions" = mkOption {
            description = "";
            type = types.nullOr (
              types.listOf (
                submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecAffinityPodAntiAffinityRequiredDuringSchedulingIgnoredDuringExecutionNamespaceSelectorMatchExpressions"
              )
            );
          };
          "matchLabels" = mkOption {
            description = "";
            type = types.nullOr (types.attrsOf types.str);
          };
        };

        config = {
          "matchExpressions" = mkOverride 1002 null;
          "matchLabels" = mkOverride 1002 null;
        };

      };
    "seaweed.seaweedfs.com.v1.SeaweedSpecAffinityPodAntiAffinityRequiredDuringSchedulingIgnoredDuringExecutionNamespaceSelectorMatchExpressions" =
      {

        options = {
          "key" = mkOption {
            description = "";
            type = types.str;
          };
          "operator" = mkOption {
            description = "";
            type = types.str;
          };
          "values" = mkOption {
            description = "";
            type = types.nullOr (types.listOf types.str);
          };
        };

        config = {
          "values" = mkOverride 1002 null;
        };

      };
    "seaweed.seaweedfs.com.v1.SeaweedSpecBackup" = {

      options = {
        "dataMirror" = mkOption {
          description = "";
          type = types.nullOr (
            types.listOf (submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecBackupDataMirror")
          );
        };
        "image" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "schedule" = mkOption {
          description = "";
          type = types.nullOr (
            coerceAttrsOfSubmodulesToListByKey "seaweed.seaweedfs.com.v1.SeaweedSpecBackupSchedule" "name" [
              "name"
            ]
          );
          apply = attrsToList;
        };
        "storages" = mkOption {
          description = "";
          type = types.attrsOf types.attrs;
        };
      };

      config = {
        "dataMirror" = mkOverride 1002 null;
        "image" = mkOverride 1002 null;
        "schedule" = mkOverride 1002 null;
      };

    };
    "seaweed.seaweedfs.com.v1.SeaweedSpecBackupDataMirror" = {

      options = {
        "filerPath" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "storageName" = mkOption {
          description = "";
          type = types.str;
        };
      };

      config = {
        "filerPath" = mkOverride 1002 null;
      };

    };
    "seaweed.seaweedfs.com.v1.SeaweedSpecBackupSchedule" = {

      options = {
        "filerPath" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "keep" = mkOption {
          description = "";
          type = types.nullOr types.int;
        };
        "name" = mkOption {
          description = "";
          type = types.str;
        };
        "schedule" = mkOption {
          description = "";
          type = types.str;
        };
        "storageName" = mkOption {
          description = "";
          type = types.str;
        };
        "suspend" = mkOption {
          description = "";
          type = types.nullOr types.bool;
        };
      };

      config = {
        "filerPath" = mkOverride 1002 null;
        "keep" = mkOverride 1002 null;
        "suspend" = mkOverride 1002 null;
      };

    };
    "seaweed.seaweedfs.com.v1.SeaweedSpecFiler" = {

      options = {
        "affinity" = mkOption {
          description = "";
          type = types.nullOr (submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecFilerAffinity");
        };
        "annotations" = mkOption {
          description = "";
          type = types.nullOr (types.attrsOf types.str);
        };
        "claims" = mkOption {
          description = "";
          type = types.nullOr (
            coerceAttrsOfSubmodulesToListByKey "seaweed.seaweedfs.com.v1.SeaweedSpecFilerClaims" "name" [
              "name"
            ]
          );
          apply = attrsToList;
        };
        "config" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "configSecret" = mkOption {
          description = "";
          type = types.nullOr (submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecFilerConfigSecret");
        };
        "containerSecurityContext" = mkOption {
          description = "";
          type = types.nullOr (
            submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecFilerContainerSecurityContext"
          );
        };
        "env" = mkOption {
          description = "";
          type = types.nullOr (
            coerceAttrsOfSubmodulesToListByKey "seaweed.seaweedfs.com.v1.SeaweedSpecFilerEnv" "name" [ ]
          );
          apply = attrsToList;
        };
        "extraArgs" = mkOption {
          description = "";
          type = types.nullOr (types.listOf types.str);
        };
        "grpcIngress" = mkOption {
          description = "";
          type = types.nullOr (submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecFilerGrpcIngress");
        };
        "hostNetwork" = mkOption {
          description = "";
          type = types.nullOr types.bool;
        };
        "iam" = mkOption {
          description = "";
          type = types.nullOr types.bool;
        };
        "iceberg" = mkOption {
          description = "";
          type = types.nullOr (submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecFilerIceberg");
        };
        "imagePullPolicy" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "imagePullSecrets" = mkOption {
          description = "";
          type = types.nullOr (
            coerceAttrsOfSubmodulesToListByKey "seaweed.seaweedfs.com.v1.SeaweedSpecFilerImagePullSecrets"
              "name"
              [ ]
          );
          apply = attrsToList;
        };
        "ingress" = mkOption {
          description = "";
          type = types.nullOr (submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecFilerIngress");
        };
        "initContainers" = mkOption {
          description = "";
          type = types.nullOr types.unspecified;
        };
        "labels" = mkOption {
          description = "";
          type = types.nullOr (types.attrsOf types.str);
        };
        "limits" = mkOption {
          description = "";
          type = types.nullOr (types.attrsOf (types.either types.int types.str));
        };
        "livenessProbe" = mkOption {
          description = "";
          type = types.nullOr (submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecFilerLivenessProbe");
        };
        "loggingArgs" = mkOption {
          description = "";
          type = types.nullOr (types.listOf types.str);
        };
        "maxMB" = mkOption {
          description = "";
          type = types.nullOr types.int;
        };
        "metricsPort" = mkOption {
          description = "";
          type = types.nullOr types.int;
        };
        "nodeSelector" = mkOption {
          description = "";
          type = types.nullOr (types.attrsOf types.str);
        };
        "persistence" = mkOption {
          description = "";
          type = types.nullOr (submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecFilerPersistence");
        };
        "podSecurityContext" = mkOption {
          description = "";
          type = types.nullOr (submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecFilerPodSecurityContext");
        };
        "priorityClassName" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "readinessProbe" = mkOption {
          description = "";
          type = types.nullOr (submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecFilerReadinessProbe");
        };
        "replicas" = mkOption {
          description = "";
          type = types.int;
        };
        "requests" = mkOption {
          description = "";
          type = types.nullOr (types.attrsOf (types.either types.int types.str));
        };
        "s3" = mkOption {
          description = "";
          type = types.nullOr (submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecFilerS3");
        };
        "s3Ingress" = mkOption {
          description = "";
          type = types.nullOr (submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecFilerS3Ingress");
        };
        "schedulerName" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "service" = mkOption {
          description = "";
          type = types.nullOr (submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecFilerService");
        };
        "serviceAccountName" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "sidecars" = mkOption {
          description = "";
          type = types.nullOr types.unspecified;
        };
        "statefulSetUpdateStrategy" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "terminationGracePeriodSeconds" = mkOption {
          description = "";
          type = types.nullOr types.int;
        };
        "tolerations" = mkOption {
          description = "";
          type = types.nullOr (
            types.listOf (submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecFilerTolerations")
          );
        };
        "version" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "volumeMounts" = mkOption {
          description = "";
          type = types.nullOr (
            coerceAttrsOfSubmodulesToListByKey "seaweed.seaweedfs.com.v1.SeaweedSpecFilerVolumeMounts" "name"
              [ ]
          );
          apply = attrsToList;
        };
        "volumes" = mkOption {
          description = "";
          type = types.nullOr (
            coerceAttrsOfSubmodulesToListByKey "seaweed.seaweedfs.com.v1.SeaweedSpecFilerVolumes" "name" [ ]
          );
          apply = attrsToList;
        };
      };

      config = {
        "affinity" = mkOverride 1002 null;
        "annotations" = mkOverride 1002 null;
        "claims" = mkOverride 1002 null;
        "config" = mkOverride 1002 null;
        "configSecret" = mkOverride 1002 null;
        "containerSecurityContext" = mkOverride 1002 null;
        "env" = mkOverride 1002 null;
        "extraArgs" = mkOverride 1002 null;
        "grpcIngress" = mkOverride 1002 null;
        "hostNetwork" = mkOverride 1002 null;
        "iam" = mkOverride 1002 null;
        "iceberg" = mkOverride 1002 null;
        "imagePullPolicy" = mkOverride 1002 null;
        "imagePullSecrets" = mkOverride 1002 null;
        "ingress" = mkOverride 1002 null;
        "initContainers" = mkOverride 1002 null;
        "labels" = mkOverride 1002 null;
        "limits" = mkOverride 1002 null;
        "livenessProbe" = mkOverride 1002 null;
        "loggingArgs" = mkOverride 1002 null;
        "maxMB" = mkOverride 1002 null;
        "metricsPort" = mkOverride 1002 null;
        "nodeSelector" = mkOverride 1002 null;
        "persistence" = mkOverride 1002 null;
        "podSecurityContext" = mkOverride 1002 null;
        "priorityClassName" = mkOverride 1002 null;
        "readinessProbe" = mkOverride 1002 null;
        "requests" = mkOverride 1002 null;
        "s3" = mkOverride 1002 null;
        "s3Ingress" = mkOverride 1002 null;
        "schedulerName" = mkOverride 1002 null;
        "service" = mkOverride 1002 null;
        "serviceAccountName" = mkOverride 1002 null;
        "sidecars" = mkOverride 1002 null;
        "statefulSetUpdateStrategy" = mkOverride 1002 null;
        "terminationGracePeriodSeconds" = mkOverride 1002 null;
        "tolerations" = mkOverride 1002 null;
        "version" = mkOverride 1002 null;
        "volumeMounts" = mkOverride 1002 null;
        "volumes" = mkOverride 1002 null;
      };

    };
    "seaweed.seaweedfs.com.v1.SeaweedSpecFilerAffinity" = {

      options = {
        "nodeAffinity" = mkOption {
          description = "";
          type = types.nullOr (submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecFilerAffinityNodeAffinity");
        };
        "podAffinity" = mkOption {
          description = "";
          type = types.nullOr (submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecFilerAffinityPodAffinity");
        };
        "podAntiAffinity" = mkOption {
          description = "";
          type = types.nullOr (
            submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecFilerAffinityPodAntiAffinity"
          );
        };
      };

      config = {
        "nodeAffinity" = mkOverride 1002 null;
        "podAffinity" = mkOverride 1002 null;
        "podAntiAffinity" = mkOverride 1002 null;
      };

    };
    "seaweed.seaweedfs.com.v1.SeaweedSpecFilerAffinityNodeAffinity" = {

      options = {
        "preferredDuringSchedulingIgnoredDuringExecution" = mkOption {
          description = "";
          type = types.nullOr (
            types.listOf (
              submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecFilerAffinityNodeAffinityPreferredDuringSchedulingIgnoredDuringExecution"
            )
          );
        };
        "requiredDuringSchedulingIgnoredDuringExecution" = mkOption {
          description = "";
          type = types.nullOr (
            submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecFilerAffinityNodeAffinityRequiredDuringSchedulingIgnoredDuringExecution"
          );
        };
      };

      config = {
        "preferredDuringSchedulingIgnoredDuringExecution" = mkOverride 1002 null;
        "requiredDuringSchedulingIgnoredDuringExecution" = mkOverride 1002 null;
      };

    };
    "seaweed.seaweedfs.com.v1.SeaweedSpecFilerAffinityNodeAffinityPreferredDuringSchedulingIgnoredDuringExecution" =
      {

        options = {
          "preference" = mkOption {
            description = "";
            type = submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecFilerAffinityNodeAffinityPreferredDuringSchedulingIgnoredDuringExecutionPreference";
          };
          "weight" = mkOption {
            description = "";
            type = types.int;
          };
        };

        config = { };

      };
    "seaweed.seaweedfs.com.v1.SeaweedSpecFilerAffinityNodeAffinityPreferredDuringSchedulingIgnoredDuringExecutionPreference" =
      {

        options = {
          "matchExpressions" = mkOption {
            description = "";
            type = types.nullOr (
              types.listOf (
                submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecFilerAffinityNodeAffinityPreferredDuringSchedulingIgnoredDuringExecutionPreferenceMatchExpressions"
              )
            );
          };
          "matchFields" = mkOption {
            description = "";
            type = types.nullOr (
              types.listOf (
                submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecFilerAffinityNodeAffinityPreferredDuringSchedulingIgnoredDuringExecutionPreferenceMatchFields"
              )
            );
          };
        };

        config = {
          "matchExpressions" = mkOverride 1002 null;
          "matchFields" = mkOverride 1002 null;
        };

      };
    "seaweed.seaweedfs.com.v1.SeaweedSpecFilerAffinityNodeAffinityPreferredDuringSchedulingIgnoredDuringExecutionPreferenceMatchExpressions" =
      {

        options = {
          "key" = mkOption {
            description = "";
            type = types.str;
          };
          "operator" = mkOption {
            description = "";
            type = types.str;
          };
          "values" = mkOption {
            description = "";
            type = types.nullOr (types.listOf types.str);
          };
        };

        config = {
          "values" = mkOverride 1002 null;
        };

      };
    "seaweed.seaweedfs.com.v1.SeaweedSpecFilerAffinityNodeAffinityPreferredDuringSchedulingIgnoredDuringExecutionPreferenceMatchFields" =
      {

        options = {
          "key" = mkOption {
            description = "";
            type = types.str;
          };
          "operator" = mkOption {
            description = "";
            type = types.str;
          };
          "values" = mkOption {
            description = "";
            type = types.nullOr (types.listOf types.str);
          };
        };

        config = {
          "values" = mkOverride 1002 null;
        };

      };
    "seaweed.seaweedfs.com.v1.SeaweedSpecFilerAffinityNodeAffinityRequiredDuringSchedulingIgnoredDuringExecution" =
      {

        options = {
          "nodeSelectorTerms" = mkOption {
            description = "";
            type = types.listOf (
              submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecFilerAffinityNodeAffinityRequiredDuringSchedulingIgnoredDuringExecutionNodeSelectorTerms"
            );
          };
        };

        config = { };

      };
    "seaweed.seaweedfs.com.v1.SeaweedSpecFilerAffinityNodeAffinityRequiredDuringSchedulingIgnoredDuringExecutionNodeSelectorTerms" =
      {

        options = {
          "matchExpressions" = mkOption {
            description = "";
            type = types.nullOr (
              types.listOf (
                submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecFilerAffinityNodeAffinityRequiredDuringSchedulingIgnoredDuringExecutionNodeSelectorTermsMatchExpressions"
              )
            );
          };
          "matchFields" = mkOption {
            description = "";
            type = types.nullOr (
              types.listOf (
                submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecFilerAffinityNodeAffinityRequiredDuringSchedulingIgnoredDuringExecutionNodeSelectorTermsMatchFields"
              )
            );
          };
        };

        config = {
          "matchExpressions" = mkOverride 1002 null;
          "matchFields" = mkOverride 1002 null;
        };

      };
    "seaweed.seaweedfs.com.v1.SeaweedSpecFilerAffinityNodeAffinityRequiredDuringSchedulingIgnoredDuringExecutionNodeSelectorTermsMatchExpressions" =
      {

        options = {
          "key" = mkOption {
            description = "";
            type = types.str;
          };
          "operator" = mkOption {
            description = "";
            type = types.str;
          };
          "values" = mkOption {
            description = "";
            type = types.nullOr (types.listOf types.str);
          };
        };

        config = {
          "values" = mkOverride 1002 null;
        };

      };
    "seaweed.seaweedfs.com.v1.SeaweedSpecFilerAffinityNodeAffinityRequiredDuringSchedulingIgnoredDuringExecutionNodeSelectorTermsMatchFields" =
      {

        options = {
          "key" = mkOption {
            description = "";
            type = types.str;
          };
          "operator" = mkOption {
            description = "";
            type = types.str;
          };
          "values" = mkOption {
            description = "";
            type = types.nullOr (types.listOf types.str);
          };
        };

        config = {
          "values" = mkOverride 1002 null;
        };

      };
    "seaweed.seaweedfs.com.v1.SeaweedSpecFilerAffinityPodAffinity" = {

      options = {
        "preferredDuringSchedulingIgnoredDuringExecution" = mkOption {
          description = "";
          type = types.nullOr (
            types.listOf (
              submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecFilerAffinityPodAffinityPreferredDuringSchedulingIgnoredDuringExecution"
            )
          );
        };
        "requiredDuringSchedulingIgnoredDuringExecution" = mkOption {
          description = "";
          type = types.nullOr (
            types.listOf (
              submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecFilerAffinityPodAffinityRequiredDuringSchedulingIgnoredDuringExecution"
            )
          );
        };
      };

      config = {
        "preferredDuringSchedulingIgnoredDuringExecution" = mkOverride 1002 null;
        "requiredDuringSchedulingIgnoredDuringExecution" = mkOverride 1002 null;
      };

    };
    "seaweed.seaweedfs.com.v1.SeaweedSpecFilerAffinityPodAffinityPreferredDuringSchedulingIgnoredDuringExecution" =
      {

        options = {
          "podAffinityTerm" = mkOption {
            description = "";
            type = submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecFilerAffinityPodAffinityPreferredDuringSchedulingIgnoredDuringExecutionPodAffinityTerm";
          };
          "weight" = mkOption {
            description = "";
            type = types.int;
          };
        };

        config = { };

      };
    "seaweed.seaweedfs.com.v1.SeaweedSpecFilerAffinityPodAffinityPreferredDuringSchedulingIgnoredDuringExecutionPodAffinityTerm" =
      {

        options = {
          "labelSelector" = mkOption {
            description = "";
            type = types.nullOr (
              submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecFilerAffinityPodAffinityPreferredDuringSchedulingIgnoredDuringExecutionPodAffinityTermLabelSelector"
            );
          };
          "matchLabelKeys" = mkOption {
            description = "";
            type = types.nullOr (types.listOf types.str);
          };
          "mismatchLabelKeys" = mkOption {
            description = "";
            type = types.nullOr (types.listOf types.str);
          };
          "namespaceSelector" = mkOption {
            description = "";
            type = types.nullOr (
              submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecFilerAffinityPodAffinityPreferredDuringSchedulingIgnoredDuringExecutionPodAffinityTermNamespaceSelector"
            );
          };
          "namespaces" = mkOption {
            description = "";
            type = types.nullOr (types.listOf types.str);
          };
          "topologyKey" = mkOption {
            description = "";
            type = types.str;
          };
        };

        config = {
          "labelSelector" = mkOverride 1002 null;
          "matchLabelKeys" = mkOverride 1002 null;
          "mismatchLabelKeys" = mkOverride 1002 null;
          "namespaceSelector" = mkOverride 1002 null;
          "namespaces" = mkOverride 1002 null;
        };

      };
    "seaweed.seaweedfs.com.v1.SeaweedSpecFilerAffinityPodAffinityPreferredDuringSchedulingIgnoredDuringExecutionPodAffinityTermLabelSelector" =
      {

        options = {
          "matchExpressions" = mkOption {
            description = "";
            type = types.nullOr (
              types.listOf (
                submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecFilerAffinityPodAffinityPreferredDuringSchedulingIgnoredDuringExecutionPodAffinityTermLabelSelectorMatchExpressions"
              )
            );
          };
          "matchLabels" = mkOption {
            description = "";
            type = types.nullOr (types.attrsOf types.str);
          };
        };

        config = {
          "matchExpressions" = mkOverride 1002 null;
          "matchLabels" = mkOverride 1002 null;
        };

      };
    "seaweed.seaweedfs.com.v1.SeaweedSpecFilerAffinityPodAffinityPreferredDuringSchedulingIgnoredDuringExecutionPodAffinityTermLabelSelectorMatchExpressions" =
      {

        options = {
          "key" = mkOption {
            description = "";
            type = types.str;
          };
          "operator" = mkOption {
            description = "";
            type = types.str;
          };
          "values" = mkOption {
            description = "";
            type = types.nullOr (types.listOf types.str);
          };
        };

        config = {
          "values" = mkOverride 1002 null;
        };

      };
    "seaweed.seaweedfs.com.v1.SeaweedSpecFilerAffinityPodAffinityPreferredDuringSchedulingIgnoredDuringExecutionPodAffinityTermNamespaceSelector" =
      {

        options = {
          "matchExpressions" = mkOption {
            description = "";
            type = types.nullOr (
              types.listOf (
                submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecFilerAffinityPodAffinityPreferredDuringSchedulingIgnoredDuringExecutionPodAffinityTermNamespaceSelectorMatchExpressions"
              )
            );
          };
          "matchLabels" = mkOption {
            description = "";
            type = types.nullOr (types.attrsOf types.str);
          };
        };

        config = {
          "matchExpressions" = mkOverride 1002 null;
          "matchLabels" = mkOverride 1002 null;
        };

      };
    "seaweed.seaweedfs.com.v1.SeaweedSpecFilerAffinityPodAffinityPreferredDuringSchedulingIgnoredDuringExecutionPodAffinityTermNamespaceSelectorMatchExpressions" =
      {

        options = {
          "key" = mkOption {
            description = "";
            type = types.str;
          };
          "operator" = mkOption {
            description = "";
            type = types.str;
          };
          "values" = mkOption {
            description = "";
            type = types.nullOr (types.listOf types.str);
          };
        };

        config = {
          "values" = mkOverride 1002 null;
        };

      };
    "seaweed.seaweedfs.com.v1.SeaweedSpecFilerAffinityPodAffinityRequiredDuringSchedulingIgnoredDuringExecution" =
      {

        options = {
          "labelSelector" = mkOption {
            description = "";
            type = types.nullOr (
              submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecFilerAffinityPodAffinityRequiredDuringSchedulingIgnoredDuringExecutionLabelSelector"
            );
          };
          "matchLabelKeys" = mkOption {
            description = "";
            type = types.nullOr (types.listOf types.str);
          };
          "mismatchLabelKeys" = mkOption {
            description = "";
            type = types.nullOr (types.listOf types.str);
          };
          "namespaceSelector" = mkOption {
            description = "";
            type = types.nullOr (
              submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecFilerAffinityPodAffinityRequiredDuringSchedulingIgnoredDuringExecutionNamespaceSelector"
            );
          };
          "namespaces" = mkOption {
            description = "";
            type = types.nullOr (types.listOf types.str);
          };
          "topologyKey" = mkOption {
            description = "";
            type = types.str;
          };
        };

        config = {
          "labelSelector" = mkOverride 1002 null;
          "matchLabelKeys" = mkOverride 1002 null;
          "mismatchLabelKeys" = mkOverride 1002 null;
          "namespaceSelector" = mkOverride 1002 null;
          "namespaces" = mkOverride 1002 null;
        };

      };
    "seaweed.seaweedfs.com.v1.SeaweedSpecFilerAffinityPodAffinityRequiredDuringSchedulingIgnoredDuringExecutionLabelSelector" =
      {

        options = {
          "matchExpressions" = mkOption {
            description = "";
            type = types.nullOr (
              types.listOf (
                submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecFilerAffinityPodAffinityRequiredDuringSchedulingIgnoredDuringExecutionLabelSelectorMatchExpressions"
              )
            );
          };
          "matchLabels" = mkOption {
            description = "";
            type = types.nullOr (types.attrsOf types.str);
          };
        };

        config = {
          "matchExpressions" = mkOverride 1002 null;
          "matchLabels" = mkOverride 1002 null;
        };

      };
    "seaweed.seaweedfs.com.v1.SeaweedSpecFilerAffinityPodAffinityRequiredDuringSchedulingIgnoredDuringExecutionLabelSelectorMatchExpressions" =
      {

        options = {
          "key" = mkOption {
            description = "";
            type = types.str;
          };
          "operator" = mkOption {
            description = "";
            type = types.str;
          };
          "values" = mkOption {
            description = "";
            type = types.nullOr (types.listOf types.str);
          };
        };

        config = {
          "values" = mkOverride 1002 null;
        };

      };
    "seaweed.seaweedfs.com.v1.SeaweedSpecFilerAffinityPodAffinityRequiredDuringSchedulingIgnoredDuringExecutionNamespaceSelector" =
      {

        options = {
          "matchExpressions" = mkOption {
            description = "";
            type = types.nullOr (
              types.listOf (
                submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecFilerAffinityPodAffinityRequiredDuringSchedulingIgnoredDuringExecutionNamespaceSelectorMatchExpressions"
              )
            );
          };
          "matchLabels" = mkOption {
            description = "";
            type = types.nullOr (types.attrsOf types.str);
          };
        };

        config = {
          "matchExpressions" = mkOverride 1002 null;
          "matchLabels" = mkOverride 1002 null;
        };

      };
    "seaweed.seaweedfs.com.v1.SeaweedSpecFilerAffinityPodAffinityRequiredDuringSchedulingIgnoredDuringExecutionNamespaceSelectorMatchExpressions" =
      {

        options = {
          "key" = mkOption {
            description = "";
            type = types.str;
          };
          "operator" = mkOption {
            description = "";
            type = types.str;
          };
          "values" = mkOption {
            description = "";
            type = types.nullOr (types.listOf types.str);
          };
        };

        config = {
          "values" = mkOverride 1002 null;
        };

      };
    "seaweed.seaweedfs.com.v1.SeaweedSpecFilerAffinityPodAntiAffinity" = {

      options = {
        "preferredDuringSchedulingIgnoredDuringExecution" = mkOption {
          description = "";
          type = types.nullOr (
            types.listOf (
              submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecFilerAffinityPodAntiAffinityPreferredDuringSchedulingIgnoredDuringExecution"
            )
          );
        };
        "requiredDuringSchedulingIgnoredDuringExecution" = mkOption {
          description = "";
          type = types.nullOr (
            types.listOf (
              submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecFilerAffinityPodAntiAffinityRequiredDuringSchedulingIgnoredDuringExecution"
            )
          );
        };
      };

      config = {
        "preferredDuringSchedulingIgnoredDuringExecution" = mkOverride 1002 null;
        "requiredDuringSchedulingIgnoredDuringExecution" = mkOverride 1002 null;
      };

    };
    "seaweed.seaweedfs.com.v1.SeaweedSpecFilerAffinityPodAntiAffinityPreferredDuringSchedulingIgnoredDuringExecution" =
      {

        options = {
          "podAffinityTerm" = mkOption {
            description = "";
            type = submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecFilerAffinityPodAntiAffinityPreferredDuringSchedulingIgnoredDuringExecutionPodAffinityTerm";
          };
          "weight" = mkOption {
            description = "";
            type = types.int;
          };
        };

        config = { };

      };
    "seaweed.seaweedfs.com.v1.SeaweedSpecFilerAffinityPodAntiAffinityPreferredDuringSchedulingIgnoredDuringExecutionPodAffinityTerm" =
      {

        options = {
          "labelSelector" = mkOption {
            description = "";
            type = types.nullOr (
              submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecFilerAffinityPodAntiAffinityPreferredDuringSchedulingIgnoredDuringExecutionPodAffinityTermLabelSelector"
            );
          };
          "matchLabelKeys" = mkOption {
            description = "";
            type = types.nullOr (types.listOf types.str);
          };
          "mismatchLabelKeys" = mkOption {
            description = "";
            type = types.nullOr (types.listOf types.str);
          };
          "namespaceSelector" = mkOption {
            description = "";
            type = types.nullOr (
              submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecFilerAffinityPodAntiAffinityPreferredDuringSchedulingIgnoredDuringExecutionPodAffinityTermNamespaceSelector"
            );
          };
          "namespaces" = mkOption {
            description = "";
            type = types.nullOr (types.listOf types.str);
          };
          "topologyKey" = mkOption {
            description = "";
            type = types.str;
          };
        };

        config = {
          "labelSelector" = mkOverride 1002 null;
          "matchLabelKeys" = mkOverride 1002 null;
          "mismatchLabelKeys" = mkOverride 1002 null;
          "namespaceSelector" = mkOverride 1002 null;
          "namespaces" = mkOverride 1002 null;
        };

      };
    "seaweed.seaweedfs.com.v1.SeaweedSpecFilerAffinityPodAntiAffinityPreferredDuringSchedulingIgnoredDuringExecutionPodAffinityTermLabelSelector" =
      {

        options = {
          "matchExpressions" = mkOption {
            description = "";
            type = types.nullOr (
              types.listOf (
                submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecFilerAffinityPodAntiAffinityPreferredDuringSchedulingIgnoredDuringExecutionPodAffinityTermLabelSelectorMatchExpressions"
              )
            );
          };
          "matchLabels" = mkOption {
            description = "";
            type = types.nullOr (types.attrsOf types.str);
          };
        };

        config = {
          "matchExpressions" = mkOverride 1002 null;
          "matchLabels" = mkOverride 1002 null;
        };

      };
    "seaweed.seaweedfs.com.v1.SeaweedSpecFilerAffinityPodAntiAffinityPreferredDuringSchedulingIgnoredDuringExecutionPodAffinityTermLabelSelectorMatchExpressions" =
      {

        options = {
          "key" = mkOption {
            description = "";
            type = types.str;
          };
          "operator" = mkOption {
            description = "";
            type = types.str;
          };
          "values" = mkOption {
            description = "";
            type = types.nullOr (types.listOf types.str);
          };
        };

        config = {
          "values" = mkOverride 1002 null;
        };

      };
    "seaweed.seaweedfs.com.v1.SeaweedSpecFilerAffinityPodAntiAffinityPreferredDuringSchedulingIgnoredDuringExecutionPodAffinityTermNamespaceSelector" =
      {

        options = {
          "matchExpressions" = mkOption {
            description = "";
            type = types.nullOr (
              types.listOf (
                submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecFilerAffinityPodAntiAffinityPreferredDuringSchedulingIgnoredDuringExecutionPodAffinityTermNamespaceSelectorMatchExpressions"
              )
            );
          };
          "matchLabels" = mkOption {
            description = "";
            type = types.nullOr (types.attrsOf types.str);
          };
        };

        config = {
          "matchExpressions" = mkOverride 1002 null;
          "matchLabels" = mkOverride 1002 null;
        };

      };
    "seaweed.seaweedfs.com.v1.SeaweedSpecFilerAffinityPodAntiAffinityPreferredDuringSchedulingIgnoredDuringExecutionPodAffinityTermNamespaceSelectorMatchExpressions" =
      {

        options = {
          "key" = mkOption {
            description = "";
            type = types.str;
          };
          "operator" = mkOption {
            description = "";
            type = types.str;
          };
          "values" = mkOption {
            description = "";
            type = types.nullOr (types.listOf types.str);
          };
        };

        config = {
          "values" = mkOverride 1002 null;
        };

      };
    "seaweed.seaweedfs.com.v1.SeaweedSpecFilerAffinityPodAntiAffinityRequiredDuringSchedulingIgnoredDuringExecution" =
      {

        options = {
          "labelSelector" = mkOption {
            description = "";
            type = types.nullOr (
              submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecFilerAffinityPodAntiAffinityRequiredDuringSchedulingIgnoredDuringExecutionLabelSelector"
            );
          };
          "matchLabelKeys" = mkOption {
            description = "";
            type = types.nullOr (types.listOf types.str);
          };
          "mismatchLabelKeys" = mkOption {
            description = "";
            type = types.nullOr (types.listOf types.str);
          };
          "namespaceSelector" = mkOption {
            description = "";
            type = types.nullOr (
              submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecFilerAffinityPodAntiAffinityRequiredDuringSchedulingIgnoredDuringExecutionNamespaceSelector"
            );
          };
          "namespaces" = mkOption {
            description = "";
            type = types.nullOr (types.listOf types.str);
          };
          "topologyKey" = mkOption {
            description = "";
            type = types.str;
          };
        };

        config = {
          "labelSelector" = mkOverride 1002 null;
          "matchLabelKeys" = mkOverride 1002 null;
          "mismatchLabelKeys" = mkOverride 1002 null;
          "namespaceSelector" = mkOverride 1002 null;
          "namespaces" = mkOverride 1002 null;
        };

      };
    "seaweed.seaweedfs.com.v1.SeaweedSpecFilerAffinityPodAntiAffinityRequiredDuringSchedulingIgnoredDuringExecutionLabelSelector" =
      {

        options = {
          "matchExpressions" = mkOption {
            description = "";
            type = types.nullOr (
              types.listOf (
                submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecFilerAffinityPodAntiAffinityRequiredDuringSchedulingIgnoredDuringExecutionLabelSelectorMatchExpressions"
              )
            );
          };
          "matchLabels" = mkOption {
            description = "";
            type = types.nullOr (types.attrsOf types.str);
          };
        };

        config = {
          "matchExpressions" = mkOverride 1002 null;
          "matchLabels" = mkOverride 1002 null;
        };

      };
    "seaweed.seaweedfs.com.v1.SeaweedSpecFilerAffinityPodAntiAffinityRequiredDuringSchedulingIgnoredDuringExecutionLabelSelectorMatchExpressions" =
      {

        options = {
          "key" = mkOption {
            description = "";
            type = types.str;
          };
          "operator" = mkOption {
            description = "";
            type = types.str;
          };
          "values" = mkOption {
            description = "";
            type = types.nullOr (types.listOf types.str);
          };
        };

        config = {
          "values" = mkOverride 1002 null;
        };

      };
    "seaweed.seaweedfs.com.v1.SeaweedSpecFilerAffinityPodAntiAffinityRequiredDuringSchedulingIgnoredDuringExecutionNamespaceSelector" =
      {

        options = {
          "matchExpressions" = mkOption {
            description = "";
            type = types.nullOr (
              types.listOf (
                submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecFilerAffinityPodAntiAffinityRequiredDuringSchedulingIgnoredDuringExecutionNamespaceSelectorMatchExpressions"
              )
            );
          };
          "matchLabels" = mkOption {
            description = "";
            type = types.nullOr (types.attrsOf types.str);
          };
        };

        config = {
          "matchExpressions" = mkOverride 1002 null;
          "matchLabels" = mkOverride 1002 null;
        };

      };
    "seaweed.seaweedfs.com.v1.SeaweedSpecFilerAffinityPodAntiAffinityRequiredDuringSchedulingIgnoredDuringExecutionNamespaceSelectorMatchExpressions" =
      {

        options = {
          "key" = mkOption {
            description = "";
            type = types.str;
          };
          "operator" = mkOption {
            description = "";
            type = types.str;
          };
          "values" = mkOption {
            description = "";
            type = types.nullOr (types.listOf types.str);
          };
        };

        config = {
          "values" = mkOverride 1002 null;
        };

      };
    "seaweed.seaweedfs.com.v1.SeaweedSpecFilerClaims" = {

      options = {
        "name" = mkOption {
          description = "";
          type = types.str;
        };
        "request" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
      };

      config = {
        "request" = mkOverride 1002 null;
      };

    };
    "seaweed.seaweedfs.com.v1.SeaweedSpecFilerConfigSecret" = {

      options = {
        "key" = mkOption {
          description = "";
          type = types.str;
        };
        "name" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "optional" = mkOption {
          description = "";
          type = types.nullOr types.bool;
        };
      };

      config = {
        "name" = mkOverride 1002 null;
        "optional" = mkOverride 1002 null;
      };

    };
    "seaweed.seaweedfs.com.v1.SeaweedSpecFilerContainerSecurityContext" = {

      options = {
        "allowPrivilegeEscalation" = mkOption {
          description = "";
          type = types.nullOr types.bool;
        };
        "appArmorProfile" = mkOption {
          description = "";
          type = types.nullOr (
            submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecFilerContainerSecurityContextAppArmorProfile"
          );
        };
        "capabilities" = mkOption {
          description = "";
          type = types.nullOr (
            submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecFilerContainerSecurityContextCapabilities"
          );
        };
        "privileged" = mkOption {
          description = "";
          type = types.nullOr types.bool;
        };
        "procMount" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "readOnlyRootFilesystem" = mkOption {
          description = "";
          type = types.nullOr types.bool;
        };
        "runAsGroup" = mkOption {
          description = "";
          type = types.nullOr types.int;
        };
        "runAsNonRoot" = mkOption {
          description = "";
          type = types.nullOr types.bool;
        };
        "runAsUser" = mkOption {
          description = "";
          type = types.nullOr types.int;
        };
        "seLinuxOptions" = mkOption {
          description = "";
          type = types.nullOr (
            submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecFilerContainerSecurityContextSeLinuxOptions"
          );
        };
        "seccompProfile" = mkOption {
          description = "";
          type = types.nullOr (
            submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecFilerContainerSecurityContextSeccompProfile"
          );
        };
        "windowsOptions" = mkOption {
          description = "";
          type = types.nullOr (
            submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecFilerContainerSecurityContextWindowsOptions"
          );
        };
      };

      config = {
        "allowPrivilegeEscalation" = mkOverride 1002 null;
        "appArmorProfile" = mkOverride 1002 null;
        "capabilities" = mkOverride 1002 null;
        "privileged" = mkOverride 1002 null;
        "procMount" = mkOverride 1002 null;
        "readOnlyRootFilesystem" = mkOverride 1002 null;
        "runAsGroup" = mkOverride 1002 null;
        "runAsNonRoot" = mkOverride 1002 null;
        "runAsUser" = mkOverride 1002 null;
        "seLinuxOptions" = mkOverride 1002 null;
        "seccompProfile" = mkOverride 1002 null;
        "windowsOptions" = mkOverride 1002 null;
      };

    };
    "seaweed.seaweedfs.com.v1.SeaweedSpecFilerContainerSecurityContextAppArmorProfile" = {

      options = {
        "localhostProfile" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "type" = mkOption {
          description = "";
          type = types.str;
        };
      };

      config = {
        "localhostProfile" = mkOverride 1002 null;
      };

    };
    "seaweed.seaweedfs.com.v1.SeaweedSpecFilerContainerSecurityContextCapabilities" = {

      options = {
        "add" = mkOption {
          description = "";
          type = types.nullOr (types.listOf types.str);
        };
        "drop" = mkOption {
          description = "";
          type = types.nullOr (types.listOf types.str);
        };
      };

      config = {
        "add" = mkOverride 1002 null;
        "drop" = mkOverride 1002 null;
      };

    };
    "seaweed.seaweedfs.com.v1.SeaweedSpecFilerContainerSecurityContextSeLinuxOptions" = {

      options = {
        "level" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "role" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "type" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "user" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
      };

      config = {
        "level" = mkOverride 1002 null;
        "role" = mkOverride 1002 null;
        "type" = mkOverride 1002 null;
        "user" = mkOverride 1002 null;
      };

    };
    "seaweed.seaweedfs.com.v1.SeaweedSpecFilerContainerSecurityContextSeccompProfile" = {

      options = {
        "localhostProfile" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "type" = mkOption {
          description = "";
          type = types.str;
        };
      };

      config = {
        "localhostProfile" = mkOverride 1002 null;
      };

    };
    "seaweed.seaweedfs.com.v1.SeaweedSpecFilerContainerSecurityContextWindowsOptions" = {

      options = {
        "gmsaCredentialSpec" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "gmsaCredentialSpecName" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "hostProcess" = mkOption {
          description = "";
          type = types.nullOr types.bool;
        };
        "runAsUserName" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
      };

      config = {
        "gmsaCredentialSpec" = mkOverride 1002 null;
        "gmsaCredentialSpecName" = mkOverride 1002 null;
        "hostProcess" = mkOverride 1002 null;
        "runAsUserName" = mkOverride 1002 null;
      };

    };
    "seaweed.seaweedfs.com.v1.SeaweedSpecFilerEnv" = {

      options = {
        "name" = mkOption {
          description = "";
          type = types.str;
        };
        "value" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "valueFrom" = mkOption {
          description = "";
          type = types.nullOr (submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecFilerEnvValueFrom");
        };
      };

      config = {
        "value" = mkOverride 1002 null;
        "valueFrom" = mkOverride 1002 null;
      };

    };
    "seaweed.seaweedfs.com.v1.SeaweedSpecFilerEnvValueFrom" = {

      options = {
        "configMapKeyRef" = mkOption {
          description = "";
          type = types.nullOr (
            submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecFilerEnvValueFromConfigMapKeyRef"
          );
        };
        "fieldRef" = mkOption {
          description = "";
          type = types.nullOr (submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecFilerEnvValueFromFieldRef");
        };
        "fileKeyRef" = mkOption {
          description = "";
          type = types.nullOr (submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecFilerEnvValueFromFileKeyRef");
        };
        "resourceFieldRef" = mkOption {
          description = "";
          type = types.nullOr (
            submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecFilerEnvValueFromResourceFieldRef"
          );
        };
        "secretKeyRef" = mkOption {
          description = "";
          type = types.nullOr (
            submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecFilerEnvValueFromSecretKeyRef"
          );
        };
      };

      config = {
        "configMapKeyRef" = mkOverride 1002 null;
        "fieldRef" = mkOverride 1002 null;
        "fileKeyRef" = mkOverride 1002 null;
        "resourceFieldRef" = mkOverride 1002 null;
        "secretKeyRef" = mkOverride 1002 null;
      };

    };
    "seaweed.seaweedfs.com.v1.SeaweedSpecFilerEnvValueFromConfigMapKeyRef" = {

      options = {
        "key" = mkOption {
          description = "";
          type = types.str;
        };
        "name" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "optional" = mkOption {
          description = "";
          type = types.nullOr types.bool;
        };
      };

      config = {
        "name" = mkOverride 1002 null;
        "optional" = mkOverride 1002 null;
      };

    };
    "seaweed.seaweedfs.com.v1.SeaweedSpecFilerEnvValueFromFieldRef" = {

      options = {
        "apiVersion" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "fieldPath" = mkOption {
          description = "";
          type = types.str;
        };
      };

      config = {
        "apiVersion" = mkOverride 1002 null;
      };

    };
    "seaweed.seaweedfs.com.v1.SeaweedSpecFilerEnvValueFromFileKeyRef" = {

      options = {
        "key" = mkOption {
          description = "";
          type = types.str;
        };
        "optional" = mkOption {
          description = "";
          type = types.nullOr types.bool;
        };
        "path" = mkOption {
          description = "";
          type = types.str;
        };
        "volumeName" = mkOption {
          description = "";
          type = types.str;
        };
      };

      config = {
        "optional" = mkOverride 1002 null;
      };

    };
    "seaweed.seaweedfs.com.v1.SeaweedSpecFilerEnvValueFromResourceFieldRef" = {

      options = {
        "containerName" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "divisor" = mkOption {
          description = "";
          type = types.nullOr (types.either types.int types.str);
        };
        "resource" = mkOption {
          description = "";
          type = types.str;
        };
      };

      config = {
        "containerName" = mkOverride 1002 null;
        "divisor" = mkOverride 1002 null;
      };

    };
    "seaweed.seaweedfs.com.v1.SeaweedSpecFilerEnvValueFromSecretKeyRef" = {

      options = {
        "key" = mkOption {
          description = "";
          type = types.str;
        };
        "name" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "optional" = mkOption {
          description = "";
          type = types.nullOr types.bool;
        };
      };

      config = {
        "name" = mkOverride 1002 null;
        "optional" = mkOverride 1002 null;
      };

    };
    "seaweed.seaweedfs.com.v1.SeaweedSpecFilerGrpcIngress" = {

      options = {
        "annotations" = mkOption {
          description = "";
          type = types.nullOr (types.attrsOf types.str);
        };
        "className" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "enabled" = mkOption {
          description = "";
          type = types.nullOr types.bool;
        };
        "host" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "path" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "tls" = mkOption {
          description = "";
          type = types.nullOr (
            types.listOf (submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecFilerGrpcIngressTls")
          );
        };
      };

      config = {
        "annotations" = mkOverride 1002 null;
        "className" = mkOverride 1002 null;
        "enabled" = mkOverride 1002 null;
        "host" = mkOverride 1002 null;
        "path" = mkOverride 1002 null;
        "tls" = mkOverride 1002 null;
      };

    };
    "seaweed.seaweedfs.com.v1.SeaweedSpecFilerGrpcIngressTls" = {

      options = {
        "hosts" = mkOption {
          description = "";
          type = types.nullOr (types.listOf types.str);
        };
        "secretName" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
      };

      config = {
        "hosts" = mkOverride 1002 null;
        "secretName" = mkOverride 1002 null;
      };

    };
    "seaweed.seaweedfs.com.v1.SeaweedSpecFilerIceberg" = {

      options = {
        "enabled" = mkOption {
          description = "";
          type = types.nullOr types.bool;
        };
        "port" = mkOption {
          description = "";
          type = types.nullOr types.int;
        };
      };

      config = {
        "enabled" = mkOverride 1002 null;
        "port" = mkOverride 1002 null;
      };

    };
    "seaweed.seaweedfs.com.v1.SeaweedSpecFilerImagePullSecrets" = {

      options = {
        "name" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
      };

      config = {
        "name" = mkOverride 1002 null;
      };

    };
    "seaweed.seaweedfs.com.v1.SeaweedSpecFilerIngress" = {

      options = {
        "annotations" = mkOption {
          description = "";
          type = types.nullOr (types.attrsOf types.str);
        };
        "className" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "enabled" = mkOption {
          description = "";
          type = types.nullOr types.bool;
        };
        "host" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "path" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "tls" = mkOption {
          description = "";
          type = types.nullOr (
            types.listOf (submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecFilerIngressTls")
          );
        };
      };

      config = {
        "annotations" = mkOverride 1002 null;
        "className" = mkOverride 1002 null;
        "enabled" = mkOverride 1002 null;
        "host" = mkOverride 1002 null;
        "path" = mkOverride 1002 null;
        "tls" = mkOverride 1002 null;
      };

    };
    "seaweed.seaweedfs.com.v1.SeaweedSpecFilerIngressTls" = {

      options = {
        "hosts" = mkOption {
          description = "";
          type = types.nullOr (types.listOf types.str);
        };
        "secretName" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
      };

      config = {
        "hosts" = mkOverride 1002 null;
        "secretName" = mkOverride 1002 null;
      };

    };
    "seaweed.seaweedfs.com.v1.SeaweedSpecFilerLivenessProbe" = {

      options = {
        "failureThreshold" = mkOption {
          description = "";
          type = types.nullOr types.int;
        };
        "initialDelaySeconds" = mkOption {
          description = "";
          type = types.nullOr types.int;
        };
        "periodSeconds" = mkOption {
          description = "";
          type = types.nullOr types.int;
        };
        "timeoutSeconds" = mkOption {
          description = "";
          type = types.nullOr types.int;
        };
      };

      config = {
        "failureThreshold" = mkOverride 1002 null;
        "initialDelaySeconds" = mkOverride 1002 null;
        "periodSeconds" = mkOverride 1002 null;
        "timeoutSeconds" = mkOverride 1002 null;
      };

    };
    "seaweed.seaweedfs.com.v1.SeaweedSpecFilerPersistence" = {

      options = {
        "accessModes" = mkOption {
          description = "";
          type = types.nullOr (types.listOf types.str);
        };
        "annotations" = mkOption {
          description = "";
          type = types.nullOr (types.attrsOf types.str);
        };
        "dataSource" = mkOption {
          description = "";
          type = types.nullOr (submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecFilerPersistenceDataSource");
        };
        "enabled" = mkOption {
          description = "";
          type = types.nullOr types.bool;
        };
        "existingClaim" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "labels" = mkOption {
          description = "";
          type = types.nullOr (types.attrsOf types.str);
        };
        "mountPath" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "resources" = mkOption {
          description = "";
          type = types.nullOr (submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecFilerPersistenceResources");
        };
        "selector" = mkOption {
          description = "";
          type = types.nullOr (submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecFilerPersistenceSelector");
        };
        "storageClassName" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "subPath" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "volumeMode" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "volumeName" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
      };

      config = {
        "accessModes" = mkOverride 1002 null;
        "annotations" = mkOverride 1002 null;
        "dataSource" = mkOverride 1002 null;
        "enabled" = mkOverride 1002 null;
        "existingClaim" = mkOverride 1002 null;
        "labels" = mkOverride 1002 null;
        "mountPath" = mkOverride 1002 null;
        "resources" = mkOverride 1002 null;
        "selector" = mkOverride 1002 null;
        "storageClassName" = mkOverride 1002 null;
        "subPath" = mkOverride 1002 null;
        "volumeMode" = mkOverride 1002 null;
        "volumeName" = mkOverride 1002 null;
      };

    };
    "seaweed.seaweedfs.com.v1.SeaweedSpecFilerPersistenceDataSource" = {

      options = {
        "apiGroup" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "kind" = mkOption {
          description = "";
          type = types.str;
        };
        "name" = mkOption {
          description = "";
          type = types.str;
        };
      };

      config = {
        "apiGroup" = mkOverride 1002 null;
      };

    };
    "seaweed.seaweedfs.com.v1.SeaweedSpecFilerPersistenceResources" = {

      options = {
        "limits" = mkOption {
          description = "";
          type = types.nullOr (types.attrsOf (types.either types.int types.str));
        };
        "requests" = mkOption {
          description = "";
          type = types.nullOr (types.attrsOf (types.either types.int types.str));
        };
      };

      config = {
        "limits" = mkOverride 1002 null;
        "requests" = mkOverride 1002 null;
      };

    };
    "seaweed.seaweedfs.com.v1.SeaweedSpecFilerPersistenceSelector" = {

      options = {
        "matchExpressions" = mkOption {
          description = "";
          type = types.nullOr (
            types.listOf (
              submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecFilerPersistenceSelectorMatchExpressions"
            )
          );
        };
        "matchLabels" = mkOption {
          description = "";
          type = types.nullOr (types.attrsOf types.str);
        };
      };

      config = {
        "matchExpressions" = mkOverride 1002 null;
        "matchLabels" = mkOverride 1002 null;
      };

    };
    "seaweed.seaweedfs.com.v1.SeaweedSpecFilerPersistenceSelectorMatchExpressions" = {

      options = {
        "key" = mkOption {
          description = "";
          type = types.str;
        };
        "operator" = mkOption {
          description = "";
          type = types.str;
        };
        "values" = mkOption {
          description = "";
          type = types.nullOr (types.listOf types.str);
        };
      };

      config = {
        "values" = mkOverride 1002 null;
      };

    };
    "seaweed.seaweedfs.com.v1.SeaweedSpecFilerPodSecurityContext" = {

      options = {
        "appArmorProfile" = mkOption {
          description = "";
          type = types.nullOr (
            submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecFilerPodSecurityContextAppArmorProfile"
          );
        };
        "fsGroup" = mkOption {
          description = "";
          type = types.nullOr types.int;
        };
        "fsGroupChangePolicy" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "runAsGroup" = mkOption {
          description = "";
          type = types.nullOr types.int;
        };
        "runAsNonRoot" = mkOption {
          description = "";
          type = types.nullOr types.bool;
        };
        "runAsUser" = mkOption {
          description = "";
          type = types.nullOr types.int;
        };
        "seLinuxChangePolicy" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "seLinuxOptions" = mkOption {
          description = "";
          type = types.nullOr (
            submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecFilerPodSecurityContextSeLinuxOptions"
          );
        };
        "seccompProfile" = mkOption {
          description = "";
          type = types.nullOr (
            submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecFilerPodSecurityContextSeccompProfile"
          );
        };
        "supplementalGroups" = mkOption {
          description = "";
          type = types.nullOr (types.listOf types.int);
        };
        "supplementalGroupsPolicy" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "sysctls" = mkOption {
          description = "";
          type = types.nullOr (
            coerceAttrsOfSubmodulesToListByKey
              "seaweed.seaweedfs.com.v1.SeaweedSpecFilerPodSecurityContextSysctls"
              "name"
              [ ]
          );
          apply = attrsToList;
        };
        "windowsOptions" = mkOption {
          description = "";
          type = types.nullOr (
            submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecFilerPodSecurityContextWindowsOptions"
          );
        };
      };

      config = {
        "appArmorProfile" = mkOverride 1002 null;
        "fsGroup" = mkOverride 1002 null;
        "fsGroupChangePolicy" = mkOverride 1002 null;
        "runAsGroup" = mkOverride 1002 null;
        "runAsNonRoot" = mkOverride 1002 null;
        "runAsUser" = mkOverride 1002 null;
        "seLinuxChangePolicy" = mkOverride 1002 null;
        "seLinuxOptions" = mkOverride 1002 null;
        "seccompProfile" = mkOverride 1002 null;
        "supplementalGroups" = mkOverride 1002 null;
        "supplementalGroupsPolicy" = mkOverride 1002 null;
        "sysctls" = mkOverride 1002 null;
        "windowsOptions" = mkOverride 1002 null;
      };

    };
    "seaweed.seaweedfs.com.v1.SeaweedSpecFilerPodSecurityContextAppArmorProfile" = {

      options = {
        "localhostProfile" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "type" = mkOption {
          description = "";
          type = types.str;
        };
      };

      config = {
        "localhostProfile" = mkOverride 1002 null;
      };

    };
    "seaweed.seaweedfs.com.v1.SeaweedSpecFilerPodSecurityContextSeLinuxOptions" = {

      options = {
        "level" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "role" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "type" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "user" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
      };

      config = {
        "level" = mkOverride 1002 null;
        "role" = mkOverride 1002 null;
        "type" = mkOverride 1002 null;
        "user" = mkOverride 1002 null;
      };

    };
    "seaweed.seaweedfs.com.v1.SeaweedSpecFilerPodSecurityContextSeccompProfile" = {

      options = {
        "localhostProfile" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "type" = mkOption {
          description = "";
          type = types.str;
        };
      };

      config = {
        "localhostProfile" = mkOverride 1002 null;
      };

    };
    "seaweed.seaweedfs.com.v1.SeaweedSpecFilerPodSecurityContextSysctls" = {

      options = {
        "name" = mkOption {
          description = "";
          type = types.str;
        };
        "value" = mkOption {
          description = "";
          type = types.str;
        };
      };

      config = { };

    };
    "seaweed.seaweedfs.com.v1.SeaweedSpecFilerPodSecurityContextWindowsOptions" = {

      options = {
        "gmsaCredentialSpec" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "gmsaCredentialSpecName" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "hostProcess" = mkOption {
          description = "";
          type = types.nullOr types.bool;
        };
        "runAsUserName" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
      };

      config = {
        "gmsaCredentialSpec" = mkOverride 1002 null;
        "gmsaCredentialSpecName" = mkOverride 1002 null;
        "hostProcess" = mkOverride 1002 null;
        "runAsUserName" = mkOverride 1002 null;
      };

    };
    "seaweed.seaweedfs.com.v1.SeaweedSpecFilerReadinessProbe" = {

      options = {
        "failureThreshold" = mkOption {
          description = "";
          type = types.nullOr types.int;
        };
        "initialDelaySeconds" = mkOption {
          description = "";
          type = types.nullOr types.int;
        };
        "periodSeconds" = mkOption {
          description = "";
          type = types.nullOr types.int;
        };
        "successThreshold" = mkOption {
          description = "";
          type = types.nullOr types.int;
        };
        "timeoutSeconds" = mkOption {
          description = "";
          type = types.nullOr types.int;
        };
      };

      config = {
        "failureThreshold" = mkOverride 1002 null;
        "initialDelaySeconds" = mkOverride 1002 null;
        "periodSeconds" = mkOverride 1002 null;
        "successThreshold" = mkOverride 1002 null;
        "timeoutSeconds" = mkOverride 1002 null;
      };

    };
    "seaweed.seaweedfs.com.v1.SeaweedSpecFilerS3" = {

      options = {
        "configSecret" = mkOption {
          description = "";
          type = types.nullOr (submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecFilerS3ConfigSecret");
        };
        "enabled" = mkOption {
          description = "";
          type = types.nullOr types.bool;
        };
      };

      config = {
        "configSecret" = mkOverride 1002 null;
        "enabled" = mkOverride 1002 null;
      };

    };
    "seaweed.seaweedfs.com.v1.SeaweedSpecFilerS3ConfigSecret" = {

      options = {
        "key" = mkOption {
          description = "";
          type = types.str;
        };
        "name" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "optional" = mkOption {
          description = "";
          type = types.nullOr types.bool;
        };
      };

      config = {
        "name" = mkOverride 1002 null;
        "optional" = mkOverride 1002 null;
      };

    };
    "seaweed.seaweedfs.com.v1.SeaweedSpecFilerS3Ingress" = {

      options = {
        "annotations" = mkOption {
          description = "";
          type = types.nullOr (types.attrsOf types.str);
        };
        "className" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "enabled" = mkOption {
          description = "";
          type = types.nullOr types.bool;
        };
        "host" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "path" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "tls" = mkOption {
          description = "";
          type = types.nullOr (
            types.listOf (submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecFilerS3IngressTls")
          );
        };
      };

      config = {
        "annotations" = mkOverride 1002 null;
        "className" = mkOverride 1002 null;
        "enabled" = mkOverride 1002 null;
        "host" = mkOverride 1002 null;
        "path" = mkOverride 1002 null;
        "tls" = mkOverride 1002 null;
      };

    };
    "seaweed.seaweedfs.com.v1.SeaweedSpecFilerS3IngressTls" = {

      options = {
        "hosts" = mkOption {
          description = "";
          type = types.nullOr (types.listOf types.str);
        };
        "secretName" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
      };

      config = {
        "hosts" = mkOverride 1002 null;
        "secretName" = mkOverride 1002 null;
      };

    };
    "seaweed.seaweedfs.com.v1.SeaweedSpecFilerService" = {

      options = {
        "annotations" = mkOption {
          description = "";
          type = types.nullOr (types.attrsOf types.str);
        };
        "clusterIP" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "loadBalancerIP" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "type" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
      };

      config = {
        "annotations" = mkOverride 1002 null;
        "clusterIP" = mkOverride 1002 null;
        "loadBalancerIP" = mkOverride 1002 null;
        "type" = mkOverride 1002 null;
      };

    };
    "seaweed.seaweedfs.com.v1.SeaweedSpecFilerTolerations" = {

      options = {
        "effect" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "key" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "operator" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "tolerationSeconds" = mkOption {
          description = "";
          type = types.nullOr types.int;
        };
        "value" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
      };

      config = {
        "effect" = mkOverride 1002 null;
        "key" = mkOverride 1002 null;
        "operator" = mkOverride 1002 null;
        "tolerationSeconds" = mkOverride 1002 null;
        "value" = mkOverride 1002 null;
      };

    };
    "seaweed.seaweedfs.com.v1.SeaweedSpecFilerVolumeMounts" = {

      options = {
        "mountPath" = mkOption {
          description = "";
          type = types.str;
        };
        "mountPropagation" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "name" = mkOption {
          description = "";
          type = types.str;
        };
        "readOnly" = mkOption {
          description = "";
          type = types.nullOr types.bool;
        };
        "recursiveReadOnly" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "subPath" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "subPathExpr" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
      };

      config = {
        "mountPropagation" = mkOverride 1002 null;
        "readOnly" = mkOverride 1002 null;
        "recursiveReadOnly" = mkOverride 1002 null;
        "subPath" = mkOverride 1002 null;
        "subPathExpr" = mkOverride 1002 null;
      };

    };
    "seaweed.seaweedfs.com.v1.SeaweedSpecFilerVolumes" = {

      options = {
        "awsElasticBlockStore" = mkOption {
          description = "";
          type = types.nullOr (
            submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecFilerVolumesAwsElasticBlockStore"
          );
        };
        "azureDisk" = mkOption {
          description = "";
          type = types.nullOr (submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecFilerVolumesAzureDisk");
        };
        "azureFile" = mkOption {
          description = "";
          type = types.nullOr (submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecFilerVolumesAzureFile");
        };
        "cephfs" = mkOption {
          description = "";
          type = types.nullOr (submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecFilerVolumesCephfs");
        };
        "cinder" = mkOption {
          description = "";
          type = types.nullOr (submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecFilerVolumesCinder");
        };
        "configMap" = mkOption {
          description = "";
          type = types.nullOr (submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecFilerVolumesConfigMap");
        };
        "csi" = mkOption {
          description = "";
          type = types.nullOr (submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecFilerVolumesCsi");
        };
        "downwardAPI" = mkOption {
          description = "";
          type = types.nullOr (submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecFilerVolumesDownwardAPI");
        };
        "emptyDir" = mkOption {
          description = "";
          type = types.nullOr (submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecFilerVolumesEmptyDir");
        };
        "ephemeral" = mkOption {
          description = "";
          type = types.nullOr (submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecFilerVolumesEphemeral");
        };
        "fc" = mkOption {
          description = "";
          type = types.nullOr (submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecFilerVolumesFc");
        };
        "flexVolume" = mkOption {
          description = "";
          type = types.nullOr (submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecFilerVolumesFlexVolume");
        };
        "flocker" = mkOption {
          description = "";
          type = types.nullOr (submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecFilerVolumesFlocker");
        };
        "gcePersistentDisk" = mkOption {
          description = "";
          type = types.nullOr (
            submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecFilerVolumesGcePersistentDisk"
          );
        };
        "gitRepo" = mkOption {
          description = "";
          type = types.nullOr (submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecFilerVolumesGitRepo");
        };
        "glusterfs" = mkOption {
          description = "";
          type = types.nullOr (submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecFilerVolumesGlusterfs");
        };
        "hostPath" = mkOption {
          description = "";
          type = types.nullOr (submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecFilerVolumesHostPath");
        };
        "image" = mkOption {
          description = "";
          type = types.nullOr (submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecFilerVolumesImage");
        };
        "iscsi" = mkOption {
          description = "";
          type = types.nullOr (submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecFilerVolumesIscsi");
        };
        "name" = mkOption {
          description = "";
          type = types.str;
        };
        "nfs" = mkOption {
          description = "";
          type = types.nullOr (submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecFilerVolumesNfs");
        };
        "persistentVolumeClaim" = mkOption {
          description = "";
          type = types.nullOr (
            submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecFilerVolumesPersistentVolumeClaim"
          );
        };
        "photonPersistentDisk" = mkOption {
          description = "";
          type = types.nullOr (
            submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecFilerVolumesPhotonPersistentDisk"
          );
        };
        "portworxVolume" = mkOption {
          description = "";
          type = types.nullOr (submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecFilerVolumesPortworxVolume");
        };
        "projected" = mkOption {
          description = "";
          type = types.nullOr (submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecFilerVolumesProjected");
        };
        "quobyte" = mkOption {
          description = "";
          type = types.nullOr (submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecFilerVolumesQuobyte");
        };
        "rbd" = mkOption {
          description = "";
          type = types.nullOr (submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecFilerVolumesRbd");
        };
        "scaleIO" = mkOption {
          description = "";
          type = types.nullOr (submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecFilerVolumesScaleIO");
        };
        "secret" = mkOption {
          description = "";
          type = types.nullOr (submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecFilerVolumesSecret");
        };
        "storageos" = mkOption {
          description = "";
          type = types.nullOr (submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecFilerVolumesStorageos");
        };
        "vsphereVolume" = mkOption {
          description = "";
          type = types.nullOr (submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecFilerVolumesVsphereVolume");
        };
      };

      config = {
        "awsElasticBlockStore" = mkOverride 1002 null;
        "azureDisk" = mkOverride 1002 null;
        "azureFile" = mkOverride 1002 null;
        "cephfs" = mkOverride 1002 null;
        "cinder" = mkOverride 1002 null;
        "configMap" = mkOverride 1002 null;
        "csi" = mkOverride 1002 null;
        "downwardAPI" = mkOverride 1002 null;
        "emptyDir" = mkOverride 1002 null;
        "ephemeral" = mkOverride 1002 null;
        "fc" = mkOverride 1002 null;
        "flexVolume" = mkOverride 1002 null;
        "flocker" = mkOverride 1002 null;
        "gcePersistentDisk" = mkOverride 1002 null;
        "gitRepo" = mkOverride 1002 null;
        "glusterfs" = mkOverride 1002 null;
        "hostPath" = mkOverride 1002 null;
        "image" = mkOverride 1002 null;
        "iscsi" = mkOverride 1002 null;
        "nfs" = mkOverride 1002 null;
        "persistentVolumeClaim" = mkOverride 1002 null;
        "photonPersistentDisk" = mkOverride 1002 null;
        "portworxVolume" = mkOverride 1002 null;
        "projected" = mkOverride 1002 null;
        "quobyte" = mkOverride 1002 null;
        "rbd" = mkOverride 1002 null;
        "scaleIO" = mkOverride 1002 null;
        "secret" = mkOverride 1002 null;
        "storageos" = mkOverride 1002 null;
        "vsphereVolume" = mkOverride 1002 null;
      };

    };
    "seaweed.seaweedfs.com.v1.SeaweedSpecFilerVolumesAwsElasticBlockStore" = {

      options = {
        "fsType" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "partition" = mkOption {
          description = "";
          type = types.nullOr types.int;
        };
        "readOnly" = mkOption {
          description = "";
          type = types.nullOr types.bool;
        };
        "volumeID" = mkOption {
          description = "";
          type = types.str;
        };
      };

      config = {
        "fsType" = mkOverride 1002 null;
        "partition" = mkOverride 1002 null;
        "readOnly" = mkOverride 1002 null;
      };

    };
    "seaweed.seaweedfs.com.v1.SeaweedSpecFilerVolumesAzureDisk" = {

      options = {
        "cachingMode" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "diskName" = mkOption {
          description = "";
          type = types.str;
        };
        "diskURI" = mkOption {
          description = "";
          type = types.str;
        };
        "fsType" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "kind" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "readOnly" = mkOption {
          description = "";
          type = types.nullOr types.bool;
        };
      };

      config = {
        "cachingMode" = mkOverride 1002 null;
        "fsType" = mkOverride 1002 null;
        "kind" = mkOverride 1002 null;
        "readOnly" = mkOverride 1002 null;
      };

    };
    "seaweed.seaweedfs.com.v1.SeaweedSpecFilerVolumesAzureFile" = {

      options = {
        "readOnly" = mkOption {
          description = "";
          type = types.nullOr types.bool;
        };
        "secretName" = mkOption {
          description = "";
          type = types.str;
        };
        "shareName" = mkOption {
          description = "";
          type = types.str;
        };
      };

      config = {
        "readOnly" = mkOverride 1002 null;
      };

    };
    "seaweed.seaweedfs.com.v1.SeaweedSpecFilerVolumesCephfs" = {

      options = {
        "monitors" = mkOption {
          description = "";
          type = types.listOf types.str;
        };
        "path" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "readOnly" = mkOption {
          description = "";
          type = types.nullOr types.bool;
        };
        "secretFile" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "secretRef" = mkOption {
          description = "";
          type = types.nullOr (submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecFilerVolumesCephfsSecretRef");
        };
        "user" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
      };

      config = {
        "path" = mkOverride 1002 null;
        "readOnly" = mkOverride 1002 null;
        "secretFile" = mkOverride 1002 null;
        "secretRef" = mkOverride 1002 null;
        "user" = mkOverride 1002 null;
      };

    };
    "seaweed.seaweedfs.com.v1.SeaweedSpecFilerVolumesCephfsSecretRef" = {

      options = {
        "name" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
      };

      config = {
        "name" = mkOverride 1002 null;
      };

    };
    "seaweed.seaweedfs.com.v1.SeaweedSpecFilerVolumesCinder" = {

      options = {
        "fsType" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "readOnly" = mkOption {
          description = "";
          type = types.nullOr types.bool;
        };
        "secretRef" = mkOption {
          description = "";
          type = types.nullOr (submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecFilerVolumesCinderSecretRef");
        };
        "volumeID" = mkOption {
          description = "";
          type = types.str;
        };
      };

      config = {
        "fsType" = mkOverride 1002 null;
        "readOnly" = mkOverride 1002 null;
        "secretRef" = mkOverride 1002 null;
      };

    };
    "seaweed.seaweedfs.com.v1.SeaweedSpecFilerVolumesCinderSecretRef" = {

      options = {
        "name" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
      };

      config = {
        "name" = mkOverride 1002 null;
      };

    };
    "seaweed.seaweedfs.com.v1.SeaweedSpecFilerVolumesConfigMap" = {

      options = {
        "defaultMode" = mkOption {
          description = "";
          type = types.nullOr types.int;
        };
        "items" = mkOption {
          description = "";
          type = types.nullOr (
            types.listOf (submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecFilerVolumesConfigMapItems")
          );
        };
        "name" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "optional" = mkOption {
          description = "";
          type = types.nullOr types.bool;
        };
      };

      config = {
        "defaultMode" = mkOverride 1002 null;
        "items" = mkOverride 1002 null;
        "name" = mkOverride 1002 null;
        "optional" = mkOverride 1002 null;
      };

    };
    "seaweed.seaweedfs.com.v1.SeaweedSpecFilerVolumesConfigMapItems" = {

      options = {
        "key" = mkOption {
          description = "";
          type = types.str;
        };
        "mode" = mkOption {
          description = "";
          type = types.nullOr types.int;
        };
        "path" = mkOption {
          description = "";
          type = types.str;
        };
      };

      config = {
        "mode" = mkOverride 1002 null;
      };

    };
    "seaweed.seaweedfs.com.v1.SeaweedSpecFilerVolumesCsi" = {

      options = {
        "driver" = mkOption {
          description = "";
          type = types.str;
        };
        "fsType" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "nodePublishSecretRef" = mkOption {
          description = "";
          type = types.nullOr (
            submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecFilerVolumesCsiNodePublishSecretRef"
          );
        };
        "readOnly" = mkOption {
          description = "";
          type = types.nullOr types.bool;
        };
        "volumeAttributes" = mkOption {
          description = "";
          type = types.nullOr (types.attrsOf types.str);
        };
      };

      config = {
        "fsType" = mkOverride 1002 null;
        "nodePublishSecretRef" = mkOverride 1002 null;
        "readOnly" = mkOverride 1002 null;
        "volumeAttributes" = mkOverride 1002 null;
      };

    };
    "seaweed.seaweedfs.com.v1.SeaweedSpecFilerVolumesCsiNodePublishSecretRef" = {

      options = {
        "name" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
      };

      config = {
        "name" = mkOverride 1002 null;
      };

    };
    "seaweed.seaweedfs.com.v1.SeaweedSpecFilerVolumesDownwardAPI" = {

      options = {
        "defaultMode" = mkOption {
          description = "";
          type = types.nullOr types.int;
        };
        "items" = mkOption {
          description = "";
          type = types.nullOr (
            types.listOf (submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecFilerVolumesDownwardAPIItems")
          );
        };
      };

      config = {
        "defaultMode" = mkOverride 1002 null;
        "items" = mkOverride 1002 null;
      };

    };
    "seaweed.seaweedfs.com.v1.SeaweedSpecFilerVolumesDownwardAPIItems" = {

      options = {
        "fieldRef" = mkOption {
          description = "";
          type = types.nullOr (
            submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecFilerVolumesDownwardAPIItemsFieldRef"
          );
        };
        "mode" = mkOption {
          description = "";
          type = types.nullOr types.int;
        };
        "path" = mkOption {
          description = "";
          type = types.str;
        };
        "resourceFieldRef" = mkOption {
          description = "";
          type = types.nullOr (
            submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecFilerVolumesDownwardAPIItemsResourceFieldRef"
          );
        };
      };

      config = {
        "fieldRef" = mkOverride 1002 null;
        "mode" = mkOverride 1002 null;
        "resourceFieldRef" = mkOverride 1002 null;
      };

    };
    "seaweed.seaweedfs.com.v1.SeaweedSpecFilerVolumesDownwardAPIItemsFieldRef" = {

      options = {
        "apiVersion" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "fieldPath" = mkOption {
          description = "";
          type = types.str;
        };
      };

      config = {
        "apiVersion" = mkOverride 1002 null;
      };

    };
    "seaweed.seaweedfs.com.v1.SeaweedSpecFilerVolumesDownwardAPIItemsResourceFieldRef" = {

      options = {
        "containerName" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "divisor" = mkOption {
          description = "";
          type = types.nullOr (types.either types.int types.str);
        };
        "resource" = mkOption {
          description = "";
          type = types.str;
        };
      };

      config = {
        "containerName" = mkOverride 1002 null;
        "divisor" = mkOverride 1002 null;
      };

    };
    "seaweed.seaweedfs.com.v1.SeaweedSpecFilerVolumesEmptyDir" = {

      options = {
        "medium" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "sizeLimit" = mkOption {
          description = "";
          type = types.nullOr (types.either types.int types.str);
        };
      };

      config = {
        "medium" = mkOverride 1002 null;
        "sizeLimit" = mkOverride 1002 null;
      };

    };
    "seaweed.seaweedfs.com.v1.SeaweedSpecFilerVolumesEphemeral" = {

      options = {
        "volumeClaimTemplate" = mkOption {
          description = "";
          type = types.nullOr (
            submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecFilerVolumesEphemeralVolumeClaimTemplate"
          );
        };
      };

      config = {
        "volumeClaimTemplate" = mkOverride 1002 null;
      };

    };
    "seaweed.seaweedfs.com.v1.SeaweedSpecFilerVolumesEphemeralVolumeClaimTemplate" = {

      options = {
        "metadata" = mkOption {
          description = "";
          type = types.nullOr types.attrs;
        };
        "spec" = mkOption {
          description = "";
          type = submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecFilerVolumesEphemeralVolumeClaimTemplateSpec";
        };
      };

      config = {
        "metadata" = mkOverride 1002 null;
      };

    };
    "seaweed.seaweedfs.com.v1.SeaweedSpecFilerVolumesEphemeralVolumeClaimTemplateSpec" = {

      options = {
        "accessModes" = mkOption {
          description = "";
          type = types.nullOr (types.listOf types.str);
        };
        "dataSource" = mkOption {
          description = "";
          type = types.nullOr (
            submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecFilerVolumesEphemeralVolumeClaimTemplateSpecDataSource"
          );
        };
        "dataSourceRef" = mkOption {
          description = "";
          type = types.nullOr (
            submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecFilerVolumesEphemeralVolumeClaimTemplateSpecDataSourceRef"
          );
        };
        "resources" = mkOption {
          description = "";
          type = types.nullOr (
            submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecFilerVolumesEphemeralVolumeClaimTemplateSpecResources"
          );
        };
        "selector" = mkOption {
          description = "";
          type = types.nullOr (
            submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecFilerVolumesEphemeralVolumeClaimTemplateSpecSelector"
          );
        };
        "storageClassName" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "volumeAttributesClassName" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "volumeMode" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "volumeName" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
      };

      config = {
        "accessModes" = mkOverride 1002 null;
        "dataSource" = mkOverride 1002 null;
        "dataSourceRef" = mkOverride 1002 null;
        "resources" = mkOverride 1002 null;
        "selector" = mkOverride 1002 null;
        "storageClassName" = mkOverride 1002 null;
        "volumeAttributesClassName" = mkOverride 1002 null;
        "volumeMode" = mkOverride 1002 null;
        "volumeName" = mkOverride 1002 null;
      };

    };
    "seaweed.seaweedfs.com.v1.SeaweedSpecFilerVolumesEphemeralVolumeClaimTemplateSpecDataSource" = {

      options = {
        "apiGroup" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "kind" = mkOption {
          description = "";
          type = types.str;
        };
        "name" = mkOption {
          description = "";
          type = types.str;
        };
      };

      config = {
        "apiGroup" = mkOverride 1002 null;
      };

    };
    "seaweed.seaweedfs.com.v1.SeaweedSpecFilerVolumesEphemeralVolumeClaimTemplateSpecDataSourceRef" = {

      options = {
        "apiGroup" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "kind" = mkOption {
          description = "";
          type = types.str;
        };
        "name" = mkOption {
          description = "";
          type = types.str;
        };
        "namespace" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
      };

      config = {
        "apiGroup" = mkOverride 1002 null;
        "namespace" = mkOverride 1002 null;
      };

    };
    "seaweed.seaweedfs.com.v1.SeaweedSpecFilerVolumesEphemeralVolumeClaimTemplateSpecResources" = {

      options = {
        "limits" = mkOption {
          description = "";
          type = types.nullOr (types.attrsOf (types.either types.int types.str));
        };
        "requests" = mkOption {
          description = "";
          type = types.nullOr (types.attrsOf (types.either types.int types.str));
        };
      };

      config = {
        "limits" = mkOverride 1002 null;
        "requests" = mkOverride 1002 null;
      };

    };
    "seaweed.seaweedfs.com.v1.SeaweedSpecFilerVolumesEphemeralVolumeClaimTemplateSpecSelector" = {

      options = {
        "matchExpressions" = mkOption {
          description = "";
          type = types.nullOr (
            types.listOf (
              submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecFilerVolumesEphemeralVolumeClaimTemplateSpecSelectorMatchExpressions"
            )
          );
        };
        "matchLabels" = mkOption {
          description = "";
          type = types.nullOr (types.attrsOf types.str);
        };
      };

      config = {
        "matchExpressions" = mkOverride 1002 null;
        "matchLabels" = mkOverride 1002 null;
      };

    };
    "seaweed.seaweedfs.com.v1.SeaweedSpecFilerVolumesEphemeralVolumeClaimTemplateSpecSelectorMatchExpressions" =
      {

        options = {
          "key" = mkOption {
            description = "";
            type = types.str;
          };
          "operator" = mkOption {
            description = "";
            type = types.str;
          };
          "values" = mkOption {
            description = "";
            type = types.nullOr (types.listOf types.str);
          };
        };

        config = {
          "values" = mkOverride 1002 null;
        };

      };
    "seaweed.seaweedfs.com.v1.SeaweedSpecFilerVolumesFc" = {

      options = {
        "fsType" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "lun" = mkOption {
          description = "";
          type = types.nullOr types.int;
        };
        "readOnly" = mkOption {
          description = "";
          type = types.nullOr types.bool;
        };
        "targetWWNs" = mkOption {
          description = "";
          type = types.nullOr (types.listOf types.str);
        };
        "wwids" = mkOption {
          description = "";
          type = types.nullOr (types.listOf types.str);
        };
      };

      config = {
        "fsType" = mkOverride 1002 null;
        "lun" = mkOverride 1002 null;
        "readOnly" = mkOverride 1002 null;
        "targetWWNs" = mkOverride 1002 null;
        "wwids" = mkOverride 1002 null;
      };

    };
    "seaweed.seaweedfs.com.v1.SeaweedSpecFilerVolumesFlexVolume" = {

      options = {
        "driver" = mkOption {
          description = "";
          type = types.str;
        };
        "fsType" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "options" = mkOption {
          description = "";
          type = types.nullOr (types.attrsOf types.str);
        };
        "readOnly" = mkOption {
          description = "";
          type = types.nullOr types.bool;
        };
        "secretRef" = mkOption {
          description = "";
          type = types.nullOr (
            submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecFilerVolumesFlexVolumeSecretRef"
          );
        };
      };

      config = {
        "fsType" = mkOverride 1002 null;
        "options" = mkOverride 1002 null;
        "readOnly" = mkOverride 1002 null;
        "secretRef" = mkOverride 1002 null;
      };

    };
    "seaweed.seaweedfs.com.v1.SeaweedSpecFilerVolumesFlexVolumeSecretRef" = {

      options = {
        "name" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
      };

      config = {
        "name" = mkOverride 1002 null;
      };

    };
    "seaweed.seaweedfs.com.v1.SeaweedSpecFilerVolumesFlocker" = {

      options = {
        "datasetName" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "datasetUUID" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
      };

      config = {
        "datasetName" = mkOverride 1002 null;
        "datasetUUID" = mkOverride 1002 null;
      };

    };
    "seaweed.seaweedfs.com.v1.SeaweedSpecFilerVolumesGcePersistentDisk" = {

      options = {
        "fsType" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "partition" = mkOption {
          description = "";
          type = types.nullOr types.int;
        };
        "pdName" = mkOption {
          description = "";
          type = types.str;
        };
        "readOnly" = mkOption {
          description = "";
          type = types.nullOr types.bool;
        };
      };

      config = {
        "fsType" = mkOverride 1002 null;
        "partition" = mkOverride 1002 null;
        "readOnly" = mkOverride 1002 null;
      };

    };
    "seaweed.seaweedfs.com.v1.SeaweedSpecFilerVolumesGitRepo" = {

      options = {
        "directory" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "repository" = mkOption {
          description = "";
          type = types.str;
        };
        "revision" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
      };

      config = {
        "directory" = mkOverride 1002 null;
        "revision" = mkOverride 1002 null;
      };

    };
    "seaweed.seaweedfs.com.v1.SeaweedSpecFilerVolumesGlusterfs" = {

      options = {
        "endpoints" = mkOption {
          description = "";
          type = types.str;
        };
        "path" = mkOption {
          description = "";
          type = types.str;
        };
        "readOnly" = mkOption {
          description = "";
          type = types.nullOr types.bool;
        };
      };

      config = {
        "readOnly" = mkOverride 1002 null;
      };

    };
    "seaweed.seaweedfs.com.v1.SeaweedSpecFilerVolumesHostPath" = {

      options = {
        "path" = mkOption {
          description = "";
          type = types.str;
        };
        "type" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
      };

      config = {
        "type" = mkOverride 1002 null;
      };

    };
    "seaweed.seaweedfs.com.v1.SeaweedSpecFilerVolumesImage" = {

      options = {
        "pullPolicy" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "reference" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
      };

      config = {
        "pullPolicy" = mkOverride 1002 null;
        "reference" = mkOverride 1002 null;
      };

    };
    "seaweed.seaweedfs.com.v1.SeaweedSpecFilerVolumesIscsi" = {

      options = {
        "chapAuthDiscovery" = mkOption {
          description = "";
          type = types.nullOr types.bool;
        };
        "chapAuthSession" = mkOption {
          description = "";
          type = types.nullOr types.bool;
        };
        "fsType" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "initiatorName" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "iqn" = mkOption {
          description = "";
          type = types.str;
        };
        "iscsiInterface" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "lun" = mkOption {
          description = "";
          type = types.int;
        };
        "portals" = mkOption {
          description = "";
          type = types.nullOr (types.listOf types.str);
        };
        "readOnly" = mkOption {
          description = "";
          type = types.nullOr types.bool;
        };
        "secretRef" = mkOption {
          description = "";
          type = types.nullOr (submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecFilerVolumesIscsiSecretRef");
        };
        "targetPortal" = mkOption {
          description = "";
          type = types.str;
        };
      };

      config = {
        "chapAuthDiscovery" = mkOverride 1002 null;
        "chapAuthSession" = mkOverride 1002 null;
        "fsType" = mkOverride 1002 null;
        "initiatorName" = mkOverride 1002 null;
        "iscsiInterface" = mkOverride 1002 null;
        "portals" = mkOverride 1002 null;
        "readOnly" = mkOverride 1002 null;
        "secretRef" = mkOverride 1002 null;
      };

    };
    "seaweed.seaweedfs.com.v1.SeaweedSpecFilerVolumesIscsiSecretRef" = {

      options = {
        "name" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
      };

      config = {
        "name" = mkOverride 1002 null;
      };

    };
    "seaweed.seaweedfs.com.v1.SeaweedSpecFilerVolumesNfs" = {

      options = {
        "path" = mkOption {
          description = "";
          type = types.str;
        };
        "readOnly" = mkOption {
          description = "";
          type = types.nullOr types.bool;
        };
        "server" = mkOption {
          description = "";
          type = types.str;
        };
      };

      config = {
        "readOnly" = mkOverride 1002 null;
      };

    };
    "seaweed.seaweedfs.com.v1.SeaweedSpecFilerVolumesPersistentVolumeClaim" = {

      options = {
        "claimName" = mkOption {
          description = "";
          type = types.str;
        };
        "readOnly" = mkOption {
          description = "";
          type = types.nullOr types.bool;
        };
      };

      config = {
        "readOnly" = mkOverride 1002 null;
      };

    };
    "seaweed.seaweedfs.com.v1.SeaweedSpecFilerVolumesPhotonPersistentDisk" = {

      options = {
        "fsType" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "pdID" = mkOption {
          description = "";
          type = types.str;
        };
      };

      config = {
        "fsType" = mkOverride 1002 null;
      };

    };
    "seaweed.seaweedfs.com.v1.SeaweedSpecFilerVolumesPortworxVolume" = {

      options = {
        "fsType" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "readOnly" = mkOption {
          description = "";
          type = types.nullOr types.bool;
        };
        "volumeID" = mkOption {
          description = "";
          type = types.str;
        };
      };

      config = {
        "fsType" = mkOverride 1002 null;
        "readOnly" = mkOverride 1002 null;
      };

    };
    "seaweed.seaweedfs.com.v1.SeaweedSpecFilerVolumesProjected" = {

      options = {
        "defaultMode" = mkOption {
          description = "";
          type = types.nullOr types.int;
        };
        "sources" = mkOption {
          description = "";
          type = types.nullOr (
            types.listOf (submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecFilerVolumesProjectedSources")
          );
        };
      };

      config = {
        "defaultMode" = mkOverride 1002 null;
        "sources" = mkOverride 1002 null;
      };

    };
    "seaweed.seaweedfs.com.v1.SeaweedSpecFilerVolumesProjectedSources" = {

      options = {
        "clusterTrustBundle" = mkOption {
          description = "";
          type = types.nullOr (
            submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecFilerVolumesProjectedSourcesClusterTrustBundle"
          );
        };
        "configMap" = mkOption {
          description = "";
          type = types.nullOr (
            submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecFilerVolumesProjectedSourcesConfigMap"
          );
        };
        "downwardAPI" = mkOption {
          description = "";
          type = types.nullOr (
            submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecFilerVolumesProjectedSourcesDownwardAPI"
          );
        };
        "podCertificate" = mkOption {
          description = "";
          type = types.nullOr (
            submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecFilerVolumesProjectedSourcesPodCertificate"
          );
        };
        "secret" = mkOption {
          description = "";
          type = types.nullOr (
            submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecFilerVolumesProjectedSourcesSecret"
          );
        };
        "serviceAccountToken" = mkOption {
          description = "";
          type = types.nullOr (
            submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecFilerVolumesProjectedSourcesServiceAccountToken"
          );
        };
      };

      config = {
        "clusterTrustBundle" = mkOverride 1002 null;
        "configMap" = mkOverride 1002 null;
        "downwardAPI" = mkOverride 1002 null;
        "podCertificate" = mkOverride 1002 null;
        "secret" = mkOverride 1002 null;
        "serviceAccountToken" = mkOverride 1002 null;
      };

    };
    "seaweed.seaweedfs.com.v1.SeaweedSpecFilerVolumesProjectedSourcesClusterTrustBundle" = {

      options = {
        "labelSelector" = mkOption {
          description = "";
          type = types.nullOr (
            submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecFilerVolumesProjectedSourcesClusterTrustBundleLabelSelector"
          );
        };
        "name" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "optional" = mkOption {
          description = "";
          type = types.nullOr types.bool;
        };
        "path" = mkOption {
          description = "";
          type = types.str;
        };
        "signerName" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
      };

      config = {
        "labelSelector" = mkOverride 1002 null;
        "name" = mkOverride 1002 null;
        "optional" = mkOverride 1002 null;
        "signerName" = mkOverride 1002 null;
      };

    };
    "seaweed.seaweedfs.com.v1.SeaweedSpecFilerVolumesProjectedSourcesClusterTrustBundleLabelSelector" =
      {

        options = {
          "matchExpressions" = mkOption {
            description = "";
            type = types.nullOr (
              types.listOf (
                submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecFilerVolumesProjectedSourcesClusterTrustBundleLabelSelectorMatchExpressions"
              )
            );
          };
          "matchLabels" = mkOption {
            description = "";
            type = types.nullOr (types.attrsOf types.str);
          };
        };

        config = {
          "matchExpressions" = mkOverride 1002 null;
          "matchLabels" = mkOverride 1002 null;
        };

      };
    "seaweed.seaweedfs.com.v1.SeaweedSpecFilerVolumesProjectedSourcesClusterTrustBundleLabelSelectorMatchExpressions" =
      {

        options = {
          "key" = mkOption {
            description = "";
            type = types.str;
          };
          "operator" = mkOption {
            description = "";
            type = types.str;
          };
          "values" = mkOption {
            description = "";
            type = types.nullOr (types.listOf types.str);
          };
        };

        config = {
          "values" = mkOverride 1002 null;
        };

      };
    "seaweed.seaweedfs.com.v1.SeaweedSpecFilerVolumesProjectedSourcesConfigMap" = {

      options = {
        "items" = mkOption {
          description = "";
          type = types.nullOr (
            types.listOf (
              submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecFilerVolumesProjectedSourcesConfigMapItems"
            )
          );
        };
        "name" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "optional" = mkOption {
          description = "";
          type = types.nullOr types.bool;
        };
      };

      config = {
        "items" = mkOverride 1002 null;
        "name" = mkOverride 1002 null;
        "optional" = mkOverride 1002 null;
      };

    };
    "seaweed.seaweedfs.com.v1.SeaweedSpecFilerVolumesProjectedSourcesConfigMapItems" = {

      options = {
        "key" = mkOption {
          description = "";
          type = types.str;
        };
        "mode" = mkOption {
          description = "";
          type = types.nullOr types.int;
        };
        "path" = mkOption {
          description = "";
          type = types.str;
        };
      };

      config = {
        "mode" = mkOverride 1002 null;
      };

    };
    "seaweed.seaweedfs.com.v1.SeaweedSpecFilerVolumesProjectedSourcesDownwardAPI" = {

      options = {
        "items" = mkOption {
          description = "";
          type = types.nullOr (
            types.listOf (
              submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecFilerVolumesProjectedSourcesDownwardAPIItems"
            )
          );
        };
      };

      config = {
        "items" = mkOverride 1002 null;
      };

    };
    "seaweed.seaweedfs.com.v1.SeaweedSpecFilerVolumesProjectedSourcesDownwardAPIItems" = {

      options = {
        "fieldRef" = mkOption {
          description = "";
          type = types.nullOr (
            submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecFilerVolumesProjectedSourcesDownwardAPIItemsFieldRef"
          );
        };
        "mode" = mkOption {
          description = "";
          type = types.nullOr types.int;
        };
        "path" = mkOption {
          description = "";
          type = types.str;
        };
        "resourceFieldRef" = mkOption {
          description = "";
          type = types.nullOr (
            submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecFilerVolumesProjectedSourcesDownwardAPIItemsResourceFieldRef"
          );
        };
      };

      config = {
        "fieldRef" = mkOverride 1002 null;
        "mode" = mkOverride 1002 null;
        "resourceFieldRef" = mkOverride 1002 null;
      };

    };
    "seaweed.seaweedfs.com.v1.SeaweedSpecFilerVolumesProjectedSourcesDownwardAPIItemsFieldRef" = {

      options = {
        "apiVersion" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "fieldPath" = mkOption {
          description = "";
          type = types.str;
        };
      };

      config = {
        "apiVersion" = mkOverride 1002 null;
      };

    };
    "seaweed.seaweedfs.com.v1.SeaweedSpecFilerVolumesProjectedSourcesDownwardAPIItemsResourceFieldRef" =
      {

        options = {
          "containerName" = mkOption {
            description = "";
            type = types.nullOr types.str;
          };
          "divisor" = mkOption {
            description = "";
            type = types.nullOr (types.either types.int types.str);
          };
          "resource" = mkOption {
            description = "";
            type = types.str;
          };
        };

        config = {
          "containerName" = mkOverride 1002 null;
          "divisor" = mkOverride 1002 null;
        };

      };
    "seaweed.seaweedfs.com.v1.SeaweedSpecFilerVolumesProjectedSourcesPodCertificate" = {

      options = {
        "certificateChainPath" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "credentialBundlePath" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "keyPath" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "keyType" = mkOption {
          description = "";
          type = types.str;
        };
        "maxExpirationSeconds" = mkOption {
          description = "";
          type = types.nullOr types.int;
        };
        "signerName" = mkOption {
          description = "";
          type = types.str;
        };
        "userAnnotations" = mkOption {
          description = "";
          type = types.nullOr (types.attrsOf types.str);
        };
      };

      config = {
        "certificateChainPath" = mkOverride 1002 null;
        "credentialBundlePath" = mkOverride 1002 null;
        "keyPath" = mkOverride 1002 null;
        "maxExpirationSeconds" = mkOverride 1002 null;
        "userAnnotations" = mkOverride 1002 null;
      };

    };
    "seaweed.seaweedfs.com.v1.SeaweedSpecFilerVolumesProjectedSourcesSecret" = {

      options = {
        "items" = mkOption {
          description = "";
          type = types.nullOr (
            types.listOf (
              submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecFilerVolumesProjectedSourcesSecretItems"
            )
          );
        };
        "name" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "optional" = mkOption {
          description = "";
          type = types.nullOr types.bool;
        };
      };

      config = {
        "items" = mkOverride 1002 null;
        "name" = mkOverride 1002 null;
        "optional" = mkOverride 1002 null;
      };

    };
    "seaweed.seaweedfs.com.v1.SeaweedSpecFilerVolumesProjectedSourcesSecretItems" = {

      options = {
        "key" = mkOption {
          description = "";
          type = types.str;
        };
        "mode" = mkOption {
          description = "";
          type = types.nullOr types.int;
        };
        "path" = mkOption {
          description = "";
          type = types.str;
        };
      };

      config = {
        "mode" = mkOverride 1002 null;
      };

    };
    "seaweed.seaweedfs.com.v1.SeaweedSpecFilerVolumesProjectedSourcesServiceAccountToken" = {

      options = {
        "audience" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "expirationSeconds" = mkOption {
          description = "";
          type = types.nullOr types.int;
        };
        "path" = mkOption {
          description = "";
          type = types.str;
        };
      };

      config = {
        "audience" = mkOverride 1002 null;
        "expirationSeconds" = mkOverride 1002 null;
      };

    };
    "seaweed.seaweedfs.com.v1.SeaweedSpecFilerVolumesQuobyte" = {

      options = {
        "group" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "readOnly" = mkOption {
          description = "";
          type = types.nullOr types.bool;
        };
        "registry" = mkOption {
          description = "";
          type = types.str;
        };
        "tenant" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "user" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "volume" = mkOption {
          description = "";
          type = types.str;
        };
      };

      config = {
        "group" = mkOverride 1002 null;
        "readOnly" = mkOverride 1002 null;
        "tenant" = mkOverride 1002 null;
        "user" = mkOverride 1002 null;
      };

    };
    "seaweed.seaweedfs.com.v1.SeaweedSpecFilerVolumesRbd" = {

      options = {
        "fsType" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "image" = mkOption {
          description = "";
          type = types.str;
        };
        "keyring" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "monitors" = mkOption {
          description = "";
          type = types.listOf types.str;
        };
        "pool" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "readOnly" = mkOption {
          description = "";
          type = types.nullOr types.bool;
        };
        "secretRef" = mkOption {
          description = "";
          type = types.nullOr (submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecFilerVolumesRbdSecretRef");
        };
        "user" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
      };

      config = {
        "fsType" = mkOverride 1002 null;
        "keyring" = mkOverride 1002 null;
        "pool" = mkOverride 1002 null;
        "readOnly" = mkOverride 1002 null;
        "secretRef" = mkOverride 1002 null;
        "user" = mkOverride 1002 null;
      };

    };
    "seaweed.seaweedfs.com.v1.SeaweedSpecFilerVolumesRbdSecretRef" = {

      options = {
        "name" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
      };

      config = {
        "name" = mkOverride 1002 null;
      };

    };
    "seaweed.seaweedfs.com.v1.SeaweedSpecFilerVolumesScaleIO" = {

      options = {
        "fsType" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "gateway" = mkOption {
          description = "";
          type = types.str;
        };
        "protectionDomain" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "readOnly" = mkOption {
          description = "";
          type = types.nullOr types.bool;
        };
        "secretRef" = mkOption {
          description = "";
          type = submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecFilerVolumesScaleIOSecretRef";
        };
        "sslEnabled" = mkOption {
          description = "";
          type = types.nullOr types.bool;
        };
        "storageMode" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "storagePool" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "system" = mkOption {
          description = "";
          type = types.str;
        };
        "volumeName" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
      };

      config = {
        "fsType" = mkOverride 1002 null;
        "protectionDomain" = mkOverride 1002 null;
        "readOnly" = mkOverride 1002 null;
        "sslEnabled" = mkOverride 1002 null;
        "storageMode" = mkOverride 1002 null;
        "storagePool" = mkOverride 1002 null;
        "volumeName" = mkOverride 1002 null;
      };

    };
    "seaweed.seaweedfs.com.v1.SeaweedSpecFilerVolumesScaleIOSecretRef" = {

      options = {
        "name" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
      };

      config = {
        "name" = mkOverride 1002 null;
      };

    };
    "seaweed.seaweedfs.com.v1.SeaweedSpecFilerVolumesSecret" = {

      options = {
        "defaultMode" = mkOption {
          description = "";
          type = types.nullOr types.int;
        };
        "items" = mkOption {
          description = "";
          type = types.nullOr (
            types.listOf (submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecFilerVolumesSecretItems")
          );
        };
        "optional" = mkOption {
          description = "";
          type = types.nullOr types.bool;
        };
        "secretName" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
      };

      config = {
        "defaultMode" = mkOverride 1002 null;
        "items" = mkOverride 1002 null;
        "optional" = mkOverride 1002 null;
        "secretName" = mkOverride 1002 null;
      };

    };
    "seaweed.seaweedfs.com.v1.SeaweedSpecFilerVolumesSecretItems" = {

      options = {
        "key" = mkOption {
          description = "";
          type = types.str;
        };
        "mode" = mkOption {
          description = "";
          type = types.nullOr types.int;
        };
        "path" = mkOption {
          description = "";
          type = types.str;
        };
      };

      config = {
        "mode" = mkOverride 1002 null;
      };

    };
    "seaweed.seaweedfs.com.v1.SeaweedSpecFilerVolumesStorageos" = {

      options = {
        "fsType" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "readOnly" = mkOption {
          description = "";
          type = types.nullOr types.bool;
        };
        "secretRef" = mkOption {
          description = "";
          type = types.nullOr (
            submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecFilerVolumesStorageosSecretRef"
          );
        };
        "volumeName" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "volumeNamespace" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
      };

      config = {
        "fsType" = mkOverride 1002 null;
        "readOnly" = mkOverride 1002 null;
        "secretRef" = mkOverride 1002 null;
        "volumeName" = mkOverride 1002 null;
        "volumeNamespace" = mkOverride 1002 null;
      };

    };
    "seaweed.seaweedfs.com.v1.SeaweedSpecFilerVolumesStorageosSecretRef" = {

      options = {
        "name" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
      };

      config = {
        "name" = mkOverride 1002 null;
      };

    };
    "seaweed.seaweedfs.com.v1.SeaweedSpecFilerVolumesVsphereVolume" = {

      options = {
        "fsType" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "storagePolicyID" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "storagePolicyName" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "volumePath" = mkOption {
          description = "";
          type = types.str;
        };
      };

      config = {
        "fsType" = mkOverride 1002 null;
        "storagePolicyID" = mkOverride 1002 null;
        "storagePolicyName" = mkOverride 1002 null;
      };

    };
    "seaweed.seaweedfs.com.v1.SeaweedSpecImagePullSecrets" = {

      options = {
        "name" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
      };

      config = {
        "name" = mkOverride 1002 null;
      };

    };
    "seaweed.seaweedfs.com.v1.SeaweedSpecMaster" = {

      options = {
        "affinity" = mkOption {
          description = "";
          type = types.nullOr (submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecMasterAffinity");
        };
        "annotations" = mkOption {
          description = "";
          type = types.nullOr (types.attrsOf types.str);
        };
        "claims" = mkOption {
          description = "";
          type = types.nullOr (
            coerceAttrsOfSubmodulesToListByKey "seaweed.seaweedfs.com.v1.SeaweedSpecMasterClaims" "name" [
              "name"
            ]
          );
          apply = attrsToList;
        };
        "concurrentStart" = mkOption {
          description = "";
          type = types.nullOr types.bool;
        };
        "config" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "configSecret" = mkOption {
          description = "";
          type = types.nullOr (submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecMasterConfigSecret");
        };
        "containerSecurityContext" = mkOption {
          description = "";
          type = types.nullOr (
            submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecMasterContainerSecurityContext"
          );
        };
        "defaultReplication" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "env" = mkOption {
          description = "";
          type = types.nullOr (
            coerceAttrsOfSubmodulesToListByKey "seaweed.seaweedfs.com.v1.SeaweedSpecMasterEnv" "name" [ ]
          );
          apply = attrsToList;
        };
        "extraArgs" = mkOption {
          description = "";
          type = types.nullOr (types.listOf types.str);
        };
        "garbageThreshold" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "hostNetwork" = mkOption {
          description = "";
          type = types.nullOr types.bool;
        };
        "imagePullPolicy" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "imagePullSecrets" = mkOption {
          description = "";
          type = types.nullOr (
            coerceAttrsOfSubmodulesToListByKey "seaweed.seaweedfs.com.v1.SeaweedSpecMasterImagePullSecrets"
              "name"
              [ ]
          );
          apply = attrsToList;
        };
        "ingress" = mkOption {
          description = "";
          type = types.nullOr (submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecMasterIngress");
        };
        "initContainers" = mkOption {
          description = "";
          type = types.nullOr types.unspecified;
        };
        "labels" = mkOption {
          description = "";
          type = types.nullOr (types.attrsOf types.str);
        };
        "limits" = mkOption {
          description = "";
          type = types.nullOr (types.attrsOf (types.either types.int types.str));
        };
        "livenessProbe" = mkOption {
          description = "";
          type = types.nullOr (submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecMasterLivenessProbe");
        };
        "loggingArgs" = mkOption {
          description = "";
          type = types.nullOr (types.listOf types.str);
        };
        "metricsPort" = mkOption {
          description = "";
          type = types.nullOr types.int;
        };
        "nodeSelector" = mkOption {
          description = "";
          type = types.nullOr (types.attrsOf types.str);
        };
        "podSecurityContext" = mkOption {
          description = "";
          type = types.nullOr (submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecMasterPodSecurityContext");
        };
        "priorityClassName" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "pulseSeconds" = mkOption {
          description = "";
          type = types.nullOr types.int;
        };
        "readinessProbe" = mkOption {
          description = "";
          type = types.nullOr (submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecMasterReadinessProbe");
        };
        "replicas" = mkOption {
          description = "";
          type = types.int;
        };
        "requests" = mkOption {
          description = "";
          type = types.nullOr (types.attrsOf (types.either types.int types.str));
        };
        "schedulerName" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "service" = mkOption {
          description = "";
          type = types.nullOr (submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecMasterService");
        };
        "serviceAccountName" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "sidecars" = mkOption {
          description = "";
          type = types.nullOr types.unspecified;
        };
        "statefulSetUpdateStrategy" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "terminationGracePeriodSeconds" = mkOption {
          description = "";
          type = types.nullOr types.int;
        };
        "tolerations" = mkOption {
          description = "";
          type = types.nullOr (
            types.listOf (submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecMasterTolerations")
          );
        };
        "version" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "volumeMounts" = mkOption {
          description = "";
          type = types.nullOr (
            coerceAttrsOfSubmodulesToListByKey "seaweed.seaweedfs.com.v1.SeaweedSpecMasterVolumeMounts" "name"
              [ ]
          );
          apply = attrsToList;
        };
        "volumePreallocate" = mkOption {
          description = "";
          type = types.nullOr types.bool;
        };
        "volumeSizeLimitMB" = mkOption {
          description = "";
          type = types.nullOr types.int;
        };
        "volumes" = mkOption {
          description = "";
          type = types.nullOr (
            coerceAttrsOfSubmodulesToListByKey "seaweed.seaweedfs.com.v1.SeaweedSpecMasterVolumes" "name" [ ]
          );
          apply = attrsToList;
        };
      };

      config = {
        "affinity" = mkOverride 1002 null;
        "annotations" = mkOverride 1002 null;
        "claims" = mkOverride 1002 null;
        "concurrentStart" = mkOverride 1002 null;
        "config" = mkOverride 1002 null;
        "configSecret" = mkOverride 1002 null;
        "containerSecurityContext" = mkOverride 1002 null;
        "defaultReplication" = mkOverride 1002 null;
        "env" = mkOverride 1002 null;
        "extraArgs" = mkOverride 1002 null;
        "garbageThreshold" = mkOverride 1002 null;
        "hostNetwork" = mkOverride 1002 null;
        "imagePullPolicy" = mkOverride 1002 null;
        "imagePullSecrets" = mkOverride 1002 null;
        "ingress" = mkOverride 1002 null;
        "initContainers" = mkOverride 1002 null;
        "labels" = mkOverride 1002 null;
        "limits" = mkOverride 1002 null;
        "livenessProbe" = mkOverride 1002 null;
        "loggingArgs" = mkOverride 1002 null;
        "metricsPort" = mkOverride 1002 null;
        "nodeSelector" = mkOverride 1002 null;
        "podSecurityContext" = mkOverride 1002 null;
        "priorityClassName" = mkOverride 1002 null;
        "pulseSeconds" = mkOverride 1002 null;
        "readinessProbe" = mkOverride 1002 null;
        "requests" = mkOverride 1002 null;
        "schedulerName" = mkOverride 1002 null;
        "service" = mkOverride 1002 null;
        "serviceAccountName" = mkOverride 1002 null;
        "sidecars" = mkOverride 1002 null;
        "statefulSetUpdateStrategy" = mkOverride 1002 null;
        "terminationGracePeriodSeconds" = mkOverride 1002 null;
        "tolerations" = mkOverride 1002 null;
        "version" = mkOverride 1002 null;
        "volumeMounts" = mkOverride 1002 null;
        "volumePreallocate" = mkOverride 1002 null;
        "volumeSizeLimitMB" = mkOverride 1002 null;
        "volumes" = mkOverride 1002 null;
      };

    };
    "seaweed.seaweedfs.com.v1.SeaweedSpecMasterAffinity" = {

      options = {
        "nodeAffinity" = mkOption {
          description = "";
          type = types.nullOr (submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecMasterAffinityNodeAffinity");
        };
        "podAffinity" = mkOption {
          description = "";
          type = types.nullOr (submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecMasterAffinityPodAffinity");
        };
        "podAntiAffinity" = mkOption {
          description = "";
          type = types.nullOr (
            submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecMasterAffinityPodAntiAffinity"
          );
        };
      };

      config = {
        "nodeAffinity" = mkOverride 1002 null;
        "podAffinity" = mkOverride 1002 null;
        "podAntiAffinity" = mkOverride 1002 null;
      };

    };
    "seaweed.seaweedfs.com.v1.SeaweedSpecMasterAffinityNodeAffinity" = {

      options = {
        "preferredDuringSchedulingIgnoredDuringExecution" = mkOption {
          description = "";
          type = types.nullOr (
            types.listOf (
              submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecMasterAffinityNodeAffinityPreferredDuringSchedulingIgnoredDuringExecution"
            )
          );
        };
        "requiredDuringSchedulingIgnoredDuringExecution" = mkOption {
          description = "";
          type = types.nullOr (
            submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecMasterAffinityNodeAffinityRequiredDuringSchedulingIgnoredDuringExecution"
          );
        };
      };

      config = {
        "preferredDuringSchedulingIgnoredDuringExecution" = mkOverride 1002 null;
        "requiredDuringSchedulingIgnoredDuringExecution" = mkOverride 1002 null;
      };

    };
    "seaweed.seaweedfs.com.v1.SeaweedSpecMasterAffinityNodeAffinityPreferredDuringSchedulingIgnoredDuringExecution" =
      {

        options = {
          "preference" = mkOption {
            description = "";
            type = submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecMasterAffinityNodeAffinityPreferredDuringSchedulingIgnoredDuringExecutionPreference";
          };
          "weight" = mkOption {
            description = "";
            type = types.int;
          };
        };

        config = { };

      };
    "seaweed.seaweedfs.com.v1.SeaweedSpecMasterAffinityNodeAffinityPreferredDuringSchedulingIgnoredDuringExecutionPreference" =
      {

        options = {
          "matchExpressions" = mkOption {
            description = "";
            type = types.nullOr (
              types.listOf (
                submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecMasterAffinityNodeAffinityPreferredDuringSchedulingIgnoredDuringExecutionPreferenceMatchExpressions"
              )
            );
          };
          "matchFields" = mkOption {
            description = "";
            type = types.nullOr (
              types.listOf (
                submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecMasterAffinityNodeAffinityPreferredDuringSchedulingIgnoredDuringExecutionPreferenceMatchFields"
              )
            );
          };
        };

        config = {
          "matchExpressions" = mkOverride 1002 null;
          "matchFields" = mkOverride 1002 null;
        };

      };
    "seaweed.seaweedfs.com.v1.SeaweedSpecMasterAffinityNodeAffinityPreferredDuringSchedulingIgnoredDuringExecutionPreferenceMatchExpressions" =
      {

        options = {
          "key" = mkOption {
            description = "";
            type = types.str;
          };
          "operator" = mkOption {
            description = "";
            type = types.str;
          };
          "values" = mkOption {
            description = "";
            type = types.nullOr (types.listOf types.str);
          };
        };

        config = {
          "values" = mkOverride 1002 null;
        };

      };
    "seaweed.seaweedfs.com.v1.SeaweedSpecMasterAffinityNodeAffinityPreferredDuringSchedulingIgnoredDuringExecutionPreferenceMatchFields" =
      {

        options = {
          "key" = mkOption {
            description = "";
            type = types.str;
          };
          "operator" = mkOption {
            description = "";
            type = types.str;
          };
          "values" = mkOption {
            description = "";
            type = types.nullOr (types.listOf types.str);
          };
        };

        config = {
          "values" = mkOverride 1002 null;
        };

      };
    "seaweed.seaweedfs.com.v1.SeaweedSpecMasterAffinityNodeAffinityRequiredDuringSchedulingIgnoredDuringExecution" =
      {

        options = {
          "nodeSelectorTerms" = mkOption {
            description = "";
            type = types.listOf (
              submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecMasterAffinityNodeAffinityRequiredDuringSchedulingIgnoredDuringExecutionNodeSelectorTerms"
            );
          };
        };

        config = { };

      };
    "seaweed.seaweedfs.com.v1.SeaweedSpecMasterAffinityNodeAffinityRequiredDuringSchedulingIgnoredDuringExecutionNodeSelectorTerms" =
      {

        options = {
          "matchExpressions" = mkOption {
            description = "";
            type = types.nullOr (
              types.listOf (
                submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecMasterAffinityNodeAffinityRequiredDuringSchedulingIgnoredDuringExecutionNodeSelectorTermsMatchExpressions"
              )
            );
          };
          "matchFields" = mkOption {
            description = "";
            type = types.nullOr (
              types.listOf (
                submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecMasterAffinityNodeAffinityRequiredDuringSchedulingIgnoredDuringExecutionNodeSelectorTermsMatchFields"
              )
            );
          };
        };

        config = {
          "matchExpressions" = mkOverride 1002 null;
          "matchFields" = mkOverride 1002 null;
        };

      };
    "seaweed.seaweedfs.com.v1.SeaweedSpecMasterAffinityNodeAffinityRequiredDuringSchedulingIgnoredDuringExecutionNodeSelectorTermsMatchExpressions" =
      {

        options = {
          "key" = mkOption {
            description = "";
            type = types.str;
          };
          "operator" = mkOption {
            description = "";
            type = types.str;
          };
          "values" = mkOption {
            description = "";
            type = types.nullOr (types.listOf types.str);
          };
        };

        config = {
          "values" = mkOverride 1002 null;
        };

      };
    "seaweed.seaweedfs.com.v1.SeaweedSpecMasterAffinityNodeAffinityRequiredDuringSchedulingIgnoredDuringExecutionNodeSelectorTermsMatchFields" =
      {

        options = {
          "key" = mkOption {
            description = "";
            type = types.str;
          };
          "operator" = mkOption {
            description = "";
            type = types.str;
          };
          "values" = mkOption {
            description = "";
            type = types.nullOr (types.listOf types.str);
          };
        };

        config = {
          "values" = mkOverride 1002 null;
        };

      };
    "seaweed.seaweedfs.com.v1.SeaweedSpecMasterAffinityPodAffinity" = {

      options = {
        "preferredDuringSchedulingIgnoredDuringExecution" = mkOption {
          description = "";
          type = types.nullOr (
            types.listOf (
              submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecMasterAffinityPodAffinityPreferredDuringSchedulingIgnoredDuringExecution"
            )
          );
        };
        "requiredDuringSchedulingIgnoredDuringExecution" = mkOption {
          description = "";
          type = types.nullOr (
            types.listOf (
              submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecMasterAffinityPodAffinityRequiredDuringSchedulingIgnoredDuringExecution"
            )
          );
        };
      };

      config = {
        "preferredDuringSchedulingIgnoredDuringExecution" = mkOverride 1002 null;
        "requiredDuringSchedulingIgnoredDuringExecution" = mkOverride 1002 null;
      };

    };
    "seaweed.seaweedfs.com.v1.SeaweedSpecMasterAffinityPodAffinityPreferredDuringSchedulingIgnoredDuringExecution" =
      {

        options = {
          "podAffinityTerm" = mkOption {
            description = "";
            type = submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecMasterAffinityPodAffinityPreferredDuringSchedulingIgnoredDuringExecutionPodAffinityTerm";
          };
          "weight" = mkOption {
            description = "";
            type = types.int;
          };
        };

        config = { };

      };
    "seaweed.seaweedfs.com.v1.SeaweedSpecMasterAffinityPodAffinityPreferredDuringSchedulingIgnoredDuringExecutionPodAffinityTerm" =
      {

        options = {
          "labelSelector" = mkOption {
            description = "";
            type = types.nullOr (
              submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecMasterAffinityPodAffinityPreferredDuringSchedulingIgnoredDuringExecutionPodAffinityTermLabelSelector"
            );
          };
          "matchLabelKeys" = mkOption {
            description = "";
            type = types.nullOr (types.listOf types.str);
          };
          "mismatchLabelKeys" = mkOption {
            description = "";
            type = types.nullOr (types.listOf types.str);
          };
          "namespaceSelector" = mkOption {
            description = "";
            type = types.nullOr (
              submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecMasterAffinityPodAffinityPreferredDuringSchedulingIgnoredDuringExecutionPodAffinityTermNamespaceSelector"
            );
          };
          "namespaces" = mkOption {
            description = "";
            type = types.nullOr (types.listOf types.str);
          };
          "topologyKey" = mkOption {
            description = "";
            type = types.str;
          };
        };

        config = {
          "labelSelector" = mkOverride 1002 null;
          "matchLabelKeys" = mkOverride 1002 null;
          "mismatchLabelKeys" = mkOverride 1002 null;
          "namespaceSelector" = mkOverride 1002 null;
          "namespaces" = mkOverride 1002 null;
        };

      };
    "seaweed.seaweedfs.com.v1.SeaweedSpecMasterAffinityPodAffinityPreferredDuringSchedulingIgnoredDuringExecutionPodAffinityTermLabelSelector" =
      {

        options = {
          "matchExpressions" = mkOption {
            description = "";
            type = types.nullOr (
              types.listOf (
                submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecMasterAffinityPodAffinityPreferredDuringSchedulingIgnoredDuringExecutionPodAffinityTermLabelSelectorMatchExpressions"
              )
            );
          };
          "matchLabels" = mkOption {
            description = "";
            type = types.nullOr (types.attrsOf types.str);
          };
        };

        config = {
          "matchExpressions" = mkOverride 1002 null;
          "matchLabels" = mkOverride 1002 null;
        };

      };
    "seaweed.seaweedfs.com.v1.SeaweedSpecMasterAffinityPodAffinityPreferredDuringSchedulingIgnoredDuringExecutionPodAffinityTermLabelSelectorMatchExpressions" =
      {

        options = {
          "key" = mkOption {
            description = "";
            type = types.str;
          };
          "operator" = mkOption {
            description = "";
            type = types.str;
          };
          "values" = mkOption {
            description = "";
            type = types.nullOr (types.listOf types.str);
          };
        };

        config = {
          "values" = mkOverride 1002 null;
        };

      };
    "seaweed.seaweedfs.com.v1.SeaweedSpecMasterAffinityPodAffinityPreferredDuringSchedulingIgnoredDuringExecutionPodAffinityTermNamespaceSelector" =
      {

        options = {
          "matchExpressions" = mkOption {
            description = "";
            type = types.nullOr (
              types.listOf (
                submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecMasterAffinityPodAffinityPreferredDuringSchedulingIgnoredDuringExecutionPodAffinityTermNamespaceSelectorMatchExpressions"
              )
            );
          };
          "matchLabels" = mkOption {
            description = "";
            type = types.nullOr (types.attrsOf types.str);
          };
        };

        config = {
          "matchExpressions" = mkOverride 1002 null;
          "matchLabels" = mkOverride 1002 null;
        };

      };
    "seaweed.seaweedfs.com.v1.SeaweedSpecMasterAffinityPodAffinityPreferredDuringSchedulingIgnoredDuringExecutionPodAffinityTermNamespaceSelectorMatchExpressions" =
      {

        options = {
          "key" = mkOption {
            description = "";
            type = types.str;
          };
          "operator" = mkOption {
            description = "";
            type = types.str;
          };
          "values" = mkOption {
            description = "";
            type = types.nullOr (types.listOf types.str);
          };
        };

        config = {
          "values" = mkOverride 1002 null;
        };

      };
    "seaweed.seaweedfs.com.v1.SeaweedSpecMasterAffinityPodAffinityRequiredDuringSchedulingIgnoredDuringExecution" =
      {

        options = {
          "labelSelector" = mkOption {
            description = "";
            type = types.nullOr (
              submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecMasterAffinityPodAffinityRequiredDuringSchedulingIgnoredDuringExecutionLabelSelector"
            );
          };
          "matchLabelKeys" = mkOption {
            description = "";
            type = types.nullOr (types.listOf types.str);
          };
          "mismatchLabelKeys" = mkOption {
            description = "";
            type = types.nullOr (types.listOf types.str);
          };
          "namespaceSelector" = mkOption {
            description = "";
            type = types.nullOr (
              submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecMasterAffinityPodAffinityRequiredDuringSchedulingIgnoredDuringExecutionNamespaceSelector"
            );
          };
          "namespaces" = mkOption {
            description = "";
            type = types.nullOr (types.listOf types.str);
          };
          "topologyKey" = mkOption {
            description = "";
            type = types.str;
          };
        };

        config = {
          "labelSelector" = mkOverride 1002 null;
          "matchLabelKeys" = mkOverride 1002 null;
          "mismatchLabelKeys" = mkOverride 1002 null;
          "namespaceSelector" = mkOverride 1002 null;
          "namespaces" = mkOverride 1002 null;
        };

      };
    "seaweed.seaweedfs.com.v1.SeaweedSpecMasterAffinityPodAffinityRequiredDuringSchedulingIgnoredDuringExecutionLabelSelector" =
      {

        options = {
          "matchExpressions" = mkOption {
            description = "";
            type = types.nullOr (
              types.listOf (
                submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecMasterAffinityPodAffinityRequiredDuringSchedulingIgnoredDuringExecutionLabelSelectorMatchExpressions"
              )
            );
          };
          "matchLabels" = mkOption {
            description = "";
            type = types.nullOr (types.attrsOf types.str);
          };
        };

        config = {
          "matchExpressions" = mkOverride 1002 null;
          "matchLabels" = mkOverride 1002 null;
        };

      };
    "seaweed.seaweedfs.com.v1.SeaweedSpecMasterAffinityPodAffinityRequiredDuringSchedulingIgnoredDuringExecutionLabelSelectorMatchExpressions" =
      {

        options = {
          "key" = mkOption {
            description = "";
            type = types.str;
          };
          "operator" = mkOption {
            description = "";
            type = types.str;
          };
          "values" = mkOption {
            description = "";
            type = types.nullOr (types.listOf types.str);
          };
        };

        config = {
          "values" = mkOverride 1002 null;
        };

      };
    "seaweed.seaweedfs.com.v1.SeaweedSpecMasterAffinityPodAffinityRequiredDuringSchedulingIgnoredDuringExecutionNamespaceSelector" =
      {

        options = {
          "matchExpressions" = mkOption {
            description = "";
            type = types.nullOr (
              types.listOf (
                submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecMasterAffinityPodAffinityRequiredDuringSchedulingIgnoredDuringExecutionNamespaceSelectorMatchExpressions"
              )
            );
          };
          "matchLabels" = mkOption {
            description = "";
            type = types.nullOr (types.attrsOf types.str);
          };
        };

        config = {
          "matchExpressions" = mkOverride 1002 null;
          "matchLabels" = mkOverride 1002 null;
        };

      };
    "seaweed.seaweedfs.com.v1.SeaweedSpecMasterAffinityPodAffinityRequiredDuringSchedulingIgnoredDuringExecutionNamespaceSelectorMatchExpressions" =
      {

        options = {
          "key" = mkOption {
            description = "";
            type = types.str;
          };
          "operator" = mkOption {
            description = "";
            type = types.str;
          };
          "values" = mkOption {
            description = "";
            type = types.nullOr (types.listOf types.str);
          };
        };

        config = {
          "values" = mkOverride 1002 null;
        };

      };
    "seaweed.seaweedfs.com.v1.SeaweedSpecMasterAffinityPodAntiAffinity" = {

      options = {
        "preferredDuringSchedulingIgnoredDuringExecution" = mkOption {
          description = "";
          type = types.nullOr (
            types.listOf (
              submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecMasterAffinityPodAntiAffinityPreferredDuringSchedulingIgnoredDuringExecution"
            )
          );
        };
        "requiredDuringSchedulingIgnoredDuringExecution" = mkOption {
          description = "";
          type = types.nullOr (
            types.listOf (
              submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecMasterAffinityPodAntiAffinityRequiredDuringSchedulingIgnoredDuringExecution"
            )
          );
        };
      };

      config = {
        "preferredDuringSchedulingIgnoredDuringExecution" = mkOverride 1002 null;
        "requiredDuringSchedulingIgnoredDuringExecution" = mkOverride 1002 null;
      };

    };
    "seaweed.seaweedfs.com.v1.SeaweedSpecMasterAffinityPodAntiAffinityPreferredDuringSchedulingIgnoredDuringExecution" =
      {

        options = {
          "podAffinityTerm" = mkOption {
            description = "";
            type = submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecMasterAffinityPodAntiAffinityPreferredDuringSchedulingIgnoredDuringExecutionPodAffinityTerm";
          };
          "weight" = mkOption {
            description = "";
            type = types.int;
          };
        };

        config = { };

      };
    "seaweed.seaweedfs.com.v1.SeaweedSpecMasterAffinityPodAntiAffinityPreferredDuringSchedulingIgnoredDuringExecutionPodAffinityTerm" =
      {

        options = {
          "labelSelector" = mkOption {
            description = "";
            type = types.nullOr (
              submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecMasterAffinityPodAntiAffinityPreferredDuringSchedulingIgnoredDuringExecutionPodAffinityTermLabelSelector"
            );
          };
          "matchLabelKeys" = mkOption {
            description = "";
            type = types.nullOr (types.listOf types.str);
          };
          "mismatchLabelKeys" = mkOption {
            description = "";
            type = types.nullOr (types.listOf types.str);
          };
          "namespaceSelector" = mkOption {
            description = "";
            type = types.nullOr (
              submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecMasterAffinityPodAntiAffinityPreferredDuringSchedulingIgnoredDuringExecutionPodAffinityTermNamespaceSelector"
            );
          };
          "namespaces" = mkOption {
            description = "";
            type = types.nullOr (types.listOf types.str);
          };
          "topologyKey" = mkOption {
            description = "";
            type = types.str;
          };
        };

        config = {
          "labelSelector" = mkOverride 1002 null;
          "matchLabelKeys" = mkOverride 1002 null;
          "mismatchLabelKeys" = mkOverride 1002 null;
          "namespaceSelector" = mkOverride 1002 null;
          "namespaces" = mkOverride 1002 null;
        };

      };
    "seaweed.seaweedfs.com.v1.SeaweedSpecMasterAffinityPodAntiAffinityPreferredDuringSchedulingIgnoredDuringExecutionPodAffinityTermLabelSelector" =
      {

        options = {
          "matchExpressions" = mkOption {
            description = "";
            type = types.nullOr (
              types.listOf (
                submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecMasterAffinityPodAntiAffinityPreferredDuringSchedulingIgnoredDuringExecutionPodAffinityTermLabelSelectorMatchExpressions"
              )
            );
          };
          "matchLabels" = mkOption {
            description = "";
            type = types.nullOr (types.attrsOf types.str);
          };
        };

        config = {
          "matchExpressions" = mkOverride 1002 null;
          "matchLabels" = mkOverride 1002 null;
        };

      };
    "seaweed.seaweedfs.com.v1.SeaweedSpecMasterAffinityPodAntiAffinityPreferredDuringSchedulingIgnoredDuringExecutionPodAffinityTermLabelSelectorMatchExpressions" =
      {

        options = {
          "key" = mkOption {
            description = "";
            type = types.str;
          };
          "operator" = mkOption {
            description = "";
            type = types.str;
          };
          "values" = mkOption {
            description = "";
            type = types.nullOr (types.listOf types.str);
          };
        };

        config = {
          "values" = mkOverride 1002 null;
        };

      };
    "seaweed.seaweedfs.com.v1.SeaweedSpecMasterAffinityPodAntiAffinityPreferredDuringSchedulingIgnoredDuringExecutionPodAffinityTermNamespaceSelector" =
      {

        options = {
          "matchExpressions" = mkOption {
            description = "";
            type = types.nullOr (
              types.listOf (
                submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecMasterAffinityPodAntiAffinityPreferredDuringSchedulingIgnoredDuringExecutionPodAffinityTermNamespaceSelectorMatchExpressions"
              )
            );
          };
          "matchLabels" = mkOption {
            description = "";
            type = types.nullOr (types.attrsOf types.str);
          };
        };

        config = {
          "matchExpressions" = mkOverride 1002 null;
          "matchLabels" = mkOverride 1002 null;
        };

      };
    "seaweed.seaweedfs.com.v1.SeaweedSpecMasterAffinityPodAntiAffinityPreferredDuringSchedulingIgnoredDuringExecutionPodAffinityTermNamespaceSelectorMatchExpressions" =
      {

        options = {
          "key" = mkOption {
            description = "";
            type = types.str;
          };
          "operator" = mkOption {
            description = "";
            type = types.str;
          };
          "values" = mkOption {
            description = "";
            type = types.nullOr (types.listOf types.str);
          };
        };

        config = {
          "values" = mkOverride 1002 null;
        };

      };
    "seaweed.seaweedfs.com.v1.SeaweedSpecMasterAffinityPodAntiAffinityRequiredDuringSchedulingIgnoredDuringExecution" =
      {

        options = {
          "labelSelector" = mkOption {
            description = "";
            type = types.nullOr (
              submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecMasterAffinityPodAntiAffinityRequiredDuringSchedulingIgnoredDuringExecutionLabelSelector"
            );
          };
          "matchLabelKeys" = mkOption {
            description = "";
            type = types.nullOr (types.listOf types.str);
          };
          "mismatchLabelKeys" = mkOption {
            description = "";
            type = types.nullOr (types.listOf types.str);
          };
          "namespaceSelector" = mkOption {
            description = "";
            type = types.nullOr (
              submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecMasterAffinityPodAntiAffinityRequiredDuringSchedulingIgnoredDuringExecutionNamespaceSelector"
            );
          };
          "namespaces" = mkOption {
            description = "";
            type = types.nullOr (types.listOf types.str);
          };
          "topologyKey" = mkOption {
            description = "";
            type = types.str;
          };
        };

        config = {
          "labelSelector" = mkOverride 1002 null;
          "matchLabelKeys" = mkOverride 1002 null;
          "mismatchLabelKeys" = mkOverride 1002 null;
          "namespaceSelector" = mkOverride 1002 null;
          "namespaces" = mkOverride 1002 null;
        };

      };
    "seaweed.seaweedfs.com.v1.SeaweedSpecMasterAffinityPodAntiAffinityRequiredDuringSchedulingIgnoredDuringExecutionLabelSelector" =
      {

        options = {
          "matchExpressions" = mkOption {
            description = "";
            type = types.nullOr (
              types.listOf (
                submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecMasterAffinityPodAntiAffinityRequiredDuringSchedulingIgnoredDuringExecutionLabelSelectorMatchExpressions"
              )
            );
          };
          "matchLabels" = mkOption {
            description = "";
            type = types.nullOr (types.attrsOf types.str);
          };
        };

        config = {
          "matchExpressions" = mkOverride 1002 null;
          "matchLabels" = mkOverride 1002 null;
        };

      };
    "seaweed.seaweedfs.com.v1.SeaweedSpecMasterAffinityPodAntiAffinityRequiredDuringSchedulingIgnoredDuringExecutionLabelSelectorMatchExpressions" =
      {

        options = {
          "key" = mkOption {
            description = "";
            type = types.str;
          };
          "operator" = mkOption {
            description = "";
            type = types.str;
          };
          "values" = mkOption {
            description = "";
            type = types.nullOr (types.listOf types.str);
          };
        };

        config = {
          "values" = mkOverride 1002 null;
        };

      };
    "seaweed.seaweedfs.com.v1.SeaweedSpecMasterAffinityPodAntiAffinityRequiredDuringSchedulingIgnoredDuringExecutionNamespaceSelector" =
      {

        options = {
          "matchExpressions" = mkOption {
            description = "";
            type = types.nullOr (
              types.listOf (
                submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecMasterAffinityPodAntiAffinityRequiredDuringSchedulingIgnoredDuringExecutionNamespaceSelectorMatchExpressions"
              )
            );
          };
          "matchLabels" = mkOption {
            description = "";
            type = types.nullOr (types.attrsOf types.str);
          };
        };

        config = {
          "matchExpressions" = mkOverride 1002 null;
          "matchLabels" = mkOverride 1002 null;
        };

      };
    "seaweed.seaweedfs.com.v1.SeaweedSpecMasterAffinityPodAntiAffinityRequiredDuringSchedulingIgnoredDuringExecutionNamespaceSelectorMatchExpressions" =
      {

        options = {
          "key" = mkOption {
            description = "";
            type = types.str;
          };
          "operator" = mkOption {
            description = "";
            type = types.str;
          };
          "values" = mkOption {
            description = "";
            type = types.nullOr (types.listOf types.str);
          };
        };

        config = {
          "values" = mkOverride 1002 null;
        };

      };
    "seaweed.seaweedfs.com.v1.SeaweedSpecMasterClaims" = {

      options = {
        "name" = mkOption {
          description = "";
          type = types.str;
        };
        "request" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
      };

      config = {
        "request" = mkOverride 1002 null;
      };

    };
    "seaweed.seaweedfs.com.v1.SeaweedSpecMasterConfigSecret" = {

      options = {
        "key" = mkOption {
          description = "";
          type = types.str;
        };
        "name" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "optional" = mkOption {
          description = "";
          type = types.nullOr types.bool;
        };
      };

      config = {
        "name" = mkOverride 1002 null;
        "optional" = mkOverride 1002 null;
      };

    };
    "seaweed.seaweedfs.com.v1.SeaweedSpecMasterContainerSecurityContext" = {

      options = {
        "allowPrivilegeEscalation" = mkOption {
          description = "";
          type = types.nullOr types.bool;
        };
        "appArmorProfile" = mkOption {
          description = "";
          type = types.nullOr (
            submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecMasterContainerSecurityContextAppArmorProfile"
          );
        };
        "capabilities" = mkOption {
          description = "";
          type = types.nullOr (
            submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecMasterContainerSecurityContextCapabilities"
          );
        };
        "privileged" = mkOption {
          description = "";
          type = types.nullOr types.bool;
        };
        "procMount" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "readOnlyRootFilesystem" = mkOption {
          description = "";
          type = types.nullOr types.bool;
        };
        "runAsGroup" = mkOption {
          description = "";
          type = types.nullOr types.int;
        };
        "runAsNonRoot" = mkOption {
          description = "";
          type = types.nullOr types.bool;
        };
        "runAsUser" = mkOption {
          description = "";
          type = types.nullOr types.int;
        };
        "seLinuxOptions" = mkOption {
          description = "";
          type = types.nullOr (
            submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecMasterContainerSecurityContextSeLinuxOptions"
          );
        };
        "seccompProfile" = mkOption {
          description = "";
          type = types.nullOr (
            submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecMasterContainerSecurityContextSeccompProfile"
          );
        };
        "windowsOptions" = mkOption {
          description = "";
          type = types.nullOr (
            submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecMasterContainerSecurityContextWindowsOptions"
          );
        };
      };

      config = {
        "allowPrivilegeEscalation" = mkOverride 1002 null;
        "appArmorProfile" = mkOverride 1002 null;
        "capabilities" = mkOverride 1002 null;
        "privileged" = mkOverride 1002 null;
        "procMount" = mkOverride 1002 null;
        "readOnlyRootFilesystem" = mkOverride 1002 null;
        "runAsGroup" = mkOverride 1002 null;
        "runAsNonRoot" = mkOverride 1002 null;
        "runAsUser" = mkOverride 1002 null;
        "seLinuxOptions" = mkOverride 1002 null;
        "seccompProfile" = mkOverride 1002 null;
        "windowsOptions" = mkOverride 1002 null;
      };

    };
    "seaweed.seaweedfs.com.v1.SeaweedSpecMasterContainerSecurityContextAppArmorProfile" = {

      options = {
        "localhostProfile" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "type" = mkOption {
          description = "";
          type = types.str;
        };
      };

      config = {
        "localhostProfile" = mkOverride 1002 null;
      };

    };
    "seaweed.seaweedfs.com.v1.SeaweedSpecMasterContainerSecurityContextCapabilities" = {

      options = {
        "add" = mkOption {
          description = "";
          type = types.nullOr (types.listOf types.str);
        };
        "drop" = mkOption {
          description = "";
          type = types.nullOr (types.listOf types.str);
        };
      };

      config = {
        "add" = mkOverride 1002 null;
        "drop" = mkOverride 1002 null;
      };

    };
    "seaweed.seaweedfs.com.v1.SeaweedSpecMasterContainerSecurityContextSeLinuxOptions" = {

      options = {
        "level" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "role" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "type" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "user" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
      };

      config = {
        "level" = mkOverride 1002 null;
        "role" = mkOverride 1002 null;
        "type" = mkOverride 1002 null;
        "user" = mkOverride 1002 null;
      };

    };
    "seaweed.seaweedfs.com.v1.SeaweedSpecMasterContainerSecurityContextSeccompProfile" = {

      options = {
        "localhostProfile" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "type" = mkOption {
          description = "";
          type = types.str;
        };
      };

      config = {
        "localhostProfile" = mkOverride 1002 null;
      };

    };
    "seaweed.seaweedfs.com.v1.SeaweedSpecMasterContainerSecurityContextWindowsOptions" = {

      options = {
        "gmsaCredentialSpec" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "gmsaCredentialSpecName" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "hostProcess" = mkOption {
          description = "";
          type = types.nullOr types.bool;
        };
        "runAsUserName" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
      };

      config = {
        "gmsaCredentialSpec" = mkOverride 1002 null;
        "gmsaCredentialSpecName" = mkOverride 1002 null;
        "hostProcess" = mkOverride 1002 null;
        "runAsUserName" = mkOverride 1002 null;
      };

    };
    "seaweed.seaweedfs.com.v1.SeaweedSpecMasterEnv" = {

      options = {
        "name" = mkOption {
          description = "";
          type = types.str;
        };
        "value" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "valueFrom" = mkOption {
          description = "";
          type = types.nullOr (submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecMasterEnvValueFrom");
        };
      };

      config = {
        "value" = mkOverride 1002 null;
        "valueFrom" = mkOverride 1002 null;
      };

    };
    "seaweed.seaweedfs.com.v1.SeaweedSpecMasterEnvValueFrom" = {

      options = {
        "configMapKeyRef" = mkOption {
          description = "";
          type = types.nullOr (
            submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecMasterEnvValueFromConfigMapKeyRef"
          );
        };
        "fieldRef" = mkOption {
          description = "";
          type = types.nullOr (submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecMasterEnvValueFromFieldRef");
        };
        "fileKeyRef" = mkOption {
          description = "";
          type = types.nullOr (
            submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecMasterEnvValueFromFileKeyRef"
          );
        };
        "resourceFieldRef" = mkOption {
          description = "";
          type = types.nullOr (
            submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecMasterEnvValueFromResourceFieldRef"
          );
        };
        "secretKeyRef" = mkOption {
          description = "";
          type = types.nullOr (
            submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecMasterEnvValueFromSecretKeyRef"
          );
        };
      };

      config = {
        "configMapKeyRef" = mkOverride 1002 null;
        "fieldRef" = mkOverride 1002 null;
        "fileKeyRef" = mkOverride 1002 null;
        "resourceFieldRef" = mkOverride 1002 null;
        "secretKeyRef" = mkOverride 1002 null;
      };

    };
    "seaweed.seaweedfs.com.v1.SeaweedSpecMasterEnvValueFromConfigMapKeyRef" = {

      options = {
        "key" = mkOption {
          description = "";
          type = types.str;
        };
        "name" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "optional" = mkOption {
          description = "";
          type = types.nullOr types.bool;
        };
      };

      config = {
        "name" = mkOverride 1002 null;
        "optional" = mkOverride 1002 null;
      };

    };
    "seaweed.seaweedfs.com.v1.SeaweedSpecMasterEnvValueFromFieldRef" = {

      options = {
        "apiVersion" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "fieldPath" = mkOption {
          description = "";
          type = types.str;
        };
      };

      config = {
        "apiVersion" = mkOverride 1002 null;
      };

    };
    "seaweed.seaweedfs.com.v1.SeaweedSpecMasterEnvValueFromFileKeyRef" = {

      options = {
        "key" = mkOption {
          description = "";
          type = types.str;
        };
        "optional" = mkOption {
          description = "";
          type = types.nullOr types.bool;
        };
        "path" = mkOption {
          description = "";
          type = types.str;
        };
        "volumeName" = mkOption {
          description = "";
          type = types.str;
        };
      };

      config = {
        "optional" = mkOverride 1002 null;
      };

    };
    "seaweed.seaweedfs.com.v1.SeaweedSpecMasterEnvValueFromResourceFieldRef" = {

      options = {
        "containerName" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "divisor" = mkOption {
          description = "";
          type = types.nullOr (types.either types.int types.str);
        };
        "resource" = mkOption {
          description = "";
          type = types.str;
        };
      };

      config = {
        "containerName" = mkOverride 1002 null;
        "divisor" = mkOverride 1002 null;
      };

    };
    "seaweed.seaweedfs.com.v1.SeaweedSpecMasterEnvValueFromSecretKeyRef" = {

      options = {
        "key" = mkOption {
          description = "";
          type = types.str;
        };
        "name" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "optional" = mkOption {
          description = "";
          type = types.nullOr types.bool;
        };
      };

      config = {
        "name" = mkOverride 1002 null;
        "optional" = mkOverride 1002 null;
      };

    };
    "seaweed.seaweedfs.com.v1.SeaweedSpecMasterImagePullSecrets" = {

      options = {
        "name" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
      };

      config = {
        "name" = mkOverride 1002 null;
      };

    };
    "seaweed.seaweedfs.com.v1.SeaweedSpecMasterIngress" = {

      options = {
        "annotations" = mkOption {
          description = "";
          type = types.nullOr (types.attrsOf types.str);
        };
        "className" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "enabled" = mkOption {
          description = "";
          type = types.nullOr types.bool;
        };
        "host" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "path" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "tls" = mkOption {
          description = "";
          type = types.nullOr (
            types.listOf (submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecMasterIngressTls")
          );
        };
      };

      config = {
        "annotations" = mkOverride 1002 null;
        "className" = mkOverride 1002 null;
        "enabled" = mkOverride 1002 null;
        "host" = mkOverride 1002 null;
        "path" = mkOverride 1002 null;
        "tls" = mkOverride 1002 null;
      };

    };
    "seaweed.seaweedfs.com.v1.SeaweedSpecMasterIngressTls" = {

      options = {
        "hosts" = mkOption {
          description = "";
          type = types.nullOr (types.listOf types.str);
        };
        "secretName" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
      };

      config = {
        "hosts" = mkOverride 1002 null;
        "secretName" = mkOverride 1002 null;
      };

    };
    "seaweed.seaweedfs.com.v1.SeaweedSpecMasterLivenessProbe" = {

      options = {
        "failureThreshold" = mkOption {
          description = "";
          type = types.nullOr types.int;
        };
        "initialDelaySeconds" = mkOption {
          description = "";
          type = types.nullOr types.int;
        };
        "periodSeconds" = mkOption {
          description = "";
          type = types.nullOr types.int;
        };
        "timeoutSeconds" = mkOption {
          description = "";
          type = types.nullOr types.int;
        };
      };

      config = {
        "failureThreshold" = mkOverride 1002 null;
        "initialDelaySeconds" = mkOverride 1002 null;
        "periodSeconds" = mkOverride 1002 null;
        "timeoutSeconds" = mkOverride 1002 null;
      };

    };
    "seaweed.seaweedfs.com.v1.SeaweedSpecMasterPodSecurityContext" = {

      options = {
        "appArmorProfile" = mkOption {
          description = "";
          type = types.nullOr (
            submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecMasterPodSecurityContextAppArmorProfile"
          );
        };
        "fsGroup" = mkOption {
          description = "";
          type = types.nullOr types.int;
        };
        "fsGroupChangePolicy" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "runAsGroup" = mkOption {
          description = "";
          type = types.nullOr types.int;
        };
        "runAsNonRoot" = mkOption {
          description = "";
          type = types.nullOr types.bool;
        };
        "runAsUser" = mkOption {
          description = "";
          type = types.nullOr types.int;
        };
        "seLinuxChangePolicy" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "seLinuxOptions" = mkOption {
          description = "";
          type = types.nullOr (
            submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecMasterPodSecurityContextSeLinuxOptions"
          );
        };
        "seccompProfile" = mkOption {
          description = "";
          type = types.nullOr (
            submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecMasterPodSecurityContextSeccompProfile"
          );
        };
        "supplementalGroups" = mkOption {
          description = "";
          type = types.nullOr (types.listOf types.int);
        };
        "supplementalGroupsPolicy" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "sysctls" = mkOption {
          description = "";
          type = types.nullOr (
            coerceAttrsOfSubmodulesToListByKey
              "seaweed.seaweedfs.com.v1.SeaweedSpecMasterPodSecurityContextSysctls"
              "name"
              [ ]
          );
          apply = attrsToList;
        };
        "windowsOptions" = mkOption {
          description = "";
          type = types.nullOr (
            submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecMasterPodSecurityContextWindowsOptions"
          );
        };
      };

      config = {
        "appArmorProfile" = mkOverride 1002 null;
        "fsGroup" = mkOverride 1002 null;
        "fsGroupChangePolicy" = mkOverride 1002 null;
        "runAsGroup" = mkOverride 1002 null;
        "runAsNonRoot" = mkOverride 1002 null;
        "runAsUser" = mkOverride 1002 null;
        "seLinuxChangePolicy" = mkOverride 1002 null;
        "seLinuxOptions" = mkOverride 1002 null;
        "seccompProfile" = mkOverride 1002 null;
        "supplementalGroups" = mkOverride 1002 null;
        "supplementalGroupsPolicy" = mkOverride 1002 null;
        "sysctls" = mkOverride 1002 null;
        "windowsOptions" = mkOverride 1002 null;
      };

    };
    "seaweed.seaweedfs.com.v1.SeaweedSpecMasterPodSecurityContextAppArmorProfile" = {

      options = {
        "localhostProfile" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "type" = mkOption {
          description = "";
          type = types.str;
        };
      };

      config = {
        "localhostProfile" = mkOverride 1002 null;
      };

    };
    "seaweed.seaweedfs.com.v1.SeaweedSpecMasterPodSecurityContextSeLinuxOptions" = {

      options = {
        "level" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "role" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "type" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "user" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
      };

      config = {
        "level" = mkOverride 1002 null;
        "role" = mkOverride 1002 null;
        "type" = mkOverride 1002 null;
        "user" = mkOverride 1002 null;
      };

    };
    "seaweed.seaweedfs.com.v1.SeaweedSpecMasterPodSecurityContextSeccompProfile" = {

      options = {
        "localhostProfile" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "type" = mkOption {
          description = "";
          type = types.str;
        };
      };

      config = {
        "localhostProfile" = mkOverride 1002 null;
      };

    };
    "seaweed.seaweedfs.com.v1.SeaweedSpecMasterPodSecurityContextSysctls" = {

      options = {
        "name" = mkOption {
          description = "";
          type = types.str;
        };
        "value" = mkOption {
          description = "";
          type = types.str;
        };
      };

      config = { };

    };
    "seaweed.seaweedfs.com.v1.SeaweedSpecMasterPodSecurityContextWindowsOptions" = {

      options = {
        "gmsaCredentialSpec" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "gmsaCredentialSpecName" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "hostProcess" = mkOption {
          description = "";
          type = types.nullOr types.bool;
        };
        "runAsUserName" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
      };

      config = {
        "gmsaCredentialSpec" = mkOverride 1002 null;
        "gmsaCredentialSpecName" = mkOverride 1002 null;
        "hostProcess" = mkOverride 1002 null;
        "runAsUserName" = mkOverride 1002 null;
      };

    };
    "seaweed.seaweedfs.com.v1.SeaweedSpecMasterReadinessProbe" = {

      options = {
        "failureThreshold" = mkOption {
          description = "";
          type = types.nullOr types.int;
        };
        "initialDelaySeconds" = mkOption {
          description = "";
          type = types.nullOr types.int;
        };
        "periodSeconds" = mkOption {
          description = "";
          type = types.nullOr types.int;
        };
        "successThreshold" = mkOption {
          description = "";
          type = types.nullOr types.int;
        };
        "timeoutSeconds" = mkOption {
          description = "";
          type = types.nullOr types.int;
        };
      };

      config = {
        "failureThreshold" = mkOverride 1002 null;
        "initialDelaySeconds" = mkOverride 1002 null;
        "periodSeconds" = mkOverride 1002 null;
        "successThreshold" = mkOverride 1002 null;
        "timeoutSeconds" = mkOverride 1002 null;
      };

    };
    "seaweed.seaweedfs.com.v1.SeaweedSpecMasterService" = {

      options = {
        "annotations" = mkOption {
          description = "";
          type = types.nullOr (types.attrsOf types.str);
        };
        "clusterIP" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "loadBalancerIP" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "type" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
      };

      config = {
        "annotations" = mkOverride 1002 null;
        "clusterIP" = mkOverride 1002 null;
        "loadBalancerIP" = mkOverride 1002 null;
        "type" = mkOverride 1002 null;
      };

    };
    "seaweed.seaweedfs.com.v1.SeaweedSpecMasterTolerations" = {

      options = {
        "effect" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "key" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "operator" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "tolerationSeconds" = mkOption {
          description = "";
          type = types.nullOr types.int;
        };
        "value" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
      };

      config = {
        "effect" = mkOverride 1002 null;
        "key" = mkOverride 1002 null;
        "operator" = mkOverride 1002 null;
        "tolerationSeconds" = mkOverride 1002 null;
        "value" = mkOverride 1002 null;
      };

    };
    "seaweed.seaweedfs.com.v1.SeaweedSpecMasterVolumeMounts" = {

      options = {
        "mountPath" = mkOption {
          description = "";
          type = types.str;
        };
        "mountPropagation" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "name" = mkOption {
          description = "";
          type = types.str;
        };
        "readOnly" = mkOption {
          description = "";
          type = types.nullOr types.bool;
        };
        "recursiveReadOnly" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "subPath" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "subPathExpr" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
      };

      config = {
        "mountPropagation" = mkOverride 1002 null;
        "readOnly" = mkOverride 1002 null;
        "recursiveReadOnly" = mkOverride 1002 null;
        "subPath" = mkOverride 1002 null;
        "subPathExpr" = mkOverride 1002 null;
      };

    };
    "seaweed.seaweedfs.com.v1.SeaweedSpecMasterVolumes" = {

      options = {
        "awsElasticBlockStore" = mkOption {
          description = "";
          type = types.nullOr (
            submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecMasterVolumesAwsElasticBlockStore"
          );
        };
        "azureDisk" = mkOption {
          description = "";
          type = types.nullOr (submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecMasterVolumesAzureDisk");
        };
        "azureFile" = mkOption {
          description = "";
          type = types.nullOr (submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecMasterVolumesAzureFile");
        };
        "cephfs" = mkOption {
          description = "";
          type = types.nullOr (submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecMasterVolumesCephfs");
        };
        "cinder" = mkOption {
          description = "";
          type = types.nullOr (submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecMasterVolumesCinder");
        };
        "configMap" = mkOption {
          description = "";
          type = types.nullOr (submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecMasterVolumesConfigMap");
        };
        "csi" = mkOption {
          description = "";
          type = types.nullOr (submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecMasterVolumesCsi");
        };
        "downwardAPI" = mkOption {
          description = "";
          type = types.nullOr (submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecMasterVolumesDownwardAPI");
        };
        "emptyDir" = mkOption {
          description = "";
          type = types.nullOr (submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecMasterVolumesEmptyDir");
        };
        "ephemeral" = mkOption {
          description = "";
          type = types.nullOr (submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecMasterVolumesEphemeral");
        };
        "fc" = mkOption {
          description = "";
          type = types.nullOr (submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecMasterVolumesFc");
        };
        "flexVolume" = mkOption {
          description = "";
          type = types.nullOr (submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecMasterVolumesFlexVolume");
        };
        "flocker" = mkOption {
          description = "";
          type = types.nullOr (submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecMasterVolumesFlocker");
        };
        "gcePersistentDisk" = mkOption {
          description = "";
          type = types.nullOr (
            submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecMasterVolumesGcePersistentDisk"
          );
        };
        "gitRepo" = mkOption {
          description = "";
          type = types.nullOr (submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecMasterVolumesGitRepo");
        };
        "glusterfs" = mkOption {
          description = "";
          type = types.nullOr (submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecMasterVolumesGlusterfs");
        };
        "hostPath" = mkOption {
          description = "";
          type = types.nullOr (submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecMasterVolumesHostPath");
        };
        "image" = mkOption {
          description = "";
          type = types.nullOr (submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecMasterVolumesImage");
        };
        "iscsi" = mkOption {
          description = "";
          type = types.nullOr (submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecMasterVolumesIscsi");
        };
        "name" = mkOption {
          description = "";
          type = types.str;
        };
        "nfs" = mkOption {
          description = "";
          type = types.nullOr (submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecMasterVolumesNfs");
        };
        "persistentVolumeClaim" = mkOption {
          description = "";
          type = types.nullOr (
            submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecMasterVolumesPersistentVolumeClaim"
          );
        };
        "photonPersistentDisk" = mkOption {
          description = "";
          type = types.nullOr (
            submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecMasterVolumesPhotonPersistentDisk"
          );
        };
        "portworxVolume" = mkOption {
          description = "";
          type = types.nullOr (submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecMasterVolumesPortworxVolume");
        };
        "projected" = mkOption {
          description = "";
          type = types.nullOr (submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecMasterVolumesProjected");
        };
        "quobyte" = mkOption {
          description = "";
          type = types.nullOr (submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecMasterVolumesQuobyte");
        };
        "rbd" = mkOption {
          description = "";
          type = types.nullOr (submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecMasterVolumesRbd");
        };
        "scaleIO" = mkOption {
          description = "";
          type = types.nullOr (submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecMasterVolumesScaleIO");
        };
        "secret" = mkOption {
          description = "";
          type = types.nullOr (submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecMasterVolumesSecret");
        };
        "storageos" = mkOption {
          description = "";
          type = types.nullOr (submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecMasterVolumesStorageos");
        };
        "vsphereVolume" = mkOption {
          description = "";
          type = types.nullOr (submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecMasterVolumesVsphereVolume");
        };
      };

      config = {
        "awsElasticBlockStore" = mkOverride 1002 null;
        "azureDisk" = mkOverride 1002 null;
        "azureFile" = mkOverride 1002 null;
        "cephfs" = mkOverride 1002 null;
        "cinder" = mkOverride 1002 null;
        "configMap" = mkOverride 1002 null;
        "csi" = mkOverride 1002 null;
        "downwardAPI" = mkOverride 1002 null;
        "emptyDir" = mkOverride 1002 null;
        "ephemeral" = mkOverride 1002 null;
        "fc" = mkOverride 1002 null;
        "flexVolume" = mkOverride 1002 null;
        "flocker" = mkOverride 1002 null;
        "gcePersistentDisk" = mkOverride 1002 null;
        "gitRepo" = mkOverride 1002 null;
        "glusterfs" = mkOverride 1002 null;
        "hostPath" = mkOverride 1002 null;
        "image" = mkOverride 1002 null;
        "iscsi" = mkOverride 1002 null;
        "nfs" = mkOverride 1002 null;
        "persistentVolumeClaim" = mkOverride 1002 null;
        "photonPersistentDisk" = mkOverride 1002 null;
        "portworxVolume" = mkOverride 1002 null;
        "projected" = mkOverride 1002 null;
        "quobyte" = mkOverride 1002 null;
        "rbd" = mkOverride 1002 null;
        "scaleIO" = mkOverride 1002 null;
        "secret" = mkOverride 1002 null;
        "storageos" = mkOverride 1002 null;
        "vsphereVolume" = mkOverride 1002 null;
      };

    };
    "seaweed.seaweedfs.com.v1.SeaweedSpecMasterVolumesAwsElasticBlockStore" = {

      options = {
        "fsType" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "partition" = mkOption {
          description = "";
          type = types.nullOr types.int;
        };
        "readOnly" = mkOption {
          description = "";
          type = types.nullOr types.bool;
        };
        "volumeID" = mkOption {
          description = "";
          type = types.str;
        };
      };

      config = {
        "fsType" = mkOverride 1002 null;
        "partition" = mkOverride 1002 null;
        "readOnly" = mkOverride 1002 null;
      };

    };
    "seaweed.seaweedfs.com.v1.SeaweedSpecMasterVolumesAzureDisk" = {

      options = {
        "cachingMode" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "diskName" = mkOption {
          description = "";
          type = types.str;
        };
        "diskURI" = mkOption {
          description = "";
          type = types.str;
        };
        "fsType" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "kind" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "readOnly" = mkOption {
          description = "";
          type = types.nullOr types.bool;
        };
      };

      config = {
        "cachingMode" = mkOverride 1002 null;
        "fsType" = mkOverride 1002 null;
        "kind" = mkOverride 1002 null;
        "readOnly" = mkOverride 1002 null;
      };

    };
    "seaweed.seaweedfs.com.v1.SeaweedSpecMasterVolumesAzureFile" = {

      options = {
        "readOnly" = mkOption {
          description = "";
          type = types.nullOr types.bool;
        };
        "secretName" = mkOption {
          description = "";
          type = types.str;
        };
        "shareName" = mkOption {
          description = "";
          type = types.str;
        };
      };

      config = {
        "readOnly" = mkOverride 1002 null;
      };

    };
    "seaweed.seaweedfs.com.v1.SeaweedSpecMasterVolumesCephfs" = {

      options = {
        "monitors" = mkOption {
          description = "";
          type = types.listOf types.str;
        };
        "path" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "readOnly" = mkOption {
          description = "";
          type = types.nullOr types.bool;
        };
        "secretFile" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "secretRef" = mkOption {
          description = "";
          type = types.nullOr (
            submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecMasterVolumesCephfsSecretRef"
          );
        };
        "user" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
      };

      config = {
        "path" = mkOverride 1002 null;
        "readOnly" = mkOverride 1002 null;
        "secretFile" = mkOverride 1002 null;
        "secretRef" = mkOverride 1002 null;
        "user" = mkOverride 1002 null;
      };

    };
    "seaweed.seaweedfs.com.v1.SeaweedSpecMasterVolumesCephfsSecretRef" = {

      options = {
        "name" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
      };

      config = {
        "name" = mkOverride 1002 null;
      };

    };
    "seaweed.seaweedfs.com.v1.SeaweedSpecMasterVolumesCinder" = {

      options = {
        "fsType" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "readOnly" = mkOption {
          description = "";
          type = types.nullOr types.bool;
        };
        "secretRef" = mkOption {
          description = "";
          type = types.nullOr (
            submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecMasterVolumesCinderSecretRef"
          );
        };
        "volumeID" = mkOption {
          description = "";
          type = types.str;
        };
      };

      config = {
        "fsType" = mkOverride 1002 null;
        "readOnly" = mkOverride 1002 null;
        "secretRef" = mkOverride 1002 null;
      };

    };
    "seaweed.seaweedfs.com.v1.SeaweedSpecMasterVolumesCinderSecretRef" = {

      options = {
        "name" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
      };

      config = {
        "name" = mkOverride 1002 null;
      };

    };
    "seaweed.seaweedfs.com.v1.SeaweedSpecMasterVolumesConfigMap" = {

      options = {
        "defaultMode" = mkOption {
          description = "";
          type = types.nullOr types.int;
        };
        "items" = mkOption {
          description = "";
          type = types.nullOr (
            types.listOf (submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecMasterVolumesConfigMapItems")
          );
        };
        "name" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "optional" = mkOption {
          description = "";
          type = types.nullOr types.bool;
        };
      };

      config = {
        "defaultMode" = mkOverride 1002 null;
        "items" = mkOverride 1002 null;
        "name" = mkOverride 1002 null;
        "optional" = mkOverride 1002 null;
      };

    };
    "seaweed.seaweedfs.com.v1.SeaweedSpecMasterVolumesConfigMapItems" = {

      options = {
        "key" = mkOption {
          description = "";
          type = types.str;
        };
        "mode" = mkOption {
          description = "";
          type = types.nullOr types.int;
        };
        "path" = mkOption {
          description = "";
          type = types.str;
        };
      };

      config = {
        "mode" = mkOverride 1002 null;
      };

    };
    "seaweed.seaweedfs.com.v1.SeaweedSpecMasterVolumesCsi" = {

      options = {
        "driver" = mkOption {
          description = "";
          type = types.str;
        };
        "fsType" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "nodePublishSecretRef" = mkOption {
          description = "";
          type = types.nullOr (
            submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecMasterVolumesCsiNodePublishSecretRef"
          );
        };
        "readOnly" = mkOption {
          description = "";
          type = types.nullOr types.bool;
        };
        "volumeAttributes" = mkOption {
          description = "";
          type = types.nullOr (types.attrsOf types.str);
        };
      };

      config = {
        "fsType" = mkOverride 1002 null;
        "nodePublishSecretRef" = mkOverride 1002 null;
        "readOnly" = mkOverride 1002 null;
        "volumeAttributes" = mkOverride 1002 null;
      };

    };
    "seaweed.seaweedfs.com.v1.SeaweedSpecMasterVolumesCsiNodePublishSecretRef" = {

      options = {
        "name" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
      };

      config = {
        "name" = mkOverride 1002 null;
      };

    };
    "seaweed.seaweedfs.com.v1.SeaweedSpecMasterVolumesDownwardAPI" = {

      options = {
        "defaultMode" = mkOption {
          description = "";
          type = types.nullOr types.int;
        };
        "items" = mkOption {
          description = "";
          type = types.nullOr (
            types.listOf (submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecMasterVolumesDownwardAPIItems")
          );
        };
      };

      config = {
        "defaultMode" = mkOverride 1002 null;
        "items" = mkOverride 1002 null;
      };

    };
    "seaweed.seaweedfs.com.v1.SeaweedSpecMasterVolumesDownwardAPIItems" = {

      options = {
        "fieldRef" = mkOption {
          description = "";
          type = types.nullOr (
            submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecMasterVolumesDownwardAPIItemsFieldRef"
          );
        };
        "mode" = mkOption {
          description = "";
          type = types.nullOr types.int;
        };
        "path" = mkOption {
          description = "";
          type = types.str;
        };
        "resourceFieldRef" = mkOption {
          description = "";
          type = types.nullOr (
            submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecMasterVolumesDownwardAPIItemsResourceFieldRef"
          );
        };
      };

      config = {
        "fieldRef" = mkOverride 1002 null;
        "mode" = mkOverride 1002 null;
        "resourceFieldRef" = mkOverride 1002 null;
      };

    };
    "seaweed.seaweedfs.com.v1.SeaweedSpecMasterVolumesDownwardAPIItemsFieldRef" = {

      options = {
        "apiVersion" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "fieldPath" = mkOption {
          description = "";
          type = types.str;
        };
      };

      config = {
        "apiVersion" = mkOverride 1002 null;
      };

    };
    "seaweed.seaweedfs.com.v1.SeaweedSpecMasterVolumesDownwardAPIItemsResourceFieldRef" = {

      options = {
        "containerName" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "divisor" = mkOption {
          description = "";
          type = types.nullOr (types.either types.int types.str);
        };
        "resource" = mkOption {
          description = "";
          type = types.str;
        };
      };

      config = {
        "containerName" = mkOverride 1002 null;
        "divisor" = mkOverride 1002 null;
      };

    };
    "seaweed.seaweedfs.com.v1.SeaweedSpecMasterVolumesEmptyDir" = {

      options = {
        "medium" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "sizeLimit" = mkOption {
          description = "";
          type = types.nullOr (types.either types.int types.str);
        };
      };

      config = {
        "medium" = mkOverride 1002 null;
        "sizeLimit" = mkOverride 1002 null;
      };

    };
    "seaweed.seaweedfs.com.v1.SeaweedSpecMasterVolumesEphemeral" = {

      options = {
        "volumeClaimTemplate" = mkOption {
          description = "";
          type = types.nullOr (
            submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecMasterVolumesEphemeralVolumeClaimTemplate"
          );
        };
      };

      config = {
        "volumeClaimTemplate" = mkOverride 1002 null;
      };

    };
    "seaweed.seaweedfs.com.v1.SeaweedSpecMasterVolumesEphemeralVolumeClaimTemplate" = {

      options = {
        "metadata" = mkOption {
          description = "";
          type = types.nullOr types.attrs;
        };
        "spec" = mkOption {
          description = "";
          type = submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecMasterVolumesEphemeralVolumeClaimTemplateSpec";
        };
      };

      config = {
        "metadata" = mkOverride 1002 null;
      };

    };
    "seaweed.seaweedfs.com.v1.SeaweedSpecMasterVolumesEphemeralVolumeClaimTemplateSpec" = {

      options = {
        "accessModes" = mkOption {
          description = "";
          type = types.nullOr (types.listOf types.str);
        };
        "dataSource" = mkOption {
          description = "";
          type = types.nullOr (
            submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecMasterVolumesEphemeralVolumeClaimTemplateSpecDataSource"
          );
        };
        "dataSourceRef" = mkOption {
          description = "";
          type = types.nullOr (
            submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecMasterVolumesEphemeralVolumeClaimTemplateSpecDataSourceRef"
          );
        };
        "resources" = mkOption {
          description = "";
          type = types.nullOr (
            submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecMasterVolumesEphemeralVolumeClaimTemplateSpecResources"
          );
        };
        "selector" = mkOption {
          description = "";
          type = types.nullOr (
            submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecMasterVolumesEphemeralVolumeClaimTemplateSpecSelector"
          );
        };
        "storageClassName" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "volumeAttributesClassName" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "volumeMode" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "volumeName" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
      };

      config = {
        "accessModes" = mkOverride 1002 null;
        "dataSource" = mkOverride 1002 null;
        "dataSourceRef" = mkOverride 1002 null;
        "resources" = mkOverride 1002 null;
        "selector" = mkOverride 1002 null;
        "storageClassName" = mkOverride 1002 null;
        "volumeAttributesClassName" = mkOverride 1002 null;
        "volumeMode" = mkOverride 1002 null;
        "volumeName" = mkOverride 1002 null;
      };

    };
    "seaweed.seaweedfs.com.v1.SeaweedSpecMasterVolumesEphemeralVolumeClaimTemplateSpecDataSource" = {

      options = {
        "apiGroup" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "kind" = mkOption {
          description = "";
          type = types.str;
        };
        "name" = mkOption {
          description = "";
          type = types.str;
        };
      };

      config = {
        "apiGroup" = mkOverride 1002 null;
      };

    };
    "seaweed.seaweedfs.com.v1.SeaweedSpecMasterVolumesEphemeralVolumeClaimTemplateSpecDataSourceRef" = {

      options = {
        "apiGroup" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "kind" = mkOption {
          description = "";
          type = types.str;
        };
        "name" = mkOption {
          description = "";
          type = types.str;
        };
        "namespace" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
      };

      config = {
        "apiGroup" = mkOverride 1002 null;
        "namespace" = mkOverride 1002 null;
      };

    };
    "seaweed.seaweedfs.com.v1.SeaweedSpecMasterVolumesEphemeralVolumeClaimTemplateSpecResources" = {

      options = {
        "limits" = mkOption {
          description = "";
          type = types.nullOr (types.attrsOf (types.either types.int types.str));
        };
        "requests" = mkOption {
          description = "";
          type = types.nullOr (types.attrsOf (types.either types.int types.str));
        };
      };

      config = {
        "limits" = mkOverride 1002 null;
        "requests" = mkOverride 1002 null;
      };

    };
    "seaweed.seaweedfs.com.v1.SeaweedSpecMasterVolumesEphemeralVolumeClaimTemplateSpecSelector" = {

      options = {
        "matchExpressions" = mkOption {
          description = "";
          type = types.nullOr (
            types.listOf (
              submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecMasterVolumesEphemeralVolumeClaimTemplateSpecSelectorMatchExpressions"
            )
          );
        };
        "matchLabels" = mkOption {
          description = "";
          type = types.nullOr (types.attrsOf types.str);
        };
      };

      config = {
        "matchExpressions" = mkOverride 1002 null;
        "matchLabels" = mkOverride 1002 null;
      };

    };
    "seaweed.seaweedfs.com.v1.SeaweedSpecMasterVolumesEphemeralVolumeClaimTemplateSpecSelectorMatchExpressions" =
      {

        options = {
          "key" = mkOption {
            description = "";
            type = types.str;
          };
          "operator" = mkOption {
            description = "";
            type = types.str;
          };
          "values" = mkOption {
            description = "";
            type = types.nullOr (types.listOf types.str);
          };
        };

        config = {
          "values" = mkOverride 1002 null;
        };

      };
    "seaweed.seaweedfs.com.v1.SeaweedSpecMasterVolumesFc" = {

      options = {
        "fsType" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "lun" = mkOption {
          description = "";
          type = types.nullOr types.int;
        };
        "readOnly" = mkOption {
          description = "";
          type = types.nullOr types.bool;
        };
        "targetWWNs" = mkOption {
          description = "";
          type = types.nullOr (types.listOf types.str);
        };
        "wwids" = mkOption {
          description = "";
          type = types.nullOr (types.listOf types.str);
        };
      };

      config = {
        "fsType" = mkOverride 1002 null;
        "lun" = mkOverride 1002 null;
        "readOnly" = mkOverride 1002 null;
        "targetWWNs" = mkOverride 1002 null;
        "wwids" = mkOverride 1002 null;
      };

    };
    "seaweed.seaweedfs.com.v1.SeaweedSpecMasterVolumesFlexVolume" = {

      options = {
        "driver" = mkOption {
          description = "";
          type = types.str;
        };
        "fsType" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "options" = mkOption {
          description = "";
          type = types.nullOr (types.attrsOf types.str);
        };
        "readOnly" = mkOption {
          description = "";
          type = types.nullOr types.bool;
        };
        "secretRef" = mkOption {
          description = "";
          type = types.nullOr (
            submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecMasterVolumesFlexVolumeSecretRef"
          );
        };
      };

      config = {
        "fsType" = mkOverride 1002 null;
        "options" = mkOverride 1002 null;
        "readOnly" = mkOverride 1002 null;
        "secretRef" = mkOverride 1002 null;
      };

    };
    "seaweed.seaweedfs.com.v1.SeaweedSpecMasterVolumesFlexVolumeSecretRef" = {

      options = {
        "name" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
      };

      config = {
        "name" = mkOverride 1002 null;
      };

    };
    "seaweed.seaweedfs.com.v1.SeaweedSpecMasterVolumesFlocker" = {

      options = {
        "datasetName" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "datasetUUID" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
      };

      config = {
        "datasetName" = mkOverride 1002 null;
        "datasetUUID" = mkOverride 1002 null;
      };

    };
    "seaweed.seaweedfs.com.v1.SeaweedSpecMasterVolumesGcePersistentDisk" = {

      options = {
        "fsType" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "partition" = mkOption {
          description = "";
          type = types.nullOr types.int;
        };
        "pdName" = mkOption {
          description = "";
          type = types.str;
        };
        "readOnly" = mkOption {
          description = "";
          type = types.nullOr types.bool;
        };
      };

      config = {
        "fsType" = mkOverride 1002 null;
        "partition" = mkOverride 1002 null;
        "readOnly" = mkOverride 1002 null;
      };

    };
    "seaweed.seaweedfs.com.v1.SeaweedSpecMasterVolumesGitRepo" = {

      options = {
        "directory" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "repository" = mkOption {
          description = "";
          type = types.str;
        };
        "revision" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
      };

      config = {
        "directory" = mkOverride 1002 null;
        "revision" = mkOverride 1002 null;
      };

    };
    "seaweed.seaweedfs.com.v1.SeaweedSpecMasterVolumesGlusterfs" = {

      options = {
        "endpoints" = mkOption {
          description = "";
          type = types.str;
        };
        "path" = mkOption {
          description = "";
          type = types.str;
        };
        "readOnly" = mkOption {
          description = "";
          type = types.nullOr types.bool;
        };
      };

      config = {
        "readOnly" = mkOverride 1002 null;
      };

    };
    "seaweed.seaweedfs.com.v1.SeaweedSpecMasterVolumesHostPath" = {

      options = {
        "path" = mkOption {
          description = "";
          type = types.str;
        };
        "type" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
      };

      config = {
        "type" = mkOverride 1002 null;
      };

    };
    "seaweed.seaweedfs.com.v1.SeaweedSpecMasterVolumesImage" = {

      options = {
        "pullPolicy" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "reference" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
      };

      config = {
        "pullPolicy" = mkOverride 1002 null;
        "reference" = mkOverride 1002 null;
      };

    };
    "seaweed.seaweedfs.com.v1.SeaweedSpecMasterVolumesIscsi" = {

      options = {
        "chapAuthDiscovery" = mkOption {
          description = "";
          type = types.nullOr types.bool;
        };
        "chapAuthSession" = mkOption {
          description = "";
          type = types.nullOr types.bool;
        };
        "fsType" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "initiatorName" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "iqn" = mkOption {
          description = "";
          type = types.str;
        };
        "iscsiInterface" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "lun" = mkOption {
          description = "";
          type = types.int;
        };
        "portals" = mkOption {
          description = "";
          type = types.nullOr (types.listOf types.str);
        };
        "readOnly" = mkOption {
          description = "";
          type = types.nullOr types.bool;
        };
        "secretRef" = mkOption {
          description = "";
          type = types.nullOr (submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecMasterVolumesIscsiSecretRef");
        };
        "targetPortal" = mkOption {
          description = "";
          type = types.str;
        };
      };

      config = {
        "chapAuthDiscovery" = mkOverride 1002 null;
        "chapAuthSession" = mkOverride 1002 null;
        "fsType" = mkOverride 1002 null;
        "initiatorName" = mkOverride 1002 null;
        "iscsiInterface" = mkOverride 1002 null;
        "portals" = mkOverride 1002 null;
        "readOnly" = mkOverride 1002 null;
        "secretRef" = mkOverride 1002 null;
      };

    };
    "seaweed.seaweedfs.com.v1.SeaweedSpecMasterVolumesIscsiSecretRef" = {

      options = {
        "name" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
      };

      config = {
        "name" = mkOverride 1002 null;
      };

    };
    "seaweed.seaweedfs.com.v1.SeaweedSpecMasterVolumesNfs" = {

      options = {
        "path" = mkOption {
          description = "";
          type = types.str;
        };
        "readOnly" = mkOption {
          description = "";
          type = types.nullOr types.bool;
        };
        "server" = mkOption {
          description = "";
          type = types.str;
        };
      };

      config = {
        "readOnly" = mkOverride 1002 null;
      };

    };
    "seaweed.seaweedfs.com.v1.SeaweedSpecMasterVolumesPersistentVolumeClaim" = {

      options = {
        "claimName" = mkOption {
          description = "";
          type = types.str;
        };
        "readOnly" = mkOption {
          description = "";
          type = types.nullOr types.bool;
        };
      };

      config = {
        "readOnly" = mkOverride 1002 null;
      };

    };
    "seaweed.seaweedfs.com.v1.SeaweedSpecMasterVolumesPhotonPersistentDisk" = {

      options = {
        "fsType" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "pdID" = mkOption {
          description = "";
          type = types.str;
        };
      };

      config = {
        "fsType" = mkOverride 1002 null;
      };

    };
    "seaweed.seaweedfs.com.v1.SeaweedSpecMasterVolumesPortworxVolume" = {

      options = {
        "fsType" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "readOnly" = mkOption {
          description = "";
          type = types.nullOr types.bool;
        };
        "volumeID" = mkOption {
          description = "";
          type = types.str;
        };
      };

      config = {
        "fsType" = mkOverride 1002 null;
        "readOnly" = mkOverride 1002 null;
      };

    };
    "seaweed.seaweedfs.com.v1.SeaweedSpecMasterVolumesProjected" = {

      options = {
        "defaultMode" = mkOption {
          description = "";
          type = types.nullOr types.int;
        };
        "sources" = mkOption {
          description = "";
          type = types.nullOr (
            types.listOf (submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecMasterVolumesProjectedSources")
          );
        };
      };

      config = {
        "defaultMode" = mkOverride 1002 null;
        "sources" = mkOverride 1002 null;
      };

    };
    "seaweed.seaweedfs.com.v1.SeaweedSpecMasterVolumesProjectedSources" = {

      options = {
        "clusterTrustBundle" = mkOption {
          description = "";
          type = types.nullOr (
            submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecMasterVolumesProjectedSourcesClusterTrustBundle"
          );
        };
        "configMap" = mkOption {
          description = "";
          type = types.nullOr (
            submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecMasterVolumesProjectedSourcesConfigMap"
          );
        };
        "downwardAPI" = mkOption {
          description = "";
          type = types.nullOr (
            submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecMasterVolumesProjectedSourcesDownwardAPI"
          );
        };
        "podCertificate" = mkOption {
          description = "";
          type = types.nullOr (
            submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecMasterVolumesProjectedSourcesPodCertificate"
          );
        };
        "secret" = mkOption {
          description = "";
          type = types.nullOr (
            submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecMasterVolumesProjectedSourcesSecret"
          );
        };
        "serviceAccountToken" = mkOption {
          description = "";
          type = types.nullOr (
            submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecMasterVolumesProjectedSourcesServiceAccountToken"
          );
        };
      };

      config = {
        "clusterTrustBundle" = mkOverride 1002 null;
        "configMap" = mkOverride 1002 null;
        "downwardAPI" = mkOverride 1002 null;
        "podCertificate" = mkOverride 1002 null;
        "secret" = mkOverride 1002 null;
        "serviceAccountToken" = mkOverride 1002 null;
      };

    };
    "seaweed.seaweedfs.com.v1.SeaweedSpecMasterVolumesProjectedSourcesClusterTrustBundle" = {

      options = {
        "labelSelector" = mkOption {
          description = "";
          type = types.nullOr (
            submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecMasterVolumesProjectedSourcesClusterTrustBundleLabelSelector"
          );
        };
        "name" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "optional" = mkOption {
          description = "";
          type = types.nullOr types.bool;
        };
        "path" = mkOption {
          description = "";
          type = types.str;
        };
        "signerName" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
      };

      config = {
        "labelSelector" = mkOverride 1002 null;
        "name" = mkOverride 1002 null;
        "optional" = mkOverride 1002 null;
        "signerName" = mkOverride 1002 null;
      };

    };
    "seaweed.seaweedfs.com.v1.SeaweedSpecMasterVolumesProjectedSourcesClusterTrustBundleLabelSelector" =
      {

        options = {
          "matchExpressions" = mkOption {
            description = "";
            type = types.nullOr (
              types.listOf (
                submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecMasterVolumesProjectedSourcesClusterTrustBundleLabelSelectorMatchExpressions"
              )
            );
          };
          "matchLabels" = mkOption {
            description = "";
            type = types.nullOr (types.attrsOf types.str);
          };
        };

        config = {
          "matchExpressions" = mkOverride 1002 null;
          "matchLabels" = mkOverride 1002 null;
        };

      };
    "seaweed.seaweedfs.com.v1.SeaweedSpecMasterVolumesProjectedSourcesClusterTrustBundleLabelSelectorMatchExpressions" =
      {

        options = {
          "key" = mkOption {
            description = "";
            type = types.str;
          };
          "operator" = mkOption {
            description = "";
            type = types.str;
          };
          "values" = mkOption {
            description = "";
            type = types.nullOr (types.listOf types.str);
          };
        };

        config = {
          "values" = mkOverride 1002 null;
        };

      };
    "seaweed.seaweedfs.com.v1.SeaweedSpecMasterVolumesProjectedSourcesConfigMap" = {

      options = {
        "items" = mkOption {
          description = "";
          type = types.nullOr (
            types.listOf (
              submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecMasterVolumesProjectedSourcesConfigMapItems"
            )
          );
        };
        "name" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "optional" = mkOption {
          description = "";
          type = types.nullOr types.bool;
        };
      };

      config = {
        "items" = mkOverride 1002 null;
        "name" = mkOverride 1002 null;
        "optional" = mkOverride 1002 null;
      };

    };
    "seaweed.seaweedfs.com.v1.SeaweedSpecMasterVolumesProjectedSourcesConfigMapItems" = {

      options = {
        "key" = mkOption {
          description = "";
          type = types.str;
        };
        "mode" = mkOption {
          description = "";
          type = types.nullOr types.int;
        };
        "path" = mkOption {
          description = "";
          type = types.str;
        };
      };

      config = {
        "mode" = mkOverride 1002 null;
      };

    };
    "seaweed.seaweedfs.com.v1.SeaweedSpecMasterVolumesProjectedSourcesDownwardAPI" = {

      options = {
        "items" = mkOption {
          description = "";
          type = types.nullOr (
            types.listOf (
              submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecMasterVolumesProjectedSourcesDownwardAPIItems"
            )
          );
        };
      };

      config = {
        "items" = mkOverride 1002 null;
      };

    };
    "seaweed.seaweedfs.com.v1.SeaweedSpecMasterVolumesProjectedSourcesDownwardAPIItems" = {

      options = {
        "fieldRef" = mkOption {
          description = "";
          type = types.nullOr (
            submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecMasterVolumesProjectedSourcesDownwardAPIItemsFieldRef"
          );
        };
        "mode" = mkOption {
          description = "";
          type = types.nullOr types.int;
        };
        "path" = mkOption {
          description = "";
          type = types.str;
        };
        "resourceFieldRef" = mkOption {
          description = "";
          type = types.nullOr (
            submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecMasterVolumesProjectedSourcesDownwardAPIItemsResourceFieldRef"
          );
        };
      };

      config = {
        "fieldRef" = mkOverride 1002 null;
        "mode" = mkOverride 1002 null;
        "resourceFieldRef" = mkOverride 1002 null;
      };

    };
    "seaweed.seaweedfs.com.v1.SeaweedSpecMasterVolumesProjectedSourcesDownwardAPIItemsFieldRef" = {

      options = {
        "apiVersion" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "fieldPath" = mkOption {
          description = "";
          type = types.str;
        };
      };

      config = {
        "apiVersion" = mkOverride 1002 null;
      };

    };
    "seaweed.seaweedfs.com.v1.SeaweedSpecMasterVolumesProjectedSourcesDownwardAPIItemsResourceFieldRef" =
      {

        options = {
          "containerName" = mkOption {
            description = "";
            type = types.nullOr types.str;
          };
          "divisor" = mkOption {
            description = "";
            type = types.nullOr (types.either types.int types.str);
          };
          "resource" = mkOption {
            description = "";
            type = types.str;
          };
        };

        config = {
          "containerName" = mkOverride 1002 null;
          "divisor" = mkOverride 1002 null;
        };

      };
    "seaweed.seaweedfs.com.v1.SeaweedSpecMasterVolumesProjectedSourcesPodCertificate" = {

      options = {
        "certificateChainPath" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "credentialBundlePath" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "keyPath" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "keyType" = mkOption {
          description = "";
          type = types.str;
        };
        "maxExpirationSeconds" = mkOption {
          description = "";
          type = types.nullOr types.int;
        };
        "signerName" = mkOption {
          description = "";
          type = types.str;
        };
        "userAnnotations" = mkOption {
          description = "";
          type = types.nullOr (types.attrsOf types.str);
        };
      };

      config = {
        "certificateChainPath" = mkOverride 1002 null;
        "credentialBundlePath" = mkOverride 1002 null;
        "keyPath" = mkOverride 1002 null;
        "maxExpirationSeconds" = mkOverride 1002 null;
        "userAnnotations" = mkOverride 1002 null;
      };

    };
    "seaweed.seaweedfs.com.v1.SeaweedSpecMasterVolumesProjectedSourcesSecret" = {

      options = {
        "items" = mkOption {
          description = "";
          type = types.nullOr (
            types.listOf (
              submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecMasterVolumesProjectedSourcesSecretItems"
            )
          );
        };
        "name" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "optional" = mkOption {
          description = "";
          type = types.nullOr types.bool;
        };
      };

      config = {
        "items" = mkOverride 1002 null;
        "name" = mkOverride 1002 null;
        "optional" = mkOverride 1002 null;
      };

    };
    "seaweed.seaweedfs.com.v1.SeaweedSpecMasterVolumesProjectedSourcesSecretItems" = {

      options = {
        "key" = mkOption {
          description = "";
          type = types.str;
        };
        "mode" = mkOption {
          description = "";
          type = types.nullOr types.int;
        };
        "path" = mkOption {
          description = "";
          type = types.str;
        };
      };

      config = {
        "mode" = mkOverride 1002 null;
      };

    };
    "seaweed.seaweedfs.com.v1.SeaweedSpecMasterVolumesProjectedSourcesServiceAccountToken" = {

      options = {
        "audience" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "expirationSeconds" = mkOption {
          description = "";
          type = types.nullOr types.int;
        };
        "path" = mkOption {
          description = "";
          type = types.str;
        };
      };

      config = {
        "audience" = mkOverride 1002 null;
        "expirationSeconds" = mkOverride 1002 null;
      };

    };
    "seaweed.seaweedfs.com.v1.SeaweedSpecMasterVolumesQuobyte" = {

      options = {
        "group" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "readOnly" = mkOption {
          description = "";
          type = types.nullOr types.bool;
        };
        "registry" = mkOption {
          description = "";
          type = types.str;
        };
        "tenant" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "user" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "volume" = mkOption {
          description = "";
          type = types.str;
        };
      };

      config = {
        "group" = mkOverride 1002 null;
        "readOnly" = mkOverride 1002 null;
        "tenant" = mkOverride 1002 null;
        "user" = mkOverride 1002 null;
      };

    };
    "seaweed.seaweedfs.com.v1.SeaweedSpecMasterVolumesRbd" = {

      options = {
        "fsType" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "image" = mkOption {
          description = "";
          type = types.str;
        };
        "keyring" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "monitors" = mkOption {
          description = "";
          type = types.listOf types.str;
        };
        "pool" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "readOnly" = mkOption {
          description = "";
          type = types.nullOr types.bool;
        };
        "secretRef" = mkOption {
          description = "";
          type = types.nullOr (submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecMasterVolumesRbdSecretRef");
        };
        "user" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
      };

      config = {
        "fsType" = mkOverride 1002 null;
        "keyring" = mkOverride 1002 null;
        "pool" = mkOverride 1002 null;
        "readOnly" = mkOverride 1002 null;
        "secretRef" = mkOverride 1002 null;
        "user" = mkOverride 1002 null;
      };

    };
    "seaweed.seaweedfs.com.v1.SeaweedSpecMasterVolumesRbdSecretRef" = {

      options = {
        "name" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
      };

      config = {
        "name" = mkOverride 1002 null;
      };

    };
    "seaweed.seaweedfs.com.v1.SeaweedSpecMasterVolumesScaleIO" = {

      options = {
        "fsType" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "gateway" = mkOption {
          description = "";
          type = types.str;
        };
        "protectionDomain" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "readOnly" = mkOption {
          description = "";
          type = types.nullOr types.bool;
        };
        "secretRef" = mkOption {
          description = "";
          type = submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecMasterVolumesScaleIOSecretRef";
        };
        "sslEnabled" = mkOption {
          description = "";
          type = types.nullOr types.bool;
        };
        "storageMode" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "storagePool" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "system" = mkOption {
          description = "";
          type = types.str;
        };
        "volumeName" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
      };

      config = {
        "fsType" = mkOverride 1002 null;
        "protectionDomain" = mkOverride 1002 null;
        "readOnly" = mkOverride 1002 null;
        "sslEnabled" = mkOverride 1002 null;
        "storageMode" = mkOverride 1002 null;
        "storagePool" = mkOverride 1002 null;
        "volumeName" = mkOverride 1002 null;
      };

    };
    "seaweed.seaweedfs.com.v1.SeaweedSpecMasterVolumesScaleIOSecretRef" = {

      options = {
        "name" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
      };

      config = {
        "name" = mkOverride 1002 null;
      };

    };
    "seaweed.seaweedfs.com.v1.SeaweedSpecMasterVolumesSecret" = {

      options = {
        "defaultMode" = mkOption {
          description = "";
          type = types.nullOr types.int;
        };
        "items" = mkOption {
          description = "";
          type = types.nullOr (
            types.listOf (submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecMasterVolumesSecretItems")
          );
        };
        "optional" = mkOption {
          description = "";
          type = types.nullOr types.bool;
        };
        "secretName" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
      };

      config = {
        "defaultMode" = mkOverride 1002 null;
        "items" = mkOverride 1002 null;
        "optional" = mkOverride 1002 null;
        "secretName" = mkOverride 1002 null;
      };

    };
    "seaweed.seaweedfs.com.v1.SeaweedSpecMasterVolumesSecretItems" = {

      options = {
        "key" = mkOption {
          description = "";
          type = types.str;
        };
        "mode" = mkOption {
          description = "";
          type = types.nullOr types.int;
        };
        "path" = mkOption {
          description = "";
          type = types.str;
        };
      };

      config = {
        "mode" = mkOverride 1002 null;
      };

    };
    "seaweed.seaweedfs.com.v1.SeaweedSpecMasterVolumesStorageos" = {

      options = {
        "fsType" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "readOnly" = mkOption {
          description = "";
          type = types.nullOr types.bool;
        };
        "secretRef" = mkOption {
          description = "";
          type = types.nullOr (
            submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecMasterVolumesStorageosSecretRef"
          );
        };
        "volumeName" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "volumeNamespace" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
      };

      config = {
        "fsType" = mkOverride 1002 null;
        "readOnly" = mkOverride 1002 null;
        "secretRef" = mkOverride 1002 null;
        "volumeName" = mkOverride 1002 null;
        "volumeNamespace" = mkOverride 1002 null;
      };

    };
    "seaweed.seaweedfs.com.v1.SeaweedSpecMasterVolumesStorageosSecretRef" = {

      options = {
        "name" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
      };

      config = {
        "name" = mkOverride 1002 null;
      };

    };
    "seaweed.seaweedfs.com.v1.SeaweedSpecMasterVolumesVsphereVolume" = {

      options = {
        "fsType" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "storagePolicyID" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "storagePolicyName" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "volumePath" = mkOption {
          description = "";
          type = types.str;
        };
      };

      config = {
        "fsType" = mkOverride 1002 null;
        "storagePolicyID" = mkOverride 1002 null;
        "storagePolicyName" = mkOverride 1002 null;
      };

    };
    "seaweed.seaweedfs.com.v1.SeaweedSpecS3" = {

      options = {
        "affinity" = mkOption {
          description = "";
          type = types.nullOr (submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecS3Affinity");
        };
        "annotations" = mkOption {
          description = "";
          type = types.nullOr (types.attrsOf types.str);
        };
        "claims" = mkOption {
          description = "";
          type = types.nullOr (
            coerceAttrsOfSubmodulesToListByKey "seaweed.seaweedfs.com.v1.SeaweedSpecS3Claims" "name" [ "name" ]
          );
          apply = attrsToList;
        };
        "configSecret" = mkOption {
          description = "";
          type = types.nullOr (submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecS3ConfigSecret");
        };
        "containerSecurityContext" = mkOption {
          description = "";
          type = types.nullOr (submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecS3ContainerSecurityContext");
        };
        "domainName" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "env" = mkOption {
          description = "";
          type = types.nullOr (
            coerceAttrsOfSubmodulesToListByKey "seaweed.seaweedfs.com.v1.SeaweedSpecS3Env" "name" [ ]
          );
          apply = attrsToList;
        };
        "extraArgs" = mkOption {
          description = "";
          type = types.nullOr (types.listOf types.str);
        };
        "hostNetwork" = mkOption {
          description = "";
          type = types.nullOr types.bool;
        };
        "iam" = mkOption {
          description = "";
          type = types.nullOr types.bool;
        };
        "imagePullPolicy" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "imagePullSecrets" = mkOption {
          description = "";
          type = types.nullOr (
            coerceAttrsOfSubmodulesToListByKey "seaweed.seaweedfs.com.v1.SeaweedSpecS3ImagePullSecrets" "name"
              [ ]
          );
          apply = attrsToList;
        };
        "ingress" = mkOption {
          description = "";
          type = types.nullOr (submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecS3Ingress");
        };
        "initContainers" = mkOption {
          description = "";
          type = types.nullOr types.unspecified;
        };
        "labels" = mkOption {
          description = "";
          type = types.nullOr (types.attrsOf types.str);
        };
        "limits" = mkOption {
          description = "";
          type = types.nullOr (types.attrsOf (types.either types.int types.str));
        };
        "livenessProbe" = mkOption {
          description = "";
          type = types.nullOr (submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecS3LivenessProbe");
        };
        "loggingArgs" = mkOption {
          description = "";
          type = types.nullOr (types.listOf types.str);
        };
        "metricsPort" = mkOption {
          description = "";
          type = types.nullOr types.int;
        };
        "nodeSelector" = mkOption {
          description = "";
          type = types.nullOr (types.attrsOf types.str);
        };
        "podSecurityContext" = mkOption {
          description = "";
          type = types.nullOr (submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecS3PodSecurityContext");
        };
        "port" = mkOption {
          description = "";
          type = types.nullOr types.int;
        };
        "priorityClassName" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "readinessProbe" = mkOption {
          description = "";
          type = types.nullOr (submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecS3ReadinessProbe");
        };
        "replicas" = mkOption {
          description = "";
          type = types.int;
        };
        "requests" = mkOption {
          description = "";
          type = types.nullOr (types.attrsOf (types.either types.int types.str));
        };
        "schedulerName" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "service" = mkOption {
          description = "";
          type = types.nullOr (submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecS3Service");
        };
        "serviceAccountName" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "sidecars" = mkOption {
          description = "";
          type = types.nullOr types.unspecified;
        };
        "statefulSetUpdateStrategy" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "terminationGracePeriodSeconds" = mkOption {
          description = "";
          type = types.nullOr types.int;
        };
        "tolerations" = mkOption {
          description = "";
          type = types.nullOr (
            types.listOf (submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecS3Tolerations")
          );
        };
        "version" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "volumeMounts" = mkOption {
          description = "";
          type = types.nullOr (
            coerceAttrsOfSubmodulesToListByKey "seaweed.seaweedfs.com.v1.SeaweedSpecS3VolumeMounts" "name" [ ]
          );
          apply = attrsToList;
        };
        "volumes" = mkOption {
          description = "";
          type = types.nullOr (
            coerceAttrsOfSubmodulesToListByKey "seaweed.seaweedfs.com.v1.SeaweedSpecS3Volumes" "name" [ ]
          );
          apply = attrsToList;
        };
      };

      config = {
        "affinity" = mkOverride 1002 null;
        "annotations" = mkOverride 1002 null;
        "claims" = mkOverride 1002 null;
        "configSecret" = mkOverride 1002 null;
        "containerSecurityContext" = mkOverride 1002 null;
        "domainName" = mkOverride 1002 null;
        "env" = mkOverride 1002 null;
        "extraArgs" = mkOverride 1002 null;
        "hostNetwork" = mkOverride 1002 null;
        "iam" = mkOverride 1002 null;
        "imagePullPolicy" = mkOverride 1002 null;
        "imagePullSecrets" = mkOverride 1002 null;
        "ingress" = mkOverride 1002 null;
        "initContainers" = mkOverride 1002 null;
        "labels" = mkOverride 1002 null;
        "limits" = mkOverride 1002 null;
        "livenessProbe" = mkOverride 1002 null;
        "loggingArgs" = mkOverride 1002 null;
        "metricsPort" = mkOverride 1002 null;
        "nodeSelector" = mkOverride 1002 null;
        "podSecurityContext" = mkOverride 1002 null;
        "port" = mkOverride 1002 null;
        "priorityClassName" = mkOverride 1002 null;
        "readinessProbe" = mkOverride 1002 null;
        "requests" = mkOverride 1002 null;
        "schedulerName" = mkOverride 1002 null;
        "service" = mkOverride 1002 null;
        "serviceAccountName" = mkOverride 1002 null;
        "sidecars" = mkOverride 1002 null;
        "statefulSetUpdateStrategy" = mkOverride 1002 null;
        "terminationGracePeriodSeconds" = mkOverride 1002 null;
        "tolerations" = mkOverride 1002 null;
        "version" = mkOverride 1002 null;
        "volumeMounts" = mkOverride 1002 null;
        "volumes" = mkOverride 1002 null;
      };

    };
    "seaweed.seaweedfs.com.v1.SeaweedSpecS3Affinity" = {

      options = {
        "nodeAffinity" = mkOption {
          description = "";
          type = types.nullOr (submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecS3AffinityNodeAffinity");
        };
        "podAffinity" = mkOption {
          description = "";
          type = types.nullOr (submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecS3AffinityPodAffinity");
        };
        "podAntiAffinity" = mkOption {
          description = "";
          type = types.nullOr (submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecS3AffinityPodAntiAffinity");
        };
      };

      config = {
        "nodeAffinity" = mkOverride 1002 null;
        "podAffinity" = mkOverride 1002 null;
        "podAntiAffinity" = mkOverride 1002 null;
      };

    };
    "seaweed.seaweedfs.com.v1.SeaweedSpecS3AffinityNodeAffinity" = {

      options = {
        "preferredDuringSchedulingIgnoredDuringExecution" = mkOption {
          description = "";
          type = types.nullOr (
            types.listOf (
              submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecS3AffinityNodeAffinityPreferredDuringSchedulingIgnoredDuringExecution"
            )
          );
        };
        "requiredDuringSchedulingIgnoredDuringExecution" = mkOption {
          description = "";
          type = types.nullOr (
            submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecS3AffinityNodeAffinityRequiredDuringSchedulingIgnoredDuringExecution"
          );
        };
      };

      config = {
        "preferredDuringSchedulingIgnoredDuringExecution" = mkOverride 1002 null;
        "requiredDuringSchedulingIgnoredDuringExecution" = mkOverride 1002 null;
      };

    };
    "seaweed.seaweedfs.com.v1.SeaweedSpecS3AffinityNodeAffinityPreferredDuringSchedulingIgnoredDuringExecution" =
      {

        options = {
          "preference" = mkOption {
            description = "";
            type = submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecS3AffinityNodeAffinityPreferredDuringSchedulingIgnoredDuringExecutionPreference";
          };
          "weight" = mkOption {
            description = "";
            type = types.int;
          };
        };

        config = { };

      };
    "seaweed.seaweedfs.com.v1.SeaweedSpecS3AffinityNodeAffinityPreferredDuringSchedulingIgnoredDuringExecutionPreference" =
      {

        options = {
          "matchExpressions" = mkOption {
            description = "";
            type = types.nullOr (
              types.listOf (
                submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecS3AffinityNodeAffinityPreferredDuringSchedulingIgnoredDuringExecutionPreferenceMatchExpressions"
              )
            );
          };
          "matchFields" = mkOption {
            description = "";
            type = types.nullOr (
              types.listOf (
                submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecS3AffinityNodeAffinityPreferredDuringSchedulingIgnoredDuringExecutionPreferenceMatchFields"
              )
            );
          };
        };

        config = {
          "matchExpressions" = mkOverride 1002 null;
          "matchFields" = mkOverride 1002 null;
        };

      };
    "seaweed.seaweedfs.com.v1.SeaweedSpecS3AffinityNodeAffinityPreferredDuringSchedulingIgnoredDuringExecutionPreferenceMatchExpressions" =
      {

        options = {
          "key" = mkOption {
            description = "";
            type = types.str;
          };
          "operator" = mkOption {
            description = "";
            type = types.str;
          };
          "values" = mkOption {
            description = "";
            type = types.nullOr (types.listOf types.str);
          };
        };

        config = {
          "values" = mkOverride 1002 null;
        };

      };
    "seaweed.seaweedfs.com.v1.SeaweedSpecS3AffinityNodeAffinityPreferredDuringSchedulingIgnoredDuringExecutionPreferenceMatchFields" =
      {

        options = {
          "key" = mkOption {
            description = "";
            type = types.str;
          };
          "operator" = mkOption {
            description = "";
            type = types.str;
          };
          "values" = mkOption {
            description = "";
            type = types.nullOr (types.listOf types.str);
          };
        };

        config = {
          "values" = mkOverride 1002 null;
        };

      };
    "seaweed.seaweedfs.com.v1.SeaweedSpecS3AffinityNodeAffinityRequiredDuringSchedulingIgnoredDuringExecution" =
      {

        options = {
          "nodeSelectorTerms" = mkOption {
            description = "";
            type = types.listOf (
              submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecS3AffinityNodeAffinityRequiredDuringSchedulingIgnoredDuringExecutionNodeSelectorTerms"
            );
          };
        };

        config = { };

      };
    "seaweed.seaweedfs.com.v1.SeaweedSpecS3AffinityNodeAffinityRequiredDuringSchedulingIgnoredDuringExecutionNodeSelectorTerms" =
      {

        options = {
          "matchExpressions" = mkOption {
            description = "";
            type = types.nullOr (
              types.listOf (
                submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecS3AffinityNodeAffinityRequiredDuringSchedulingIgnoredDuringExecutionNodeSelectorTermsMatchExpressions"
              )
            );
          };
          "matchFields" = mkOption {
            description = "";
            type = types.nullOr (
              types.listOf (
                submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecS3AffinityNodeAffinityRequiredDuringSchedulingIgnoredDuringExecutionNodeSelectorTermsMatchFields"
              )
            );
          };
        };

        config = {
          "matchExpressions" = mkOverride 1002 null;
          "matchFields" = mkOverride 1002 null;
        };

      };
    "seaweed.seaweedfs.com.v1.SeaweedSpecS3AffinityNodeAffinityRequiredDuringSchedulingIgnoredDuringExecutionNodeSelectorTermsMatchExpressions" =
      {

        options = {
          "key" = mkOption {
            description = "";
            type = types.str;
          };
          "operator" = mkOption {
            description = "";
            type = types.str;
          };
          "values" = mkOption {
            description = "";
            type = types.nullOr (types.listOf types.str);
          };
        };

        config = {
          "values" = mkOverride 1002 null;
        };

      };
    "seaweed.seaweedfs.com.v1.SeaweedSpecS3AffinityNodeAffinityRequiredDuringSchedulingIgnoredDuringExecutionNodeSelectorTermsMatchFields" =
      {

        options = {
          "key" = mkOption {
            description = "";
            type = types.str;
          };
          "operator" = mkOption {
            description = "";
            type = types.str;
          };
          "values" = mkOption {
            description = "";
            type = types.nullOr (types.listOf types.str);
          };
        };

        config = {
          "values" = mkOverride 1002 null;
        };

      };
    "seaweed.seaweedfs.com.v1.SeaweedSpecS3AffinityPodAffinity" = {

      options = {
        "preferredDuringSchedulingIgnoredDuringExecution" = mkOption {
          description = "";
          type = types.nullOr (
            types.listOf (
              submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecS3AffinityPodAffinityPreferredDuringSchedulingIgnoredDuringExecution"
            )
          );
        };
        "requiredDuringSchedulingIgnoredDuringExecution" = mkOption {
          description = "";
          type = types.nullOr (
            types.listOf (
              submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecS3AffinityPodAffinityRequiredDuringSchedulingIgnoredDuringExecution"
            )
          );
        };
      };

      config = {
        "preferredDuringSchedulingIgnoredDuringExecution" = mkOverride 1002 null;
        "requiredDuringSchedulingIgnoredDuringExecution" = mkOverride 1002 null;
      };

    };
    "seaweed.seaweedfs.com.v1.SeaweedSpecS3AffinityPodAffinityPreferredDuringSchedulingIgnoredDuringExecution" =
      {

        options = {
          "podAffinityTerm" = mkOption {
            description = "";
            type = submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecS3AffinityPodAffinityPreferredDuringSchedulingIgnoredDuringExecutionPodAffinityTerm";
          };
          "weight" = mkOption {
            description = "";
            type = types.int;
          };
        };

        config = { };

      };
    "seaweed.seaweedfs.com.v1.SeaweedSpecS3AffinityPodAffinityPreferredDuringSchedulingIgnoredDuringExecutionPodAffinityTerm" =
      {

        options = {
          "labelSelector" = mkOption {
            description = "";
            type = types.nullOr (
              submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecS3AffinityPodAffinityPreferredDuringSchedulingIgnoredDuringExecutionPodAffinityTermLabelSelector"
            );
          };
          "matchLabelKeys" = mkOption {
            description = "";
            type = types.nullOr (types.listOf types.str);
          };
          "mismatchLabelKeys" = mkOption {
            description = "";
            type = types.nullOr (types.listOf types.str);
          };
          "namespaceSelector" = mkOption {
            description = "";
            type = types.nullOr (
              submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecS3AffinityPodAffinityPreferredDuringSchedulingIgnoredDuringExecutionPodAffinityTermNamespaceSelector"
            );
          };
          "namespaces" = mkOption {
            description = "";
            type = types.nullOr (types.listOf types.str);
          };
          "topologyKey" = mkOption {
            description = "";
            type = types.str;
          };
        };

        config = {
          "labelSelector" = mkOverride 1002 null;
          "matchLabelKeys" = mkOverride 1002 null;
          "mismatchLabelKeys" = mkOverride 1002 null;
          "namespaceSelector" = mkOverride 1002 null;
          "namespaces" = mkOverride 1002 null;
        };

      };
    "seaweed.seaweedfs.com.v1.SeaweedSpecS3AffinityPodAffinityPreferredDuringSchedulingIgnoredDuringExecutionPodAffinityTermLabelSelector" =
      {

        options = {
          "matchExpressions" = mkOption {
            description = "";
            type = types.nullOr (
              types.listOf (
                submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecS3AffinityPodAffinityPreferredDuringSchedulingIgnoredDuringExecutionPodAffinityTermLabelSelectorMatchExpressions"
              )
            );
          };
          "matchLabels" = mkOption {
            description = "";
            type = types.nullOr (types.attrsOf types.str);
          };
        };

        config = {
          "matchExpressions" = mkOverride 1002 null;
          "matchLabels" = mkOverride 1002 null;
        };

      };
    "seaweed.seaweedfs.com.v1.SeaweedSpecS3AffinityPodAffinityPreferredDuringSchedulingIgnoredDuringExecutionPodAffinityTermLabelSelectorMatchExpressions" =
      {

        options = {
          "key" = mkOption {
            description = "";
            type = types.str;
          };
          "operator" = mkOption {
            description = "";
            type = types.str;
          };
          "values" = mkOption {
            description = "";
            type = types.nullOr (types.listOf types.str);
          };
        };

        config = {
          "values" = mkOverride 1002 null;
        };

      };
    "seaweed.seaweedfs.com.v1.SeaweedSpecS3AffinityPodAffinityPreferredDuringSchedulingIgnoredDuringExecutionPodAffinityTermNamespaceSelector" =
      {

        options = {
          "matchExpressions" = mkOption {
            description = "";
            type = types.nullOr (
              types.listOf (
                submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecS3AffinityPodAffinityPreferredDuringSchedulingIgnoredDuringExecutionPodAffinityTermNamespaceSelectorMatchExpressions"
              )
            );
          };
          "matchLabels" = mkOption {
            description = "";
            type = types.nullOr (types.attrsOf types.str);
          };
        };

        config = {
          "matchExpressions" = mkOverride 1002 null;
          "matchLabels" = mkOverride 1002 null;
        };

      };
    "seaweed.seaweedfs.com.v1.SeaweedSpecS3AffinityPodAffinityPreferredDuringSchedulingIgnoredDuringExecutionPodAffinityTermNamespaceSelectorMatchExpressions" =
      {

        options = {
          "key" = mkOption {
            description = "";
            type = types.str;
          };
          "operator" = mkOption {
            description = "";
            type = types.str;
          };
          "values" = mkOption {
            description = "";
            type = types.nullOr (types.listOf types.str);
          };
        };

        config = {
          "values" = mkOverride 1002 null;
        };

      };
    "seaweed.seaweedfs.com.v1.SeaweedSpecS3AffinityPodAffinityRequiredDuringSchedulingIgnoredDuringExecution" =
      {

        options = {
          "labelSelector" = mkOption {
            description = "";
            type = types.nullOr (
              submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecS3AffinityPodAffinityRequiredDuringSchedulingIgnoredDuringExecutionLabelSelector"
            );
          };
          "matchLabelKeys" = mkOption {
            description = "";
            type = types.nullOr (types.listOf types.str);
          };
          "mismatchLabelKeys" = mkOption {
            description = "";
            type = types.nullOr (types.listOf types.str);
          };
          "namespaceSelector" = mkOption {
            description = "";
            type = types.nullOr (
              submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecS3AffinityPodAffinityRequiredDuringSchedulingIgnoredDuringExecutionNamespaceSelector"
            );
          };
          "namespaces" = mkOption {
            description = "";
            type = types.nullOr (types.listOf types.str);
          };
          "topologyKey" = mkOption {
            description = "";
            type = types.str;
          };
        };

        config = {
          "labelSelector" = mkOverride 1002 null;
          "matchLabelKeys" = mkOverride 1002 null;
          "mismatchLabelKeys" = mkOverride 1002 null;
          "namespaceSelector" = mkOverride 1002 null;
          "namespaces" = mkOverride 1002 null;
        };

      };
    "seaweed.seaweedfs.com.v1.SeaweedSpecS3AffinityPodAffinityRequiredDuringSchedulingIgnoredDuringExecutionLabelSelector" =
      {

        options = {
          "matchExpressions" = mkOption {
            description = "";
            type = types.nullOr (
              types.listOf (
                submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecS3AffinityPodAffinityRequiredDuringSchedulingIgnoredDuringExecutionLabelSelectorMatchExpressions"
              )
            );
          };
          "matchLabels" = mkOption {
            description = "";
            type = types.nullOr (types.attrsOf types.str);
          };
        };

        config = {
          "matchExpressions" = mkOverride 1002 null;
          "matchLabels" = mkOverride 1002 null;
        };

      };
    "seaweed.seaweedfs.com.v1.SeaweedSpecS3AffinityPodAffinityRequiredDuringSchedulingIgnoredDuringExecutionLabelSelectorMatchExpressions" =
      {

        options = {
          "key" = mkOption {
            description = "";
            type = types.str;
          };
          "operator" = mkOption {
            description = "";
            type = types.str;
          };
          "values" = mkOption {
            description = "";
            type = types.nullOr (types.listOf types.str);
          };
        };

        config = {
          "values" = mkOverride 1002 null;
        };

      };
    "seaweed.seaweedfs.com.v1.SeaweedSpecS3AffinityPodAffinityRequiredDuringSchedulingIgnoredDuringExecutionNamespaceSelector" =
      {

        options = {
          "matchExpressions" = mkOption {
            description = "";
            type = types.nullOr (
              types.listOf (
                submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecS3AffinityPodAffinityRequiredDuringSchedulingIgnoredDuringExecutionNamespaceSelectorMatchExpressions"
              )
            );
          };
          "matchLabels" = mkOption {
            description = "";
            type = types.nullOr (types.attrsOf types.str);
          };
        };

        config = {
          "matchExpressions" = mkOverride 1002 null;
          "matchLabels" = mkOverride 1002 null;
        };

      };
    "seaweed.seaweedfs.com.v1.SeaweedSpecS3AffinityPodAffinityRequiredDuringSchedulingIgnoredDuringExecutionNamespaceSelectorMatchExpressions" =
      {

        options = {
          "key" = mkOption {
            description = "";
            type = types.str;
          };
          "operator" = mkOption {
            description = "";
            type = types.str;
          };
          "values" = mkOption {
            description = "";
            type = types.nullOr (types.listOf types.str);
          };
        };

        config = {
          "values" = mkOverride 1002 null;
        };

      };
    "seaweed.seaweedfs.com.v1.SeaweedSpecS3AffinityPodAntiAffinity" = {

      options = {
        "preferredDuringSchedulingIgnoredDuringExecution" = mkOption {
          description = "";
          type = types.nullOr (
            types.listOf (
              submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecS3AffinityPodAntiAffinityPreferredDuringSchedulingIgnoredDuringExecution"
            )
          );
        };
        "requiredDuringSchedulingIgnoredDuringExecution" = mkOption {
          description = "";
          type = types.nullOr (
            types.listOf (
              submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecS3AffinityPodAntiAffinityRequiredDuringSchedulingIgnoredDuringExecution"
            )
          );
        };
      };

      config = {
        "preferredDuringSchedulingIgnoredDuringExecution" = mkOverride 1002 null;
        "requiredDuringSchedulingIgnoredDuringExecution" = mkOverride 1002 null;
      };

    };
    "seaweed.seaweedfs.com.v1.SeaweedSpecS3AffinityPodAntiAffinityPreferredDuringSchedulingIgnoredDuringExecution" =
      {

        options = {
          "podAffinityTerm" = mkOption {
            description = "";
            type = submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecS3AffinityPodAntiAffinityPreferredDuringSchedulingIgnoredDuringExecutionPodAffinityTerm";
          };
          "weight" = mkOption {
            description = "";
            type = types.int;
          };
        };

        config = { };

      };
    "seaweed.seaweedfs.com.v1.SeaweedSpecS3AffinityPodAntiAffinityPreferredDuringSchedulingIgnoredDuringExecutionPodAffinityTerm" =
      {

        options = {
          "labelSelector" = mkOption {
            description = "";
            type = types.nullOr (
              submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecS3AffinityPodAntiAffinityPreferredDuringSchedulingIgnoredDuringExecutionPodAffinityTermLabelSelector"
            );
          };
          "matchLabelKeys" = mkOption {
            description = "";
            type = types.nullOr (types.listOf types.str);
          };
          "mismatchLabelKeys" = mkOption {
            description = "";
            type = types.nullOr (types.listOf types.str);
          };
          "namespaceSelector" = mkOption {
            description = "";
            type = types.nullOr (
              submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecS3AffinityPodAntiAffinityPreferredDuringSchedulingIgnoredDuringExecutionPodAffinityTermNamespaceSelector"
            );
          };
          "namespaces" = mkOption {
            description = "";
            type = types.nullOr (types.listOf types.str);
          };
          "topologyKey" = mkOption {
            description = "";
            type = types.str;
          };
        };

        config = {
          "labelSelector" = mkOverride 1002 null;
          "matchLabelKeys" = mkOverride 1002 null;
          "mismatchLabelKeys" = mkOverride 1002 null;
          "namespaceSelector" = mkOverride 1002 null;
          "namespaces" = mkOverride 1002 null;
        };

      };
    "seaweed.seaweedfs.com.v1.SeaweedSpecS3AffinityPodAntiAffinityPreferredDuringSchedulingIgnoredDuringExecutionPodAffinityTermLabelSelector" =
      {

        options = {
          "matchExpressions" = mkOption {
            description = "";
            type = types.nullOr (
              types.listOf (
                submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecS3AffinityPodAntiAffinityPreferredDuringSchedulingIgnoredDuringExecutionPodAffinityTermLabelSelectorMatchExpressions"
              )
            );
          };
          "matchLabels" = mkOption {
            description = "";
            type = types.nullOr (types.attrsOf types.str);
          };
        };

        config = {
          "matchExpressions" = mkOverride 1002 null;
          "matchLabels" = mkOverride 1002 null;
        };

      };
    "seaweed.seaweedfs.com.v1.SeaweedSpecS3AffinityPodAntiAffinityPreferredDuringSchedulingIgnoredDuringExecutionPodAffinityTermLabelSelectorMatchExpressions" =
      {

        options = {
          "key" = mkOption {
            description = "";
            type = types.str;
          };
          "operator" = mkOption {
            description = "";
            type = types.str;
          };
          "values" = mkOption {
            description = "";
            type = types.nullOr (types.listOf types.str);
          };
        };

        config = {
          "values" = mkOverride 1002 null;
        };

      };
    "seaweed.seaweedfs.com.v1.SeaweedSpecS3AffinityPodAntiAffinityPreferredDuringSchedulingIgnoredDuringExecutionPodAffinityTermNamespaceSelector" =
      {

        options = {
          "matchExpressions" = mkOption {
            description = "";
            type = types.nullOr (
              types.listOf (
                submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecS3AffinityPodAntiAffinityPreferredDuringSchedulingIgnoredDuringExecutionPodAffinityTermNamespaceSelectorMatchExpressions"
              )
            );
          };
          "matchLabels" = mkOption {
            description = "";
            type = types.nullOr (types.attrsOf types.str);
          };
        };

        config = {
          "matchExpressions" = mkOverride 1002 null;
          "matchLabels" = mkOverride 1002 null;
        };

      };
    "seaweed.seaweedfs.com.v1.SeaweedSpecS3AffinityPodAntiAffinityPreferredDuringSchedulingIgnoredDuringExecutionPodAffinityTermNamespaceSelectorMatchExpressions" =
      {

        options = {
          "key" = mkOption {
            description = "";
            type = types.str;
          };
          "operator" = mkOption {
            description = "";
            type = types.str;
          };
          "values" = mkOption {
            description = "";
            type = types.nullOr (types.listOf types.str);
          };
        };

        config = {
          "values" = mkOverride 1002 null;
        };

      };
    "seaweed.seaweedfs.com.v1.SeaweedSpecS3AffinityPodAntiAffinityRequiredDuringSchedulingIgnoredDuringExecution" =
      {

        options = {
          "labelSelector" = mkOption {
            description = "";
            type = types.nullOr (
              submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecS3AffinityPodAntiAffinityRequiredDuringSchedulingIgnoredDuringExecutionLabelSelector"
            );
          };
          "matchLabelKeys" = mkOption {
            description = "";
            type = types.nullOr (types.listOf types.str);
          };
          "mismatchLabelKeys" = mkOption {
            description = "";
            type = types.nullOr (types.listOf types.str);
          };
          "namespaceSelector" = mkOption {
            description = "";
            type = types.nullOr (
              submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecS3AffinityPodAntiAffinityRequiredDuringSchedulingIgnoredDuringExecutionNamespaceSelector"
            );
          };
          "namespaces" = mkOption {
            description = "";
            type = types.nullOr (types.listOf types.str);
          };
          "topologyKey" = mkOption {
            description = "";
            type = types.str;
          };
        };

        config = {
          "labelSelector" = mkOverride 1002 null;
          "matchLabelKeys" = mkOverride 1002 null;
          "mismatchLabelKeys" = mkOverride 1002 null;
          "namespaceSelector" = mkOverride 1002 null;
          "namespaces" = mkOverride 1002 null;
        };

      };
    "seaweed.seaweedfs.com.v1.SeaweedSpecS3AffinityPodAntiAffinityRequiredDuringSchedulingIgnoredDuringExecutionLabelSelector" =
      {

        options = {
          "matchExpressions" = mkOption {
            description = "";
            type = types.nullOr (
              types.listOf (
                submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecS3AffinityPodAntiAffinityRequiredDuringSchedulingIgnoredDuringExecutionLabelSelectorMatchExpressions"
              )
            );
          };
          "matchLabels" = mkOption {
            description = "";
            type = types.nullOr (types.attrsOf types.str);
          };
        };

        config = {
          "matchExpressions" = mkOverride 1002 null;
          "matchLabels" = mkOverride 1002 null;
        };

      };
    "seaweed.seaweedfs.com.v1.SeaweedSpecS3AffinityPodAntiAffinityRequiredDuringSchedulingIgnoredDuringExecutionLabelSelectorMatchExpressions" =
      {

        options = {
          "key" = mkOption {
            description = "";
            type = types.str;
          };
          "operator" = mkOption {
            description = "";
            type = types.str;
          };
          "values" = mkOption {
            description = "";
            type = types.nullOr (types.listOf types.str);
          };
        };

        config = {
          "values" = mkOverride 1002 null;
        };

      };
    "seaweed.seaweedfs.com.v1.SeaweedSpecS3AffinityPodAntiAffinityRequiredDuringSchedulingIgnoredDuringExecutionNamespaceSelector" =
      {

        options = {
          "matchExpressions" = mkOption {
            description = "";
            type = types.nullOr (
              types.listOf (
                submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecS3AffinityPodAntiAffinityRequiredDuringSchedulingIgnoredDuringExecutionNamespaceSelectorMatchExpressions"
              )
            );
          };
          "matchLabels" = mkOption {
            description = "";
            type = types.nullOr (types.attrsOf types.str);
          };
        };

        config = {
          "matchExpressions" = mkOverride 1002 null;
          "matchLabels" = mkOverride 1002 null;
        };

      };
    "seaweed.seaweedfs.com.v1.SeaweedSpecS3AffinityPodAntiAffinityRequiredDuringSchedulingIgnoredDuringExecutionNamespaceSelectorMatchExpressions" =
      {

        options = {
          "key" = mkOption {
            description = "";
            type = types.str;
          };
          "operator" = mkOption {
            description = "";
            type = types.str;
          };
          "values" = mkOption {
            description = "";
            type = types.nullOr (types.listOf types.str);
          };
        };

        config = {
          "values" = mkOverride 1002 null;
        };

      };
    "seaweed.seaweedfs.com.v1.SeaweedSpecS3Claims" = {

      options = {
        "name" = mkOption {
          description = "";
          type = types.str;
        };
        "request" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
      };

      config = {
        "request" = mkOverride 1002 null;
      };

    };
    "seaweed.seaweedfs.com.v1.SeaweedSpecS3ConfigSecret" = {

      options = {
        "key" = mkOption {
          description = "";
          type = types.str;
        };
        "name" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "optional" = mkOption {
          description = "";
          type = types.nullOr types.bool;
        };
      };

      config = {
        "name" = mkOverride 1002 null;
        "optional" = mkOverride 1002 null;
      };

    };
    "seaweed.seaweedfs.com.v1.SeaweedSpecS3ContainerSecurityContext" = {

      options = {
        "allowPrivilegeEscalation" = mkOption {
          description = "";
          type = types.nullOr types.bool;
        };
        "appArmorProfile" = mkOption {
          description = "";
          type = types.nullOr (
            submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecS3ContainerSecurityContextAppArmorProfile"
          );
        };
        "capabilities" = mkOption {
          description = "";
          type = types.nullOr (
            submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecS3ContainerSecurityContextCapabilities"
          );
        };
        "privileged" = mkOption {
          description = "";
          type = types.nullOr types.bool;
        };
        "procMount" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "readOnlyRootFilesystem" = mkOption {
          description = "";
          type = types.nullOr types.bool;
        };
        "runAsGroup" = mkOption {
          description = "";
          type = types.nullOr types.int;
        };
        "runAsNonRoot" = mkOption {
          description = "";
          type = types.nullOr types.bool;
        };
        "runAsUser" = mkOption {
          description = "";
          type = types.nullOr types.int;
        };
        "seLinuxOptions" = mkOption {
          description = "";
          type = types.nullOr (
            submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecS3ContainerSecurityContextSeLinuxOptions"
          );
        };
        "seccompProfile" = mkOption {
          description = "";
          type = types.nullOr (
            submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecS3ContainerSecurityContextSeccompProfile"
          );
        };
        "windowsOptions" = mkOption {
          description = "";
          type = types.nullOr (
            submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecS3ContainerSecurityContextWindowsOptions"
          );
        };
      };

      config = {
        "allowPrivilegeEscalation" = mkOverride 1002 null;
        "appArmorProfile" = mkOverride 1002 null;
        "capabilities" = mkOverride 1002 null;
        "privileged" = mkOverride 1002 null;
        "procMount" = mkOverride 1002 null;
        "readOnlyRootFilesystem" = mkOverride 1002 null;
        "runAsGroup" = mkOverride 1002 null;
        "runAsNonRoot" = mkOverride 1002 null;
        "runAsUser" = mkOverride 1002 null;
        "seLinuxOptions" = mkOverride 1002 null;
        "seccompProfile" = mkOverride 1002 null;
        "windowsOptions" = mkOverride 1002 null;
      };

    };
    "seaweed.seaweedfs.com.v1.SeaweedSpecS3ContainerSecurityContextAppArmorProfile" = {

      options = {
        "localhostProfile" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "type" = mkOption {
          description = "";
          type = types.str;
        };
      };

      config = {
        "localhostProfile" = mkOverride 1002 null;
      };

    };
    "seaweed.seaweedfs.com.v1.SeaweedSpecS3ContainerSecurityContextCapabilities" = {

      options = {
        "add" = mkOption {
          description = "";
          type = types.nullOr (types.listOf types.str);
        };
        "drop" = mkOption {
          description = "";
          type = types.nullOr (types.listOf types.str);
        };
      };

      config = {
        "add" = mkOverride 1002 null;
        "drop" = mkOverride 1002 null;
      };

    };
    "seaweed.seaweedfs.com.v1.SeaweedSpecS3ContainerSecurityContextSeLinuxOptions" = {

      options = {
        "level" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "role" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "type" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "user" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
      };

      config = {
        "level" = mkOverride 1002 null;
        "role" = mkOverride 1002 null;
        "type" = mkOverride 1002 null;
        "user" = mkOverride 1002 null;
      };

    };
    "seaweed.seaweedfs.com.v1.SeaweedSpecS3ContainerSecurityContextSeccompProfile" = {

      options = {
        "localhostProfile" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "type" = mkOption {
          description = "";
          type = types.str;
        };
      };

      config = {
        "localhostProfile" = mkOverride 1002 null;
      };

    };
    "seaweed.seaweedfs.com.v1.SeaweedSpecS3ContainerSecurityContextWindowsOptions" = {

      options = {
        "gmsaCredentialSpec" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "gmsaCredentialSpecName" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "hostProcess" = mkOption {
          description = "";
          type = types.nullOr types.bool;
        };
        "runAsUserName" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
      };

      config = {
        "gmsaCredentialSpec" = mkOverride 1002 null;
        "gmsaCredentialSpecName" = mkOverride 1002 null;
        "hostProcess" = mkOverride 1002 null;
        "runAsUserName" = mkOverride 1002 null;
      };

    };
    "seaweed.seaweedfs.com.v1.SeaweedSpecS3Env" = {

      options = {
        "name" = mkOption {
          description = "";
          type = types.str;
        };
        "value" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "valueFrom" = mkOption {
          description = "";
          type = types.nullOr (submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecS3EnvValueFrom");
        };
      };

      config = {
        "value" = mkOverride 1002 null;
        "valueFrom" = mkOverride 1002 null;
      };

    };
    "seaweed.seaweedfs.com.v1.SeaweedSpecS3EnvValueFrom" = {

      options = {
        "configMapKeyRef" = mkOption {
          description = "";
          type = types.nullOr (
            submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecS3EnvValueFromConfigMapKeyRef"
          );
        };
        "fieldRef" = mkOption {
          description = "";
          type = types.nullOr (submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecS3EnvValueFromFieldRef");
        };
        "fileKeyRef" = mkOption {
          description = "";
          type = types.nullOr (submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecS3EnvValueFromFileKeyRef");
        };
        "resourceFieldRef" = mkOption {
          description = "";
          type = types.nullOr (
            submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecS3EnvValueFromResourceFieldRef"
          );
        };
        "secretKeyRef" = mkOption {
          description = "";
          type = types.nullOr (submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecS3EnvValueFromSecretKeyRef");
        };
      };

      config = {
        "configMapKeyRef" = mkOverride 1002 null;
        "fieldRef" = mkOverride 1002 null;
        "fileKeyRef" = mkOverride 1002 null;
        "resourceFieldRef" = mkOverride 1002 null;
        "secretKeyRef" = mkOverride 1002 null;
      };

    };
    "seaweed.seaweedfs.com.v1.SeaweedSpecS3EnvValueFromConfigMapKeyRef" = {

      options = {
        "key" = mkOption {
          description = "";
          type = types.str;
        };
        "name" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "optional" = mkOption {
          description = "";
          type = types.nullOr types.bool;
        };
      };

      config = {
        "name" = mkOverride 1002 null;
        "optional" = mkOverride 1002 null;
      };

    };
    "seaweed.seaweedfs.com.v1.SeaweedSpecS3EnvValueFromFieldRef" = {

      options = {
        "apiVersion" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "fieldPath" = mkOption {
          description = "";
          type = types.str;
        };
      };

      config = {
        "apiVersion" = mkOverride 1002 null;
      };

    };
    "seaweed.seaweedfs.com.v1.SeaweedSpecS3EnvValueFromFileKeyRef" = {

      options = {
        "key" = mkOption {
          description = "";
          type = types.str;
        };
        "optional" = mkOption {
          description = "";
          type = types.nullOr types.bool;
        };
        "path" = mkOption {
          description = "";
          type = types.str;
        };
        "volumeName" = mkOption {
          description = "";
          type = types.str;
        };
      };

      config = {
        "optional" = mkOverride 1002 null;
      };

    };
    "seaweed.seaweedfs.com.v1.SeaweedSpecS3EnvValueFromResourceFieldRef" = {

      options = {
        "containerName" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "divisor" = mkOption {
          description = "";
          type = types.nullOr (types.either types.int types.str);
        };
        "resource" = mkOption {
          description = "";
          type = types.str;
        };
      };

      config = {
        "containerName" = mkOverride 1002 null;
        "divisor" = mkOverride 1002 null;
      };

    };
    "seaweed.seaweedfs.com.v1.SeaweedSpecS3EnvValueFromSecretKeyRef" = {

      options = {
        "key" = mkOption {
          description = "";
          type = types.str;
        };
        "name" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "optional" = mkOption {
          description = "";
          type = types.nullOr types.bool;
        };
      };

      config = {
        "name" = mkOverride 1002 null;
        "optional" = mkOverride 1002 null;
      };

    };
    "seaweed.seaweedfs.com.v1.SeaweedSpecS3ImagePullSecrets" = {

      options = {
        "name" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
      };

      config = {
        "name" = mkOverride 1002 null;
      };

    };
    "seaweed.seaweedfs.com.v1.SeaweedSpecS3Ingress" = {

      options = {
        "annotations" = mkOption {
          description = "";
          type = types.nullOr (types.attrsOf types.str);
        };
        "className" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "enabled" = mkOption {
          description = "";
          type = types.nullOr types.bool;
        };
        "host" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "path" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "tls" = mkOption {
          description = "";
          type = types.nullOr (types.listOf (submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecS3IngressTls"));
        };
      };

      config = {
        "annotations" = mkOverride 1002 null;
        "className" = mkOverride 1002 null;
        "enabled" = mkOverride 1002 null;
        "host" = mkOverride 1002 null;
        "path" = mkOverride 1002 null;
        "tls" = mkOverride 1002 null;
      };

    };
    "seaweed.seaweedfs.com.v1.SeaweedSpecS3IngressTls" = {

      options = {
        "hosts" = mkOption {
          description = "";
          type = types.nullOr (types.listOf types.str);
        };
        "secretName" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
      };

      config = {
        "hosts" = mkOverride 1002 null;
        "secretName" = mkOverride 1002 null;
      };

    };
    "seaweed.seaweedfs.com.v1.SeaweedSpecS3LivenessProbe" = {

      options = {
        "failureThreshold" = mkOption {
          description = "";
          type = types.nullOr types.int;
        };
        "initialDelaySeconds" = mkOption {
          description = "";
          type = types.nullOr types.int;
        };
        "periodSeconds" = mkOption {
          description = "";
          type = types.nullOr types.int;
        };
        "timeoutSeconds" = mkOption {
          description = "";
          type = types.nullOr types.int;
        };
      };

      config = {
        "failureThreshold" = mkOverride 1002 null;
        "initialDelaySeconds" = mkOverride 1002 null;
        "periodSeconds" = mkOverride 1002 null;
        "timeoutSeconds" = mkOverride 1002 null;
      };

    };
    "seaweed.seaweedfs.com.v1.SeaweedSpecS3PodSecurityContext" = {

      options = {
        "appArmorProfile" = mkOption {
          description = "";
          type = types.nullOr (
            submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecS3PodSecurityContextAppArmorProfile"
          );
        };
        "fsGroup" = mkOption {
          description = "";
          type = types.nullOr types.int;
        };
        "fsGroupChangePolicy" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "runAsGroup" = mkOption {
          description = "";
          type = types.nullOr types.int;
        };
        "runAsNonRoot" = mkOption {
          description = "";
          type = types.nullOr types.bool;
        };
        "runAsUser" = mkOption {
          description = "";
          type = types.nullOr types.int;
        };
        "seLinuxChangePolicy" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "seLinuxOptions" = mkOption {
          description = "";
          type = types.nullOr (
            submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecS3PodSecurityContextSeLinuxOptions"
          );
        };
        "seccompProfile" = mkOption {
          description = "";
          type = types.nullOr (
            submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecS3PodSecurityContextSeccompProfile"
          );
        };
        "supplementalGroups" = mkOption {
          description = "";
          type = types.nullOr (types.listOf types.int);
        };
        "supplementalGroupsPolicy" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "sysctls" = mkOption {
          description = "";
          type = types.nullOr (
            coerceAttrsOfSubmodulesToListByKey "seaweed.seaweedfs.com.v1.SeaweedSpecS3PodSecurityContextSysctls"
              "name"
              [ ]
          );
          apply = attrsToList;
        };
        "windowsOptions" = mkOption {
          description = "";
          type = types.nullOr (
            submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecS3PodSecurityContextWindowsOptions"
          );
        };
      };

      config = {
        "appArmorProfile" = mkOverride 1002 null;
        "fsGroup" = mkOverride 1002 null;
        "fsGroupChangePolicy" = mkOverride 1002 null;
        "runAsGroup" = mkOverride 1002 null;
        "runAsNonRoot" = mkOverride 1002 null;
        "runAsUser" = mkOverride 1002 null;
        "seLinuxChangePolicy" = mkOverride 1002 null;
        "seLinuxOptions" = mkOverride 1002 null;
        "seccompProfile" = mkOverride 1002 null;
        "supplementalGroups" = mkOverride 1002 null;
        "supplementalGroupsPolicy" = mkOverride 1002 null;
        "sysctls" = mkOverride 1002 null;
        "windowsOptions" = mkOverride 1002 null;
      };

    };
    "seaweed.seaweedfs.com.v1.SeaweedSpecS3PodSecurityContextAppArmorProfile" = {

      options = {
        "localhostProfile" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "type" = mkOption {
          description = "";
          type = types.str;
        };
      };

      config = {
        "localhostProfile" = mkOverride 1002 null;
      };

    };
    "seaweed.seaweedfs.com.v1.SeaweedSpecS3PodSecurityContextSeLinuxOptions" = {

      options = {
        "level" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "role" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "type" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "user" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
      };

      config = {
        "level" = mkOverride 1002 null;
        "role" = mkOverride 1002 null;
        "type" = mkOverride 1002 null;
        "user" = mkOverride 1002 null;
      };

    };
    "seaweed.seaweedfs.com.v1.SeaweedSpecS3PodSecurityContextSeccompProfile" = {

      options = {
        "localhostProfile" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "type" = mkOption {
          description = "";
          type = types.str;
        };
      };

      config = {
        "localhostProfile" = mkOverride 1002 null;
      };

    };
    "seaweed.seaweedfs.com.v1.SeaweedSpecS3PodSecurityContextSysctls" = {

      options = {
        "name" = mkOption {
          description = "";
          type = types.str;
        };
        "value" = mkOption {
          description = "";
          type = types.str;
        };
      };

      config = { };

    };
    "seaweed.seaweedfs.com.v1.SeaweedSpecS3PodSecurityContextWindowsOptions" = {

      options = {
        "gmsaCredentialSpec" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "gmsaCredentialSpecName" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "hostProcess" = mkOption {
          description = "";
          type = types.nullOr types.bool;
        };
        "runAsUserName" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
      };

      config = {
        "gmsaCredentialSpec" = mkOverride 1002 null;
        "gmsaCredentialSpecName" = mkOverride 1002 null;
        "hostProcess" = mkOverride 1002 null;
        "runAsUserName" = mkOverride 1002 null;
      };

    };
    "seaweed.seaweedfs.com.v1.SeaweedSpecS3ReadinessProbe" = {

      options = {
        "failureThreshold" = mkOption {
          description = "";
          type = types.nullOr types.int;
        };
        "initialDelaySeconds" = mkOption {
          description = "";
          type = types.nullOr types.int;
        };
        "periodSeconds" = mkOption {
          description = "";
          type = types.nullOr types.int;
        };
        "successThreshold" = mkOption {
          description = "";
          type = types.nullOr types.int;
        };
        "timeoutSeconds" = mkOption {
          description = "";
          type = types.nullOr types.int;
        };
      };

      config = {
        "failureThreshold" = mkOverride 1002 null;
        "initialDelaySeconds" = mkOverride 1002 null;
        "periodSeconds" = mkOverride 1002 null;
        "successThreshold" = mkOverride 1002 null;
        "timeoutSeconds" = mkOverride 1002 null;
      };

    };
    "seaweed.seaweedfs.com.v1.SeaweedSpecS3Service" = {

      options = {
        "annotations" = mkOption {
          description = "";
          type = types.nullOr (types.attrsOf types.str);
        };
        "clusterIP" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "loadBalancerIP" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "type" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
      };

      config = {
        "annotations" = mkOverride 1002 null;
        "clusterIP" = mkOverride 1002 null;
        "loadBalancerIP" = mkOverride 1002 null;
        "type" = mkOverride 1002 null;
      };

    };
    "seaweed.seaweedfs.com.v1.SeaweedSpecS3Tolerations" = {

      options = {
        "effect" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "key" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "operator" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "tolerationSeconds" = mkOption {
          description = "";
          type = types.nullOr types.int;
        };
        "value" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
      };

      config = {
        "effect" = mkOverride 1002 null;
        "key" = mkOverride 1002 null;
        "operator" = mkOverride 1002 null;
        "tolerationSeconds" = mkOverride 1002 null;
        "value" = mkOverride 1002 null;
      };

    };
    "seaweed.seaweedfs.com.v1.SeaweedSpecS3VolumeMounts" = {

      options = {
        "mountPath" = mkOption {
          description = "";
          type = types.str;
        };
        "mountPropagation" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "name" = mkOption {
          description = "";
          type = types.str;
        };
        "readOnly" = mkOption {
          description = "";
          type = types.nullOr types.bool;
        };
        "recursiveReadOnly" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "subPath" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "subPathExpr" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
      };

      config = {
        "mountPropagation" = mkOverride 1002 null;
        "readOnly" = mkOverride 1002 null;
        "recursiveReadOnly" = mkOverride 1002 null;
        "subPath" = mkOverride 1002 null;
        "subPathExpr" = mkOverride 1002 null;
      };

    };
    "seaweed.seaweedfs.com.v1.SeaweedSpecS3Volumes" = {

      options = {
        "awsElasticBlockStore" = mkOption {
          description = "";
          type = types.nullOr (
            submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecS3VolumesAwsElasticBlockStore"
          );
        };
        "azureDisk" = mkOption {
          description = "";
          type = types.nullOr (submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecS3VolumesAzureDisk");
        };
        "azureFile" = mkOption {
          description = "";
          type = types.nullOr (submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecS3VolumesAzureFile");
        };
        "cephfs" = mkOption {
          description = "";
          type = types.nullOr (submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecS3VolumesCephfs");
        };
        "cinder" = mkOption {
          description = "";
          type = types.nullOr (submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecS3VolumesCinder");
        };
        "configMap" = mkOption {
          description = "";
          type = types.nullOr (submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecS3VolumesConfigMap");
        };
        "csi" = mkOption {
          description = "";
          type = types.nullOr (submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecS3VolumesCsi");
        };
        "downwardAPI" = mkOption {
          description = "";
          type = types.nullOr (submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecS3VolumesDownwardAPI");
        };
        "emptyDir" = mkOption {
          description = "";
          type = types.nullOr (submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecS3VolumesEmptyDir");
        };
        "ephemeral" = mkOption {
          description = "";
          type = types.nullOr (submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecS3VolumesEphemeral");
        };
        "fc" = mkOption {
          description = "";
          type = types.nullOr (submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecS3VolumesFc");
        };
        "flexVolume" = mkOption {
          description = "";
          type = types.nullOr (submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecS3VolumesFlexVolume");
        };
        "flocker" = mkOption {
          description = "";
          type = types.nullOr (submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecS3VolumesFlocker");
        };
        "gcePersistentDisk" = mkOption {
          description = "";
          type = types.nullOr (submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecS3VolumesGcePersistentDisk");
        };
        "gitRepo" = mkOption {
          description = "";
          type = types.nullOr (submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecS3VolumesGitRepo");
        };
        "glusterfs" = mkOption {
          description = "";
          type = types.nullOr (submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecS3VolumesGlusterfs");
        };
        "hostPath" = mkOption {
          description = "";
          type = types.nullOr (submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecS3VolumesHostPath");
        };
        "image" = mkOption {
          description = "";
          type = types.nullOr (submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecS3VolumesImage");
        };
        "iscsi" = mkOption {
          description = "";
          type = types.nullOr (submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecS3VolumesIscsi");
        };
        "name" = mkOption {
          description = "";
          type = types.str;
        };
        "nfs" = mkOption {
          description = "";
          type = types.nullOr (submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecS3VolumesNfs");
        };
        "persistentVolumeClaim" = mkOption {
          description = "";
          type = types.nullOr (
            submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecS3VolumesPersistentVolumeClaim"
          );
        };
        "photonPersistentDisk" = mkOption {
          description = "";
          type = types.nullOr (
            submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecS3VolumesPhotonPersistentDisk"
          );
        };
        "portworxVolume" = mkOption {
          description = "";
          type = types.nullOr (submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecS3VolumesPortworxVolume");
        };
        "projected" = mkOption {
          description = "";
          type = types.nullOr (submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecS3VolumesProjected");
        };
        "quobyte" = mkOption {
          description = "";
          type = types.nullOr (submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecS3VolumesQuobyte");
        };
        "rbd" = mkOption {
          description = "";
          type = types.nullOr (submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecS3VolumesRbd");
        };
        "scaleIO" = mkOption {
          description = "";
          type = types.nullOr (submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecS3VolumesScaleIO");
        };
        "secret" = mkOption {
          description = "";
          type = types.nullOr (submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecS3VolumesSecret");
        };
        "storageos" = mkOption {
          description = "";
          type = types.nullOr (submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecS3VolumesStorageos");
        };
        "vsphereVolume" = mkOption {
          description = "";
          type = types.nullOr (submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecS3VolumesVsphereVolume");
        };
      };

      config = {
        "awsElasticBlockStore" = mkOverride 1002 null;
        "azureDisk" = mkOverride 1002 null;
        "azureFile" = mkOverride 1002 null;
        "cephfs" = mkOverride 1002 null;
        "cinder" = mkOverride 1002 null;
        "configMap" = mkOverride 1002 null;
        "csi" = mkOverride 1002 null;
        "downwardAPI" = mkOverride 1002 null;
        "emptyDir" = mkOverride 1002 null;
        "ephemeral" = mkOverride 1002 null;
        "fc" = mkOverride 1002 null;
        "flexVolume" = mkOverride 1002 null;
        "flocker" = mkOverride 1002 null;
        "gcePersistentDisk" = mkOverride 1002 null;
        "gitRepo" = mkOverride 1002 null;
        "glusterfs" = mkOverride 1002 null;
        "hostPath" = mkOverride 1002 null;
        "image" = mkOverride 1002 null;
        "iscsi" = mkOverride 1002 null;
        "nfs" = mkOverride 1002 null;
        "persistentVolumeClaim" = mkOverride 1002 null;
        "photonPersistentDisk" = mkOverride 1002 null;
        "portworxVolume" = mkOverride 1002 null;
        "projected" = mkOverride 1002 null;
        "quobyte" = mkOverride 1002 null;
        "rbd" = mkOverride 1002 null;
        "scaleIO" = mkOverride 1002 null;
        "secret" = mkOverride 1002 null;
        "storageos" = mkOverride 1002 null;
        "vsphereVolume" = mkOverride 1002 null;
      };

    };
    "seaweed.seaweedfs.com.v1.SeaweedSpecS3VolumesAwsElasticBlockStore" = {

      options = {
        "fsType" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "partition" = mkOption {
          description = "";
          type = types.nullOr types.int;
        };
        "readOnly" = mkOption {
          description = "";
          type = types.nullOr types.bool;
        };
        "volumeID" = mkOption {
          description = "";
          type = types.str;
        };
      };

      config = {
        "fsType" = mkOverride 1002 null;
        "partition" = mkOverride 1002 null;
        "readOnly" = mkOverride 1002 null;
      };

    };
    "seaweed.seaweedfs.com.v1.SeaweedSpecS3VolumesAzureDisk" = {

      options = {
        "cachingMode" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "diskName" = mkOption {
          description = "";
          type = types.str;
        };
        "diskURI" = mkOption {
          description = "";
          type = types.str;
        };
        "fsType" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "kind" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "readOnly" = mkOption {
          description = "";
          type = types.nullOr types.bool;
        };
      };

      config = {
        "cachingMode" = mkOverride 1002 null;
        "fsType" = mkOverride 1002 null;
        "kind" = mkOverride 1002 null;
        "readOnly" = mkOverride 1002 null;
      };

    };
    "seaweed.seaweedfs.com.v1.SeaweedSpecS3VolumesAzureFile" = {

      options = {
        "readOnly" = mkOption {
          description = "";
          type = types.nullOr types.bool;
        };
        "secretName" = mkOption {
          description = "";
          type = types.str;
        };
        "shareName" = mkOption {
          description = "";
          type = types.str;
        };
      };

      config = {
        "readOnly" = mkOverride 1002 null;
      };

    };
    "seaweed.seaweedfs.com.v1.SeaweedSpecS3VolumesCephfs" = {

      options = {
        "monitors" = mkOption {
          description = "";
          type = types.listOf types.str;
        };
        "path" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "readOnly" = mkOption {
          description = "";
          type = types.nullOr types.bool;
        };
        "secretFile" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "secretRef" = mkOption {
          description = "";
          type = types.nullOr (submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecS3VolumesCephfsSecretRef");
        };
        "user" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
      };

      config = {
        "path" = mkOverride 1002 null;
        "readOnly" = mkOverride 1002 null;
        "secretFile" = mkOverride 1002 null;
        "secretRef" = mkOverride 1002 null;
        "user" = mkOverride 1002 null;
      };

    };
    "seaweed.seaweedfs.com.v1.SeaweedSpecS3VolumesCephfsSecretRef" = {

      options = {
        "name" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
      };

      config = {
        "name" = mkOverride 1002 null;
      };

    };
    "seaweed.seaweedfs.com.v1.SeaweedSpecS3VolumesCinder" = {

      options = {
        "fsType" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "readOnly" = mkOption {
          description = "";
          type = types.nullOr types.bool;
        };
        "secretRef" = mkOption {
          description = "";
          type = types.nullOr (submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecS3VolumesCinderSecretRef");
        };
        "volumeID" = mkOption {
          description = "";
          type = types.str;
        };
      };

      config = {
        "fsType" = mkOverride 1002 null;
        "readOnly" = mkOverride 1002 null;
        "secretRef" = mkOverride 1002 null;
      };

    };
    "seaweed.seaweedfs.com.v1.SeaweedSpecS3VolumesCinderSecretRef" = {

      options = {
        "name" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
      };

      config = {
        "name" = mkOverride 1002 null;
      };

    };
    "seaweed.seaweedfs.com.v1.SeaweedSpecS3VolumesConfigMap" = {

      options = {
        "defaultMode" = mkOption {
          description = "";
          type = types.nullOr types.int;
        };
        "items" = mkOption {
          description = "";
          type = types.nullOr (
            types.listOf (submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecS3VolumesConfigMapItems")
          );
        };
        "name" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "optional" = mkOption {
          description = "";
          type = types.nullOr types.bool;
        };
      };

      config = {
        "defaultMode" = mkOverride 1002 null;
        "items" = mkOverride 1002 null;
        "name" = mkOverride 1002 null;
        "optional" = mkOverride 1002 null;
      };

    };
    "seaweed.seaweedfs.com.v1.SeaweedSpecS3VolumesConfigMapItems" = {

      options = {
        "key" = mkOption {
          description = "";
          type = types.str;
        };
        "mode" = mkOption {
          description = "";
          type = types.nullOr types.int;
        };
        "path" = mkOption {
          description = "";
          type = types.str;
        };
      };

      config = {
        "mode" = mkOverride 1002 null;
      };

    };
    "seaweed.seaweedfs.com.v1.SeaweedSpecS3VolumesCsi" = {

      options = {
        "driver" = mkOption {
          description = "";
          type = types.str;
        };
        "fsType" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "nodePublishSecretRef" = mkOption {
          description = "";
          type = types.nullOr (
            submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecS3VolumesCsiNodePublishSecretRef"
          );
        };
        "readOnly" = mkOption {
          description = "";
          type = types.nullOr types.bool;
        };
        "volumeAttributes" = mkOption {
          description = "";
          type = types.nullOr (types.attrsOf types.str);
        };
      };

      config = {
        "fsType" = mkOverride 1002 null;
        "nodePublishSecretRef" = mkOverride 1002 null;
        "readOnly" = mkOverride 1002 null;
        "volumeAttributes" = mkOverride 1002 null;
      };

    };
    "seaweed.seaweedfs.com.v1.SeaweedSpecS3VolumesCsiNodePublishSecretRef" = {

      options = {
        "name" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
      };

      config = {
        "name" = mkOverride 1002 null;
      };

    };
    "seaweed.seaweedfs.com.v1.SeaweedSpecS3VolumesDownwardAPI" = {

      options = {
        "defaultMode" = mkOption {
          description = "";
          type = types.nullOr types.int;
        };
        "items" = mkOption {
          description = "";
          type = types.nullOr (
            types.listOf (submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecS3VolumesDownwardAPIItems")
          );
        };
      };

      config = {
        "defaultMode" = mkOverride 1002 null;
        "items" = mkOverride 1002 null;
      };

    };
    "seaweed.seaweedfs.com.v1.SeaweedSpecS3VolumesDownwardAPIItems" = {

      options = {
        "fieldRef" = mkOption {
          description = "";
          type = types.nullOr (
            submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecS3VolumesDownwardAPIItemsFieldRef"
          );
        };
        "mode" = mkOption {
          description = "";
          type = types.nullOr types.int;
        };
        "path" = mkOption {
          description = "";
          type = types.str;
        };
        "resourceFieldRef" = mkOption {
          description = "";
          type = types.nullOr (
            submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecS3VolumesDownwardAPIItemsResourceFieldRef"
          );
        };
      };

      config = {
        "fieldRef" = mkOverride 1002 null;
        "mode" = mkOverride 1002 null;
        "resourceFieldRef" = mkOverride 1002 null;
      };

    };
    "seaweed.seaweedfs.com.v1.SeaweedSpecS3VolumesDownwardAPIItemsFieldRef" = {

      options = {
        "apiVersion" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "fieldPath" = mkOption {
          description = "";
          type = types.str;
        };
      };

      config = {
        "apiVersion" = mkOverride 1002 null;
      };

    };
    "seaweed.seaweedfs.com.v1.SeaweedSpecS3VolumesDownwardAPIItemsResourceFieldRef" = {

      options = {
        "containerName" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "divisor" = mkOption {
          description = "";
          type = types.nullOr (types.either types.int types.str);
        };
        "resource" = mkOption {
          description = "";
          type = types.str;
        };
      };

      config = {
        "containerName" = mkOverride 1002 null;
        "divisor" = mkOverride 1002 null;
      };

    };
    "seaweed.seaweedfs.com.v1.SeaweedSpecS3VolumesEmptyDir" = {

      options = {
        "medium" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "sizeLimit" = mkOption {
          description = "";
          type = types.nullOr (types.either types.int types.str);
        };
      };

      config = {
        "medium" = mkOverride 1002 null;
        "sizeLimit" = mkOverride 1002 null;
      };

    };
    "seaweed.seaweedfs.com.v1.SeaweedSpecS3VolumesEphemeral" = {

      options = {
        "volumeClaimTemplate" = mkOption {
          description = "";
          type = types.nullOr (
            submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecS3VolumesEphemeralVolumeClaimTemplate"
          );
        };
      };

      config = {
        "volumeClaimTemplate" = mkOverride 1002 null;
      };

    };
    "seaweed.seaweedfs.com.v1.SeaweedSpecS3VolumesEphemeralVolumeClaimTemplate" = {

      options = {
        "metadata" = mkOption {
          description = "";
          type = types.nullOr types.attrs;
        };
        "spec" = mkOption {
          description = "";
          type = submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecS3VolumesEphemeralVolumeClaimTemplateSpec";
        };
      };

      config = {
        "metadata" = mkOverride 1002 null;
      };

    };
    "seaweed.seaweedfs.com.v1.SeaweedSpecS3VolumesEphemeralVolumeClaimTemplateSpec" = {

      options = {
        "accessModes" = mkOption {
          description = "";
          type = types.nullOr (types.listOf types.str);
        };
        "dataSource" = mkOption {
          description = "";
          type = types.nullOr (
            submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecS3VolumesEphemeralVolumeClaimTemplateSpecDataSource"
          );
        };
        "dataSourceRef" = mkOption {
          description = "";
          type = types.nullOr (
            submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecS3VolumesEphemeralVolumeClaimTemplateSpecDataSourceRef"
          );
        };
        "resources" = mkOption {
          description = "";
          type = types.nullOr (
            submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecS3VolumesEphemeralVolumeClaimTemplateSpecResources"
          );
        };
        "selector" = mkOption {
          description = "";
          type = types.nullOr (
            submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecS3VolumesEphemeralVolumeClaimTemplateSpecSelector"
          );
        };
        "storageClassName" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "volumeAttributesClassName" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "volumeMode" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "volumeName" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
      };

      config = {
        "accessModes" = mkOverride 1002 null;
        "dataSource" = mkOverride 1002 null;
        "dataSourceRef" = mkOverride 1002 null;
        "resources" = mkOverride 1002 null;
        "selector" = mkOverride 1002 null;
        "storageClassName" = mkOverride 1002 null;
        "volumeAttributesClassName" = mkOverride 1002 null;
        "volumeMode" = mkOverride 1002 null;
        "volumeName" = mkOverride 1002 null;
      };

    };
    "seaweed.seaweedfs.com.v1.SeaweedSpecS3VolumesEphemeralVolumeClaimTemplateSpecDataSource" = {

      options = {
        "apiGroup" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "kind" = mkOption {
          description = "";
          type = types.str;
        };
        "name" = mkOption {
          description = "";
          type = types.str;
        };
      };

      config = {
        "apiGroup" = mkOverride 1002 null;
      };

    };
    "seaweed.seaweedfs.com.v1.SeaweedSpecS3VolumesEphemeralVolumeClaimTemplateSpecDataSourceRef" = {

      options = {
        "apiGroup" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "kind" = mkOption {
          description = "";
          type = types.str;
        };
        "name" = mkOption {
          description = "";
          type = types.str;
        };
        "namespace" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
      };

      config = {
        "apiGroup" = mkOverride 1002 null;
        "namespace" = mkOverride 1002 null;
      };

    };
    "seaweed.seaweedfs.com.v1.SeaweedSpecS3VolumesEphemeralVolumeClaimTemplateSpecResources" = {

      options = {
        "limits" = mkOption {
          description = "";
          type = types.nullOr (types.attrsOf (types.either types.int types.str));
        };
        "requests" = mkOption {
          description = "";
          type = types.nullOr (types.attrsOf (types.either types.int types.str));
        };
      };

      config = {
        "limits" = mkOverride 1002 null;
        "requests" = mkOverride 1002 null;
      };

    };
    "seaweed.seaweedfs.com.v1.SeaweedSpecS3VolumesEphemeralVolumeClaimTemplateSpecSelector" = {

      options = {
        "matchExpressions" = mkOption {
          description = "";
          type = types.nullOr (
            types.listOf (
              submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecS3VolumesEphemeralVolumeClaimTemplateSpecSelectorMatchExpressions"
            )
          );
        };
        "matchLabels" = mkOption {
          description = "";
          type = types.nullOr (types.attrsOf types.str);
        };
      };

      config = {
        "matchExpressions" = mkOverride 1002 null;
        "matchLabels" = mkOverride 1002 null;
      };

    };
    "seaweed.seaweedfs.com.v1.SeaweedSpecS3VolumesEphemeralVolumeClaimTemplateSpecSelectorMatchExpressions" =
      {

        options = {
          "key" = mkOption {
            description = "";
            type = types.str;
          };
          "operator" = mkOption {
            description = "";
            type = types.str;
          };
          "values" = mkOption {
            description = "";
            type = types.nullOr (types.listOf types.str);
          };
        };

        config = {
          "values" = mkOverride 1002 null;
        };

      };
    "seaweed.seaweedfs.com.v1.SeaweedSpecS3VolumesFc" = {

      options = {
        "fsType" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "lun" = mkOption {
          description = "";
          type = types.nullOr types.int;
        };
        "readOnly" = mkOption {
          description = "";
          type = types.nullOr types.bool;
        };
        "targetWWNs" = mkOption {
          description = "";
          type = types.nullOr (types.listOf types.str);
        };
        "wwids" = mkOption {
          description = "";
          type = types.nullOr (types.listOf types.str);
        };
      };

      config = {
        "fsType" = mkOverride 1002 null;
        "lun" = mkOverride 1002 null;
        "readOnly" = mkOverride 1002 null;
        "targetWWNs" = mkOverride 1002 null;
        "wwids" = mkOverride 1002 null;
      };

    };
    "seaweed.seaweedfs.com.v1.SeaweedSpecS3VolumesFlexVolume" = {

      options = {
        "driver" = mkOption {
          description = "";
          type = types.str;
        };
        "fsType" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "options" = mkOption {
          description = "";
          type = types.nullOr (types.attrsOf types.str);
        };
        "readOnly" = mkOption {
          description = "";
          type = types.nullOr types.bool;
        };
        "secretRef" = mkOption {
          description = "";
          type = types.nullOr (
            submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecS3VolumesFlexVolumeSecretRef"
          );
        };
      };

      config = {
        "fsType" = mkOverride 1002 null;
        "options" = mkOverride 1002 null;
        "readOnly" = mkOverride 1002 null;
        "secretRef" = mkOverride 1002 null;
      };

    };
    "seaweed.seaweedfs.com.v1.SeaweedSpecS3VolumesFlexVolumeSecretRef" = {

      options = {
        "name" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
      };

      config = {
        "name" = mkOverride 1002 null;
      };

    };
    "seaweed.seaweedfs.com.v1.SeaweedSpecS3VolumesFlocker" = {

      options = {
        "datasetName" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "datasetUUID" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
      };

      config = {
        "datasetName" = mkOverride 1002 null;
        "datasetUUID" = mkOverride 1002 null;
      };

    };
    "seaweed.seaweedfs.com.v1.SeaweedSpecS3VolumesGcePersistentDisk" = {

      options = {
        "fsType" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "partition" = mkOption {
          description = "";
          type = types.nullOr types.int;
        };
        "pdName" = mkOption {
          description = "";
          type = types.str;
        };
        "readOnly" = mkOption {
          description = "";
          type = types.nullOr types.bool;
        };
      };

      config = {
        "fsType" = mkOverride 1002 null;
        "partition" = mkOverride 1002 null;
        "readOnly" = mkOverride 1002 null;
      };

    };
    "seaweed.seaweedfs.com.v1.SeaweedSpecS3VolumesGitRepo" = {

      options = {
        "directory" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "repository" = mkOption {
          description = "";
          type = types.str;
        };
        "revision" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
      };

      config = {
        "directory" = mkOverride 1002 null;
        "revision" = mkOverride 1002 null;
      };

    };
    "seaweed.seaweedfs.com.v1.SeaweedSpecS3VolumesGlusterfs" = {

      options = {
        "endpoints" = mkOption {
          description = "";
          type = types.str;
        };
        "path" = mkOption {
          description = "";
          type = types.str;
        };
        "readOnly" = mkOption {
          description = "";
          type = types.nullOr types.bool;
        };
      };

      config = {
        "readOnly" = mkOverride 1002 null;
      };

    };
    "seaweed.seaweedfs.com.v1.SeaweedSpecS3VolumesHostPath" = {

      options = {
        "path" = mkOption {
          description = "";
          type = types.str;
        };
        "type" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
      };

      config = {
        "type" = mkOverride 1002 null;
      };

    };
    "seaweed.seaweedfs.com.v1.SeaweedSpecS3VolumesImage" = {

      options = {
        "pullPolicy" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "reference" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
      };

      config = {
        "pullPolicy" = mkOverride 1002 null;
        "reference" = mkOverride 1002 null;
      };

    };
    "seaweed.seaweedfs.com.v1.SeaweedSpecS3VolumesIscsi" = {

      options = {
        "chapAuthDiscovery" = mkOption {
          description = "";
          type = types.nullOr types.bool;
        };
        "chapAuthSession" = mkOption {
          description = "";
          type = types.nullOr types.bool;
        };
        "fsType" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "initiatorName" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "iqn" = mkOption {
          description = "";
          type = types.str;
        };
        "iscsiInterface" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "lun" = mkOption {
          description = "";
          type = types.int;
        };
        "portals" = mkOption {
          description = "";
          type = types.nullOr (types.listOf types.str);
        };
        "readOnly" = mkOption {
          description = "";
          type = types.nullOr types.bool;
        };
        "secretRef" = mkOption {
          description = "";
          type = types.nullOr (submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecS3VolumesIscsiSecretRef");
        };
        "targetPortal" = mkOption {
          description = "";
          type = types.str;
        };
      };

      config = {
        "chapAuthDiscovery" = mkOverride 1002 null;
        "chapAuthSession" = mkOverride 1002 null;
        "fsType" = mkOverride 1002 null;
        "initiatorName" = mkOverride 1002 null;
        "iscsiInterface" = mkOverride 1002 null;
        "portals" = mkOverride 1002 null;
        "readOnly" = mkOverride 1002 null;
        "secretRef" = mkOverride 1002 null;
      };

    };
    "seaweed.seaweedfs.com.v1.SeaweedSpecS3VolumesIscsiSecretRef" = {

      options = {
        "name" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
      };

      config = {
        "name" = mkOverride 1002 null;
      };

    };
    "seaweed.seaweedfs.com.v1.SeaweedSpecS3VolumesNfs" = {

      options = {
        "path" = mkOption {
          description = "";
          type = types.str;
        };
        "readOnly" = mkOption {
          description = "";
          type = types.nullOr types.bool;
        };
        "server" = mkOption {
          description = "";
          type = types.str;
        };
      };

      config = {
        "readOnly" = mkOverride 1002 null;
      };

    };
    "seaweed.seaweedfs.com.v1.SeaweedSpecS3VolumesPersistentVolumeClaim" = {

      options = {
        "claimName" = mkOption {
          description = "";
          type = types.str;
        };
        "readOnly" = mkOption {
          description = "";
          type = types.nullOr types.bool;
        };
      };

      config = {
        "readOnly" = mkOverride 1002 null;
      };

    };
    "seaweed.seaweedfs.com.v1.SeaweedSpecS3VolumesPhotonPersistentDisk" = {

      options = {
        "fsType" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "pdID" = mkOption {
          description = "";
          type = types.str;
        };
      };

      config = {
        "fsType" = mkOverride 1002 null;
      };

    };
    "seaweed.seaweedfs.com.v1.SeaweedSpecS3VolumesPortworxVolume" = {

      options = {
        "fsType" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "readOnly" = mkOption {
          description = "";
          type = types.nullOr types.bool;
        };
        "volumeID" = mkOption {
          description = "";
          type = types.str;
        };
      };

      config = {
        "fsType" = mkOverride 1002 null;
        "readOnly" = mkOverride 1002 null;
      };

    };
    "seaweed.seaweedfs.com.v1.SeaweedSpecS3VolumesProjected" = {

      options = {
        "defaultMode" = mkOption {
          description = "";
          type = types.nullOr types.int;
        };
        "sources" = mkOption {
          description = "";
          type = types.nullOr (
            types.listOf (submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecS3VolumesProjectedSources")
          );
        };
      };

      config = {
        "defaultMode" = mkOverride 1002 null;
        "sources" = mkOverride 1002 null;
      };

    };
    "seaweed.seaweedfs.com.v1.SeaweedSpecS3VolumesProjectedSources" = {

      options = {
        "clusterTrustBundle" = mkOption {
          description = "";
          type = types.nullOr (
            submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecS3VolumesProjectedSourcesClusterTrustBundle"
          );
        };
        "configMap" = mkOption {
          description = "";
          type = types.nullOr (
            submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecS3VolumesProjectedSourcesConfigMap"
          );
        };
        "downwardAPI" = mkOption {
          description = "";
          type = types.nullOr (
            submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecS3VolumesProjectedSourcesDownwardAPI"
          );
        };
        "podCertificate" = mkOption {
          description = "";
          type = types.nullOr (
            submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecS3VolumesProjectedSourcesPodCertificate"
          );
        };
        "secret" = mkOption {
          description = "";
          type = types.nullOr (
            submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecS3VolumesProjectedSourcesSecret"
          );
        };
        "serviceAccountToken" = mkOption {
          description = "";
          type = types.nullOr (
            submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecS3VolumesProjectedSourcesServiceAccountToken"
          );
        };
      };

      config = {
        "clusterTrustBundle" = mkOverride 1002 null;
        "configMap" = mkOverride 1002 null;
        "downwardAPI" = mkOverride 1002 null;
        "podCertificate" = mkOverride 1002 null;
        "secret" = mkOverride 1002 null;
        "serviceAccountToken" = mkOverride 1002 null;
      };

    };
    "seaweed.seaweedfs.com.v1.SeaweedSpecS3VolumesProjectedSourcesClusterTrustBundle" = {

      options = {
        "labelSelector" = mkOption {
          description = "";
          type = types.nullOr (
            submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecS3VolumesProjectedSourcesClusterTrustBundleLabelSelector"
          );
        };
        "name" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "optional" = mkOption {
          description = "";
          type = types.nullOr types.bool;
        };
        "path" = mkOption {
          description = "";
          type = types.str;
        };
        "signerName" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
      };

      config = {
        "labelSelector" = mkOverride 1002 null;
        "name" = mkOverride 1002 null;
        "optional" = mkOverride 1002 null;
        "signerName" = mkOverride 1002 null;
      };

    };
    "seaweed.seaweedfs.com.v1.SeaweedSpecS3VolumesProjectedSourcesClusterTrustBundleLabelSelector" = {

      options = {
        "matchExpressions" = mkOption {
          description = "";
          type = types.nullOr (
            types.listOf (
              submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecS3VolumesProjectedSourcesClusterTrustBundleLabelSelectorMatchExpressions"
            )
          );
        };
        "matchLabels" = mkOption {
          description = "";
          type = types.nullOr (types.attrsOf types.str);
        };
      };

      config = {
        "matchExpressions" = mkOverride 1002 null;
        "matchLabels" = mkOverride 1002 null;
      };

    };
    "seaweed.seaweedfs.com.v1.SeaweedSpecS3VolumesProjectedSourcesClusterTrustBundleLabelSelectorMatchExpressions" =
      {

        options = {
          "key" = mkOption {
            description = "";
            type = types.str;
          };
          "operator" = mkOption {
            description = "";
            type = types.str;
          };
          "values" = mkOption {
            description = "";
            type = types.nullOr (types.listOf types.str);
          };
        };

        config = {
          "values" = mkOverride 1002 null;
        };

      };
    "seaweed.seaweedfs.com.v1.SeaweedSpecS3VolumesProjectedSourcesConfigMap" = {

      options = {
        "items" = mkOption {
          description = "";
          type = types.nullOr (
            types.listOf (
              submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecS3VolumesProjectedSourcesConfigMapItems"
            )
          );
        };
        "name" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "optional" = mkOption {
          description = "";
          type = types.nullOr types.bool;
        };
      };

      config = {
        "items" = mkOverride 1002 null;
        "name" = mkOverride 1002 null;
        "optional" = mkOverride 1002 null;
      };

    };
    "seaweed.seaweedfs.com.v1.SeaweedSpecS3VolumesProjectedSourcesConfigMapItems" = {

      options = {
        "key" = mkOption {
          description = "";
          type = types.str;
        };
        "mode" = mkOption {
          description = "";
          type = types.nullOr types.int;
        };
        "path" = mkOption {
          description = "";
          type = types.str;
        };
      };

      config = {
        "mode" = mkOverride 1002 null;
      };

    };
    "seaweed.seaweedfs.com.v1.SeaweedSpecS3VolumesProjectedSourcesDownwardAPI" = {

      options = {
        "items" = mkOption {
          description = "";
          type = types.nullOr (
            types.listOf (
              submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecS3VolumesProjectedSourcesDownwardAPIItems"
            )
          );
        };
      };

      config = {
        "items" = mkOverride 1002 null;
      };

    };
    "seaweed.seaweedfs.com.v1.SeaweedSpecS3VolumesProjectedSourcesDownwardAPIItems" = {

      options = {
        "fieldRef" = mkOption {
          description = "";
          type = types.nullOr (
            submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecS3VolumesProjectedSourcesDownwardAPIItemsFieldRef"
          );
        };
        "mode" = mkOption {
          description = "";
          type = types.nullOr types.int;
        };
        "path" = mkOption {
          description = "";
          type = types.str;
        };
        "resourceFieldRef" = mkOption {
          description = "";
          type = types.nullOr (
            submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecS3VolumesProjectedSourcesDownwardAPIItemsResourceFieldRef"
          );
        };
      };

      config = {
        "fieldRef" = mkOverride 1002 null;
        "mode" = mkOverride 1002 null;
        "resourceFieldRef" = mkOverride 1002 null;
      };

    };
    "seaweed.seaweedfs.com.v1.SeaweedSpecS3VolumesProjectedSourcesDownwardAPIItemsFieldRef" = {

      options = {
        "apiVersion" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "fieldPath" = mkOption {
          description = "";
          type = types.str;
        };
      };

      config = {
        "apiVersion" = mkOverride 1002 null;
      };

    };
    "seaweed.seaweedfs.com.v1.SeaweedSpecS3VolumesProjectedSourcesDownwardAPIItemsResourceFieldRef" = {

      options = {
        "containerName" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "divisor" = mkOption {
          description = "";
          type = types.nullOr (types.either types.int types.str);
        };
        "resource" = mkOption {
          description = "";
          type = types.str;
        };
      };

      config = {
        "containerName" = mkOverride 1002 null;
        "divisor" = mkOverride 1002 null;
      };

    };
    "seaweed.seaweedfs.com.v1.SeaweedSpecS3VolumesProjectedSourcesPodCertificate" = {

      options = {
        "certificateChainPath" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "credentialBundlePath" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "keyPath" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "keyType" = mkOption {
          description = "";
          type = types.str;
        };
        "maxExpirationSeconds" = mkOption {
          description = "";
          type = types.nullOr types.int;
        };
        "signerName" = mkOption {
          description = "";
          type = types.str;
        };
        "userAnnotations" = mkOption {
          description = "";
          type = types.nullOr (types.attrsOf types.str);
        };
      };

      config = {
        "certificateChainPath" = mkOverride 1002 null;
        "credentialBundlePath" = mkOverride 1002 null;
        "keyPath" = mkOverride 1002 null;
        "maxExpirationSeconds" = mkOverride 1002 null;
        "userAnnotations" = mkOverride 1002 null;
      };

    };
    "seaweed.seaweedfs.com.v1.SeaweedSpecS3VolumesProjectedSourcesSecret" = {

      options = {
        "items" = mkOption {
          description = "";
          type = types.nullOr (
            types.listOf (
              submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecS3VolumesProjectedSourcesSecretItems"
            )
          );
        };
        "name" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "optional" = mkOption {
          description = "";
          type = types.nullOr types.bool;
        };
      };

      config = {
        "items" = mkOverride 1002 null;
        "name" = mkOverride 1002 null;
        "optional" = mkOverride 1002 null;
      };

    };
    "seaweed.seaweedfs.com.v1.SeaweedSpecS3VolumesProjectedSourcesSecretItems" = {

      options = {
        "key" = mkOption {
          description = "";
          type = types.str;
        };
        "mode" = mkOption {
          description = "";
          type = types.nullOr types.int;
        };
        "path" = mkOption {
          description = "";
          type = types.str;
        };
      };

      config = {
        "mode" = mkOverride 1002 null;
      };

    };
    "seaweed.seaweedfs.com.v1.SeaweedSpecS3VolumesProjectedSourcesServiceAccountToken" = {

      options = {
        "audience" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "expirationSeconds" = mkOption {
          description = "";
          type = types.nullOr types.int;
        };
        "path" = mkOption {
          description = "";
          type = types.str;
        };
      };

      config = {
        "audience" = mkOverride 1002 null;
        "expirationSeconds" = mkOverride 1002 null;
      };

    };
    "seaweed.seaweedfs.com.v1.SeaweedSpecS3VolumesQuobyte" = {

      options = {
        "group" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "readOnly" = mkOption {
          description = "";
          type = types.nullOr types.bool;
        };
        "registry" = mkOption {
          description = "";
          type = types.str;
        };
        "tenant" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "user" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "volume" = mkOption {
          description = "";
          type = types.str;
        };
      };

      config = {
        "group" = mkOverride 1002 null;
        "readOnly" = mkOverride 1002 null;
        "tenant" = mkOverride 1002 null;
        "user" = mkOverride 1002 null;
      };

    };
    "seaweed.seaweedfs.com.v1.SeaweedSpecS3VolumesRbd" = {

      options = {
        "fsType" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "image" = mkOption {
          description = "";
          type = types.str;
        };
        "keyring" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "monitors" = mkOption {
          description = "";
          type = types.listOf types.str;
        };
        "pool" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "readOnly" = mkOption {
          description = "";
          type = types.nullOr types.bool;
        };
        "secretRef" = mkOption {
          description = "";
          type = types.nullOr (submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecS3VolumesRbdSecretRef");
        };
        "user" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
      };

      config = {
        "fsType" = mkOverride 1002 null;
        "keyring" = mkOverride 1002 null;
        "pool" = mkOverride 1002 null;
        "readOnly" = mkOverride 1002 null;
        "secretRef" = mkOverride 1002 null;
        "user" = mkOverride 1002 null;
      };

    };
    "seaweed.seaweedfs.com.v1.SeaweedSpecS3VolumesRbdSecretRef" = {

      options = {
        "name" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
      };

      config = {
        "name" = mkOverride 1002 null;
      };

    };
    "seaweed.seaweedfs.com.v1.SeaweedSpecS3VolumesScaleIO" = {

      options = {
        "fsType" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "gateway" = mkOption {
          description = "";
          type = types.str;
        };
        "protectionDomain" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "readOnly" = mkOption {
          description = "";
          type = types.nullOr types.bool;
        };
        "secretRef" = mkOption {
          description = "";
          type = submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecS3VolumesScaleIOSecretRef";
        };
        "sslEnabled" = mkOption {
          description = "";
          type = types.nullOr types.bool;
        };
        "storageMode" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "storagePool" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "system" = mkOption {
          description = "";
          type = types.str;
        };
        "volumeName" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
      };

      config = {
        "fsType" = mkOverride 1002 null;
        "protectionDomain" = mkOverride 1002 null;
        "readOnly" = mkOverride 1002 null;
        "sslEnabled" = mkOverride 1002 null;
        "storageMode" = mkOverride 1002 null;
        "storagePool" = mkOverride 1002 null;
        "volumeName" = mkOverride 1002 null;
      };

    };
    "seaweed.seaweedfs.com.v1.SeaweedSpecS3VolumesScaleIOSecretRef" = {

      options = {
        "name" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
      };

      config = {
        "name" = mkOverride 1002 null;
      };

    };
    "seaweed.seaweedfs.com.v1.SeaweedSpecS3VolumesSecret" = {

      options = {
        "defaultMode" = mkOption {
          description = "";
          type = types.nullOr types.int;
        };
        "items" = mkOption {
          description = "";
          type = types.nullOr (
            types.listOf (submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecS3VolumesSecretItems")
          );
        };
        "optional" = mkOption {
          description = "";
          type = types.nullOr types.bool;
        };
        "secretName" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
      };

      config = {
        "defaultMode" = mkOverride 1002 null;
        "items" = mkOverride 1002 null;
        "optional" = mkOverride 1002 null;
        "secretName" = mkOverride 1002 null;
      };

    };
    "seaweed.seaweedfs.com.v1.SeaweedSpecS3VolumesSecretItems" = {

      options = {
        "key" = mkOption {
          description = "";
          type = types.str;
        };
        "mode" = mkOption {
          description = "";
          type = types.nullOr types.int;
        };
        "path" = mkOption {
          description = "";
          type = types.str;
        };
      };

      config = {
        "mode" = mkOverride 1002 null;
      };

    };
    "seaweed.seaweedfs.com.v1.SeaweedSpecS3VolumesStorageos" = {

      options = {
        "fsType" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "readOnly" = mkOption {
          description = "";
          type = types.nullOr types.bool;
        };
        "secretRef" = mkOption {
          description = "";
          type = types.nullOr (submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecS3VolumesStorageosSecretRef");
        };
        "volumeName" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "volumeNamespace" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
      };

      config = {
        "fsType" = mkOverride 1002 null;
        "readOnly" = mkOverride 1002 null;
        "secretRef" = mkOverride 1002 null;
        "volumeName" = mkOverride 1002 null;
        "volumeNamespace" = mkOverride 1002 null;
      };

    };
    "seaweed.seaweedfs.com.v1.SeaweedSpecS3VolumesStorageosSecretRef" = {

      options = {
        "name" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
      };

      config = {
        "name" = mkOverride 1002 null;
      };

    };
    "seaweed.seaweedfs.com.v1.SeaweedSpecS3VolumesVsphereVolume" = {

      options = {
        "fsType" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "storagePolicyID" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "storagePolicyName" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "volumePath" = mkOption {
          description = "";
          type = types.str;
        };
      };

      config = {
        "fsType" = mkOverride 1002 null;
        "storagePolicyID" = mkOverride 1002 null;
        "storagePolicyName" = mkOverride 1002 null;
      };

    };
    "seaweed.seaweedfs.com.v1.SeaweedSpecSftp" = {

      options = {
        "affinity" = mkOption {
          description = "";
          type = types.nullOr (submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecSftpAffinity");
        };
        "annotations" = mkOption {
          description = "";
          type = types.nullOr (types.attrsOf types.str);
        };
        "authMethods" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "claims" = mkOption {
          description = "";
          type = types.nullOr (
            coerceAttrsOfSubmodulesToListByKey "seaweed.seaweedfs.com.v1.SeaweedSpecSftpClaims" "name" [
              "name"
            ]
          );
          apply = attrsToList;
        };
        "containerSecurityContext" = mkOption {
          description = "";
          type = types.nullOr (
            submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecSftpContainerSecurityContext"
          );
        };
        "env" = mkOption {
          description = "";
          type = types.nullOr (
            coerceAttrsOfSubmodulesToListByKey "seaweed.seaweedfs.com.v1.SeaweedSpecSftpEnv" "name" [ ]
          );
          apply = attrsToList;
        };
        "extraArgs" = mkOption {
          description = "";
          type = types.nullOr (types.listOf types.str);
        };
        "hostKeysSecret" = mkOption {
          description = "";
          type = types.nullOr (submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecSftpHostKeysSecret");
        };
        "hostNetwork" = mkOption {
          description = "";
          type = types.nullOr types.bool;
        };
        "imagePullPolicy" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "imagePullSecrets" = mkOption {
          description = "";
          type = types.nullOr (
            coerceAttrsOfSubmodulesToListByKey "seaweed.seaweedfs.com.v1.SeaweedSpecSftpImagePullSecrets" "name"
              [ ]
          );
          apply = attrsToList;
        };
        "ingress" = mkOption {
          description = "";
          type = types.nullOr (submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecSftpIngress");
        };
        "initContainers" = mkOption {
          description = "";
          type = types.nullOr types.unspecified;
        };
        "labels" = mkOption {
          description = "";
          type = types.nullOr (types.attrsOf types.str);
        };
        "limits" = mkOption {
          description = "";
          type = types.nullOr (types.attrsOf (types.either types.int types.str));
        };
        "livenessProbe" = mkOption {
          description = "";
          type = types.nullOr (submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecSftpLivenessProbe");
        };
        "loggingArgs" = mkOption {
          description = "";
          type = types.nullOr (types.listOf types.str);
        };
        "maxAuthTries" = mkOption {
          description = "";
          type = types.nullOr types.int;
        };
        "metricsPort" = mkOption {
          description = "";
          type = types.nullOr types.int;
        };
        "nodeSelector" = mkOption {
          description = "";
          type = types.nullOr (types.attrsOf types.str);
        };
        "podSecurityContext" = mkOption {
          description = "";
          type = types.nullOr (submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecSftpPodSecurityContext");
        };
        "port" = mkOption {
          description = "";
          type = types.nullOr types.int;
        };
        "priorityClassName" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "readinessProbe" = mkOption {
          description = "";
          type = types.nullOr (submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecSftpReadinessProbe");
        };
        "replicas" = mkOption {
          description = "";
          type = types.int;
        };
        "requests" = mkOption {
          description = "";
          type = types.nullOr (types.attrsOf (types.either types.int types.str));
        };
        "schedulerName" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "service" = mkOption {
          description = "";
          type = types.nullOr (submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecSftpService");
        };
        "serviceAccountName" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "sidecars" = mkOption {
          description = "";
          type = types.nullOr types.unspecified;
        };
        "statefulSetUpdateStrategy" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "terminationGracePeriodSeconds" = mkOption {
          description = "";
          type = types.nullOr types.int;
        };
        "tolerations" = mkOption {
          description = "";
          type = types.nullOr (
            types.listOf (submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecSftpTolerations")
          );
        };
        "userStoreSecret" = mkOption {
          description = "";
          type = types.nullOr (submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecSftpUserStoreSecret");
        };
        "version" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "volumeMounts" = mkOption {
          description = "";
          type = types.nullOr (
            coerceAttrsOfSubmodulesToListByKey "seaweed.seaweedfs.com.v1.SeaweedSpecSftpVolumeMounts" "name" [ ]
          );
          apply = attrsToList;
        };
        "volumes" = mkOption {
          description = "";
          type = types.nullOr (
            coerceAttrsOfSubmodulesToListByKey "seaweed.seaweedfs.com.v1.SeaweedSpecSftpVolumes" "name" [ ]
          );
          apply = attrsToList;
        };
      };

      config = {
        "affinity" = mkOverride 1002 null;
        "annotations" = mkOverride 1002 null;
        "authMethods" = mkOverride 1002 null;
        "claims" = mkOverride 1002 null;
        "containerSecurityContext" = mkOverride 1002 null;
        "env" = mkOverride 1002 null;
        "extraArgs" = mkOverride 1002 null;
        "hostKeysSecret" = mkOverride 1002 null;
        "hostNetwork" = mkOverride 1002 null;
        "imagePullPolicy" = mkOverride 1002 null;
        "imagePullSecrets" = mkOverride 1002 null;
        "ingress" = mkOverride 1002 null;
        "initContainers" = mkOverride 1002 null;
        "labels" = mkOverride 1002 null;
        "limits" = mkOverride 1002 null;
        "livenessProbe" = mkOverride 1002 null;
        "loggingArgs" = mkOverride 1002 null;
        "maxAuthTries" = mkOverride 1002 null;
        "metricsPort" = mkOverride 1002 null;
        "nodeSelector" = mkOverride 1002 null;
        "podSecurityContext" = mkOverride 1002 null;
        "port" = mkOverride 1002 null;
        "priorityClassName" = mkOverride 1002 null;
        "readinessProbe" = mkOverride 1002 null;
        "requests" = mkOverride 1002 null;
        "schedulerName" = mkOverride 1002 null;
        "service" = mkOverride 1002 null;
        "serviceAccountName" = mkOverride 1002 null;
        "sidecars" = mkOverride 1002 null;
        "statefulSetUpdateStrategy" = mkOverride 1002 null;
        "terminationGracePeriodSeconds" = mkOverride 1002 null;
        "tolerations" = mkOverride 1002 null;
        "userStoreSecret" = mkOverride 1002 null;
        "version" = mkOverride 1002 null;
        "volumeMounts" = mkOverride 1002 null;
        "volumes" = mkOverride 1002 null;
      };

    };
    "seaweed.seaweedfs.com.v1.SeaweedSpecSftpAffinity" = {

      options = {
        "nodeAffinity" = mkOption {
          description = "";
          type = types.nullOr (submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecSftpAffinityNodeAffinity");
        };
        "podAffinity" = mkOption {
          description = "";
          type = types.nullOr (submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecSftpAffinityPodAffinity");
        };
        "podAntiAffinity" = mkOption {
          description = "";
          type = types.nullOr (submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecSftpAffinityPodAntiAffinity");
        };
      };

      config = {
        "nodeAffinity" = mkOverride 1002 null;
        "podAffinity" = mkOverride 1002 null;
        "podAntiAffinity" = mkOverride 1002 null;
      };

    };
    "seaweed.seaweedfs.com.v1.SeaweedSpecSftpAffinityNodeAffinity" = {

      options = {
        "preferredDuringSchedulingIgnoredDuringExecution" = mkOption {
          description = "";
          type = types.nullOr (
            types.listOf (
              submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecSftpAffinityNodeAffinityPreferredDuringSchedulingIgnoredDuringExecution"
            )
          );
        };
        "requiredDuringSchedulingIgnoredDuringExecution" = mkOption {
          description = "";
          type = types.nullOr (
            submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecSftpAffinityNodeAffinityRequiredDuringSchedulingIgnoredDuringExecution"
          );
        };
      };

      config = {
        "preferredDuringSchedulingIgnoredDuringExecution" = mkOverride 1002 null;
        "requiredDuringSchedulingIgnoredDuringExecution" = mkOverride 1002 null;
      };

    };
    "seaweed.seaweedfs.com.v1.SeaweedSpecSftpAffinityNodeAffinityPreferredDuringSchedulingIgnoredDuringExecution" =
      {

        options = {
          "preference" = mkOption {
            description = "";
            type = submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecSftpAffinityNodeAffinityPreferredDuringSchedulingIgnoredDuringExecutionPreference";
          };
          "weight" = mkOption {
            description = "";
            type = types.int;
          };
        };

        config = { };

      };
    "seaweed.seaweedfs.com.v1.SeaweedSpecSftpAffinityNodeAffinityPreferredDuringSchedulingIgnoredDuringExecutionPreference" =
      {

        options = {
          "matchExpressions" = mkOption {
            description = "";
            type = types.nullOr (
              types.listOf (
                submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecSftpAffinityNodeAffinityPreferredDuringSchedulingIgnoredDuringExecutionPreferenceMatchExpressions"
              )
            );
          };
          "matchFields" = mkOption {
            description = "";
            type = types.nullOr (
              types.listOf (
                submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecSftpAffinityNodeAffinityPreferredDuringSchedulingIgnoredDuringExecutionPreferenceMatchFields"
              )
            );
          };
        };

        config = {
          "matchExpressions" = mkOverride 1002 null;
          "matchFields" = mkOverride 1002 null;
        };

      };
    "seaweed.seaweedfs.com.v1.SeaweedSpecSftpAffinityNodeAffinityPreferredDuringSchedulingIgnoredDuringExecutionPreferenceMatchExpressions" =
      {

        options = {
          "key" = mkOption {
            description = "";
            type = types.str;
          };
          "operator" = mkOption {
            description = "";
            type = types.str;
          };
          "values" = mkOption {
            description = "";
            type = types.nullOr (types.listOf types.str);
          };
        };

        config = {
          "values" = mkOverride 1002 null;
        };

      };
    "seaweed.seaweedfs.com.v1.SeaweedSpecSftpAffinityNodeAffinityPreferredDuringSchedulingIgnoredDuringExecutionPreferenceMatchFields" =
      {

        options = {
          "key" = mkOption {
            description = "";
            type = types.str;
          };
          "operator" = mkOption {
            description = "";
            type = types.str;
          };
          "values" = mkOption {
            description = "";
            type = types.nullOr (types.listOf types.str);
          };
        };

        config = {
          "values" = mkOverride 1002 null;
        };

      };
    "seaweed.seaweedfs.com.v1.SeaweedSpecSftpAffinityNodeAffinityRequiredDuringSchedulingIgnoredDuringExecution" =
      {

        options = {
          "nodeSelectorTerms" = mkOption {
            description = "";
            type = types.listOf (
              submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecSftpAffinityNodeAffinityRequiredDuringSchedulingIgnoredDuringExecutionNodeSelectorTerms"
            );
          };
        };

        config = { };

      };
    "seaweed.seaweedfs.com.v1.SeaweedSpecSftpAffinityNodeAffinityRequiredDuringSchedulingIgnoredDuringExecutionNodeSelectorTerms" =
      {

        options = {
          "matchExpressions" = mkOption {
            description = "";
            type = types.nullOr (
              types.listOf (
                submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecSftpAffinityNodeAffinityRequiredDuringSchedulingIgnoredDuringExecutionNodeSelectorTermsMatchExpressions"
              )
            );
          };
          "matchFields" = mkOption {
            description = "";
            type = types.nullOr (
              types.listOf (
                submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecSftpAffinityNodeAffinityRequiredDuringSchedulingIgnoredDuringExecutionNodeSelectorTermsMatchFields"
              )
            );
          };
        };

        config = {
          "matchExpressions" = mkOverride 1002 null;
          "matchFields" = mkOverride 1002 null;
        };

      };
    "seaweed.seaweedfs.com.v1.SeaweedSpecSftpAffinityNodeAffinityRequiredDuringSchedulingIgnoredDuringExecutionNodeSelectorTermsMatchExpressions" =
      {

        options = {
          "key" = mkOption {
            description = "";
            type = types.str;
          };
          "operator" = mkOption {
            description = "";
            type = types.str;
          };
          "values" = mkOption {
            description = "";
            type = types.nullOr (types.listOf types.str);
          };
        };

        config = {
          "values" = mkOverride 1002 null;
        };

      };
    "seaweed.seaweedfs.com.v1.SeaweedSpecSftpAffinityNodeAffinityRequiredDuringSchedulingIgnoredDuringExecutionNodeSelectorTermsMatchFields" =
      {

        options = {
          "key" = mkOption {
            description = "";
            type = types.str;
          };
          "operator" = mkOption {
            description = "";
            type = types.str;
          };
          "values" = mkOption {
            description = "";
            type = types.nullOr (types.listOf types.str);
          };
        };

        config = {
          "values" = mkOverride 1002 null;
        };

      };
    "seaweed.seaweedfs.com.v1.SeaweedSpecSftpAffinityPodAffinity" = {

      options = {
        "preferredDuringSchedulingIgnoredDuringExecution" = mkOption {
          description = "";
          type = types.nullOr (
            types.listOf (
              submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecSftpAffinityPodAffinityPreferredDuringSchedulingIgnoredDuringExecution"
            )
          );
        };
        "requiredDuringSchedulingIgnoredDuringExecution" = mkOption {
          description = "";
          type = types.nullOr (
            types.listOf (
              submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecSftpAffinityPodAffinityRequiredDuringSchedulingIgnoredDuringExecution"
            )
          );
        };
      };

      config = {
        "preferredDuringSchedulingIgnoredDuringExecution" = mkOverride 1002 null;
        "requiredDuringSchedulingIgnoredDuringExecution" = mkOverride 1002 null;
      };

    };
    "seaweed.seaweedfs.com.v1.SeaweedSpecSftpAffinityPodAffinityPreferredDuringSchedulingIgnoredDuringExecution" =
      {

        options = {
          "podAffinityTerm" = mkOption {
            description = "";
            type = submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecSftpAffinityPodAffinityPreferredDuringSchedulingIgnoredDuringExecutionPodAffinityTerm";
          };
          "weight" = mkOption {
            description = "";
            type = types.int;
          };
        };

        config = { };

      };
    "seaweed.seaweedfs.com.v1.SeaweedSpecSftpAffinityPodAffinityPreferredDuringSchedulingIgnoredDuringExecutionPodAffinityTerm" =
      {

        options = {
          "labelSelector" = mkOption {
            description = "";
            type = types.nullOr (
              submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecSftpAffinityPodAffinityPreferredDuringSchedulingIgnoredDuringExecutionPodAffinityTermLabelSelector"
            );
          };
          "matchLabelKeys" = mkOption {
            description = "";
            type = types.nullOr (types.listOf types.str);
          };
          "mismatchLabelKeys" = mkOption {
            description = "";
            type = types.nullOr (types.listOf types.str);
          };
          "namespaceSelector" = mkOption {
            description = "";
            type = types.nullOr (
              submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecSftpAffinityPodAffinityPreferredDuringSchedulingIgnoredDuringExecutionPodAffinityTermNamespaceSelector"
            );
          };
          "namespaces" = mkOption {
            description = "";
            type = types.nullOr (types.listOf types.str);
          };
          "topologyKey" = mkOption {
            description = "";
            type = types.str;
          };
        };

        config = {
          "labelSelector" = mkOverride 1002 null;
          "matchLabelKeys" = mkOverride 1002 null;
          "mismatchLabelKeys" = mkOverride 1002 null;
          "namespaceSelector" = mkOverride 1002 null;
          "namespaces" = mkOverride 1002 null;
        };

      };
    "seaweed.seaweedfs.com.v1.SeaweedSpecSftpAffinityPodAffinityPreferredDuringSchedulingIgnoredDuringExecutionPodAffinityTermLabelSelector" =
      {

        options = {
          "matchExpressions" = mkOption {
            description = "";
            type = types.nullOr (
              types.listOf (
                submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecSftpAffinityPodAffinityPreferredDuringSchedulingIgnoredDuringExecutionPodAffinityTermLabelSelectorMatchExpressions"
              )
            );
          };
          "matchLabels" = mkOption {
            description = "";
            type = types.nullOr (types.attrsOf types.str);
          };
        };

        config = {
          "matchExpressions" = mkOverride 1002 null;
          "matchLabels" = mkOverride 1002 null;
        };

      };
    "seaweed.seaweedfs.com.v1.SeaweedSpecSftpAffinityPodAffinityPreferredDuringSchedulingIgnoredDuringExecutionPodAffinityTermLabelSelectorMatchExpressions" =
      {

        options = {
          "key" = mkOption {
            description = "";
            type = types.str;
          };
          "operator" = mkOption {
            description = "";
            type = types.str;
          };
          "values" = mkOption {
            description = "";
            type = types.nullOr (types.listOf types.str);
          };
        };

        config = {
          "values" = mkOverride 1002 null;
        };

      };
    "seaweed.seaweedfs.com.v1.SeaweedSpecSftpAffinityPodAffinityPreferredDuringSchedulingIgnoredDuringExecutionPodAffinityTermNamespaceSelector" =
      {

        options = {
          "matchExpressions" = mkOption {
            description = "";
            type = types.nullOr (
              types.listOf (
                submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecSftpAffinityPodAffinityPreferredDuringSchedulingIgnoredDuringExecutionPodAffinityTermNamespaceSelectorMatchExpressions"
              )
            );
          };
          "matchLabels" = mkOption {
            description = "";
            type = types.nullOr (types.attrsOf types.str);
          };
        };

        config = {
          "matchExpressions" = mkOverride 1002 null;
          "matchLabels" = mkOverride 1002 null;
        };

      };
    "seaweed.seaweedfs.com.v1.SeaweedSpecSftpAffinityPodAffinityPreferredDuringSchedulingIgnoredDuringExecutionPodAffinityTermNamespaceSelectorMatchExpressions" =
      {

        options = {
          "key" = mkOption {
            description = "";
            type = types.str;
          };
          "operator" = mkOption {
            description = "";
            type = types.str;
          };
          "values" = mkOption {
            description = "";
            type = types.nullOr (types.listOf types.str);
          };
        };

        config = {
          "values" = mkOverride 1002 null;
        };

      };
    "seaweed.seaweedfs.com.v1.SeaweedSpecSftpAffinityPodAffinityRequiredDuringSchedulingIgnoredDuringExecution" =
      {

        options = {
          "labelSelector" = mkOption {
            description = "";
            type = types.nullOr (
              submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecSftpAffinityPodAffinityRequiredDuringSchedulingIgnoredDuringExecutionLabelSelector"
            );
          };
          "matchLabelKeys" = mkOption {
            description = "";
            type = types.nullOr (types.listOf types.str);
          };
          "mismatchLabelKeys" = mkOption {
            description = "";
            type = types.nullOr (types.listOf types.str);
          };
          "namespaceSelector" = mkOption {
            description = "";
            type = types.nullOr (
              submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecSftpAffinityPodAffinityRequiredDuringSchedulingIgnoredDuringExecutionNamespaceSelector"
            );
          };
          "namespaces" = mkOption {
            description = "";
            type = types.nullOr (types.listOf types.str);
          };
          "topologyKey" = mkOption {
            description = "";
            type = types.str;
          };
        };

        config = {
          "labelSelector" = mkOverride 1002 null;
          "matchLabelKeys" = mkOverride 1002 null;
          "mismatchLabelKeys" = mkOverride 1002 null;
          "namespaceSelector" = mkOverride 1002 null;
          "namespaces" = mkOverride 1002 null;
        };

      };
    "seaweed.seaweedfs.com.v1.SeaweedSpecSftpAffinityPodAffinityRequiredDuringSchedulingIgnoredDuringExecutionLabelSelector" =
      {

        options = {
          "matchExpressions" = mkOption {
            description = "";
            type = types.nullOr (
              types.listOf (
                submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecSftpAffinityPodAffinityRequiredDuringSchedulingIgnoredDuringExecutionLabelSelectorMatchExpressions"
              )
            );
          };
          "matchLabels" = mkOption {
            description = "";
            type = types.nullOr (types.attrsOf types.str);
          };
        };

        config = {
          "matchExpressions" = mkOverride 1002 null;
          "matchLabels" = mkOverride 1002 null;
        };

      };
    "seaweed.seaweedfs.com.v1.SeaweedSpecSftpAffinityPodAffinityRequiredDuringSchedulingIgnoredDuringExecutionLabelSelectorMatchExpressions" =
      {

        options = {
          "key" = mkOption {
            description = "";
            type = types.str;
          };
          "operator" = mkOption {
            description = "";
            type = types.str;
          };
          "values" = mkOption {
            description = "";
            type = types.nullOr (types.listOf types.str);
          };
        };

        config = {
          "values" = mkOverride 1002 null;
        };

      };
    "seaweed.seaweedfs.com.v1.SeaweedSpecSftpAffinityPodAffinityRequiredDuringSchedulingIgnoredDuringExecutionNamespaceSelector" =
      {

        options = {
          "matchExpressions" = mkOption {
            description = "";
            type = types.nullOr (
              types.listOf (
                submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecSftpAffinityPodAffinityRequiredDuringSchedulingIgnoredDuringExecutionNamespaceSelectorMatchExpressions"
              )
            );
          };
          "matchLabels" = mkOption {
            description = "";
            type = types.nullOr (types.attrsOf types.str);
          };
        };

        config = {
          "matchExpressions" = mkOverride 1002 null;
          "matchLabels" = mkOverride 1002 null;
        };

      };
    "seaweed.seaweedfs.com.v1.SeaweedSpecSftpAffinityPodAffinityRequiredDuringSchedulingIgnoredDuringExecutionNamespaceSelectorMatchExpressions" =
      {

        options = {
          "key" = mkOption {
            description = "";
            type = types.str;
          };
          "operator" = mkOption {
            description = "";
            type = types.str;
          };
          "values" = mkOption {
            description = "";
            type = types.nullOr (types.listOf types.str);
          };
        };

        config = {
          "values" = mkOverride 1002 null;
        };

      };
    "seaweed.seaweedfs.com.v1.SeaweedSpecSftpAffinityPodAntiAffinity" = {

      options = {
        "preferredDuringSchedulingIgnoredDuringExecution" = mkOption {
          description = "";
          type = types.nullOr (
            types.listOf (
              submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecSftpAffinityPodAntiAffinityPreferredDuringSchedulingIgnoredDuringExecution"
            )
          );
        };
        "requiredDuringSchedulingIgnoredDuringExecution" = mkOption {
          description = "";
          type = types.nullOr (
            types.listOf (
              submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecSftpAffinityPodAntiAffinityRequiredDuringSchedulingIgnoredDuringExecution"
            )
          );
        };
      };

      config = {
        "preferredDuringSchedulingIgnoredDuringExecution" = mkOverride 1002 null;
        "requiredDuringSchedulingIgnoredDuringExecution" = mkOverride 1002 null;
      };

    };
    "seaweed.seaweedfs.com.v1.SeaweedSpecSftpAffinityPodAntiAffinityPreferredDuringSchedulingIgnoredDuringExecution" =
      {

        options = {
          "podAffinityTerm" = mkOption {
            description = "";
            type = submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecSftpAffinityPodAntiAffinityPreferredDuringSchedulingIgnoredDuringExecutionPodAffinityTerm";
          };
          "weight" = mkOption {
            description = "";
            type = types.int;
          };
        };

        config = { };

      };
    "seaweed.seaweedfs.com.v1.SeaweedSpecSftpAffinityPodAntiAffinityPreferredDuringSchedulingIgnoredDuringExecutionPodAffinityTerm" =
      {

        options = {
          "labelSelector" = mkOption {
            description = "";
            type = types.nullOr (
              submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecSftpAffinityPodAntiAffinityPreferredDuringSchedulingIgnoredDuringExecutionPodAffinityTermLabelSelector"
            );
          };
          "matchLabelKeys" = mkOption {
            description = "";
            type = types.nullOr (types.listOf types.str);
          };
          "mismatchLabelKeys" = mkOption {
            description = "";
            type = types.nullOr (types.listOf types.str);
          };
          "namespaceSelector" = mkOption {
            description = "";
            type = types.nullOr (
              submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecSftpAffinityPodAntiAffinityPreferredDuringSchedulingIgnoredDuringExecutionPodAffinityTermNamespaceSelector"
            );
          };
          "namespaces" = mkOption {
            description = "";
            type = types.nullOr (types.listOf types.str);
          };
          "topologyKey" = mkOption {
            description = "";
            type = types.str;
          };
        };

        config = {
          "labelSelector" = mkOverride 1002 null;
          "matchLabelKeys" = mkOverride 1002 null;
          "mismatchLabelKeys" = mkOverride 1002 null;
          "namespaceSelector" = mkOverride 1002 null;
          "namespaces" = mkOverride 1002 null;
        };

      };
    "seaweed.seaweedfs.com.v1.SeaweedSpecSftpAffinityPodAntiAffinityPreferredDuringSchedulingIgnoredDuringExecutionPodAffinityTermLabelSelector" =
      {

        options = {
          "matchExpressions" = mkOption {
            description = "";
            type = types.nullOr (
              types.listOf (
                submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecSftpAffinityPodAntiAffinityPreferredDuringSchedulingIgnoredDuringExecutionPodAffinityTermLabelSelectorMatchExpressions"
              )
            );
          };
          "matchLabels" = mkOption {
            description = "";
            type = types.nullOr (types.attrsOf types.str);
          };
        };

        config = {
          "matchExpressions" = mkOverride 1002 null;
          "matchLabels" = mkOverride 1002 null;
        };

      };
    "seaweed.seaweedfs.com.v1.SeaweedSpecSftpAffinityPodAntiAffinityPreferredDuringSchedulingIgnoredDuringExecutionPodAffinityTermLabelSelectorMatchExpressions" =
      {

        options = {
          "key" = mkOption {
            description = "";
            type = types.str;
          };
          "operator" = mkOption {
            description = "";
            type = types.str;
          };
          "values" = mkOption {
            description = "";
            type = types.nullOr (types.listOf types.str);
          };
        };

        config = {
          "values" = mkOverride 1002 null;
        };

      };
    "seaweed.seaweedfs.com.v1.SeaweedSpecSftpAffinityPodAntiAffinityPreferredDuringSchedulingIgnoredDuringExecutionPodAffinityTermNamespaceSelector" =
      {

        options = {
          "matchExpressions" = mkOption {
            description = "";
            type = types.nullOr (
              types.listOf (
                submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecSftpAffinityPodAntiAffinityPreferredDuringSchedulingIgnoredDuringExecutionPodAffinityTermNamespaceSelectorMatchExpressions"
              )
            );
          };
          "matchLabels" = mkOption {
            description = "";
            type = types.nullOr (types.attrsOf types.str);
          };
        };

        config = {
          "matchExpressions" = mkOverride 1002 null;
          "matchLabels" = mkOverride 1002 null;
        };

      };
    "seaweed.seaweedfs.com.v1.SeaweedSpecSftpAffinityPodAntiAffinityPreferredDuringSchedulingIgnoredDuringExecutionPodAffinityTermNamespaceSelectorMatchExpressions" =
      {

        options = {
          "key" = mkOption {
            description = "";
            type = types.str;
          };
          "operator" = mkOption {
            description = "";
            type = types.str;
          };
          "values" = mkOption {
            description = "";
            type = types.nullOr (types.listOf types.str);
          };
        };

        config = {
          "values" = mkOverride 1002 null;
        };

      };
    "seaweed.seaweedfs.com.v1.SeaweedSpecSftpAffinityPodAntiAffinityRequiredDuringSchedulingIgnoredDuringExecution" =
      {

        options = {
          "labelSelector" = mkOption {
            description = "";
            type = types.nullOr (
              submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecSftpAffinityPodAntiAffinityRequiredDuringSchedulingIgnoredDuringExecutionLabelSelector"
            );
          };
          "matchLabelKeys" = mkOption {
            description = "";
            type = types.nullOr (types.listOf types.str);
          };
          "mismatchLabelKeys" = mkOption {
            description = "";
            type = types.nullOr (types.listOf types.str);
          };
          "namespaceSelector" = mkOption {
            description = "";
            type = types.nullOr (
              submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecSftpAffinityPodAntiAffinityRequiredDuringSchedulingIgnoredDuringExecutionNamespaceSelector"
            );
          };
          "namespaces" = mkOption {
            description = "";
            type = types.nullOr (types.listOf types.str);
          };
          "topologyKey" = mkOption {
            description = "";
            type = types.str;
          };
        };

        config = {
          "labelSelector" = mkOverride 1002 null;
          "matchLabelKeys" = mkOverride 1002 null;
          "mismatchLabelKeys" = mkOverride 1002 null;
          "namespaceSelector" = mkOverride 1002 null;
          "namespaces" = mkOverride 1002 null;
        };

      };
    "seaweed.seaweedfs.com.v1.SeaweedSpecSftpAffinityPodAntiAffinityRequiredDuringSchedulingIgnoredDuringExecutionLabelSelector" =
      {

        options = {
          "matchExpressions" = mkOption {
            description = "";
            type = types.nullOr (
              types.listOf (
                submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecSftpAffinityPodAntiAffinityRequiredDuringSchedulingIgnoredDuringExecutionLabelSelectorMatchExpressions"
              )
            );
          };
          "matchLabels" = mkOption {
            description = "";
            type = types.nullOr (types.attrsOf types.str);
          };
        };

        config = {
          "matchExpressions" = mkOverride 1002 null;
          "matchLabels" = mkOverride 1002 null;
        };

      };
    "seaweed.seaweedfs.com.v1.SeaweedSpecSftpAffinityPodAntiAffinityRequiredDuringSchedulingIgnoredDuringExecutionLabelSelectorMatchExpressions" =
      {

        options = {
          "key" = mkOption {
            description = "";
            type = types.str;
          };
          "operator" = mkOption {
            description = "";
            type = types.str;
          };
          "values" = mkOption {
            description = "";
            type = types.nullOr (types.listOf types.str);
          };
        };

        config = {
          "values" = mkOverride 1002 null;
        };

      };
    "seaweed.seaweedfs.com.v1.SeaweedSpecSftpAffinityPodAntiAffinityRequiredDuringSchedulingIgnoredDuringExecutionNamespaceSelector" =
      {

        options = {
          "matchExpressions" = mkOption {
            description = "";
            type = types.nullOr (
              types.listOf (
                submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecSftpAffinityPodAntiAffinityRequiredDuringSchedulingIgnoredDuringExecutionNamespaceSelectorMatchExpressions"
              )
            );
          };
          "matchLabels" = mkOption {
            description = "";
            type = types.nullOr (types.attrsOf types.str);
          };
        };

        config = {
          "matchExpressions" = mkOverride 1002 null;
          "matchLabels" = mkOverride 1002 null;
        };

      };
    "seaweed.seaweedfs.com.v1.SeaweedSpecSftpAffinityPodAntiAffinityRequiredDuringSchedulingIgnoredDuringExecutionNamespaceSelectorMatchExpressions" =
      {

        options = {
          "key" = mkOption {
            description = "";
            type = types.str;
          };
          "operator" = mkOption {
            description = "";
            type = types.str;
          };
          "values" = mkOption {
            description = "";
            type = types.nullOr (types.listOf types.str);
          };
        };

        config = {
          "values" = mkOverride 1002 null;
        };

      };
    "seaweed.seaweedfs.com.v1.SeaweedSpecSftpClaims" = {

      options = {
        "name" = mkOption {
          description = "";
          type = types.str;
        };
        "request" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
      };

      config = {
        "request" = mkOverride 1002 null;
      };

    };
    "seaweed.seaweedfs.com.v1.SeaweedSpecSftpContainerSecurityContext" = {

      options = {
        "allowPrivilegeEscalation" = mkOption {
          description = "";
          type = types.nullOr types.bool;
        };
        "appArmorProfile" = mkOption {
          description = "";
          type = types.nullOr (
            submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecSftpContainerSecurityContextAppArmorProfile"
          );
        };
        "capabilities" = mkOption {
          description = "";
          type = types.nullOr (
            submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecSftpContainerSecurityContextCapabilities"
          );
        };
        "privileged" = mkOption {
          description = "";
          type = types.nullOr types.bool;
        };
        "procMount" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "readOnlyRootFilesystem" = mkOption {
          description = "";
          type = types.nullOr types.bool;
        };
        "runAsGroup" = mkOption {
          description = "";
          type = types.nullOr types.int;
        };
        "runAsNonRoot" = mkOption {
          description = "";
          type = types.nullOr types.bool;
        };
        "runAsUser" = mkOption {
          description = "";
          type = types.nullOr types.int;
        };
        "seLinuxOptions" = mkOption {
          description = "";
          type = types.nullOr (
            submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecSftpContainerSecurityContextSeLinuxOptions"
          );
        };
        "seccompProfile" = mkOption {
          description = "";
          type = types.nullOr (
            submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecSftpContainerSecurityContextSeccompProfile"
          );
        };
        "windowsOptions" = mkOption {
          description = "";
          type = types.nullOr (
            submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecSftpContainerSecurityContextWindowsOptions"
          );
        };
      };

      config = {
        "allowPrivilegeEscalation" = mkOverride 1002 null;
        "appArmorProfile" = mkOverride 1002 null;
        "capabilities" = mkOverride 1002 null;
        "privileged" = mkOverride 1002 null;
        "procMount" = mkOverride 1002 null;
        "readOnlyRootFilesystem" = mkOverride 1002 null;
        "runAsGroup" = mkOverride 1002 null;
        "runAsNonRoot" = mkOverride 1002 null;
        "runAsUser" = mkOverride 1002 null;
        "seLinuxOptions" = mkOverride 1002 null;
        "seccompProfile" = mkOverride 1002 null;
        "windowsOptions" = mkOverride 1002 null;
      };

    };
    "seaweed.seaweedfs.com.v1.SeaweedSpecSftpContainerSecurityContextAppArmorProfile" = {

      options = {
        "localhostProfile" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "type" = mkOption {
          description = "";
          type = types.str;
        };
      };

      config = {
        "localhostProfile" = mkOverride 1002 null;
      };

    };
    "seaweed.seaweedfs.com.v1.SeaweedSpecSftpContainerSecurityContextCapabilities" = {

      options = {
        "add" = mkOption {
          description = "";
          type = types.nullOr (types.listOf types.str);
        };
        "drop" = mkOption {
          description = "";
          type = types.nullOr (types.listOf types.str);
        };
      };

      config = {
        "add" = mkOverride 1002 null;
        "drop" = mkOverride 1002 null;
      };

    };
    "seaweed.seaweedfs.com.v1.SeaweedSpecSftpContainerSecurityContextSeLinuxOptions" = {

      options = {
        "level" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "role" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "type" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "user" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
      };

      config = {
        "level" = mkOverride 1002 null;
        "role" = mkOverride 1002 null;
        "type" = mkOverride 1002 null;
        "user" = mkOverride 1002 null;
      };

    };
    "seaweed.seaweedfs.com.v1.SeaweedSpecSftpContainerSecurityContextSeccompProfile" = {

      options = {
        "localhostProfile" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "type" = mkOption {
          description = "";
          type = types.str;
        };
      };

      config = {
        "localhostProfile" = mkOverride 1002 null;
      };

    };
    "seaweed.seaweedfs.com.v1.SeaweedSpecSftpContainerSecurityContextWindowsOptions" = {

      options = {
        "gmsaCredentialSpec" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "gmsaCredentialSpecName" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "hostProcess" = mkOption {
          description = "";
          type = types.nullOr types.bool;
        };
        "runAsUserName" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
      };

      config = {
        "gmsaCredentialSpec" = mkOverride 1002 null;
        "gmsaCredentialSpecName" = mkOverride 1002 null;
        "hostProcess" = mkOverride 1002 null;
        "runAsUserName" = mkOverride 1002 null;
      };

    };
    "seaweed.seaweedfs.com.v1.SeaweedSpecSftpEnv" = {

      options = {
        "name" = mkOption {
          description = "";
          type = types.str;
        };
        "value" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "valueFrom" = mkOption {
          description = "";
          type = types.nullOr (submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecSftpEnvValueFrom");
        };
      };

      config = {
        "value" = mkOverride 1002 null;
        "valueFrom" = mkOverride 1002 null;
      };

    };
    "seaweed.seaweedfs.com.v1.SeaweedSpecSftpEnvValueFrom" = {

      options = {
        "configMapKeyRef" = mkOption {
          description = "";
          type = types.nullOr (
            submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecSftpEnvValueFromConfigMapKeyRef"
          );
        };
        "fieldRef" = mkOption {
          description = "";
          type = types.nullOr (submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecSftpEnvValueFromFieldRef");
        };
        "fileKeyRef" = mkOption {
          description = "";
          type = types.nullOr (submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecSftpEnvValueFromFileKeyRef");
        };
        "resourceFieldRef" = mkOption {
          description = "";
          type = types.nullOr (
            submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecSftpEnvValueFromResourceFieldRef"
          );
        };
        "secretKeyRef" = mkOption {
          description = "";
          type = types.nullOr (
            submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecSftpEnvValueFromSecretKeyRef"
          );
        };
      };

      config = {
        "configMapKeyRef" = mkOverride 1002 null;
        "fieldRef" = mkOverride 1002 null;
        "fileKeyRef" = mkOverride 1002 null;
        "resourceFieldRef" = mkOverride 1002 null;
        "secretKeyRef" = mkOverride 1002 null;
      };

    };
    "seaweed.seaweedfs.com.v1.SeaweedSpecSftpEnvValueFromConfigMapKeyRef" = {

      options = {
        "key" = mkOption {
          description = "";
          type = types.str;
        };
        "name" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "optional" = mkOption {
          description = "";
          type = types.nullOr types.bool;
        };
      };

      config = {
        "name" = mkOverride 1002 null;
        "optional" = mkOverride 1002 null;
      };

    };
    "seaweed.seaweedfs.com.v1.SeaweedSpecSftpEnvValueFromFieldRef" = {

      options = {
        "apiVersion" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "fieldPath" = mkOption {
          description = "";
          type = types.str;
        };
      };

      config = {
        "apiVersion" = mkOverride 1002 null;
      };

    };
    "seaweed.seaweedfs.com.v1.SeaweedSpecSftpEnvValueFromFileKeyRef" = {

      options = {
        "key" = mkOption {
          description = "";
          type = types.str;
        };
        "optional" = mkOption {
          description = "";
          type = types.nullOr types.bool;
        };
        "path" = mkOption {
          description = "";
          type = types.str;
        };
        "volumeName" = mkOption {
          description = "";
          type = types.str;
        };
      };

      config = {
        "optional" = mkOverride 1002 null;
      };

    };
    "seaweed.seaweedfs.com.v1.SeaweedSpecSftpEnvValueFromResourceFieldRef" = {

      options = {
        "containerName" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "divisor" = mkOption {
          description = "";
          type = types.nullOr (types.either types.int types.str);
        };
        "resource" = mkOption {
          description = "";
          type = types.str;
        };
      };

      config = {
        "containerName" = mkOverride 1002 null;
        "divisor" = mkOverride 1002 null;
      };

    };
    "seaweed.seaweedfs.com.v1.SeaweedSpecSftpEnvValueFromSecretKeyRef" = {

      options = {
        "key" = mkOption {
          description = "";
          type = types.str;
        };
        "name" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "optional" = mkOption {
          description = "";
          type = types.nullOr types.bool;
        };
      };

      config = {
        "name" = mkOverride 1002 null;
        "optional" = mkOverride 1002 null;
      };

    };
    "seaweed.seaweedfs.com.v1.SeaweedSpecSftpHostKeysSecret" = {

      options = {
        "name" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
      };

      config = {
        "name" = mkOverride 1002 null;
      };

    };
    "seaweed.seaweedfs.com.v1.SeaweedSpecSftpImagePullSecrets" = {

      options = {
        "name" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
      };

      config = {
        "name" = mkOverride 1002 null;
      };

    };
    "seaweed.seaweedfs.com.v1.SeaweedSpecSftpIngress" = {

      options = {
        "annotations" = mkOption {
          description = "";
          type = types.nullOr (types.attrsOf types.str);
        };
        "className" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "enabled" = mkOption {
          description = "";
          type = types.nullOr types.bool;
        };
        "host" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "path" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "tls" = mkOption {
          description = "";
          type = types.nullOr (
            types.listOf (submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecSftpIngressTls")
          );
        };
      };

      config = {
        "annotations" = mkOverride 1002 null;
        "className" = mkOverride 1002 null;
        "enabled" = mkOverride 1002 null;
        "host" = mkOverride 1002 null;
        "path" = mkOverride 1002 null;
        "tls" = mkOverride 1002 null;
      };

    };
    "seaweed.seaweedfs.com.v1.SeaweedSpecSftpIngressTls" = {

      options = {
        "hosts" = mkOption {
          description = "";
          type = types.nullOr (types.listOf types.str);
        };
        "secretName" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
      };

      config = {
        "hosts" = mkOverride 1002 null;
        "secretName" = mkOverride 1002 null;
      };

    };
    "seaweed.seaweedfs.com.v1.SeaweedSpecSftpLivenessProbe" = {

      options = {
        "failureThreshold" = mkOption {
          description = "";
          type = types.nullOr types.int;
        };
        "initialDelaySeconds" = mkOption {
          description = "";
          type = types.nullOr types.int;
        };
        "periodSeconds" = mkOption {
          description = "";
          type = types.nullOr types.int;
        };
        "timeoutSeconds" = mkOption {
          description = "";
          type = types.nullOr types.int;
        };
      };

      config = {
        "failureThreshold" = mkOverride 1002 null;
        "initialDelaySeconds" = mkOverride 1002 null;
        "periodSeconds" = mkOverride 1002 null;
        "timeoutSeconds" = mkOverride 1002 null;
      };

    };
    "seaweed.seaweedfs.com.v1.SeaweedSpecSftpPodSecurityContext" = {

      options = {
        "appArmorProfile" = mkOption {
          description = "";
          type = types.nullOr (
            submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecSftpPodSecurityContextAppArmorProfile"
          );
        };
        "fsGroup" = mkOption {
          description = "";
          type = types.nullOr types.int;
        };
        "fsGroupChangePolicy" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "runAsGroup" = mkOption {
          description = "";
          type = types.nullOr types.int;
        };
        "runAsNonRoot" = mkOption {
          description = "";
          type = types.nullOr types.bool;
        };
        "runAsUser" = mkOption {
          description = "";
          type = types.nullOr types.int;
        };
        "seLinuxChangePolicy" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "seLinuxOptions" = mkOption {
          description = "";
          type = types.nullOr (
            submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecSftpPodSecurityContextSeLinuxOptions"
          );
        };
        "seccompProfile" = mkOption {
          description = "";
          type = types.nullOr (
            submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecSftpPodSecurityContextSeccompProfile"
          );
        };
        "supplementalGroups" = mkOption {
          description = "";
          type = types.nullOr (types.listOf types.int);
        };
        "supplementalGroupsPolicy" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "sysctls" = mkOption {
          description = "";
          type = types.nullOr (
            coerceAttrsOfSubmodulesToListByKey
              "seaweed.seaweedfs.com.v1.SeaweedSpecSftpPodSecurityContextSysctls"
              "name"
              [ ]
          );
          apply = attrsToList;
        };
        "windowsOptions" = mkOption {
          description = "";
          type = types.nullOr (
            submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecSftpPodSecurityContextWindowsOptions"
          );
        };
      };

      config = {
        "appArmorProfile" = mkOverride 1002 null;
        "fsGroup" = mkOverride 1002 null;
        "fsGroupChangePolicy" = mkOverride 1002 null;
        "runAsGroup" = mkOverride 1002 null;
        "runAsNonRoot" = mkOverride 1002 null;
        "runAsUser" = mkOverride 1002 null;
        "seLinuxChangePolicy" = mkOverride 1002 null;
        "seLinuxOptions" = mkOverride 1002 null;
        "seccompProfile" = mkOverride 1002 null;
        "supplementalGroups" = mkOverride 1002 null;
        "supplementalGroupsPolicy" = mkOverride 1002 null;
        "sysctls" = mkOverride 1002 null;
        "windowsOptions" = mkOverride 1002 null;
      };

    };
    "seaweed.seaweedfs.com.v1.SeaweedSpecSftpPodSecurityContextAppArmorProfile" = {

      options = {
        "localhostProfile" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "type" = mkOption {
          description = "";
          type = types.str;
        };
      };

      config = {
        "localhostProfile" = mkOverride 1002 null;
      };

    };
    "seaweed.seaweedfs.com.v1.SeaweedSpecSftpPodSecurityContextSeLinuxOptions" = {

      options = {
        "level" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "role" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "type" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "user" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
      };

      config = {
        "level" = mkOverride 1002 null;
        "role" = mkOverride 1002 null;
        "type" = mkOverride 1002 null;
        "user" = mkOverride 1002 null;
      };

    };
    "seaweed.seaweedfs.com.v1.SeaweedSpecSftpPodSecurityContextSeccompProfile" = {

      options = {
        "localhostProfile" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "type" = mkOption {
          description = "";
          type = types.str;
        };
      };

      config = {
        "localhostProfile" = mkOverride 1002 null;
      };

    };
    "seaweed.seaweedfs.com.v1.SeaweedSpecSftpPodSecurityContextSysctls" = {

      options = {
        "name" = mkOption {
          description = "";
          type = types.str;
        };
        "value" = mkOption {
          description = "";
          type = types.str;
        };
      };

      config = { };

    };
    "seaweed.seaweedfs.com.v1.SeaweedSpecSftpPodSecurityContextWindowsOptions" = {

      options = {
        "gmsaCredentialSpec" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "gmsaCredentialSpecName" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "hostProcess" = mkOption {
          description = "";
          type = types.nullOr types.bool;
        };
        "runAsUserName" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
      };

      config = {
        "gmsaCredentialSpec" = mkOverride 1002 null;
        "gmsaCredentialSpecName" = mkOverride 1002 null;
        "hostProcess" = mkOverride 1002 null;
        "runAsUserName" = mkOverride 1002 null;
      };

    };
    "seaweed.seaweedfs.com.v1.SeaweedSpecSftpReadinessProbe" = {

      options = {
        "failureThreshold" = mkOption {
          description = "";
          type = types.nullOr types.int;
        };
        "initialDelaySeconds" = mkOption {
          description = "";
          type = types.nullOr types.int;
        };
        "periodSeconds" = mkOption {
          description = "";
          type = types.nullOr types.int;
        };
        "successThreshold" = mkOption {
          description = "";
          type = types.nullOr types.int;
        };
        "timeoutSeconds" = mkOption {
          description = "";
          type = types.nullOr types.int;
        };
      };

      config = {
        "failureThreshold" = mkOverride 1002 null;
        "initialDelaySeconds" = mkOverride 1002 null;
        "periodSeconds" = mkOverride 1002 null;
        "successThreshold" = mkOverride 1002 null;
        "timeoutSeconds" = mkOverride 1002 null;
      };

    };
    "seaweed.seaweedfs.com.v1.SeaweedSpecSftpService" = {

      options = {
        "annotations" = mkOption {
          description = "";
          type = types.nullOr (types.attrsOf types.str);
        };
        "clusterIP" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "loadBalancerIP" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "type" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
      };

      config = {
        "annotations" = mkOverride 1002 null;
        "clusterIP" = mkOverride 1002 null;
        "loadBalancerIP" = mkOverride 1002 null;
        "type" = mkOverride 1002 null;
      };

    };
    "seaweed.seaweedfs.com.v1.SeaweedSpecSftpTolerations" = {

      options = {
        "effect" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "key" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "operator" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "tolerationSeconds" = mkOption {
          description = "";
          type = types.nullOr types.int;
        };
        "value" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
      };

      config = {
        "effect" = mkOverride 1002 null;
        "key" = mkOverride 1002 null;
        "operator" = mkOverride 1002 null;
        "tolerationSeconds" = mkOverride 1002 null;
        "value" = mkOverride 1002 null;
      };

    };
    "seaweed.seaweedfs.com.v1.SeaweedSpecSftpUserStoreSecret" = {

      options = {
        "key" = mkOption {
          description = "";
          type = types.str;
        };
        "name" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "optional" = mkOption {
          description = "";
          type = types.nullOr types.bool;
        };
      };

      config = {
        "name" = mkOverride 1002 null;
        "optional" = mkOverride 1002 null;
      };

    };
    "seaweed.seaweedfs.com.v1.SeaweedSpecSftpVolumeMounts" = {

      options = {
        "mountPath" = mkOption {
          description = "";
          type = types.str;
        };
        "mountPropagation" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "name" = mkOption {
          description = "";
          type = types.str;
        };
        "readOnly" = mkOption {
          description = "";
          type = types.nullOr types.bool;
        };
        "recursiveReadOnly" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "subPath" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "subPathExpr" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
      };

      config = {
        "mountPropagation" = mkOverride 1002 null;
        "readOnly" = mkOverride 1002 null;
        "recursiveReadOnly" = mkOverride 1002 null;
        "subPath" = mkOverride 1002 null;
        "subPathExpr" = mkOverride 1002 null;
      };

    };
    "seaweed.seaweedfs.com.v1.SeaweedSpecSftpVolumes" = {

      options = {
        "awsElasticBlockStore" = mkOption {
          description = "";
          type = types.nullOr (
            submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecSftpVolumesAwsElasticBlockStore"
          );
        };
        "azureDisk" = mkOption {
          description = "";
          type = types.nullOr (submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecSftpVolumesAzureDisk");
        };
        "azureFile" = mkOption {
          description = "";
          type = types.nullOr (submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecSftpVolumesAzureFile");
        };
        "cephfs" = mkOption {
          description = "";
          type = types.nullOr (submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecSftpVolumesCephfs");
        };
        "cinder" = mkOption {
          description = "";
          type = types.nullOr (submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecSftpVolumesCinder");
        };
        "configMap" = mkOption {
          description = "";
          type = types.nullOr (submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecSftpVolumesConfigMap");
        };
        "csi" = mkOption {
          description = "";
          type = types.nullOr (submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecSftpVolumesCsi");
        };
        "downwardAPI" = mkOption {
          description = "";
          type = types.nullOr (submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecSftpVolumesDownwardAPI");
        };
        "emptyDir" = mkOption {
          description = "";
          type = types.nullOr (submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecSftpVolumesEmptyDir");
        };
        "ephemeral" = mkOption {
          description = "";
          type = types.nullOr (submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecSftpVolumesEphemeral");
        };
        "fc" = mkOption {
          description = "";
          type = types.nullOr (submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecSftpVolumesFc");
        };
        "flexVolume" = mkOption {
          description = "";
          type = types.nullOr (submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecSftpVolumesFlexVolume");
        };
        "flocker" = mkOption {
          description = "";
          type = types.nullOr (submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecSftpVolumesFlocker");
        };
        "gcePersistentDisk" = mkOption {
          description = "";
          type = types.nullOr (
            submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecSftpVolumesGcePersistentDisk"
          );
        };
        "gitRepo" = mkOption {
          description = "";
          type = types.nullOr (submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecSftpVolumesGitRepo");
        };
        "glusterfs" = mkOption {
          description = "";
          type = types.nullOr (submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecSftpVolumesGlusterfs");
        };
        "hostPath" = mkOption {
          description = "";
          type = types.nullOr (submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecSftpVolumesHostPath");
        };
        "image" = mkOption {
          description = "";
          type = types.nullOr (submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecSftpVolumesImage");
        };
        "iscsi" = mkOption {
          description = "";
          type = types.nullOr (submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecSftpVolumesIscsi");
        };
        "name" = mkOption {
          description = "";
          type = types.str;
        };
        "nfs" = mkOption {
          description = "";
          type = types.nullOr (submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecSftpVolumesNfs");
        };
        "persistentVolumeClaim" = mkOption {
          description = "";
          type = types.nullOr (
            submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecSftpVolumesPersistentVolumeClaim"
          );
        };
        "photonPersistentDisk" = mkOption {
          description = "";
          type = types.nullOr (
            submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecSftpVolumesPhotonPersistentDisk"
          );
        };
        "portworxVolume" = mkOption {
          description = "";
          type = types.nullOr (submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecSftpVolumesPortworxVolume");
        };
        "projected" = mkOption {
          description = "";
          type = types.nullOr (submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecSftpVolumesProjected");
        };
        "quobyte" = mkOption {
          description = "";
          type = types.nullOr (submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecSftpVolumesQuobyte");
        };
        "rbd" = mkOption {
          description = "";
          type = types.nullOr (submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecSftpVolumesRbd");
        };
        "scaleIO" = mkOption {
          description = "";
          type = types.nullOr (submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecSftpVolumesScaleIO");
        };
        "secret" = mkOption {
          description = "";
          type = types.nullOr (submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecSftpVolumesSecret");
        };
        "storageos" = mkOption {
          description = "";
          type = types.nullOr (submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecSftpVolumesStorageos");
        };
        "vsphereVolume" = mkOption {
          description = "";
          type = types.nullOr (submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecSftpVolumesVsphereVolume");
        };
      };

      config = {
        "awsElasticBlockStore" = mkOverride 1002 null;
        "azureDisk" = mkOverride 1002 null;
        "azureFile" = mkOverride 1002 null;
        "cephfs" = mkOverride 1002 null;
        "cinder" = mkOverride 1002 null;
        "configMap" = mkOverride 1002 null;
        "csi" = mkOverride 1002 null;
        "downwardAPI" = mkOverride 1002 null;
        "emptyDir" = mkOverride 1002 null;
        "ephemeral" = mkOverride 1002 null;
        "fc" = mkOverride 1002 null;
        "flexVolume" = mkOverride 1002 null;
        "flocker" = mkOverride 1002 null;
        "gcePersistentDisk" = mkOverride 1002 null;
        "gitRepo" = mkOverride 1002 null;
        "glusterfs" = mkOverride 1002 null;
        "hostPath" = mkOverride 1002 null;
        "image" = mkOverride 1002 null;
        "iscsi" = mkOverride 1002 null;
        "nfs" = mkOverride 1002 null;
        "persistentVolumeClaim" = mkOverride 1002 null;
        "photonPersistentDisk" = mkOverride 1002 null;
        "portworxVolume" = mkOverride 1002 null;
        "projected" = mkOverride 1002 null;
        "quobyte" = mkOverride 1002 null;
        "rbd" = mkOverride 1002 null;
        "scaleIO" = mkOverride 1002 null;
        "secret" = mkOverride 1002 null;
        "storageos" = mkOverride 1002 null;
        "vsphereVolume" = mkOverride 1002 null;
      };

    };
    "seaweed.seaweedfs.com.v1.SeaweedSpecSftpVolumesAwsElasticBlockStore" = {

      options = {
        "fsType" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "partition" = mkOption {
          description = "";
          type = types.nullOr types.int;
        };
        "readOnly" = mkOption {
          description = "";
          type = types.nullOr types.bool;
        };
        "volumeID" = mkOption {
          description = "";
          type = types.str;
        };
      };

      config = {
        "fsType" = mkOverride 1002 null;
        "partition" = mkOverride 1002 null;
        "readOnly" = mkOverride 1002 null;
      };

    };
    "seaweed.seaweedfs.com.v1.SeaweedSpecSftpVolumesAzureDisk" = {

      options = {
        "cachingMode" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "diskName" = mkOption {
          description = "";
          type = types.str;
        };
        "diskURI" = mkOption {
          description = "";
          type = types.str;
        };
        "fsType" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "kind" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "readOnly" = mkOption {
          description = "";
          type = types.nullOr types.bool;
        };
      };

      config = {
        "cachingMode" = mkOverride 1002 null;
        "fsType" = mkOverride 1002 null;
        "kind" = mkOverride 1002 null;
        "readOnly" = mkOverride 1002 null;
      };

    };
    "seaweed.seaweedfs.com.v1.SeaweedSpecSftpVolumesAzureFile" = {

      options = {
        "readOnly" = mkOption {
          description = "";
          type = types.nullOr types.bool;
        };
        "secretName" = mkOption {
          description = "";
          type = types.str;
        };
        "shareName" = mkOption {
          description = "";
          type = types.str;
        };
      };

      config = {
        "readOnly" = mkOverride 1002 null;
      };

    };
    "seaweed.seaweedfs.com.v1.SeaweedSpecSftpVolumesCephfs" = {

      options = {
        "monitors" = mkOption {
          description = "";
          type = types.listOf types.str;
        };
        "path" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "readOnly" = mkOption {
          description = "";
          type = types.nullOr types.bool;
        };
        "secretFile" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "secretRef" = mkOption {
          description = "";
          type = types.nullOr (submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecSftpVolumesCephfsSecretRef");
        };
        "user" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
      };

      config = {
        "path" = mkOverride 1002 null;
        "readOnly" = mkOverride 1002 null;
        "secretFile" = mkOverride 1002 null;
        "secretRef" = mkOverride 1002 null;
        "user" = mkOverride 1002 null;
      };

    };
    "seaweed.seaweedfs.com.v1.SeaweedSpecSftpVolumesCephfsSecretRef" = {

      options = {
        "name" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
      };

      config = {
        "name" = mkOverride 1002 null;
      };

    };
    "seaweed.seaweedfs.com.v1.SeaweedSpecSftpVolumesCinder" = {

      options = {
        "fsType" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "readOnly" = mkOption {
          description = "";
          type = types.nullOr types.bool;
        };
        "secretRef" = mkOption {
          description = "";
          type = types.nullOr (submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecSftpVolumesCinderSecretRef");
        };
        "volumeID" = mkOption {
          description = "";
          type = types.str;
        };
      };

      config = {
        "fsType" = mkOverride 1002 null;
        "readOnly" = mkOverride 1002 null;
        "secretRef" = mkOverride 1002 null;
      };

    };
    "seaweed.seaweedfs.com.v1.SeaweedSpecSftpVolumesCinderSecretRef" = {

      options = {
        "name" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
      };

      config = {
        "name" = mkOverride 1002 null;
      };

    };
    "seaweed.seaweedfs.com.v1.SeaweedSpecSftpVolumesConfigMap" = {

      options = {
        "defaultMode" = mkOption {
          description = "";
          type = types.nullOr types.int;
        };
        "items" = mkOption {
          description = "";
          type = types.nullOr (
            types.listOf (submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecSftpVolumesConfigMapItems")
          );
        };
        "name" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "optional" = mkOption {
          description = "";
          type = types.nullOr types.bool;
        };
      };

      config = {
        "defaultMode" = mkOverride 1002 null;
        "items" = mkOverride 1002 null;
        "name" = mkOverride 1002 null;
        "optional" = mkOverride 1002 null;
      };

    };
    "seaweed.seaweedfs.com.v1.SeaweedSpecSftpVolumesConfigMapItems" = {

      options = {
        "key" = mkOption {
          description = "";
          type = types.str;
        };
        "mode" = mkOption {
          description = "";
          type = types.nullOr types.int;
        };
        "path" = mkOption {
          description = "";
          type = types.str;
        };
      };

      config = {
        "mode" = mkOverride 1002 null;
      };

    };
    "seaweed.seaweedfs.com.v1.SeaweedSpecSftpVolumesCsi" = {

      options = {
        "driver" = mkOption {
          description = "";
          type = types.str;
        };
        "fsType" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "nodePublishSecretRef" = mkOption {
          description = "";
          type = types.nullOr (
            submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecSftpVolumesCsiNodePublishSecretRef"
          );
        };
        "readOnly" = mkOption {
          description = "";
          type = types.nullOr types.bool;
        };
        "volumeAttributes" = mkOption {
          description = "";
          type = types.nullOr (types.attrsOf types.str);
        };
      };

      config = {
        "fsType" = mkOverride 1002 null;
        "nodePublishSecretRef" = mkOverride 1002 null;
        "readOnly" = mkOverride 1002 null;
        "volumeAttributes" = mkOverride 1002 null;
      };

    };
    "seaweed.seaweedfs.com.v1.SeaweedSpecSftpVolumesCsiNodePublishSecretRef" = {

      options = {
        "name" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
      };

      config = {
        "name" = mkOverride 1002 null;
      };

    };
    "seaweed.seaweedfs.com.v1.SeaweedSpecSftpVolumesDownwardAPI" = {

      options = {
        "defaultMode" = mkOption {
          description = "";
          type = types.nullOr types.int;
        };
        "items" = mkOption {
          description = "";
          type = types.nullOr (
            types.listOf (submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecSftpVolumesDownwardAPIItems")
          );
        };
      };

      config = {
        "defaultMode" = mkOverride 1002 null;
        "items" = mkOverride 1002 null;
      };

    };
    "seaweed.seaweedfs.com.v1.SeaweedSpecSftpVolumesDownwardAPIItems" = {

      options = {
        "fieldRef" = mkOption {
          description = "";
          type = types.nullOr (
            submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecSftpVolumesDownwardAPIItemsFieldRef"
          );
        };
        "mode" = mkOption {
          description = "";
          type = types.nullOr types.int;
        };
        "path" = mkOption {
          description = "";
          type = types.str;
        };
        "resourceFieldRef" = mkOption {
          description = "";
          type = types.nullOr (
            submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecSftpVolumesDownwardAPIItemsResourceFieldRef"
          );
        };
      };

      config = {
        "fieldRef" = mkOverride 1002 null;
        "mode" = mkOverride 1002 null;
        "resourceFieldRef" = mkOverride 1002 null;
      };

    };
    "seaweed.seaweedfs.com.v1.SeaweedSpecSftpVolumesDownwardAPIItemsFieldRef" = {

      options = {
        "apiVersion" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "fieldPath" = mkOption {
          description = "";
          type = types.str;
        };
      };

      config = {
        "apiVersion" = mkOverride 1002 null;
      };

    };
    "seaweed.seaweedfs.com.v1.SeaweedSpecSftpVolumesDownwardAPIItemsResourceFieldRef" = {

      options = {
        "containerName" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "divisor" = mkOption {
          description = "";
          type = types.nullOr (types.either types.int types.str);
        };
        "resource" = mkOption {
          description = "";
          type = types.str;
        };
      };

      config = {
        "containerName" = mkOverride 1002 null;
        "divisor" = mkOverride 1002 null;
      };

    };
    "seaweed.seaweedfs.com.v1.SeaweedSpecSftpVolumesEmptyDir" = {

      options = {
        "medium" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "sizeLimit" = mkOption {
          description = "";
          type = types.nullOr (types.either types.int types.str);
        };
      };

      config = {
        "medium" = mkOverride 1002 null;
        "sizeLimit" = mkOverride 1002 null;
      };

    };
    "seaweed.seaweedfs.com.v1.SeaweedSpecSftpVolumesEphemeral" = {

      options = {
        "volumeClaimTemplate" = mkOption {
          description = "";
          type = types.nullOr (
            submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecSftpVolumesEphemeralVolumeClaimTemplate"
          );
        };
      };

      config = {
        "volumeClaimTemplate" = mkOverride 1002 null;
      };

    };
    "seaweed.seaweedfs.com.v1.SeaweedSpecSftpVolumesEphemeralVolumeClaimTemplate" = {

      options = {
        "metadata" = mkOption {
          description = "";
          type = types.nullOr types.attrs;
        };
        "spec" = mkOption {
          description = "";
          type = submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecSftpVolumesEphemeralVolumeClaimTemplateSpec";
        };
      };

      config = {
        "metadata" = mkOverride 1002 null;
      };

    };
    "seaweed.seaweedfs.com.v1.SeaweedSpecSftpVolumesEphemeralVolumeClaimTemplateSpec" = {

      options = {
        "accessModes" = mkOption {
          description = "";
          type = types.nullOr (types.listOf types.str);
        };
        "dataSource" = mkOption {
          description = "";
          type = types.nullOr (
            submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecSftpVolumesEphemeralVolumeClaimTemplateSpecDataSource"
          );
        };
        "dataSourceRef" = mkOption {
          description = "";
          type = types.nullOr (
            submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecSftpVolumesEphemeralVolumeClaimTemplateSpecDataSourceRef"
          );
        };
        "resources" = mkOption {
          description = "";
          type = types.nullOr (
            submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecSftpVolumesEphemeralVolumeClaimTemplateSpecResources"
          );
        };
        "selector" = mkOption {
          description = "";
          type = types.nullOr (
            submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecSftpVolumesEphemeralVolumeClaimTemplateSpecSelector"
          );
        };
        "storageClassName" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "volumeAttributesClassName" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "volumeMode" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "volumeName" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
      };

      config = {
        "accessModes" = mkOverride 1002 null;
        "dataSource" = mkOverride 1002 null;
        "dataSourceRef" = mkOverride 1002 null;
        "resources" = mkOverride 1002 null;
        "selector" = mkOverride 1002 null;
        "storageClassName" = mkOverride 1002 null;
        "volumeAttributesClassName" = mkOverride 1002 null;
        "volumeMode" = mkOverride 1002 null;
        "volumeName" = mkOverride 1002 null;
      };

    };
    "seaweed.seaweedfs.com.v1.SeaweedSpecSftpVolumesEphemeralVolumeClaimTemplateSpecDataSource" = {

      options = {
        "apiGroup" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "kind" = mkOption {
          description = "";
          type = types.str;
        };
        "name" = mkOption {
          description = "";
          type = types.str;
        };
      };

      config = {
        "apiGroup" = mkOverride 1002 null;
      };

    };
    "seaweed.seaweedfs.com.v1.SeaweedSpecSftpVolumesEphemeralVolumeClaimTemplateSpecDataSourceRef" = {

      options = {
        "apiGroup" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "kind" = mkOption {
          description = "";
          type = types.str;
        };
        "name" = mkOption {
          description = "";
          type = types.str;
        };
        "namespace" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
      };

      config = {
        "apiGroup" = mkOverride 1002 null;
        "namespace" = mkOverride 1002 null;
      };

    };
    "seaweed.seaweedfs.com.v1.SeaweedSpecSftpVolumesEphemeralVolumeClaimTemplateSpecResources" = {

      options = {
        "limits" = mkOption {
          description = "";
          type = types.nullOr (types.attrsOf (types.either types.int types.str));
        };
        "requests" = mkOption {
          description = "";
          type = types.nullOr (types.attrsOf (types.either types.int types.str));
        };
      };

      config = {
        "limits" = mkOverride 1002 null;
        "requests" = mkOverride 1002 null;
      };

    };
    "seaweed.seaweedfs.com.v1.SeaweedSpecSftpVolumesEphemeralVolumeClaimTemplateSpecSelector" = {

      options = {
        "matchExpressions" = mkOption {
          description = "";
          type = types.nullOr (
            types.listOf (
              submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecSftpVolumesEphemeralVolumeClaimTemplateSpecSelectorMatchExpressions"
            )
          );
        };
        "matchLabels" = mkOption {
          description = "";
          type = types.nullOr (types.attrsOf types.str);
        };
      };

      config = {
        "matchExpressions" = mkOverride 1002 null;
        "matchLabels" = mkOverride 1002 null;
      };

    };
    "seaweed.seaweedfs.com.v1.SeaweedSpecSftpVolumesEphemeralVolumeClaimTemplateSpecSelectorMatchExpressions" =
      {

        options = {
          "key" = mkOption {
            description = "";
            type = types.str;
          };
          "operator" = mkOption {
            description = "";
            type = types.str;
          };
          "values" = mkOption {
            description = "";
            type = types.nullOr (types.listOf types.str);
          };
        };

        config = {
          "values" = mkOverride 1002 null;
        };

      };
    "seaweed.seaweedfs.com.v1.SeaweedSpecSftpVolumesFc" = {

      options = {
        "fsType" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "lun" = mkOption {
          description = "";
          type = types.nullOr types.int;
        };
        "readOnly" = mkOption {
          description = "";
          type = types.nullOr types.bool;
        };
        "targetWWNs" = mkOption {
          description = "";
          type = types.nullOr (types.listOf types.str);
        };
        "wwids" = mkOption {
          description = "";
          type = types.nullOr (types.listOf types.str);
        };
      };

      config = {
        "fsType" = mkOverride 1002 null;
        "lun" = mkOverride 1002 null;
        "readOnly" = mkOverride 1002 null;
        "targetWWNs" = mkOverride 1002 null;
        "wwids" = mkOverride 1002 null;
      };

    };
    "seaweed.seaweedfs.com.v1.SeaweedSpecSftpVolumesFlexVolume" = {

      options = {
        "driver" = mkOption {
          description = "";
          type = types.str;
        };
        "fsType" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "options" = mkOption {
          description = "";
          type = types.nullOr (types.attrsOf types.str);
        };
        "readOnly" = mkOption {
          description = "";
          type = types.nullOr types.bool;
        };
        "secretRef" = mkOption {
          description = "";
          type = types.nullOr (
            submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecSftpVolumesFlexVolumeSecretRef"
          );
        };
      };

      config = {
        "fsType" = mkOverride 1002 null;
        "options" = mkOverride 1002 null;
        "readOnly" = mkOverride 1002 null;
        "secretRef" = mkOverride 1002 null;
      };

    };
    "seaweed.seaweedfs.com.v1.SeaweedSpecSftpVolumesFlexVolumeSecretRef" = {

      options = {
        "name" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
      };

      config = {
        "name" = mkOverride 1002 null;
      };

    };
    "seaweed.seaweedfs.com.v1.SeaweedSpecSftpVolumesFlocker" = {

      options = {
        "datasetName" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "datasetUUID" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
      };

      config = {
        "datasetName" = mkOverride 1002 null;
        "datasetUUID" = mkOverride 1002 null;
      };

    };
    "seaweed.seaweedfs.com.v1.SeaweedSpecSftpVolumesGcePersistentDisk" = {

      options = {
        "fsType" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "partition" = mkOption {
          description = "";
          type = types.nullOr types.int;
        };
        "pdName" = mkOption {
          description = "";
          type = types.str;
        };
        "readOnly" = mkOption {
          description = "";
          type = types.nullOr types.bool;
        };
      };

      config = {
        "fsType" = mkOverride 1002 null;
        "partition" = mkOverride 1002 null;
        "readOnly" = mkOverride 1002 null;
      };

    };
    "seaweed.seaweedfs.com.v1.SeaweedSpecSftpVolumesGitRepo" = {

      options = {
        "directory" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "repository" = mkOption {
          description = "";
          type = types.str;
        };
        "revision" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
      };

      config = {
        "directory" = mkOverride 1002 null;
        "revision" = mkOverride 1002 null;
      };

    };
    "seaweed.seaweedfs.com.v1.SeaweedSpecSftpVolumesGlusterfs" = {

      options = {
        "endpoints" = mkOption {
          description = "";
          type = types.str;
        };
        "path" = mkOption {
          description = "";
          type = types.str;
        };
        "readOnly" = mkOption {
          description = "";
          type = types.nullOr types.bool;
        };
      };

      config = {
        "readOnly" = mkOverride 1002 null;
      };

    };
    "seaweed.seaweedfs.com.v1.SeaweedSpecSftpVolumesHostPath" = {

      options = {
        "path" = mkOption {
          description = "";
          type = types.str;
        };
        "type" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
      };

      config = {
        "type" = mkOverride 1002 null;
      };

    };
    "seaweed.seaweedfs.com.v1.SeaweedSpecSftpVolumesImage" = {

      options = {
        "pullPolicy" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "reference" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
      };

      config = {
        "pullPolicy" = mkOverride 1002 null;
        "reference" = mkOverride 1002 null;
      };

    };
    "seaweed.seaweedfs.com.v1.SeaweedSpecSftpVolumesIscsi" = {

      options = {
        "chapAuthDiscovery" = mkOption {
          description = "";
          type = types.nullOr types.bool;
        };
        "chapAuthSession" = mkOption {
          description = "";
          type = types.nullOr types.bool;
        };
        "fsType" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "initiatorName" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "iqn" = mkOption {
          description = "";
          type = types.str;
        };
        "iscsiInterface" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "lun" = mkOption {
          description = "";
          type = types.int;
        };
        "portals" = mkOption {
          description = "";
          type = types.nullOr (types.listOf types.str);
        };
        "readOnly" = mkOption {
          description = "";
          type = types.nullOr types.bool;
        };
        "secretRef" = mkOption {
          description = "";
          type = types.nullOr (submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecSftpVolumesIscsiSecretRef");
        };
        "targetPortal" = mkOption {
          description = "";
          type = types.str;
        };
      };

      config = {
        "chapAuthDiscovery" = mkOverride 1002 null;
        "chapAuthSession" = mkOverride 1002 null;
        "fsType" = mkOverride 1002 null;
        "initiatorName" = mkOverride 1002 null;
        "iscsiInterface" = mkOverride 1002 null;
        "portals" = mkOverride 1002 null;
        "readOnly" = mkOverride 1002 null;
        "secretRef" = mkOverride 1002 null;
      };

    };
    "seaweed.seaweedfs.com.v1.SeaweedSpecSftpVolumesIscsiSecretRef" = {

      options = {
        "name" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
      };

      config = {
        "name" = mkOverride 1002 null;
      };

    };
    "seaweed.seaweedfs.com.v1.SeaweedSpecSftpVolumesNfs" = {

      options = {
        "path" = mkOption {
          description = "";
          type = types.str;
        };
        "readOnly" = mkOption {
          description = "";
          type = types.nullOr types.bool;
        };
        "server" = mkOption {
          description = "";
          type = types.str;
        };
      };

      config = {
        "readOnly" = mkOverride 1002 null;
      };

    };
    "seaweed.seaweedfs.com.v1.SeaweedSpecSftpVolumesPersistentVolumeClaim" = {

      options = {
        "claimName" = mkOption {
          description = "";
          type = types.str;
        };
        "readOnly" = mkOption {
          description = "";
          type = types.nullOr types.bool;
        };
      };

      config = {
        "readOnly" = mkOverride 1002 null;
      };

    };
    "seaweed.seaweedfs.com.v1.SeaweedSpecSftpVolumesPhotonPersistentDisk" = {

      options = {
        "fsType" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "pdID" = mkOption {
          description = "";
          type = types.str;
        };
      };

      config = {
        "fsType" = mkOverride 1002 null;
      };

    };
    "seaweed.seaweedfs.com.v1.SeaweedSpecSftpVolumesPortworxVolume" = {

      options = {
        "fsType" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "readOnly" = mkOption {
          description = "";
          type = types.nullOr types.bool;
        };
        "volumeID" = mkOption {
          description = "";
          type = types.str;
        };
      };

      config = {
        "fsType" = mkOverride 1002 null;
        "readOnly" = mkOverride 1002 null;
      };

    };
    "seaweed.seaweedfs.com.v1.SeaweedSpecSftpVolumesProjected" = {

      options = {
        "defaultMode" = mkOption {
          description = "";
          type = types.nullOr types.int;
        };
        "sources" = mkOption {
          description = "";
          type = types.nullOr (
            types.listOf (submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecSftpVolumesProjectedSources")
          );
        };
      };

      config = {
        "defaultMode" = mkOverride 1002 null;
        "sources" = mkOverride 1002 null;
      };

    };
    "seaweed.seaweedfs.com.v1.SeaweedSpecSftpVolumesProjectedSources" = {

      options = {
        "clusterTrustBundle" = mkOption {
          description = "";
          type = types.nullOr (
            submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecSftpVolumesProjectedSourcesClusterTrustBundle"
          );
        };
        "configMap" = mkOption {
          description = "";
          type = types.nullOr (
            submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecSftpVolumesProjectedSourcesConfigMap"
          );
        };
        "downwardAPI" = mkOption {
          description = "";
          type = types.nullOr (
            submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecSftpVolumesProjectedSourcesDownwardAPI"
          );
        };
        "podCertificate" = mkOption {
          description = "";
          type = types.nullOr (
            submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecSftpVolumesProjectedSourcesPodCertificate"
          );
        };
        "secret" = mkOption {
          description = "";
          type = types.nullOr (
            submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecSftpVolumesProjectedSourcesSecret"
          );
        };
        "serviceAccountToken" = mkOption {
          description = "";
          type = types.nullOr (
            submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecSftpVolumesProjectedSourcesServiceAccountToken"
          );
        };
      };

      config = {
        "clusterTrustBundle" = mkOverride 1002 null;
        "configMap" = mkOverride 1002 null;
        "downwardAPI" = mkOverride 1002 null;
        "podCertificate" = mkOverride 1002 null;
        "secret" = mkOverride 1002 null;
        "serviceAccountToken" = mkOverride 1002 null;
      };

    };
    "seaweed.seaweedfs.com.v1.SeaweedSpecSftpVolumesProjectedSourcesClusterTrustBundle" = {

      options = {
        "labelSelector" = mkOption {
          description = "";
          type = types.nullOr (
            submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecSftpVolumesProjectedSourcesClusterTrustBundleLabelSelector"
          );
        };
        "name" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "optional" = mkOption {
          description = "";
          type = types.nullOr types.bool;
        };
        "path" = mkOption {
          description = "";
          type = types.str;
        };
        "signerName" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
      };

      config = {
        "labelSelector" = mkOverride 1002 null;
        "name" = mkOverride 1002 null;
        "optional" = mkOverride 1002 null;
        "signerName" = mkOverride 1002 null;
      };

    };
    "seaweed.seaweedfs.com.v1.SeaweedSpecSftpVolumesProjectedSourcesClusterTrustBundleLabelSelector" = {

      options = {
        "matchExpressions" = mkOption {
          description = "";
          type = types.nullOr (
            types.listOf (
              submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecSftpVolumesProjectedSourcesClusterTrustBundleLabelSelectorMatchExpressions"
            )
          );
        };
        "matchLabels" = mkOption {
          description = "";
          type = types.nullOr (types.attrsOf types.str);
        };
      };

      config = {
        "matchExpressions" = mkOverride 1002 null;
        "matchLabels" = mkOverride 1002 null;
      };

    };
    "seaweed.seaweedfs.com.v1.SeaweedSpecSftpVolumesProjectedSourcesClusterTrustBundleLabelSelectorMatchExpressions" =
      {

        options = {
          "key" = mkOption {
            description = "";
            type = types.str;
          };
          "operator" = mkOption {
            description = "";
            type = types.str;
          };
          "values" = mkOption {
            description = "";
            type = types.nullOr (types.listOf types.str);
          };
        };

        config = {
          "values" = mkOverride 1002 null;
        };

      };
    "seaweed.seaweedfs.com.v1.SeaweedSpecSftpVolumesProjectedSourcesConfigMap" = {

      options = {
        "items" = mkOption {
          description = "";
          type = types.nullOr (
            types.listOf (
              submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecSftpVolumesProjectedSourcesConfigMapItems"
            )
          );
        };
        "name" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "optional" = mkOption {
          description = "";
          type = types.nullOr types.bool;
        };
      };

      config = {
        "items" = mkOverride 1002 null;
        "name" = mkOverride 1002 null;
        "optional" = mkOverride 1002 null;
      };

    };
    "seaweed.seaweedfs.com.v1.SeaweedSpecSftpVolumesProjectedSourcesConfigMapItems" = {

      options = {
        "key" = mkOption {
          description = "";
          type = types.str;
        };
        "mode" = mkOption {
          description = "";
          type = types.nullOr types.int;
        };
        "path" = mkOption {
          description = "";
          type = types.str;
        };
      };

      config = {
        "mode" = mkOverride 1002 null;
      };

    };
    "seaweed.seaweedfs.com.v1.SeaweedSpecSftpVolumesProjectedSourcesDownwardAPI" = {

      options = {
        "items" = mkOption {
          description = "";
          type = types.nullOr (
            types.listOf (
              submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecSftpVolumesProjectedSourcesDownwardAPIItems"
            )
          );
        };
      };

      config = {
        "items" = mkOverride 1002 null;
      };

    };
    "seaweed.seaweedfs.com.v1.SeaweedSpecSftpVolumesProjectedSourcesDownwardAPIItems" = {

      options = {
        "fieldRef" = mkOption {
          description = "";
          type = types.nullOr (
            submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecSftpVolumesProjectedSourcesDownwardAPIItemsFieldRef"
          );
        };
        "mode" = mkOption {
          description = "";
          type = types.nullOr types.int;
        };
        "path" = mkOption {
          description = "";
          type = types.str;
        };
        "resourceFieldRef" = mkOption {
          description = "";
          type = types.nullOr (
            submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecSftpVolumesProjectedSourcesDownwardAPIItemsResourceFieldRef"
          );
        };
      };

      config = {
        "fieldRef" = mkOverride 1002 null;
        "mode" = mkOverride 1002 null;
        "resourceFieldRef" = mkOverride 1002 null;
      };

    };
    "seaweed.seaweedfs.com.v1.SeaweedSpecSftpVolumesProjectedSourcesDownwardAPIItemsFieldRef" = {

      options = {
        "apiVersion" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "fieldPath" = mkOption {
          description = "";
          type = types.str;
        };
      };

      config = {
        "apiVersion" = mkOverride 1002 null;
      };

    };
    "seaweed.seaweedfs.com.v1.SeaweedSpecSftpVolumesProjectedSourcesDownwardAPIItemsResourceFieldRef" =
      {

        options = {
          "containerName" = mkOption {
            description = "";
            type = types.nullOr types.str;
          };
          "divisor" = mkOption {
            description = "";
            type = types.nullOr (types.either types.int types.str);
          };
          "resource" = mkOption {
            description = "";
            type = types.str;
          };
        };

        config = {
          "containerName" = mkOverride 1002 null;
          "divisor" = mkOverride 1002 null;
        };

      };
    "seaweed.seaweedfs.com.v1.SeaweedSpecSftpVolumesProjectedSourcesPodCertificate" = {

      options = {
        "certificateChainPath" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "credentialBundlePath" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "keyPath" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "keyType" = mkOption {
          description = "";
          type = types.str;
        };
        "maxExpirationSeconds" = mkOption {
          description = "";
          type = types.nullOr types.int;
        };
        "signerName" = mkOption {
          description = "";
          type = types.str;
        };
        "userAnnotations" = mkOption {
          description = "";
          type = types.nullOr (types.attrsOf types.str);
        };
      };

      config = {
        "certificateChainPath" = mkOverride 1002 null;
        "credentialBundlePath" = mkOverride 1002 null;
        "keyPath" = mkOverride 1002 null;
        "maxExpirationSeconds" = mkOverride 1002 null;
        "userAnnotations" = mkOverride 1002 null;
      };

    };
    "seaweed.seaweedfs.com.v1.SeaweedSpecSftpVolumesProjectedSourcesSecret" = {

      options = {
        "items" = mkOption {
          description = "";
          type = types.nullOr (
            types.listOf (
              submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecSftpVolumesProjectedSourcesSecretItems"
            )
          );
        };
        "name" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "optional" = mkOption {
          description = "";
          type = types.nullOr types.bool;
        };
      };

      config = {
        "items" = mkOverride 1002 null;
        "name" = mkOverride 1002 null;
        "optional" = mkOverride 1002 null;
      };

    };
    "seaweed.seaweedfs.com.v1.SeaweedSpecSftpVolumesProjectedSourcesSecretItems" = {

      options = {
        "key" = mkOption {
          description = "";
          type = types.str;
        };
        "mode" = mkOption {
          description = "";
          type = types.nullOr types.int;
        };
        "path" = mkOption {
          description = "";
          type = types.str;
        };
      };

      config = {
        "mode" = mkOverride 1002 null;
      };

    };
    "seaweed.seaweedfs.com.v1.SeaweedSpecSftpVolumesProjectedSourcesServiceAccountToken" = {

      options = {
        "audience" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "expirationSeconds" = mkOption {
          description = "";
          type = types.nullOr types.int;
        };
        "path" = mkOption {
          description = "";
          type = types.str;
        };
      };

      config = {
        "audience" = mkOverride 1002 null;
        "expirationSeconds" = mkOverride 1002 null;
      };

    };
    "seaweed.seaweedfs.com.v1.SeaweedSpecSftpVolumesQuobyte" = {

      options = {
        "group" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "readOnly" = mkOption {
          description = "";
          type = types.nullOr types.bool;
        };
        "registry" = mkOption {
          description = "";
          type = types.str;
        };
        "tenant" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "user" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "volume" = mkOption {
          description = "";
          type = types.str;
        };
      };

      config = {
        "group" = mkOverride 1002 null;
        "readOnly" = mkOverride 1002 null;
        "tenant" = mkOverride 1002 null;
        "user" = mkOverride 1002 null;
      };

    };
    "seaweed.seaweedfs.com.v1.SeaweedSpecSftpVolumesRbd" = {

      options = {
        "fsType" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "image" = mkOption {
          description = "";
          type = types.str;
        };
        "keyring" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "monitors" = mkOption {
          description = "";
          type = types.listOf types.str;
        };
        "pool" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "readOnly" = mkOption {
          description = "";
          type = types.nullOr types.bool;
        };
        "secretRef" = mkOption {
          description = "";
          type = types.nullOr (submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecSftpVolumesRbdSecretRef");
        };
        "user" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
      };

      config = {
        "fsType" = mkOverride 1002 null;
        "keyring" = mkOverride 1002 null;
        "pool" = mkOverride 1002 null;
        "readOnly" = mkOverride 1002 null;
        "secretRef" = mkOverride 1002 null;
        "user" = mkOverride 1002 null;
      };

    };
    "seaweed.seaweedfs.com.v1.SeaweedSpecSftpVolumesRbdSecretRef" = {

      options = {
        "name" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
      };

      config = {
        "name" = mkOverride 1002 null;
      };

    };
    "seaweed.seaweedfs.com.v1.SeaweedSpecSftpVolumesScaleIO" = {

      options = {
        "fsType" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "gateway" = mkOption {
          description = "";
          type = types.str;
        };
        "protectionDomain" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "readOnly" = mkOption {
          description = "";
          type = types.nullOr types.bool;
        };
        "secretRef" = mkOption {
          description = "";
          type = submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecSftpVolumesScaleIOSecretRef";
        };
        "sslEnabled" = mkOption {
          description = "";
          type = types.nullOr types.bool;
        };
        "storageMode" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "storagePool" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "system" = mkOption {
          description = "";
          type = types.str;
        };
        "volumeName" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
      };

      config = {
        "fsType" = mkOverride 1002 null;
        "protectionDomain" = mkOverride 1002 null;
        "readOnly" = mkOverride 1002 null;
        "sslEnabled" = mkOverride 1002 null;
        "storageMode" = mkOverride 1002 null;
        "storagePool" = mkOverride 1002 null;
        "volumeName" = mkOverride 1002 null;
      };

    };
    "seaweed.seaweedfs.com.v1.SeaweedSpecSftpVolumesScaleIOSecretRef" = {

      options = {
        "name" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
      };

      config = {
        "name" = mkOverride 1002 null;
      };

    };
    "seaweed.seaweedfs.com.v1.SeaweedSpecSftpVolumesSecret" = {

      options = {
        "defaultMode" = mkOption {
          description = "";
          type = types.nullOr types.int;
        };
        "items" = mkOption {
          description = "";
          type = types.nullOr (
            types.listOf (submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecSftpVolumesSecretItems")
          );
        };
        "optional" = mkOption {
          description = "";
          type = types.nullOr types.bool;
        };
        "secretName" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
      };

      config = {
        "defaultMode" = mkOverride 1002 null;
        "items" = mkOverride 1002 null;
        "optional" = mkOverride 1002 null;
        "secretName" = mkOverride 1002 null;
      };

    };
    "seaweed.seaweedfs.com.v1.SeaweedSpecSftpVolumesSecretItems" = {

      options = {
        "key" = mkOption {
          description = "";
          type = types.str;
        };
        "mode" = mkOption {
          description = "";
          type = types.nullOr types.int;
        };
        "path" = mkOption {
          description = "";
          type = types.str;
        };
      };

      config = {
        "mode" = mkOverride 1002 null;
      };

    };
    "seaweed.seaweedfs.com.v1.SeaweedSpecSftpVolumesStorageos" = {

      options = {
        "fsType" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "readOnly" = mkOption {
          description = "";
          type = types.nullOr types.bool;
        };
        "secretRef" = mkOption {
          description = "";
          type = types.nullOr (
            submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecSftpVolumesStorageosSecretRef"
          );
        };
        "volumeName" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "volumeNamespace" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
      };

      config = {
        "fsType" = mkOverride 1002 null;
        "readOnly" = mkOverride 1002 null;
        "secretRef" = mkOverride 1002 null;
        "volumeName" = mkOverride 1002 null;
        "volumeNamespace" = mkOverride 1002 null;
      };

    };
    "seaweed.seaweedfs.com.v1.SeaweedSpecSftpVolumesStorageosSecretRef" = {

      options = {
        "name" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
      };

      config = {
        "name" = mkOverride 1002 null;
      };

    };
    "seaweed.seaweedfs.com.v1.SeaweedSpecSftpVolumesVsphereVolume" = {

      options = {
        "fsType" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "storagePolicyID" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "storagePolicyName" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "volumePath" = mkOption {
          description = "";
          type = types.str;
        };
      };

      config = {
        "fsType" = mkOverride 1002 null;
        "storagePolicyID" = mkOverride 1002 null;
        "storagePolicyName" = mkOverride 1002 null;
      };

    };
    "seaweed.seaweedfs.com.v1.SeaweedSpecTls" = {

      options = {
        "enabled" = mkOption {
          description = "";
          type = types.nullOr types.bool;
        };
        "issuerRef" = mkOption {
          description = "";
          type = types.nullOr (submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecTlsIssuerRef");
        };
      };

      config = {
        "enabled" = mkOverride 1002 null;
        "issuerRef" = mkOverride 1002 null;
      };

    };
    "seaweed.seaweedfs.com.v1.SeaweedSpecTlsIssuerRef" = {

      options = {
        "group" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "kind" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "name" = mkOption {
          description = "";
          type = types.str;
        };
      };

      config = {
        "group" = mkOverride 1002 null;
        "kind" = mkOverride 1002 null;
      };

    };
    "seaweed.seaweedfs.com.v1.SeaweedSpecTolerations" = {

      options = {
        "effect" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "key" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "operator" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "tolerationSeconds" = mkOption {
          description = "";
          type = types.nullOr types.int;
        };
        "value" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
      };

      config = {
        "effect" = mkOverride 1002 null;
        "key" = mkOverride 1002 null;
        "operator" = mkOverride 1002 null;
        "tolerationSeconds" = mkOverride 1002 null;
        "value" = mkOverride 1002 null;
      };

    };
    "seaweed.seaweedfs.com.v1.SeaweedSpecVolume" = {

      options = {
        "affinity" = mkOption {
          description = "";
          type = types.nullOr (submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecVolumeAffinity");
        };
        "annotations" = mkOption {
          description = "";
          type = types.nullOr (types.attrsOf types.str);
        };
        "claims" = mkOption {
          description = "";
          type = types.nullOr (
            coerceAttrsOfSubmodulesToListByKey "seaweed.seaweedfs.com.v1.SeaweedSpecVolumeClaims" "name" [
              "name"
            ]
          );
          apply = attrsToList;
        };
        "compactionMBps" = mkOption {
          description = "";
          type = types.nullOr types.int;
        };
        "containerSecurityContext" = mkOption {
          description = "";
          type = types.nullOr (
            submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecVolumeContainerSecurityContext"
          );
        };
        "dataCenter" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "env" = mkOption {
          description = "";
          type = types.nullOr (
            coerceAttrsOfSubmodulesToListByKey "seaweed.seaweedfs.com.v1.SeaweedSpecVolumeEnv" "name" [ ]
          );
          apply = attrsToList;
        };
        "extraArgs" = mkOption {
          description = "";
          type = types.nullOr (types.listOf types.str);
        };
        "fileSizeLimitMB" = mkOption {
          description = "";
          type = types.nullOr types.int;
        };
        "fixJpgOrientation" = mkOption {
          description = "";
          type = types.nullOr types.bool;
        };
        "hostNetwork" = mkOption {
          description = "";
          type = types.nullOr types.bool;
        };
        "hostPath" = mkOption {
          description = "";
          type = types.nullOr (
            types.listOf (submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecVolumeHostPath")
          );
        };
        "idleTimeout" = mkOption {
          description = "";
          type = types.nullOr types.int;
        };
        "imagePullPolicy" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "imagePullSecrets" = mkOption {
          description = "";
          type = types.nullOr (
            coerceAttrsOfSubmodulesToListByKey "seaweed.seaweedfs.com.v1.SeaweedSpecVolumeImagePullSecrets"
              "name"
              [ ]
          );
          apply = attrsToList;
        };
        "ingress" = mkOption {
          description = "";
          type = types.nullOr (submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecVolumeIngress");
        };
        "initContainers" = mkOption {
          description = "";
          type = types.nullOr types.unspecified;
        };
        "kind" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "labels" = mkOption {
          description = "";
          type = types.nullOr (types.attrsOf types.str);
        };
        "limits" = mkOption {
          description = "";
          type = types.nullOr (types.attrsOf (types.either types.int types.str));
        };
        "livenessProbe" = mkOption {
          description = "";
          type = types.nullOr (submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecVolumeLivenessProbe");
        };
        "loggingArgs" = mkOption {
          description = "";
          type = types.nullOr (types.listOf types.str);
        };
        "maxVolumeCounts" = mkOption {
          description = "";
          type = types.nullOr types.int;
        };
        "metricsPort" = mkOption {
          description = "";
          type = types.nullOr types.int;
        };
        "minFreeSpacePercent" = mkOption {
          description = "";
          type = types.nullOr types.int;
        };
        "nodeSelector" = mkOption {
          description = "";
          type = types.nullOr (types.attrsOf types.str);
        };
        "podSecurityContext" = mkOption {
          description = "";
          type = types.nullOr (submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecVolumePodSecurityContext");
        };
        "priorityClassName" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "rack" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "readinessProbe" = mkOption {
          description = "";
          type = types.nullOr (submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecVolumeReadinessProbe");
        };
        "replicas" = mkOption {
          description = "";
          type = types.int;
        };
        "requests" = mkOption {
          description = "";
          type = types.nullOr (types.attrsOf (types.either types.int types.str));
        };
        "schedulerName" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "service" = mkOption {
          description = "";
          type = types.nullOr (submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecVolumeService");
        };
        "serviceAccountName" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "sidecars" = mkOption {
          description = "";
          type = types.nullOr types.unspecified;
        };
        "statefulSetUpdateStrategy" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "storageAnnotations" = mkOption {
          description = "";
          type = types.nullOr (types.attrsOf types.str);
        };
        "storageClassName" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "storageLabels" = mkOption {
          description = "";
          type = types.nullOr (types.attrsOf types.str);
        };
        "storageSelector" = mkOption {
          description = "";
          type = types.nullOr (submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecVolumeStorageSelector");
        };
        "terminationGracePeriodSeconds" = mkOption {
          description = "";
          type = types.nullOr types.int;
        };
        "tolerations" = mkOption {
          description = "";
          type = types.nullOr (
            types.listOf (submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecVolumeTolerations")
          );
        };
        "version" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "volumeMounts" = mkOption {
          description = "";
          type = types.nullOr (
            coerceAttrsOfSubmodulesToListByKey "seaweed.seaweedfs.com.v1.SeaweedSpecVolumeVolumeMounts" "name"
              [ ]
          );
          apply = attrsToList;
        };
        "volumes" = mkOption {
          description = "";
          type = types.nullOr (
            coerceAttrsOfSubmodulesToListByKey "seaweed.seaweedfs.com.v1.SeaweedSpecVolumeVolumes" "name" [ ]
          );
          apply = attrsToList;
        };
      };

      config = {
        "affinity" = mkOverride 1002 null;
        "annotations" = mkOverride 1002 null;
        "claims" = mkOverride 1002 null;
        "compactionMBps" = mkOverride 1002 null;
        "containerSecurityContext" = mkOverride 1002 null;
        "dataCenter" = mkOverride 1002 null;
        "env" = mkOverride 1002 null;
        "extraArgs" = mkOverride 1002 null;
        "fileSizeLimitMB" = mkOverride 1002 null;
        "fixJpgOrientation" = mkOverride 1002 null;
        "hostNetwork" = mkOverride 1002 null;
        "hostPath" = mkOverride 1002 null;
        "idleTimeout" = mkOverride 1002 null;
        "imagePullPolicy" = mkOverride 1002 null;
        "imagePullSecrets" = mkOverride 1002 null;
        "ingress" = mkOverride 1002 null;
        "initContainers" = mkOverride 1002 null;
        "kind" = mkOverride 1002 null;
        "labels" = mkOverride 1002 null;
        "limits" = mkOverride 1002 null;
        "livenessProbe" = mkOverride 1002 null;
        "loggingArgs" = mkOverride 1002 null;
        "maxVolumeCounts" = mkOverride 1002 null;
        "metricsPort" = mkOverride 1002 null;
        "minFreeSpacePercent" = mkOverride 1002 null;
        "nodeSelector" = mkOverride 1002 null;
        "podSecurityContext" = mkOverride 1002 null;
        "priorityClassName" = mkOverride 1002 null;
        "rack" = mkOverride 1002 null;
        "readinessProbe" = mkOverride 1002 null;
        "requests" = mkOverride 1002 null;
        "schedulerName" = mkOverride 1002 null;
        "service" = mkOverride 1002 null;
        "serviceAccountName" = mkOverride 1002 null;
        "sidecars" = mkOverride 1002 null;
        "statefulSetUpdateStrategy" = mkOverride 1002 null;
        "storageAnnotations" = mkOverride 1002 null;
        "storageClassName" = mkOverride 1002 null;
        "storageLabels" = mkOverride 1002 null;
        "storageSelector" = mkOverride 1002 null;
        "terminationGracePeriodSeconds" = mkOverride 1002 null;
        "tolerations" = mkOverride 1002 null;
        "version" = mkOverride 1002 null;
        "volumeMounts" = mkOverride 1002 null;
        "volumes" = mkOverride 1002 null;
      };

    };
    "seaweed.seaweedfs.com.v1.SeaweedSpecVolumeAffinity" = {

      options = {
        "nodeAffinity" = mkOption {
          description = "";
          type = types.nullOr (submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecVolumeAffinityNodeAffinity");
        };
        "podAffinity" = mkOption {
          description = "";
          type = types.nullOr (submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecVolumeAffinityPodAffinity");
        };
        "podAntiAffinity" = mkOption {
          description = "";
          type = types.nullOr (
            submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecVolumeAffinityPodAntiAffinity"
          );
        };
      };

      config = {
        "nodeAffinity" = mkOverride 1002 null;
        "podAffinity" = mkOverride 1002 null;
        "podAntiAffinity" = mkOverride 1002 null;
      };

    };
    "seaweed.seaweedfs.com.v1.SeaweedSpecVolumeAffinityNodeAffinity" = {

      options = {
        "preferredDuringSchedulingIgnoredDuringExecution" = mkOption {
          description = "";
          type = types.nullOr (
            types.listOf (
              submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecVolumeAffinityNodeAffinityPreferredDuringSchedulingIgnoredDuringExecution"
            )
          );
        };
        "requiredDuringSchedulingIgnoredDuringExecution" = mkOption {
          description = "";
          type = types.nullOr (
            submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecVolumeAffinityNodeAffinityRequiredDuringSchedulingIgnoredDuringExecution"
          );
        };
      };

      config = {
        "preferredDuringSchedulingIgnoredDuringExecution" = mkOverride 1002 null;
        "requiredDuringSchedulingIgnoredDuringExecution" = mkOverride 1002 null;
      };

    };
    "seaweed.seaweedfs.com.v1.SeaweedSpecVolumeAffinityNodeAffinityPreferredDuringSchedulingIgnoredDuringExecution" =
      {

        options = {
          "preference" = mkOption {
            description = "";
            type = submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecVolumeAffinityNodeAffinityPreferredDuringSchedulingIgnoredDuringExecutionPreference";
          };
          "weight" = mkOption {
            description = "";
            type = types.int;
          };
        };

        config = { };

      };
    "seaweed.seaweedfs.com.v1.SeaweedSpecVolumeAffinityNodeAffinityPreferredDuringSchedulingIgnoredDuringExecutionPreference" =
      {

        options = {
          "matchExpressions" = mkOption {
            description = "";
            type = types.nullOr (
              types.listOf (
                submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecVolumeAffinityNodeAffinityPreferredDuringSchedulingIgnoredDuringExecutionPreferenceMatchExpressions"
              )
            );
          };
          "matchFields" = mkOption {
            description = "";
            type = types.nullOr (
              types.listOf (
                submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecVolumeAffinityNodeAffinityPreferredDuringSchedulingIgnoredDuringExecutionPreferenceMatchFields"
              )
            );
          };
        };

        config = {
          "matchExpressions" = mkOverride 1002 null;
          "matchFields" = mkOverride 1002 null;
        };

      };
    "seaweed.seaweedfs.com.v1.SeaweedSpecVolumeAffinityNodeAffinityPreferredDuringSchedulingIgnoredDuringExecutionPreferenceMatchExpressions" =
      {

        options = {
          "key" = mkOption {
            description = "";
            type = types.str;
          };
          "operator" = mkOption {
            description = "";
            type = types.str;
          };
          "values" = mkOption {
            description = "";
            type = types.nullOr (types.listOf types.str);
          };
        };

        config = {
          "values" = mkOverride 1002 null;
        };

      };
    "seaweed.seaweedfs.com.v1.SeaweedSpecVolumeAffinityNodeAffinityPreferredDuringSchedulingIgnoredDuringExecutionPreferenceMatchFields" =
      {

        options = {
          "key" = mkOption {
            description = "";
            type = types.str;
          };
          "operator" = mkOption {
            description = "";
            type = types.str;
          };
          "values" = mkOption {
            description = "";
            type = types.nullOr (types.listOf types.str);
          };
        };

        config = {
          "values" = mkOverride 1002 null;
        };

      };
    "seaweed.seaweedfs.com.v1.SeaweedSpecVolumeAffinityNodeAffinityRequiredDuringSchedulingIgnoredDuringExecution" =
      {

        options = {
          "nodeSelectorTerms" = mkOption {
            description = "";
            type = types.listOf (
              submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecVolumeAffinityNodeAffinityRequiredDuringSchedulingIgnoredDuringExecutionNodeSelectorTerms"
            );
          };
        };

        config = { };

      };
    "seaweed.seaweedfs.com.v1.SeaweedSpecVolumeAffinityNodeAffinityRequiredDuringSchedulingIgnoredDuringExecutionNodeSelectorTerms" =
      {

        options = {
          "matchExpressions" = mkOption {
            description = "";
            type = types.nullOr (
              types.listOf (
                submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecVolumeAffinityNodeAffinityRequiredDuringSchedulingIgnoredDuringExecutionNodeSelectorTermsMatchExpressions"
              )
            );
          };
          "matchFields" = mkOption {
            description = "";
            type = types.nullOr (
              types.listOf (
                submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecVolumeAffinityNodeAffinityRequiredDuringSchedulingIgnoredDuringExecutionNodeSelectorTermsMatchFields"
              )
            );
          };
        };

        config = {
          "matchExpressions" = mkOverride 1002 null;
          "matchFields" = mkOverride 1002 null;
        };

      };
    "seaweed.seaweedfs.com.v1.SeaweedSpecVolumeAffinityNodeAffinityRequiredDuringSchedulingIgnoredDuringExecutionNodeSelectorTermsMatchExpressions" =
      {

        options = {
          "key" = mkOption {
            description = "";
            type = types.str;
          };
          "operator" = mkOption {
            description = "";
            type = types.str;
          };
          "values" = mkOption {
            description = "";
            type = types.nullOr (types.listOf types.str);
          };
        };

        config = {
          "values" = mkOverride 1002 null;
        };

      };
    "seaweed.seaweedfs.com.v1.SeaweedSpecVolumeAffinityNodeAffinityRequiredDuringSchedulingIgnoredDuringExecutionNodeSelectorTermsMatchFields" =
      {

        options = {
          "key" = mkOption {
            description = "";
            type = types.str;
          };
          "operator" = mkOption {
            description = "";
            type = types.str;
          };
          "values" = mkOption {
            description = "";
            type = types.nullOr (types.listOf types.str);
          };
        };

        config = {
          "values" = mkOverride 1002 null;
        };

      };
    "seaweed.seaweedfs.com.v1.SeaweedSpecVolumeAffinityPodAffinity" = {

      options = {
        "preferredDuringSchedulingIgnoredDuringExecution" = mkOption {
          description = "";
          type = types.nullOr (
            types.listOf (
              submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecVolumeAffinityPodAffinityPreferredDuringSchedulingIgnoredDuringExecution"
            )
          );
        };
        "requiredDuringSchedulingIgnoredDuringExecution" = mkOption {
          description = "";
          type = types.nullOr (
            types.listOf (
              submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecVolumeAffinityPodAffinityRequiredDuringSchedulingIgnoredDuringExecution"
            )
          );
        };
      };

      config = {
        "preferredDuringSchedulingIgnoredDuringExecution" = mkOverride 1002 null;
        "requiredDuringSchedulingIgnoredDuringExecution" = mkOverride 1002 null;
      };

    };
    "seaweed.seaweedfs.com.v1.SeaweedSpecVolumeAffinityPodAffinityPreferredDuringSchedulingIgnoredDuringExecution" =
      {

        options = {
          "podAffinityTerm" = mkOption {
            description = "";
            type = submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecVolumeAffinityPodAffinityPreferredDuringSchedulingIgnoredDuringExecutionPodAffinityTerm";
          };
          "weight" = mkOption {
            description = "";
            type = types.int;
          };
        };

        config = { };

      };
    "seaweed.seaweedfs.com.v1.SeaweedSpecVolumeAffinityPodAffinityPreferredDuringSchedulingIgnoredDuringExecutionPodAffinityTerm" =
      {

        options = {
          "labelSelector" = mkOption {
            description = "";
            type = types.nullOr (
              submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecVolumeAffinityPodAffinityPreferredDuringSchedulingIgnoredDuringExecutionPodAffinityTermLabelSelector"
            );
          };
          "matchLabelKeys" = mkOption {
            description = "";
            type = types.nullOr (types.listOf types.str);
          };
          "mismatchLabelKeys" = mkOption {
            description = "";
            type = types.nullOr (types.listOf types.str);
          };
          "namespaceSelector" = mkOption {
            description = "";
            type = types.nullOr (
              submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecVolumeAffinityPodAffinityPreferredDuringSchedulingIgnoredDuringExecutionPodAffinityTermNamespaceSelector"
            );
          };
          "namespaces" = mkOption {
            description = "";
            type = types.nullOr (types.listOf types.str);
          };
          "topologyKey" = mkOption {
            description = "";
            type = types.str;
          };
        };

        config = {
          "labelSelector" = mkOverride 1002 null;
          "matchLabelKeys" = mkOverride 1002 null;
          "mismatchLabelKeys" = mkOverride 1002 null;
          "namespaceSelector" = mkOverride 1002 null;
          "namespaces" = mkOverride 1002 null;
        };

      };
    "seaweed.seaweedfs.com.v1.SeaweedSpecVolumeAffinityPodAffinityPreferredDuringSchedulingIgnoredDuringExecutionPodAffinityTermLabelSelector" =
      {

        options = {
          "matchExpressions" = mkOption {
            description = "";
            type = types.nullOr (
              types.listOf (
                submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecVolumeAffinityPodAffinityPreferredDuringSchedulingIgnoredDuringExecutionPodAffinityTermLabelSelectorMatchExpressions"
              )
            );
          };
          "matchLabels" = mkOption {
            description = "";
            type = types.nullOr (types.attrsOf types.str);
          };
        };

        config = {
          "matchExpressions" = mkOverride 1002 null;
          "matchLabels" = mkOverride 1002 null;
        };

      };
    "seaweed.seaweedfs.com.v1.SeaweedSpecVolumeAffinityPodAffinityPreferredDuringSchedulingIgnoredDuringExecutionPodAffinityTermLabelSelectorMatchExpressions" =
      {

        options = {
          "key" = mkOption {
            description = "";
            type = types.str;
          };
          "operator" = mkOption {
            description = "";
            type = types.str;
          };
          "values" = mkOption {
            description = "";
            type = types.nullOr (types.listOf types.str);
          };
        };

        config = {
          "values" = mkOverride 1002 null;
        };

      };
    "seaweed.seaweedfs.com.v1.SeaweedSpecVolumeAffinityPodAffinityPreferredDuringSchedulingIgnoredDuringExecutionPodAffinityTermNamespaceSelector" =
      {

        options = {
          "matchExpressions" = mkOption {
            description = "";
            type = types.nullOr (
              types.listOf (
                submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecVolumeAffinityPodAffinityPreferredDuringSchedulingIgnoredDuringExecutionPodAffinityTermNamespaceSelectorMatchExpressions"
              )
            );
          };
          "matchLabels" = mkOption {
            description = "";
            type = types.nullOr (types.attrsOf types.str);
          };
        };

        config = {
          "matchExpressions" = mkOverride 1002 null;
          "matchLabels" = mkOverride 1002 null;
        };

      };
    "seaweed.seaweedfs.com.v1.SeaweedSpecVolumeAffinityPodAffinityPreferredDuringSchedulingIgnoredDuringExecutionPodAffinityTermNamespaceSelectorMatchExpressions" =
      {

        options = {
          "key" = mkOption {
            description = "";
            type = types.str;
          };
          "operator" = mkOption {
            description = "";
            type = types.str;
          };
          "values" = mkOption {
            description = "";
            type = types.nullOr (types.listOf types.str);
          };
        };

        config = {
          "values" = mkOverride 1002 null;
        };

      };
    "seaweed.seaweedfs.com.v1.SeaweedSpecVolumeAffinityPodAffinityRequiredDuringSchedulingIgnoredDuringExecution" =
      {

        options = {
          "labelSelector" = mkOption {
            description = "";
            type = types.nullOr (
              submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecVolumeAffinityPodAffinityRequiredDuringSchedulingIgnoredDuringExecutionLabelSelector"
            );
          };
          "matchLabelKeys" = mkOption {
            description = "";
            type = types.nullOr (types.listOf types.str);
          };
          "mismatchLabelKeys" = mkOption {
            description = "";
            type = types.nullOr (types.listOf types.str);
          };
          "namespaceSelector" = mkOption {
            description = "";
            type = types.nullOr (
              submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecVolumeAffinityPodAffinityRequiredDuringSchedulingIgnoredDuringExecutionNamespaceSelector"
            );
          };
          "namespaces" = mkOption {
            description = "";
            type = types.nullOr (types.listOf types.str);
          };
          "topologyKey" = mkOption {
            description = "";
            type = types.str;
          };
        };

        config = {
          "labelSelector" = mkOverride 1002 null;
          "matchLabelKeys" = mkOverride 1002 null;
          "mismatchLabelKeys" = mkOverride 1002 null;
          "namespaceSelector" = mkOverride 1002 null;
          "namespaces" = mkOverride 1002 null;
        };

      };
    "seaweed.seaweedfs.com.v1.SeaweedSpecVolumeAffinityPodAffinityRequiredDuringSchedulingIgnoredDuringExecutionLabelSelector" =
      {

        options = {
          "matchExpressions" = mkOption {
            description = "";
            type = types.nullOr (
              types.listOf (
                submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecVolumeAffinityPodAffinityRequiredDuringSchedulingIgnoredDuringExecutionLabelSelectorMatchExpressions"
              )
            );
          };
          "matchLabels" = mkOption {
            description = "";
            type = types.nullOr (types.attrsOf types.str);
          };
        };

        config = {
          "matchExpressions" = mkOverride 1002 null;
          "matchLabels" = mkOverride 1002 null;
        };

      };
    "seaweed.seaweedfs.com.v1.SeaweedSpecVolumeAffinityPodAffinityRequiredDuringSchedulingIgnoredDuringExecutionLabelSelectorMatchExpressions" =
      {

        options = {
          "key" = mkOption {
            description = "";
            type = types.str;
          };
          "operator" = mkOption {
            description = "";
            type = types.str;
          };
          "values" = mkOption {
            description = "";
            type = types.nullOr (types.listOf types.str);
          };
        };

        config = {
          "values" = mkOverride 1002 null;
        };

      };
    "seaweed.seaweedfs.com.v1.SeaweedSpecVolumeAffinityPodAffinityRequiredDuringSchedulingIgnoredDuringExecutionNamespaceSelector" =
      {

        options = {
          "matchExpressions" = mkOption {
            description = "";
            type = types.nullOr (
              types.listOf (
                submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecVolumeAffinityPodAffinityRequiredDuringSchedulingIgnoredDuringExecutionNamespaceSelectorMatchExpressions"
              )
            );
          };
          "matchLabels" = mkOption {
            description = "";
            type = types.nullOr (types.attrsOf types.str);
          };
        };

        config = {
          "matchExpressions" = mkOverride 1002 null;
          "matchLabels" = mkOverride 1002 null;
        };

      };
    "seaweed.seaweedfs.com.v1.SeaweedSpecVolumeAffinityPodAffinityRequiredDuringSchedulingIgnoredDuringExecutionNamespaceSelectorMatchExpressions" =
      {

        options = {
          "key" = mkOption {
            description = "";
            type = types.str;
          };
          "operator" = mkOption {
            description = "";
            type = types.str;
          };
          "values" = mkOption {
            description = "";
            type = types.nullOr (types.listOf types.str);
          };
        };

        config = {
          "values" = mkOverride 1002 null;
        };

      };
    "seaweed.seaweedfs.com.v1.SeaweedSpecVolumeAffinityPodAntiAffinity" = {

      options = {
        "preferredDuringSchedulingIgnoredDuringExecution" = mkOption {
          description = "";
          type = types.nullOr (
            types.listOf (
              submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecVolumeAffinityPodAntiAffinityPreferredDuringSchedulingIgnoredDuringExecution"
            )
          );
        };
        "requiredDuringSchedulingIgnoredDuringExecution" = mkOption {
          description = "";
          type = types.nullOr (
            types.listOf (
              submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecVolumeAffinityPodAntiAffinityRequiredDuringSchedulingIgnoredDuringExecution"
            )
          );
        };
      };

      config = {
        "preferredDuringSchedulingIgnoredDuringExecution" = mkOverride 1002 null;
        "requiredDuringSchedulingIgnoredDuringExecution" = mkOverride 1002 null;
      };

    };
    "seaweed.seaweedfs.com.v1.SeaweedSpecVolumeAffinityPodAntiAffinityPreferredDuringSchedulingIgnoredDuringExecution" =
      {

        options = {
          "podAffinityTerm" = mkOption {
            description = "";
            type = submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecVolumeAffinityPodAntiAffinityPreferredDuringSchedulingIgnoredDuringExecutionPodAffinityTerm";
          };
          "weight" = mkOption {
            description = "";
            type = types.int;
          };
        };

        config = { };

      };
    "seaweed.seaweedfs.com.v1.SeaweedSpecVolumeAffinityPodAntiAffinityPreferredDuringSchedulingIgnoredDuringExecutionPodAffinityTerm" =
      {

        options = {
          "labelSelector" = mkOption {
            description = "";
            type = types.nullOr (
              submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecVolumeAffinityPodAntiAffinityPreferredDuringSchedulingIgnoredDuringExecutionPodAffinityTermLabelSelector"
            );
          };
          "matchLabelKeys" = mkOption {
            description = "";
            type = types.nullOr (types.listOf types.str);
          };
          "mismatchLabelKeys" = mkOption {
            description = "";
            type = types.nullOr (types.listOf types.str);
          };
          "namespaceSelector" = mkOption {
            description = "";
            type = types.nullOr (
              submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecVolumeAffinityPodAntiAffinityPreferredDuringSchedulingIgnoredDuringExecutionPodAffinityTermNamespaceSelector"
            );
          };
          "namespaces" = mkOption {
            description = "";
            type = types.nullOr (types.listOf types.str);
          };
          "topologyKey" = mkOption {
            description = "";
            type = types.str;
          };
        };

        config = {
          "labelSelector" = mkOverride 1002 null;
          "matchLabelKeys" = mkOverride 1002 null;
          "mismatchLabelKeys" = mkOverride 1002 null;
          "namespaceSelector" = mkOverride 1002 null;
          "namespaces" = mkOverride 1002 null;
        };

      };
    "seaweed.seaweedfs.com.v1.SeaweedSpecVolumeAffinityPodAntiAffinityPreferredDuringSchedulingIgnoredDuringExecutionPodAffinityTermLabelSelector" =
      {

        options = {
          "matchExpressions" = mkOption {
            description = "";
            type = types.nullOr (
              types.listOf (
                submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecVolumeAffinityPodAntiAffinityPreferredDuringSchedulingIgnoredDuringExecutionPodAffinityTermLabelSelectorMatchExpressions"
              )
            );
          };
          "matchLabels" = mkOption {
            description = "";
            type = types.nullOr (types.attrsOf types.str);
          };
        };

        config = {
          "matchExpressions" = mkOverride 1002 null;
          "matchLabels" = mkOverride 1002 null;
        };

      };
    "seaweed.seaweedfs.com.v1.SeaweedSpecVolumeAffinityPodAntiAffinityPreferredDuringSchedulingIgnoredDuringExecutionPodAffinityTermLabelSelectorMatchExpressions" =
      {

        options = {
          "key" = mkOption {
            description = "";
            type = types.str;
          };
          "operator" = mkOption {
            description = "";
            type = types.str;
          };
          "values" = mkOption {
            description = "";
            type = types.nullOr (types.listOf types.str);
          };
        };

        config = {
          "values" = mkOverride 1002 null;
        };

      };
    "seaweed.seaweedfs.com.v1.SeaweedSpecVolumeAffinityPodAntiAffinityPreferredDuringSchedulingIgnoredDuringExecutionPodAffinityTermNamespaceSelector" =
      {

        options = {
          "matchExpressions" = mkOption {
            description = "";
            type = types.nullOr (
              types.listOf (
                submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecVolumeAffinityPodAntiAffinityPreferredDuringSchedulingIgnoredDuringExecutionPodAffinityTermNamespaceSelectorMatchExpressions"
              )
            );
          };
          "matchLabels" = mkOption {
            description = "";
            type = types.nullOr (types.attrsOf types.str);
          };
        };

        config = {
          "matchExpressions" = mkOverride 1002 null;
          "matchLabels" = mkOverride 1002 null;
        };

      };
    "seaweed.seaweedfs.com.v1.SeaweedSpecVolumeAffinityPodAntiAffinityPreferredDuringSchedulingIgnoredDuringExecutionPodAffinityTermNamespaceSelectorMatchExpressions" =
      {

        options = {
          "key" = mkOption {
            description = "";
            type = types.str;
          };
          "operator" = mkOption {
            description = "";
            type = types.str;
          };
          "values" = mkOption {
            description = "";
            type = types.nullOr (types.listOf types.str);
          };
        };

        config = {
          "values" = mkOverride 1002 null;
        };

      };
    "seaweed.seaweedfs.com.v1.SeaweedSpecVolumeAffinityPodAntiAffinityRequiredDuringSchedulingIgnoredDuringExecution" =
      {

        options = {
          "labelSelector" = mkOption {
            description = "";
            type = types.nullOr (
              submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecVolumeAffinityPodAntiAffinityRequiredDuringSchedulingIgnoredDuringExecutionLabelSelector"
            );
          };
          "matchLabelKeys" = mkOption {
            description = "";
            type = types.nullOr (types.listOf types.str);
          };
          "mismatchLabelKeys" = mkOption {
            description = "";
            type = types.nullOr (types.listOf types.str);
          };
          "namespaceSelector" = mkOption {
            description = "";
            type = types.nullOr (
              submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecVolumeAffinityPodAntiAffinityRequiredDuringSchedulingIgnoredDuringExecutionNamespaceSelector"
            );
          };
          "namespaces" = mkOption {
            description = "";
            type = types.nullOr (types.listOf types.str);
          };
          "topologyKey" = mkOption {
            description = "";
            type = types.str;
          };
        };

        config = {
          "labelSelector" = mkOverride 1002 null;
          "matchLabelKeys" = mkOverride 1002 null;
          "mismatchLabelKeys" = mkOverride 1002 null;
          "namespaceSelector" = mkOverride 1002 null;
          "namespaces" = mkOverride 1002 null;
        };

      };
    "seaweed.seaweedfs.com.v1.SeaweedSpecVolumeAffinityPodAntiAffinityRequiredDuringSchedulingIgnoredDuringExecutionLabelSelector" =
      {

        options = {
          "matchExpressions" = mkOption {
            description = "";
            type = types.nullOr (
              types.listOf (
                submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecVolumeAffinityPodAntiAffinityRequiredDuringSchedulingIgnoredDuringExecutionLabelSelectorMatchExpressions"
              )
            );
          };
          "matchLabels" = mkOption {
            description = "";
            type = types.nullOr (types.attrsOf types.str);
          };
        };

        config = {
          "matchExpressions" = mkOverride 1002 null;
          "matchLabels" = mkOverride 1002 null;
        };

      };
    "seaweed.seaweedfs.com.v1.SeaweedSpecVolumeAffinityPodAntiAffinityRequiredDuringSchedulingIgnoredDuringExecutionLabelSelectorMatchExpressions" =
      {

        options = {
          "key" = mkOption {
            description = "";
            type = types.str;
          };
          "operator" = mkOption {
            description = "";
            type = types.str;
          };
          "values" = mkOption {
            description = "";
            type = types.nullOr (types.listOf types.str);
          };
        };

        config = {
          "values" = mkOverride 1002 null;
        };

      };
    "seaweed.seaweedfs.com.v1.SeaweedSpecVolumeAffinityPodAntiAffinityRequiredDuringSchedulingIgnoredDuringExecutionNamespaceSelector" =
      {

        options = {
          "matchExpressions" = mkOption {
            description = "";
            type = types.nullOr (
              types.listOf (
                submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecVolumeAffinityPodAntiAffinityRequiredDuringSchedulingIgnoredDuringExecutionNamespaceSelectorMatchExpressions"
              )
            );
          };
          "matchLabels" = mkOption {
            description = "";
            type = types.nullOr (types.attrsOf types.str);
          };
        };

        config = {
          "matchExpressions" = mkOverride 1002 null;
          "matchLabels" = mkOverride 1002 null;
        };

      };
    "seaweed.seaweedfs.com.v1.SeaweedSpecVolumeAffinityPodAntiAffinityRequiredDuringSchedulingIgnoredDuringExecutionNamespaceSelectorMatchExpressions" =
      {

        options = {
          "key" = mkOption {
            description = "";
            type = types.str;
          };
          "operator" = mkOption {
            description = "";
            type = types.str;
          };
          "values" = mkOption {
            description = "";
            type = types.nullOr (types.listOf types.str);
          };
        };

        config = {
          "values" = mkOverride 1002 null;
        };

      };
    "seaweed.seaweedfs.com.v1.SeaweedSpecVolumeClaims" = {

      options = {
        "name" = mkOption {
          description = "";
          type = types.str;
        };
        "request" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
      };

      config = {
        "request" = mkOverride 1002 null;
      };

    };
    "seaweed.seaweedfs.com.v1.SeaweedSpecVolumeContainerSecurityContext" = {

      options = {
        "allowPrivilegeEscalation" = mkOption {
          description = "";
          type = types.nullOr types.bool;
        };
        "appArmorProfile" = mkOption {
          description = "";
          type = types.nullOr (
            submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecVolumeContainerSecurityContextAppArmorProfile"
          );
        };
        "capabilities" = mkOption {
          description = "";
          type = types.nullOr (
            submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecVolumeContainerSecurityContextCapabilities"
          );
        };
        "privileged" = mkOption {
          description = "";
          type = types.nullOr types.bool;
        };
        "procMount" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "readOnlyRootFilesystem" = mkOption {
          description = "";
          type = types.nullOr types.bool;
        };
        "runAsGroup" = mkOption {
          description = "";
          type = types.nullOr types.int;
        };
        "runAsNonRoot" = mkOption {
          description = "";
          type = types.nullOr types.bool;
        };
        "runAsUser" = mkOption {
          description = "";
          type = types.nullOr types.int;
        };
        "seLinuxOptions" = mkOption {
          description = "";
          type = types.nullOr (
            submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecVolumeContainerSecurityContextSeLinuxOptions"
          );
        };
        "seccompProfile" = mkOption {
          description = "";
          type = types.nullOr (
            submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecVolumeContainerSecurityContextSeccompProfile"
          );
        };
        "windowsOptions" = mkOption {
          description = "";
          type = types.nullOr (
            submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecVolumeContainerSecurityContextWindowsOptions"
          );
        };
      };

      config = {
        "allowPrivilegeEscalation" = mkOverride 1002 null;
        "appArmorProfile" = mkOverride 1002 null;
        "capabilities" = mkOverride 1002 null;
        "privileged" = mkOverride 1002 null;
        "procMount" = mkOverride 1002 null;
        "readOnlyRootFilesystem" = mkOverride 1002 null;
        "runAsGroup" = mkOverride 1002 null;
        "runAsNonRoot" = mkOverride 1002 null;
        "runAsUser" = mkOverride 1002 null;
        "seLinuxOptions" = mkOverride 1002 null;
        "seccompProfile" = mkOverride 1002 null;
        "windowsOptions" = mkOverride 1002 null;
      };

    };
    "seaweed.seaweedfs.com.v1.SeaweedSpecVolumeContainerSecurityContextAppArmorProfile" = {

      options = {
        "localhostProfile" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "type" = mkOption {
          description = "";
          type = types.str;
        };
      };

      config = {
        "localhostProfile" = mkOverride 1002 null;
      };

    };
    "seaweed.seaweedfs.com.v1.SeaweedSpecVolumeContainerSecurityContextCapabilities" = {

      options = {
        "add" = mkOption {
          description = "";
          type = types.nullOr (types.listOf types.str);
        };
        "drop" = mkOption {
          description = "";
          type = types.nullOr (types.listOf types.str);
        };
      };

      config = {
        "add" = mkOverride 1002 null;
        "drop" = mkOverride 1002 null;
      };

    };
    "seaweed.seaweedfs.com.v1.SeaweedSpecVolumeContainerSecurityContextSeLinuxOptions" = {

      options = {
        "level" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "role" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "type" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "user" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
      };

      config = {
        "level" = mkOverride 1002 null;
        "role" = mkOverride 1002 null;
        "type" = mkOverride 1002 null;
        "user" = mkOverride 1002 null;
      };

    };
    "seaweed.seaweedfs.com.v1.SeaweedSpecVolumeContainerSecurityContextSeccompProfile" = {

      options = {
        "localhostProfile" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "type" = mkOption {
          description = "";
          type = types.str;
        };
      };

      config = {
        "localhostProfile" = mkOverride 1002 null;
      };

    };
    "seaweed.seaweedfs.com.v1.SeaweedSpecVolumeContainerSecurityContextWindowsOptions" = {

      options = {
        "gmsaCredentialSpec" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "gmsaCredentialSpecName" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "hostProcess" = mkOption {
          description = "";
          type = types.nullOr types.bool;
        };
        "runAsUserName" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
      };

      config = {
        "gmsaCredentialSpec" = mkOverride 1002 null;
        "gmsaCredentialSpecName" = mkOverride 1002 null;
        "hostProcess" = mkOverride 1002 null;
        "runAsUserName" = mkOverride 1002 null;
      };

    };
    "seaweed.seaweedfs.com.v1.SeaweedSpecVolumeEnv" = {

      options = {
        "name" = mkOption {
          description = "";
          type = types.str;
        };
        "value" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "valueFrom" = mkOption {
          description = "";
          type = types.nullOr (submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecVolumeEnvValueFrom");
        };
      };

      config = {
        "value" = mkOverride 1002 null;
        "valueFrom" = mkOverride 1002 null;
      };

    };
    "seaweed.seaweedfs.com.v1.SeaweedSpecVolumeEnvValueFrom" = {

      options = {
        "configMapKeyRef" = mkOption {
          description = "";
          type = types.nullOr (
            submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecVolumeEnvValueFromConfigMapKeyRef"
          );
        };
        "fieldRef" = mkOption {
          description = "";
          type = types.nullOr (submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecVolumeEnvValueFromFieldRef");
        };
        "fileKeyRef" = mkOption {
          description = "";
          type = types.nullOr (
            submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecVolumeEnvValueFromFileKeyRef"
          );
        };
        "resourceFieldRef" = mkOption {
          description = "";
          type = types.nullOr (
            submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecVolumeEnvValueFromResourceFieldRef"
          );
        };
        "secretKeyRef" = mkOption {
          description = "";
          type = types.nullOr (
            submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecVolumeEnvValueFromSecretKeyRef"
          );
        };
      };

      config = {
        "configMapKeyRef" = mkOverride 1002 null;
        "fieldRef" = mkOverride 1002 null;
        "fileKeyRef" = mkOverride 1002 null;
        "resourceFieldRef" = mkOverride 1002 null;
        "secretKeyRef" = mkOverride 1002 null;
      };

    };
    "seaweed.seaweedfs.com.v1.SeaweedSpecVolumeEnvValueFromConfigMapKeyRef" = {

      options = {
        "key" = mkOption {
          description = "";
          type = types.str;
        };
        "name" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "optional" = mkOption {
          description = "";
          type = types.nullOr types.bool;
        };
      };

      config = {
        "name" = mkOverride 1002 null;
        "optional" = mkOverride 1002 null;
      };

    };
    "seaweed.seaweedfs.com.v1.SeaweedSpecVolumeEnvValueFromFieldRef" = {

      options = {
        "apiVersion" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "fieldPath" = mkOption {
          description = "";
          type = types.str;
        };
      };

      config = {
        "apiVersion" = mkOverride 1002 null;
      };

    };
    "seaweed.seaweedfs.com.v1.SeaweedSpecVolumeEnvValueFromFileKeyRef" = {

      options = {
        "key" = mkOption {
          description = "";
          type = types.str;
        };
        "optional" = mkOption {
          description = "";
          type = types.nullOr types.bool;
        };
        "path" = mkOption {
          description = "";
          type = types.str;
        };
        "volumeName" = mkOption {
          description = "";
          type = types.str;
        };
      };

      config = {
        "optional" = mkOverride 1002 null;
      };

    };
    "seaweed.seaweedfs.com.v1.SeaweedSpecVolumeEnvValueFromResourceFieldRef" = {

      options = {
        "containerName" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "divisor" = mkOption {
          description = "";
          type = types.nullOr (types.either types.int types.str);
        };
        "resource" = mkOption {
          description = "";
          type = types.str;
        };
      };

      config = {
        "containerName" = mkOverride 1002 null;
        "divisor" = mkOverride 1002 null;
      };

    };
    "seaweed.seaweedfs.com.v1.SeaweedSpecVolumeEnvValueFromSecretKeyRef" = {

      options = {
        "key" = mkOption {
          description = "";
          type = types.str;
        };
        "name" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "optional" = mkOption {
          description = "";
          type = types.nullOr types.bool;
        };
      };

      config = {
        "name" = mkOverride 1002 null;
        "optional" = mkOverride 1002 null;
      };

    };
    "seaweed.seaweedfs.com.v1.SeaweedSpecVolumeHostPath" = {

      options = {
        "maxVolumeCount" = mkOption {
          description = "";
          type = types.nullOr types.int;
        };
        "path" = mkOption {
          description = "";
          type = types.str;
        };
        "type" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
      };

      config = {
        "maxVolumeCount" = mkOverride 1002 null;
        "type" = mkOverride 1002 null;
      };

    };
    "seaweed.seaweedfs.com.v1.SeaweedSpecVolumeImagePullSecrets" = {

      options = {
        "name" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
      };

      config = {
        "name" = mkOverride 1002 null;
      };

    };
    "seaweed.seaweedfs.com.v1.SeaweedSpecVolumeIngress" = {

      options = {
        "annotations" = mkOption {
          description = "";
          type = types.nullOr (types.attrsOf types.str);
        };
        "className" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "enabled" = mkOption {
          description = "";
          type = types.nullOr types.bool;
        };
        "host" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "path" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "tls" = mkOption {
          description = "";
          type = types.nullOr (
            types.listOf (submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecVolumeIngressTls")
          );
        };
      };

      config = {
        "annotations" = mkOverride 1002 null;
        "className" = mkOverride 1002 null;
        "enabled" = mkOverride 1002 null;
        "host" = mkOverride 1002 null;
        "path" = mkOverride 1002 null;
        "tls" = mkOverride 1002 null;
      };

    };
    "seaweed.seaweedfs.com.v1.SeaweedSpecVolumeIngressTls" = {

      options = {
        "hosts" = mkOption {
          description = "";
          type = types.nullOr (types.listOf types.str);
        };
        "secretName" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
      };

      config = {
        "hosts" = mkOverride 1002 null;
        "secretName" = mkOverride 1002 null;
      };

    };
    "seaweed.seaweedfs.com.v1.SeaweedSpecVolumeLivenessProbe" = {

      options = {
        "failureThreshold" = mkOption {
          description = "";
          type = types.nullOr types.int;
        };
        "initialDelaySeconds" = mkOption {
          description = "";
          type = types.nullOr types.int;
        };
        "periodSeconds" = mkOption {
          description = "";
          type = types.nullOr types.int;
        };
        "timeoutSeconds" = mkOption {
          description = "";
          type = types.nullOr types.int;
        };
      };

      config = {
        "failureThreshold" = mkOverride 1002 null;
        "initialDelaySeconds" = mkOverride 1002 null;
        "periodSeconds" = mkOverride 1002 null;
        "timeoutSeconds" = mkOverride 1002 null;
      };

    };
    "seaweed.seaweedfs.com.v1.SeaweedSpecVolumePodSecurityContext" = {

      options = {
        "appArmorProfile" = mkOption {
          description = "";
          type = types.nullOr (
            submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecVolumePodSecurityContextAppArmorProfile"
          );
        };
        "fsGroup" = mkOption {
          description = "";
          type = types.nullOr types.int;
        };
        "fsGroupChangePolicy" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "runAsGroup" = mkOption {
          description = "";
          type = types.nullOr types.int;
        };
        "runAsNonRoot" = mkOption {
          description = "";
          type = types.nullOr types.bool;
        };
        "runAsUser" = mkOption {
          description = "";
          type = types.nullOr types.int;
        };
        "seLinuxChangePolicy" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "seLinuxOptions" = mkOption {
          description = "";
          type = types.nullOr (
            submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecVolumePodSecurityContextSeLinuxOptions"
          );
        };
        "seccompProfile" = mkOption {
          description = "";
          type = types.nullOr (
            submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecVolumePodSecurityContextSeccompProfile"
          );
        };
        "supplementalGroups" = mkOption {
          description = "";
          type = types.nullOr (types.listOf types.int);
        };
        "supplementalGroupsPolicy" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "sysctls" = mkOption {
          description = "";
          type = types.nullOr (
            coerceAttrsOfSubmodulesToListByKey
              "seaweed.seaweedfs.com.v1.SeaweedSpecVolumePodSecurityContextSysctls"
              "name"
              [ ]
          );
          apply = attrsToList;
        };
        "windowsOptions" = mkOption {
          description = "";
          type = types.nullOr (
            submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecVolumePodSecurityContextWindowsOptions"
          );
        };
      };

      config = {
        "appArmorProfile" = mkOverride 1002 null;
        "fsGroup" = mkOverride 1002 null;
        "fsGroupChangePolicy" = mkOverride 1002 null;
        "runAsGroup" = mkOverride 1002 null;
        "runAsNonRoot" = mkOverride 1002 null;
        "runAsUser" = mkOverride 1002 null;
        "seLinuxChangePolicy" = mkOverride 1002 null;
        "seLinuxOptions" = mkOverride 1002 null;
        "seccompProfile" = mkOverride 1002 null;
        "supplementalGroups" = mkOverride 1002 null;
        "supplementalGroupsPolicy" = mkOverride 1002 null;
        "sysctls" = mkOverride 1002 null;
        "windowsOptions" = mkOverride 1002 null;
      };

    };
    "seaweed.seaweedfs.com.v1.SeaweedSpecVolumePodSecurityContextAppArmorProfile" = {

      options = {
        "localhostProfile" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "type" = mkOption {
          description = "";
          type = types.str;
        };
      };

      config = {
        "localhostProfile" = mkOverride 1002 null;
      };

    };
    "seaweed.seaweedfs.com.v1.SeaweedSpecVolumePodSecurityContextSeLinuxOptions" = {

      options = {
        "level" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "role" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "type" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "user" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
      };

      config = {
        "level" = mkOverride 1002 null;
        "role" = mkOverride 1002 null;
        "type" = mkOverride 1002 null;
        "user" = mkOverride 1002 null;
      };

    };
    "seaweed.seaweedfs.com.v1.SeaweedSpecVolumePodSecurityContextSeccompProfile" = {

      options = {
        "localhostProfile" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "type" = mkOption {
          description = "";
          type = types.str;
        };
      };

      config = {
        "localhostProfile" = mkOverride 1002 null;
      };

    };
    "seaweed.seaweedfs.com.v1.SeaweedSpecVolumePodSecurityContextSysctls" = {

      options = {
        "name" = mkOption {
          description = "";
          type = types.str;
        };
        "value" = mkOption {
          description = "";
          type = types.str;
        };
      };

      config = { };

    };
    "seaweed.seaweedfs.com.v1.SeaweedSpecVolumePodSecurityContextWindowsOptions" = {

      options = {
        "gmsaCredentialSpec" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "gmsaCredentialSpecName" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "hostProcess" = mkOption {
          description = "";
          type = types.nullOr types.bool;
        };
        "runAsUserName" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
      };

      config = {
        "gmsaCredentialSpec" = mkOverride 1002 null;
        "gmsaCredentialSpecName" = mkOverride 1002 null;
        "hostProcess" = mkOverride 1002 null;
        "runAsUserName" = mkOverride 1002 null;
      };

    };
    "seaweed.seaweedfs.com.v1.SeaweedSpecVolumeReadinessProbe" = {

      options = {
        "failureThreshold" = mkOption {
          description = "";
          type = types.nullOr types.int;
        };
        "initialDelaySeconds" = mkOption {
          description = "";
          type = types.nullOr types.int;
        };
        "periodSeconds" = mkOption {
          description = "";
          type = types.nullOr types.int;
        };
        "successThreshold" = mkOption {
          description = "";
          type = types.nullOr types.int;
        };
        "timeoutSeconds" = mkOption {
          description = "";
          type = types.nullOr types.int;
        };
      };

      config = {
        "failureThreshold" = mkOverride 1002 null;
        "initialDelaySeconds" = mkOverride 1002 null;
        "periodSeconds" = mkOverride 1002 null;
        "successThreshold" = mkOverride 1002 null;
        "timeoutSeconds" = mkOverride 1002 null;
      };

    };
    "seaweed.seaweedfs.com.v1.SeaweedSpecVolumeService" = {

      options = {
        "annotations" = mkOption {
          description = "";
          type = types.nullOr (types.attrsOf types.str);
        };
        "clusterIP" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "loadBalancerIP" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "type" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
      };

      config = {
        "annotations" = mkOverride 1002 null;
        "clusterIP" = mkOverride 1002 null;
        "loadBalancerIP" = mkOverride 1002 null;
        "type" = mkOverride 1002 null;
      };

    };
    "seaweed.seaweedfs.com.v1.SeaweedSpecVolumeStorageSelector" = {

      options = {
        "matchExpressions" = mkOption {
          description = "";
          type = types.nullOr (
            types.listOf (
              submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecVolumeStorageSelectorMatchExpressions"
            )
          );
        };
        "matchLabels" = mkOption {
          description = "";
          type = types.nullOr (types.attrsOf types.str);
        };
      };

      config = {
        "matchExpressions" = mkOverride 1002 null;
        "matchLabels" = mkOverride 1002 null;
      };

    };
    "seaweed.seaweedfs.com.v1.SeaweedSpecVolumeStorageSelectorMatchExpressions" = {

      options = {
        "key" = mkOption {
          description = "";
          type = types.str;
        };
        "operator" = mkOption {
          description = "";
          type = types.str;
        };
        "values" = mkOption {
          description = "";
          type = types.nullOr (types.listOf types.str);
        };
      };

      config = {
        "values" = mkOverride 1002 null;
      };

    };
    "seaweed.seaweedfs.com.v1.SeaweedSpecVolumeTolerations" = {

      options = {
        "effect" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "key" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "operator" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "tolerationSeconds" = mkOption {
          description = "";
          type = types.nullOr types.int;
        };
        "value" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
      };

      config = {
        "effect" = mkOverride 1002 null;
        "key" = mkOverride 1002 null;
        "operator" = mkOverride 1002 null;
        "tolerationSeconds" = mkOverride 1002 null;
        "value" = mkOverride 1002 null;
      };

    };
    "seaweed.seaweedfs.com.v1.SeaweedSpecVolumeVolumeMounts" = {

      options = {
        "mountPath" = mkOption {
          description = "";
          type = types.str;
        };
        "mountPropagation" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "name" = mkOption {
          description = "";
          type = types.str;
        };
        "readOnly" = mkOption {
          description = "";
          type = types.nullOr types.bool;
        };
        "recursiveReadOnly" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "subPath" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "subPathExpr" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
      };

      config = {
        "mountPropagation" = mkOverride 1002 null;
        "readOnly" = mkOverride 1002 null;
        "recursiveReadOnly" = mkOverride 1002 null;
        "subPath" = mkOverride 1002 null;
        "subPathExpr" = mkOverride 1002 null;
      };

    };
    "seaweed.seaweedfs.com.v1.SeaweedSpecVolumeVolumes" = {

      options = {
        "awsElasticBlockStore" = mkOption {
          description = "";
          type = types.nullOr (
            submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecVolumeVolumesAwsElasticBlockStore"
          );
        };
        "azureDisk" = mkOption {
          description = "";
          type = types.nullOr (submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecVolumeVolumesAzureDisk");
        };
        "azureFile" = mkOption {
          description = "";
          type = types.nullOr (submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecVolumeVolumesAzureFile");
        };
        "cephfs" = mkOption {
          description = "";
          type = types.nullOr (submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecVolumeVolumesCephfs");
        };
        "cinder" = mkOption {
          description = "";
          type = types.nullOr (submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecVolumeVolumesCinder");
        };
        "configMap" = mkOption {
          description = "";
          type = types.nullOr (submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecVolumeVolumesConfigMap");
        };
        "csi" = mkOption {
          description = "";
          type = types.nullOr (submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecVolumeVolumesCsi");
        };
        "downwardAPI" = mkOption {
          description = "";
          type = types.nullOr (submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecVolumeVolumesDownwardAPI");
        };
        "emptyDir" = mkOption {
          description = "";
          type = types.nullOr (submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecVolumeVolumesEmptyDir");
        };
        "ephemeral" = mkOption {
          description = "";
          type = types.nullOr (submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecVolumeVolumesEphemeral");
        };
        "fc" = mkOption {
          description = "";
          type = types.nullOr (submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecVolumeVolumesFc");
        };
        "flexVolume" = mkOption {
          description = "";
          type = types.nullOr (submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecVolumeVolumesFlexVolume");
        };
        "flocker" = mkOption {
          description = "";
          type = types.nullOr (submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecVolumeVolumesFlocker");
        };
        "gcePersistentDisk" = mkOption {
          description = "";
          type = types.nullOr (
            submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecVolumeVolumesGcePersistentDisk"
          );
        };
        "gitRepo" = mkOption {
          description = "";
          type = types.nullOr (submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecVolumeVolumesGitRepo");
        };
        "glusterfs" = mkOption {
          description = "";
          type = types.nullOr (submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecVolumeVolumesGlusterfs");
        };
        "hostPath" = mkOption {
          description = "";
          type = types.nullOr (submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecVolumeVolumesHostPath");
        };
        "image" = mkOption {
          description = "";
          type = types.nullOr (submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecVolumeVolumesImage");
        };
        "iscsi" = mkOption {
          description = "";
          type = types.nullOr (submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecVolumeVolumesIscsi");
        };
        "name" = mkOption {
          description = "";
          type = types.str;
        };
        "nfs" = mkOption {
          description = "";
          type = types.nullOr (submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecVolumeVolumesNfs");
        };
        "persistentVolumeClaim" = mkOption {
          description = "";
          type = types.nullOr (
            submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecVolumeVolumesPersistentVolumeClaim"
          );
        };
        "photonPersistentDisk" = mkOption {
          description = "";
          type = types.nullOr (
            submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecVolumeVolumesPhotonPersistentDisk"
          );
        };
        "portworxVolume" = mkOption {
          description = "";
          type = types.nullOr (submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecVolumeVolumesPortworxVolume");
        };
        "projected" = mkOption {
          description = "";
          type = types.nullOr (submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecVolumeVolumesProjected");
        };
        "quobyte" = mkOption {
          description = "";
          type = types.nullOr (submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecVolumeVolumesQuobyte");
        };
        "rbd" = mkOption {
          description = "";
          type = types.nullOr (submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecVolumeVolumesRbd");
        };
        "scaleIO" = mkOption {
          description = "";
          type = types.nullOr (submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecVolumeVolumesScaleIO");
        };
        "secret" = mkOption {
          description = "";
          type = types.nullOr (submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecVolumeVolumesSecret");
        };
        "storageos" = mkOption {
          description = "";
          type = types.nullOr (submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecVolumeVolumesStorageos");
        };
        "vsphereVolume" = mkOption {
          description = "";
          type = types.nullOr (submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecVolumeVolumesVsphereVolume");
        };
      };

      config = {
        "awsElasticBlockStore" = mkOverride 1002 null;
        "azureDisk" = mkOverride 1002 null;
        "azureFile" = mkOverride 1002 null;
        "cephfs" = mkOverride 1002 null;
        "cinder" = mkOverride 1002 null;
        "configMap" = mkOverride 1002 null;
        "csi" = mkOverride 1002 null;
        "downwardAPI" = mkOverride 1002 null;
        "emptyDir" = mkOverride 1002 null;
        "ephemeral" = mkOverride 1002 null;
        "fc" = mkOverride 1002 null;
        "flexVolume" = mkOverride 1002 null;
        "flocker" = mkOverride 1002 null;
        "gcePersistentDisk" = mkOverride 1002 null;
        "gitRepo" = mkOverride 1002 null;
        "glusterfs" = mkOverride 1002 null;
        "hostPath" = mkOverride 1002 null;
        "image" = mkOverride 1002 null;
        "iscsi" = mkOverride 1002 null;
        "nfs" = mkOverride 1002 null;
        "persistentVolumeClaim" = mkOverride 1002 null;
        "photonPersistentDisk" = mkOverride 1002 null;
        "portworxVolume" = mkOverride 1002 null;
        "projected" = mkOverride 1002 null;
        "quobyte" = mkOverride 1002 null;
        "rbd" = mkOverride 1002 null;
        "scaleIO" = mkOverride 1002 null;
        "secret" = mkOverride 1002 null;
        "storageos" = mkOverride 1002 null;
        "vsphereVolume" = mkOverride 1002 null;
      };

    };
    "seaweed.seaweedfs.com.v1.SeaweedSpecVolumeVolumesAwsElasticBlockStore" = {

      options = {
        "fsType" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "partition" = mkOption {
          description = "";
          type = types.nullOr types.int;
        };
        "readOnly" = mkOption {
          description = "";
          type = types.nullOr types.bool;
        };
        "volumeID" = mkOption {
          description = "";
          type = types.str;
        };
      };

      config = {
        "fsType" = mkOverride 1002 null;
        "partition" = mkOverride 1002 null;
        "readOnly" = mkOverride 1002 null;
      };

    };
    "seaweed.seaweedfs.com.v1.SeaweedSpecVolumeVolumesAzureDisk" = {

      options = {
        "cachingMode" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "diskName" = mkOption {
          description = "";
          type = types.str;
        };
        "diskURI" = mkOption {
          description = "";
          type = types.str;
        };
        "fsType" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "kind" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "readOnly" = mkOption {
          description = "";
          type = types.nullOr types.bool;
        };
      };

      config = {
        "cachingMode" = mkOverride 1002 null;
        "fsType" = mkOverride 1002 null;
        "kind" = mkOverride 1002 null;
        "readOnly" = mkOverride 1002 null;
      };

    };
    "seaweed.seaweedfs.com.v1.SeaweedSpecVolumeVolumesAzureFile" = {

      options = {
        "readOnly" = mkOption {
          description = "";
          type = types.nullOr types.bool;
        };
        "secretName" = mkOption {
          description = "";
          type = types.str;
        };
        "shareName" = mkOption {
          description = "";
          type = types.str;
        };
      };

      config = {
        "readOnly" = mkOverride 1002 null;
      };

    };
    "seaweed.seaweedfs.com.v1.SeaweedSpecVolumeVolumesCephfs" = {

      options = {
        "monitors" = mkOption {
          description = "";
          type = types.listOf types.str;
        };
        "path" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "readOnly" = mkOption {
          description = "";
          type = types.nullOr types.bool;
        };
        "secretFile" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "secretRef" = mkOption {
          description = "";
          type = types.nullOr (
            submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecVolumeVolumesCephfsSecretRef"
          );
        };
        "user" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
      };

      config = {
        "path" = mkOverride 1002 null;
        "readOnly" = mkOverride 1002 null;
        "secretFile" = mkOverride 1002 null;
        "secretRef" = mkOverride 1002 null;
        "user" = mkOverride 1002 null;
      };

    };
    "seaweed.seaweedfs.com.v1.SeaweedSpecVolumeVolumesCephfsSecretRef" = {

      options = {
        "name" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
      };

      config = {
        "name" = mkOverride 1002 null;
      };

    };
    "seaweed.seaweedfs.com.v1.SeaweedSpecVolumeVolumesCinder" = {

      options = {
        "fsType" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "readOnly" = mkOption {
          description = "";
          type = types.nullOr types.bool;
        };
        "secretRef" = mkOption {
          description = "";
          type = types.nullOr (
            submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecVolumeVolumesCinderSecretRef"
          );
        };
        "volumeID" = mkOption {
          description = "";
          type = types.str;
        };
      };

      config = {
        "fsType" = mkOverride 1002 null;
        "readOnly" = mkOverride 1002 null;
        "secretRef" = mkOverride 1002 null;
      };

    };
    "seaweed.seaweedfs.com.v1.SeaweedSpecVolumeVolumesCinderSecretRef" = {

      options = {
        "name" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
      };

      config = {
        "name" = mkOverride 1002 null;
      };

    };
    "seaweed.seaweedfs.com.v1.SeaweedSpecVolumeVolumesConfigMap" = {

      options = {
        "defaultMode" = mkOption {
          description = "";
          type = types.nullOr types.int;
        };
        "items" = mkOption {
          description = "";
          type = types.nullOr (
            types.listOf (submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecVolumeVolumesConfigMapItems")
          );
        };
        "name" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "optional" = mkOption {
          description = "";
          type = types.nullOr types.bool;
        };
      };

      config = {
        "defaultMode" = mkOverride 1002 null;
        "items" = mkOverride 1002 null;
        "name" = mkOverride 1002 null;
        "optional" = mkOverride 1002 null;
      };

    };
    "seaweed.seaweedfs.com.v1.SeaweedSpecVolumeVolumesConfigMapItems" = {

      options = {
        "key" = mkOption {
          description = "";
          type = types.str;
        };
        "mode" = mkOption {
          description = "";
          type = types.nullOr types.int;
        };
        "path" = mkOption {
          description = "";
          type = types.str;
        };
      };

      config = {
        "mode" = mkOverride 1002 null;
      };

    };
    "seaweed.seaweedfs.com.v1.SeaweedSpecVolumeVolumesCsi" = {

      options = {
        "driver" = mkOption {
          description = "";
          type = types.str;
        };
        "fsType" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "nodePublishSecretRef" = mkOption {
          description = "";
          type = types.nullOr (
            submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecVolumeVolumesCsiNodePublishSecretRef"
          );
        };
        "readOnly" = mkOption {
          description = "";
          type = types.nullOr types.bool;
        };
        "volumeAttributes" = mkOption {
          description = "";
          type = types.nullOr (types.attrsOf types.str);
        };
      };

      config = {
        "fsType" = mkOverride 1002 null;
        "nodePublishSecretRef" = mkOverride 1002 null;
        "readOnly" = mkOverride 1002 null;
        "volumeAttributes" = mkOverride 1002 null;
      };

    };
    "seaweed.seaweedfs.com.v1.SeaweedSpecVolumeVolumesCsiNodePublishSecretRef" = {

      options = {
        "name" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
      };

      config = {
        "name" = mkOverride 1002 null;
      };

    };
    "seaweed.seaweedfs.com.v1.SeaweedSpecVolumeVolumesDownwardAPI" = {

      options = {
        "defaultMode" = mkOption {
          description = "";
          type = types.nullOr types.int;
        };
        "items" = mkOption {
          description = "";
          type = types.nullOr (
            types.listOf (submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecVolumeVolumesDownwardAPIItems")
          );
        };
      };

      config = {
        "defaultMode" = mkOverride 1002 null;
        "items" = mkOverride 1002 null;
      };

    };
    "seaweed.seaweedfs.com.v1.SeaweedSpecVolumeVolumesDownwardAPIItems" = {

      options = {
        "fieldRef" = mkOption {
          description = "";
          type = types.nullOr (
            submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecVolumeVolumesDownwardAPIItemsFieldRef"
          );
        };
        "mode" = mkOption {
          description = "";
          type = types.nullOr types.int;
        };
        "path" = mkOption {
          description = "";
          type = types.str;
        };
        "resourceFieldRef" = mkOption {
          description = "";
          type = types.nullOr (
            submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecVolumeVolumesDownwardAPIItemsResourceFieldRef"
          );
        };
      };

      config = {
        "fieldRef" = mkOverride 1002 null;
        "mode" = mkOverride 1002 null;
        "resourceFieldRef" = mkOverride 1002 null;
      };

    };
    "seaweed.seaweedfs.com.v1.SeaweedSpecVolumeVolumesDownwardAPIItemsFieldRef" = {

      options = {
        "apiVersion" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "fieldPath" = mkOption {
          description = "";
          type = types.str;
        };
      };

      config = {
        "apiVersion" = mkOverride 1002 null;
      };

    };
    "seaweed.seaweedfs.com.v1.SeaweedSpecVolumeVolumesDownwardAPIItemsResourceFieldRef" = {

      options = {
        "containerName" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "divisor" = mkOption {
          description = "";
          type = types.nullOr (types.either types.int types.str);
        };
        "resource" = mkOption {
          description = "";
          type = types.str;
        };
      };

      config = {
        "containerName" = mkOverride 1002 null;
        "divisor" = mkOverride 1002 null;
      };

    };
    "seaweed.seaweedfs.com.v1.SeaweedSpecVolumeVolumesEmptyDir" = {

      options = {
        "medium" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "sizeLimit" = mkOption {
          description = "";
          type = types.nullOr (types.either types.int types.str);
        };
      };

      config = {
        "medium" = mkOverride 1002 null;
        "sizeLimit" = mkOverride 1002 null;
      };

    };
    "seaweed.seaweedfs.com.v1.SeaweedSpecVolumeVolumesEphemeral" = {

      options = {
        "volumeClaimTemplate" = mkOption {
          description = "";
          type = types.nullOr (
            submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecVolumeVolumesEphemeralVolumeClaimTemplate"
          );
        };
      };

      config = {
        "volumeClaimTemplate" = mkOverride 1002 null;
      };

    };
    "seaweed.seaweedfs.com.v1.SeaweedSpecVolumeVolumesEphemeralVolumeClaimTemplate" = {

      options = {
        "metadata" = mkOption {
          description = "";
          type = types.nullOr types.attrs;
        };
        "spec" = mkOption {
          description = "";
          type = submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecVolumeVolumesEphemeralVolumeClaimTemplateSpec";
        };
      };

      config = {
        "metadata" = mkOverride 1002 null;
      };

    };
    "seaweed.seaweedfs.com.v1.SeaweedSpecVolumeVolumesEphemeralVolumeClaimTemplateSpec" = {

      options = {
        "accessModes" = mkOption {
          description = "";
          type = types.nullOr (types.listOf types.str);
        };
        "dataSource" = mkOption {
          description = "";
          type = types.nullOr (
            submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecVolumeVolumesEphemeralVolumeClaimTemplateSpecDataSource"
          );
        };
        "dataSourceRef" = mkOption {
          description = "";
          type = types.nullOr (
            submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecVolumeVolumesEphemeralVolumeClaimTemplateSpecDataSourceRef"
          );
        };
        "resources" = mkOption {
          description = "";
          type = types.nullOr (
            submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecVolumeVolumesEphemeralVolumeClaimTemplateSpecResources"
          );
        };
        "selector" = mkOption {
          description = "";
          type = types.nullOr (
            submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecVolumeVolumesEphemeralVolumeClaimTemplateSpecSelector"
          );
        };
        "storageClassName" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "volumeAttributesClassName" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "volumeMode" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "volumeName" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
      };

      config = {
        "accessModes" = mkOverride 1002 null;
        "dataSource" = mkOverride 1002 null;
        "dataSourceRef" = mkOverride 1002 null;
        "resources" = mkOverride 1002 null;
        "selector" = mkOverride 1002 null;
        "storageClassName" = mkOverride 1002 null;
        "volumeAttributesClassName" = mkOverride 1002 null;
        "volumeMode" = mkOverride 1002 null;
        "volumeName" = mkOverride 1002 null;
      };

    };
    "seaweed.seaweedfs.com.v1.SeaweedSpecVolumeVolumesEphemeralVolumeClaimTemplateSpecDataSource" = {

      options = {
        "apiGroup" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "kind" = mkOption {
          description = "";
          type = types.str;
        };
        "name" = mkOption {
          description = "";
          type = types.str;
        };
      };

      config = {
        "apiGroup" = mkOverride 1002 null;
      };

    };
    "seaweed.seaweedfs.com.v1.SeaweedSpecVolumeVolumesEphemeralVolumeClaimTemplateSpecDataSourceRef" = {

      options = {
        "apiGroup" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "kind" = mkOption {
          description = "";
          type = types.str;
        };
        "name" = mkOption {
          description = "";
          type = types.str;
        };
        "namespace" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
      };

      config = {
        "apiGroup" = mkOverride 1002 null;
        "namespace" = mkOverride 1002 null;
      };

    };
    "seaweed.seaweedfs.com.v1.SeaweedSpecVolumeVolumesEphemeralVolumeClaimTemplateSpecResources" = {

      options = {
        "limits" = mkOption {
          description = "";
          type = types.nullOr (types.attrsOf (types.either types.int types.str));
        };
        "requests" = mkOption {
          description = "";
          type = types.nullOr (types.attrsOf (types.either types.int types.str));
        };
      };

      config = {
        "limits" = mkOverride 1002 null;
        "requests" = mkOverride 1002 null;
      };

    };
    "seaweed.seaweedfs.com.v1.SeaweedSpecVolumeVolumesEphemeralVolumeClaimTemplateSpecSelector" = {

      options = {
        "matchExpressions" = mkOption {
          description = "";
          type = types.nullOr (
            types.listOf (
              submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecVolumeVolumesEphemeralVolumeClaimTemplateSpecSelectorMatchExpressions"
            )
          );
        };
        "matchLabels" = mkOption {
          description = "";
          type = types.nullOr (types.attrsOf types.str);
        };
      };

      config = {
        "matchExpressions" = mkOverride 1002 null;
        "matchLabels" = mkOverride 1002 null;
      };

    };
    "seaweed.seaweedfs.com.v1.SeaweedSpecVolumeVolumesEphemeralVolumeClaimTemplateSpecSelectorMatchExpressions" =
      {

        options = {
          "key" = mkOption {
            description = "";
            type = types.str;
          };
          "operator" = mkOption {
            description = "";
            type = types.str;
          };
          "values" = mkOption {
            description = "";
            type = types.nullOr (types.listOf types.str);
          };
        };

        config = {
          "values" = mkOverride 1002 null;
        };

      };
    "seaweed.seaweedfs.com.v1.SeaweedSpecVolumeVolumesFc" = {

      options = {
        "fsType" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "lun" = mkOption {
          description = "";
          type = types.nullOr types.int;
        };
        "readOnly" = mkOption {
          description = "";
          type = types.nullOr types.bool;
        };
        "targetWWNs" = mkOption {
          description = "";
          type = types.nullOr (types.listOf types.str);
        };
        "wwids" = mkOption {
          description = "";
          type = types.nullOr (types.listOf types.str);
        };
      };

      config = {
        "fsType" = mkOverride 1002 null;
        "lun" = mkOverride 1002 null;
        "readOnly" = mkOverride 1002 null;
        "targetWWNs" = mkOverride 1002 null;
        "wwids" = mkOverride 1002 null;
      };

    };
    "seaweed.seaweedfs.com.v1.SeaweedSpecVolumeVolumesFlexVolume" = {

      options = {
        "driver" = mkOption {
          description = "";
          type = types.str;
        };
        "fsType" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "options" = mkOption {
          description = "";
          type = types.nullOr (types.attrsOf types.str);
        };
        "readOnly" = mkOption {
          description = "";
          type = types.nullOr types.bool;
        };
        "secretRef" = mkOption {
          description = "";
          type = types.nullOr (
            submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecVolumeVolumesFlexVolumeSecretRef"
          );
        };
      };

      config = {
        "fsType" = mkOverride 1002 null;
        "options" = mkOverride 1002 null;
        "readOnly" = mkOverride 1002 null;
        "secretRef" = mkOverride 1002 null;
      };

    };
    "seaweed.seaweedfs.com.v1.SeaweedSpecVolumeVolumesFlexVolumeSecretRef" = {

      options = {
        "name" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
      };

      config = {
        "name" = mkOverride 1002 null;
      };

    };
    "seaweed.seaweedfs.com.v1.SeaweedSpecVolumeVolumesFlocker" = {

      options = {
        "datasetName" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "datasetUUID" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
      };

      config = {
        "datasetName" = mkOverride 1002 null;
        "datasetUUID" = mkOverride 1002 null;
      };

    };
    "seaweed.seaweedfs.com.v1.SeaweedSpecVolumeVolumesGcePersistentDisk" = {

      options = {
        "fsType" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "partition" = mkOption {
          description = "";
          type = types.nullOr types.int;
        };
        "pdName" = mkOption {
          description = "";
          type = types.str;
        };
        "readOnly" = mkOption {
          description = "";
          type = types.nullOr types.bool;
        };
      };

      config = {
        "fsType" = mkOverride 1002 null;
        "partition" = mkOverride 1002 null;
        "readOnly" = mkOverride 1002 null;
      };

    };
    "seaweed.seaweedfs.com.v1.SeaweedSpecVolumeVolumesGitRepo" = {

      options = {
        "directory" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "repository" = mkOption {
          description = "";
          type = types.str;
        };
        "revision" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
      };

      config = {
        "directory" = mkOverride 1002 null;
        "revision" = mkOverride 1002 null;
      };

    };
    "seaweed.seaweedfs.com.v1.SeaweedSpecVolumeVolumesGlusterfs" = {

      options = {
        "endpoints" = mkOption {
          description = "";
          type = types.str;
        };
        "path" = mkOption {
          description = "";
          type = types.str;
        };
        "readOnly" = mkOption {
          description = "";
          type = types.nullOr types.bool;
        };
      };

      config = {
        "readOnly" = mkOverride 1002 null;
      };

    };
    "seaweed.seaweedfs.com.v1.SeaweedSpecVolumeVolumesHostPath" = {

      options = {
        "path" = mkOption {
          description = "";
          type = types.str;
        };
        "type" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
      };

      config = {
        "type" = mkOverride 1002 null;
      };

    };
    "seaweed.seaweedfs.com.v1.SeaweedSpecVolumeVolumesImage" = {

      options = {
        "pullPolicy" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "reference" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
      };

      config = {
        "pullPolicy" = mkOverride 1002 null;
        "reference" = mkOverride 1002 null;
      };

    };
    "seaweed.seaweedfs.com.v1.SeaweedSpecVolumeVolumesIscsi" = {

      options = {
        "chapAuthDiscovery" = mkOption {
          description = "";
          type = types.nullOr types.bool;
        };
        "chapAuthSession" = mkOption {
          description = "";
          type = types.nullOr types.bool;
        };
        "fsType" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "initiatorName" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "iqn" = mkOption {
          description = "";
          type = types.str;
        };
        "iscsiInterface" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "lun" = mkOption {
          description = "";
          type = types.int;
        };
        "portals" = mkOption {
          description = "";
          type = types.nullOr (types.listOf types.str);
        };
        "readOnly" = mkOption {
          description = "";
          type = types.nullOr types.bool;
        };
        "secretRef" = mkOption {
          description = "";
          type = types.nullOr (submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecVolumeVolumesIscsiSecretRef");
        };
        "targetPortal" = mkOption {
          description = "";
          type = types.str;
        };
      };

      config = {
        "chapAuthDiscovery" = mkOverride 1002 null;
        "chapAuthSession" = mkOverride 1002 null;
        "fsType" = mkOverride 1002 null;
        "initiatorName" = mkOverride 1002 null;
        "iscsiInterface" = mkOverride 1002 null;
        "portals" = mkOverride 1002 null;
        "readOnly" = mkOverride 1002 null;
        "secretRef" = mkOverride 1002 null;
      };

    };
    "seaweed.seaweedfs.com.v1.SeaweedSpecVolumeVolumesIscsiSecretRef" = {

      options = {
        "name" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
      };

      config = {
        "name" = mkOverride 1002 null;
      };

    };
    "seaweed.seaweedfs.com.v1.SeaweedSpecVolumeVolumesNfs" = {

      options = {
        "path" = mkOption {
          description = "";
          type = types.str;
        };
        "readOnly" = mkOption {
          description = "";
          type = types.nullOr types.bool;
        };
        "server" = mkOption {
          description = "";
          type = types.str;
        };
      };

      config = {
        "readOnly" = mkOverride 1002 null;
      };

    };
    "seaweed.seaweedfs.com.v1.SeaweedSpecVolumeVolumesPersistentVolumeClaim" = {

      options = {
        "claimName" = mkOption {
          description = "";
          type = types.str;
        };
        "readOnly" = mkOption {
          description = "";
          type = types.nullOr types.bool;
        };
      };

      config = {
        "readOnly" = mkOverride 1002 null;
      };

    };
    "seaweed.seaweedfs.com.v1.SeaweedSpecVolumeVolumesPhotonPersistentDisk" = {

      options = {
        "fsType" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "pdID" = mkOption {
          description = "";
          type = types.str;
        };
      };

      config = {
        "fsType" = mkOverride 1002 null;
      };

    };
    "seaweed.seaweedfs.com.v1.SeaweedSpecVolumeVolumesPortworxVolume" = {

      options = {
        "fsType" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "readOnly" = mkOption {
          description = "";
          type = types.nullOr types.bool;
        };
        "volumeID" = mkOption {
          description = "";
          type = types.str;
        };
      };

      config = {
        "fsType" = mkOverride 1002 null;
        "readOnly" = mkOverride 1002 null;
      };

    };
    "seaweed.seaweedfs.com.v1.SeaweedSpecVolumeVolumesProjected" = {

      options = {
        "defaultMode" = mkOption {
          description = "";
          type = types.nullOr types.int;
        };
        "sources" = mkOption {
          description = "";
          type = types.nullOr (
            types.listOf (submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecVolumeVolumesProjectedSources")
          );
        };
      };

      config = {
        "defaultMode" = mkOverride 1002 null;
        "sources" = mkOverride 1002 null;
      };

    };
    "seaweed.seaweedfs.com.v1.SeaweedSpecVolumeVolumesProjectedSources" = {

      options = {
        "clusterTrustBundle" = mkOption {
          description = "";
          type = types.nullOr (
            submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecVolumeVolumesProjectedSourcesClusterTrustBundle"
          );
        };
        "configMap" = mkOption {
          description = "";
          type = types.nullOr (
            submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecVolumeVolumesProjectedSourcesConfigMap"
          );
        };
        "downwardAPI" = mkOption {
          description = "";
          type = types.nullOr (
            submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecVolumeVolumesProjectedSourcesDownwardAPI"
          );
        };
        "podCertificate" = mkOption {
          description = "";
          type = types.nullOr (
            submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecVolumeVolumesProjectedSourcesPodCertificate"
          );
        };
        "secret" = mkOption {
          description = "";
          type = types.nullOr (
            submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecVolumeVolumesProjectedSourcesSecret"
          );
        };
        "serviceAccountToken" = mkOption {
          description = "";
          type = types.nullOr (
            submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecVolumeVolumesProjectedSourcesServiceAccountToken"
          );
        };
      };

      config = {
        "clusterTrustBundle" = mkOverride 1002 null;
        "configMap" = mkOverride 1002 null;
        "downwardAPI" = mkOverride 1002 null;
        "podCertificate" = mkOverride 1002 null;
        "secret" = mkOverride 1002 null;
        "serviceAccountToken" = mkOverride 1002 null;
      };

    };
    "seaweed.seaweedfs.com.v1.SeaweedSpecVolumeVolumesProjectedSourcesClusterTrustBundle" = {

      options = {
        "labelSelector" = mkOption {
          description = "";
          type = types.nullOr (
            submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecVolumeVolumesProjectedSourcesClusterTrustBundleLabelSelector"
          );
        };
        "name" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "optional" = mkOption {
          description = "";
          type = types.nullOr types.bool;
        };
        "path" = mkOption {
          description = "";
          type = types.str;
        };
        "signerName" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
      };

      config = {
        "labelSelector" = mkOverride 1002 null;
        "name" = mkOverride 1002 null;
        "optional" = mkOverride 1002 null;
        "signerName" = mkOverride 1002 null;
      };

    };
    "seaweed.seaweedfs.com.v1.SeaweedSpecVolumeVolumesProjectedSourcesClusterTrustBundleLabelSelector" =
      {

        options = {
          "matchExpressions" = mkOption {
            description = "";
            type = types.nullOr (
              types.listOf (
                submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecVolumeVolumesProjectedSourcesClusterTrustBundleLabelSelectorMatchExpressions"
              )
            );
          };
          "matchLabels" = mkOption {
            description = "";
            type = types.nullOr (types.attrsOf types.str);
          };
        };

        config = {
          "matchExpressions" = mkOverride 1002 null;
          "matchLabels" = mkOverride 1002 null;
        };

      };
    "seaweed.seaweedfs.com.v1.SeaweedSpecVolumeVolumesProjectedSourcesClusterTrustBundleLabelSelectorMatchExpressions" =
      {

        options = {
          "key" = mkOption {
            description = "";
            type = types.str;
          };
          "operator" = mkOption {
            description = "";
            type = types.str;
          };
          "values" = mkOption {
            description = "";
            type = types.nullOr (types.listOf types.str);
          };
        };

        config = {
          "values" = mkOverride 1002 null;
        };

      };
    "seaweed.seaweedfs.com.v1.SeaweedSpecVolumeVolumesProjectedSourcesConfigMap" = {

      options = {
        "items" = mkOption {
          description = "";
          type = types.nullOr (
            types.listOf (
              submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecVolumeVolumesProjectedSourcesConfigMapItems"
            )
          );
        };
        "name" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "optional" = mkOption {
          description = "";
          type = types.nullOr types.bool;
        };
      };

      config = {
        "items" = mkOverride 1002 null;
        "name" = mkOverride 1002 null;
        "optional" = mkOverride 1002 null;
      };

    };
    "seaweed.seaweedfs.com.v1.SeaweedSpecVolumeVolumesProjectedSourcesConfigMapItems" = {

      options = {
        "key" = mkOption {
          description = "";
          type = types.str;
        };
        "mode" = mkOption {
          description = "";
          type = types.nullOr types.int;
        };
        "path" = mkOption {
          description = "";
          type = types.str;
        };
      };

      config = {
        "mode" = mkOverride 1002 null;
      };

    };
    "seaweed.seaweedfs.com.v1.SeaweedSpecVolumeVolumesProjectedSourcesDownwardAPI" = {

      options = {
        "items" = mkOption {
          description = "";
          type = types.nullOr (
            types.listOf (
              submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecVolumeVolumesProjectedSourcesDownwardAPIItems"
            )
          );
        };
      };

      config = {
        "items" = mkOverride 1002 null;
      };

    };
    "seaweed.seaweedfs.com.v1.SeaweedSpecVolumeVolumesProjectedSourcesDownwardAPIItems" = {

      options = {
        "fieldRef" = mkOption {
          description = "";
          type = types.nullOr (
            submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecVolumeVolumesProjectedSourcesDownwardAPIItemsFieldRef"
          );
        };
        "mode" = mkOption {
          description = "";
          type = types.nullOr types.int;
        };
        "path" = mkOption {
          description = "";
          type = types.str;
        };
        "resourceFieldRef" = mkOption {
          description = "";
          type = types.nullOr (
            submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecVolumeVolumesProjectedSourcesDownwardAPIItemsResourceFieldRef"
          );
        };
      };

      config = {
        "fieldRef" = mkOverride 1002 null;
        "mode" = mkOverride 1002 null;
        "resourceFieldRef" = mkOverride 1002 null;
      };

    };
    "seaweed.seaweedfs.com.v1.SeaweedSpecVolumeVolumesProjectedSourcesDownwardAPIItemsFieldRef" = {

      options = {
        "apiVersion" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "fieldPath" = mkOption {
          description = "";
          type = types.str;
        };
      };

      config = {
        "apiVersion" = mkOverride 1002 null;
      };

    };
    "seaweed.seaweedfs.com.v1.SeaweedSpecVolumeVolumesProjectedSourcesDownwardAPIItemsResourceFieldRef" =
      {

        options = {
          "containerName" = mkOption {
            description = "";
            type = types.nullOr types.str;
          };
          "divisor" = mkOption {
            description = "";
            type = types.nullOr (types.either types.int types.str);
          };
          "resource" = mkOption {
            description = "";
            type = types.str;
          };
        };

        config = {
          "containerName" = mkOverride 1002 null;
          "divisor" = mkOverride 1002 null;
        };

      };
    "seaweed.seaweedfs.com.v1.SeaweedSpecVolumeVolumesProjectedSourcesPodCertificate" = {

      options = {
        "certificateChainPath" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "credentialBundlePath" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "keyPath" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "keyType" = mkOption {
          description = "";
          type = types.str;
        };
        "maxExpirationSeconds" = mkOption {
          description = "";
          type = types.nullOr types.int;
        };
        "signerName" = mkOption {
          description = "";
          type = types.str;
        };
        "userAnnotations" = mkOption {
          description = "";
          type = types.nullOr (types.attrsOf types.str);
        };
      };

      config = {
        "certificateChainPath" = mkOverride 1002 null;
        "credentialBundlePath" = mkOverride 1002 null;
        "keyPath" = mkOverride 1002 null;
        "maxExpirationSeconds" = mkOverride 1002 null;
        "userAnnotations" = mkOverride 1002 null;
      };

    };
    "seaweed.seaweedfs.com.v1.SeaweedSpecVolumeVolumesProjectedSourcesSecret" = {

      options = {
        "items" = mkOption {
          description = "";
          type = types.nullOr (
            types.listOf (
              submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecVolumeVolumesProjectedSourcesSecretItems"
            )
          );
        };
        "name" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "optional" = mkOption {
          description = "";
          type = types.nullOr types.bool;
        };
      };

      config = {
        "items" = mkOverride 1002 null;
        "name" = mkOverride 1002 null;
        "optional" = mkOverride 1002 null;
      };

    };
    "seaweed.seaweedfs.com.v1.SeaweedSpecVolumeVolumesProjectedSourcesSecretItems" = {

      options = {
        "key" = mkOption {
          description = "";
          type = types.str;
        };
        "mode" = mkOption {
          description = "";
          type = types.nullOr types.int;
        };
        "path" = mkOption {
          description = "";
          type = types.str;
        };
      };

      config = {
        "mode" = mkOverride 1002 null;
      };

    };
    "seaweed.seaweedfs.com.v1.SeaweedSpecVolumeVolumesProjectedSourcesServiceAccountToken" = {

      options = {
        "audience" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "expirationSeconds" = mkOption {
          description = "";
          type = types.nullOr types.int;
        };
        "path" = mkOption {
          description = "";
          type = types.str;
        };
      };

      config = {
        "audience" = mkOverride 1002 null;
        "expirationSeconds" = mkOverride 1002 null;
      };

    };
    "seaweed.seaweedfs.com.v1.SeaweedSpecVolumeVolumesQuobyte" = {

      options = {
        "group" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "readOnly" = mkOption {
          description = "";
          type = types.nullOr types.bool;
        };
        "registry" = mkOption {
          description = "";
          type = types.str;
        };
        "tenant" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "user" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "volume" = mkOption {
          description = "";
          type = types.str;
        };
      };

      config = {
        "group" = mkOverride 1002 null;
        "readOnly" = mkOverride 1002 null;
        "tenant" = mkOverride 1002 null;
        "user" = mkOverride 1002 null;
      };

    };
    "seaweed.seaweedfs.com.v1.SeaweedSpecVolumeVolumesRbd" = {

      options = {
        "fsType" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "image" = mkOption {
          description = "";
          type = types.str;
        };
        "keyring" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "monitors" = mkOption {
          description = "";
          type = types.listOf types.str;
        };
        "pool" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "readOnly" = mkOption {
          description = "";
          type = types.nullOr types.bool;
        };
        "secretRef" = mkOption {
          description = "";
          type = types.nullOr (submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecVolumeVolumesRbdSecretRef");
        };
        "user" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
      };

      config = {
        "fsType" = mkOverride 1002 null;
        "keyring" = mkOverride 1002 null;
        "pool" = mkOverride 1002 null;
        "readOnly" = mkOverride 1002 null;
        "secretRef" = mkOverride 1002 null;
        "user" = mkOverride 1002 null;
      };

    };
    "seaweed.seaweedfs.com.v1.SeaweedSpecVolumeVolumesRbdSecretRef" = {

      options = {
        "name" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
      };

      config = {
        "name" = mkOverride 1002 null;
      };

    };
    "seaweed.seaweedfs.com.v1.SeaweedSpecVolumeVolumesScaleIO" = {

      options = {
        "fsType" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "gateway" = mkOption {
          description = "";
          type = types.str;
        };
        "protectionDomain" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "readOnly" = mkOption {
          description = "";
          type = types.nullOr types.bool;
        };
        "secretRef" = mkOption {
          description = "";
          type = submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecVolumeVolumesScaleIOSecretRef";
        };
        "sslEnabled" = mkOption {
          description = "";
          type = types.nullOr types.bool;
        };
        "storageMode" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "storagePool" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "system" = mkOption {
          description = "";
          type = types.str;
        };
        "volumeName" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
      };

      config = {
        "fsType" = mkOverride 1002 null;
        "protectionDomain" = mkOverride 1002 null;
        "readOnly" = mkOverride 1002 null;
        "sslEnabled" = mkOverride 1002 null;
        "storageMode" = mkOverride 1002 null;
        "storagePool" = mkOverride 1002 null;
        "volumeName" = mkOverride 1002 null;
      };

    };
    "seaweed.seaweedfs.com.v1.SeaweedSpecVolumeVolumesScaleIOSecretRef" = {

      options = {
        "name" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
      };

      config = {
        "name" = mkOverride 1002 null;
      };

    };
    "seaweed.seaweedfs.com.v1.SeaweedSpecVolumeVolumesSecret" = {

      options = {
        "defaultMode" = mkOption {
          description = "";
          type = types.nullOr types.int;
        };
        "items" = mkOption {
          description = "";
          type = types.nullOr (
            types.listOf (submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecVolumeVolumesSecretItems")
          );
        };
        "optional" = mkOption {
          description = "";
          type = types.nullOr types.bool;
        };
        "secretName" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
      };

      config = {
        "defaultMode" = mkOverride 1002 null;
        "items" = mkOverride 1002 null;
        "optional" = mkOverride 1002 null;
        "secretName" = mkOverride 1002 null;
      };

    };
    "seaweed.seaweedfs.com.v1.SeaweedSpecVolumeVolumesSecretItems" = {

      options = {
        "key" = mkOption {
          description = "";
          type = types.str;
        };
        "mode" = mkOption {
          description = "";
          type = types.nullOr types.int;
        };
        "path" = mkOption {
          description = "";
          type = types.str;
        };
      };

      config = {
        "mode" = mkOverride 1002 null;
      };

    };
    "seaweed.seaweedfs.com.v1.SeaweedSpecVolumeVolumesStorageos" = {

      options = {
        "fsType" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "readOnly" = mkOption {
          description = "";
          type = types.nullOr types.bool;
        };
        "secretRef" = mkOption {
          description = "";
          type = types.nullOr (
            submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecVolumeVolumesStorageosSecretRef"
          );
        };
        "volumeName" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "volumeNamespace" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
      };

      config = {
        "fsType" = mkOverride 1002 null;
        "readOnly" = mkOverride 1002 null;
        "secretRef" = mkOverride 1002 null;
        "volumeName" = mkOverride 1002 null;
        "volumeNamespace" = mkOverride 1002 null;
      };

    };
    "seaweed.seaweedfs.com.v1.SeaweedSpecVolumeVolumesStorageosSecretRef" = {

      options = {
        "name" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
      };

      config = {
        "name" = mkOverride 1002 null;
      };

    };
    "seaweed.seaweedfs.com.v1.SeaweedSpecVolumeVolumesVsphereVolume" = {

      options = {
        "fsType" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "storagePolicyID" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "storagePolicyName" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "volumePath" = mkOption {
          description = "";
          type = types.str;
        };
      };

      config = {
        "fsType" = mkOverride 1002 null;
        "storagePolicyID" = mkOverride 1002 null;
        "storagePolicyName" = mkOverride 1002 null;
      };

    };
    "seaweed.seaweedfs.com.v1.SeaweedSpecWorker" = {

      options = {
        "affinity" = mkOption {
          description = "";
          type = types.nullOr (submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecWorkerAffinity");
        };
        "annotations" = mkOption {
          description = "";
          type = types.nullOr (types.attrsOf types.str);
        };
        "claims" = mkOption {
          description = "";
          type = types.nullOr (
            coerceAttrsOfSubmodulesToListByKey "seaweed.seaweedfs.com.v1.SeaweedSpecWorkerClaims" "name" [
              "name"
            ]
          );
          apply = attrsToList;
        };
        "containerSecurityContext" = mkOption {
          description = "";
          type = types.nullOr (
            submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecWorkerContainerSecurityContext"
          );
        };
        "env" = mkOption {
          description = "";
          type = types.nullOr (
            coerceAttrsOfSubmodulesToListByKey "seaweed.seaweedfs.com.v1.SeaweedSpecWorkerEnv" "name" [ ]
          );
          apply = attrsToList;
        };
        "extraArgs" = mkOption {
          description = "";
          type = types.nullOr (types.listOf types.str);
        };
        "hostNetwork" = mkOption {
          description = "";
          type = types.nullOr types.bool;
        };
        "imagePullPolicy" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "imagePullSecrets" = mkOption {
          description = "";
          type = types.nullOr (
            coerceAttrsOfSubmodulesToListByKey "seaweed.seaweedfs.com.v1.SeaweedSpecWorkerImagePullSecrets"
              "name"
              [ ]
          );
          apply = attrsToList;
        };
        "initContainers" = mkOption {
          description = "";
          type = types.nullOr types.unspecified;
        };
        "jobType" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "labels" = mkOption {
          description = "";
          type = types.nullOr (types.attrsOf types.str);
        };
        "limits" = mkOption {
          description = "";
          type = types.nullOr (types.attrsOf (types.either types.int types.str));
        };
        "livenessProbe" = mkOption {
          description = "";
          type = types.nullOr (submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecWorkerLivenessProbe");
        };
        "loggingArgs" = mkOption {
          description = "";
          type = types.nullOr (types.listOf types.str);
        };
        "maxDetect" = mkOption {
          description = "";
          type = types.nullOr types.int;
        };
        "maxExecute" = mkOption {
          description = "";
          type = types.nullOr types.int;
        };
        "metricsPort" = mkOption {
          description = "";
          type = types.nullOr types.int;
        };
        "nodeSelector" = mkOption {
          description = "";
          type = types.nullOr (types.attrsOf types.str);
        };
        "persistence" = mkOption {
          description = "";
          type = types.nullOr (submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecWorkerPersistence");
        };
        "podSecurityContext" = mkOption {
          description = "";
          type = types.nullOr (submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecWorkerPodSecurityContext");
        };
        "priorityClassName" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "readinessProbe" = mkOption {
          description = "";
          type = types.nullOr (submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecWorkerReadinessProbe");
        };
        "replicas" = mkOption {
          description = "";
          type = types.int;
        };
        "requests" = mkOption {
          description = "";
          type = types.nullOr (types.attrsOf (types.either types.int types.str));
        };
        "schedulerName" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "serviceAccountName" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "sidecars" = mkOption {
          description = "";
          type = types.nullOr types.unspecified;
        };
        "statefulSetUpdateStrategy" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "terminationGracePeriodSeconds" = mkOption {
          description = "";
          type = types.nullOr types.int;
        };
        "tolerations" = mkOption {
          description = "";
          type = types.nullOr (
            types.listOf (submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecWorkerTolerations")
          );
        };
        "version" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "volumeMounts" = mkOption {
          description = "";
          type = types.nullOr (
            coerceAttrsOfSubmodulesToListByKey "seaweed.seaweedfs.com.v1.SeaweedSpecWorkerVolumeMounts" "name"
              [ ]
          );
          apply = attrsToList;
        };
        "volumes" = mkOption {
          description = "";
          type = types.nullOr (
            coerceAttrsOfSubmodulesToListByKey "seaweed.seaweedfs.com.v1.SeaweedSpecWorkerVolumes" "name" [ ]
          );
          apply = attrsToList;
        };
      };

      config = {
        "affinity" = mkOverride 1002 null;
        "annotations" = mkOverride 1002 null;
        "claims" = mkOverride 1002 null;
        "containerSecurityContext" = mkOverride 1002 null;
        "env" = mkOverride 1002 null;
        "extraArgs" = mkOverride 1002 null;
        "hostNetwork" = mkOverride 1002 null;
        "imagePullPolicy" = mkOverride 1002 null;
        "imagePullSecrets" = mkOverride 1002 null;
        "initContainers" = mkOverride 1002 null;
        "jobType" = mkOverride 1002 null;
        "labels" = mkOverride 1002 null;
        "limits" = mkOverride 1002 null;
        "livenessProbe" = mkOverride 1002 null;
        "loggingArgs" = mkOverride 1002 null;
        "maxDetect" = mkOverride 1002 null;
        "maxExecute" = mkOverride 1002 null;
        "metricsPort" = mkOverride 1002 null;
        "nodeSelector" = mkOverride 1002 null;
        "persistence" = mkOverride 1002 null;
        "podSecurityContext" = mkOverride 1002 null;
        "priorityClassName" = mkOverride 1002 null;
        "readinessProbe" = mkOverride 1002 null;
        "requests" = mkOverride 1002 null;
        "schedulerName" = mkOverride 1002 null;
        "serviceAccountName" = mkOverride 1002 null;
        "sidecars" = mkOverride 1002 null;
        "statefulSetUpdateStrategy" = mkOverride 1002 null;
        "terminationGracePeriodSeconds" = mkOverride 1002 null;
        "tolerations" = mkOverride 1002 null;
        "version" = mkOverride 1002 null;
        "volumeMounts" = mkOverride 1002 null;
        "volumes" = mkOverride 1002 null;
      };

    };
    "seaweed.seaweedfs.com.v1.SeaweedSpecWorkerAffinity" = {

      options = {
        "nodeAffinity" = mkOption {
          description = "";
          type = types.nullOr (submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecWorkerAffinityNodeAffinity");
        };
        "podAffinity" = mkOption {
          description = "";
          type = types.nullOr (submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecWorkerAffinityPodAffinity");
        };
        "podAntiAffinity" = mkOption {
          description = "";
          type = types.nullOr (
            submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecWorkerAffinityPodAntiAffinity"
          );
        };
      };

      config = {
        "nodeAffinity" = mkOverride 1002 null;
        "podAffinity" = mkOverride 1002 null;
        "podAntiAffinity" = mkOverride 1002 null;
      };

    };
    "seaweed.seaweedfs.com.v1.SeaweedSpecWorkerAffinityNodeAffinity" = {

      options = {
        "preferredDuringSchedulingIgnoredDuringExecution" = mkOption {
          description = "";
          type = types.nullOr (
            types.listOf (
              submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecWorkerAffinityNodeAffinityPreferredDuringSchedulingIgnoredDuringExecution"
            )
          );
        };
        "requiredDuringSchedulingIgnoredDuringExecution" = mkOption {
          description = "";
          type = types.nullOr (
            submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecWorkerAffinityNodeAffinityRequiredDuringSchedulingIgnoredDuringExecution"
          );
        };
      };

      config = {
        "preferredDuringSchedulingIgnoredDuringExecution" = mkOverride 1002 null;
        "requiredDuringSchedulingIgnoredDuringExecution" = mkOverride 1002 null;
      };

    };
    "seaweed.seaweedfs.com.v1.SeaweedSpecWorkerAffinityNodeAffinityPreferredDuringSchedulingIgnoredDuringExecution" =
      {

        options = {
          "preference" = mkOption {
            description = "";
            type = submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecWorkerAffinityNodeAffinityPreferredDuringSchedulingIgnoredDuringExecutionPreference";
          };
          "weight" = mkOption {
            description = "";
            type = types.int;
          };
        };

        config = { };

      };
    "seaweed.seaweedfs.com.v1.SeaweedSpecWorkerAffinityNodeAffinityPreferredDuringSchedulingIgnoredDuringExecutionPreference" =
      {

        options = {
          "matchExpressions" = mkOption {
            description = "";
            type = types.nullOr (
              types.listOf (
                submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecWorkerAffinityNodeAffinityPreferredDuringSchedulingIgnoredDuringExecutionPreferenceMatchExpressions"
              )
            );
          };
          "matchFields" = mkOption {
            description = "";
            type = types.nullOr (
              types.listOf (
                submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecWorkerAffinityNodeAffinityPreferredDuringSchedulingIgnoredDuringExecutionPreferenceMatchFields"
              )
            );
          };
        };

        config = {
          "matchExpressions" = mkOverride 1002 null;
          "matchFields" = mkOverride 1002 null;
        };

      };
    "seaweed.seaweedfs.com.v1.SeaweedSpecWorkerAffinityNodeAffinityPreferredDuringSchedulingIgnoredDuringExecutionPreferenceMatchExpressions" =
      {

        options = {
          "key" = mkOption {
            description = "";
            type = types.str;
          };
          "operator" = mkOption {
            description = "";
            type = types.str;
          };
          "values" = mkOption {
            description = "";
            type = types.nullOr (types.listOf types.str);
          };
        };

        config = {
          "values" = mkOverride 1002 null;
        };

      };
    "seaweed.seaweedfs.com.v1.SeaweedSpecWorkerAffinityNodeAffinityPreferredDuringSchedulingIgnoredDuringExecutionPreferenceMatchFields" =
      {

        options = {
          "key" = mkOption {
            description = "";
            type = types.str;
          };
          "operator" = mkOption {
            description = "";
            type = types.str;
          };
          "values" = mkOption {
            description = "";
            type = types.nullOr (types.listOf types.str);
          };
        };

        config = {
          "values" = mkOverride 1002 null;
        };

      };
    "seaweed.seaweedfs.com.v1.SeaweedSpecWorkerAffinityNodeAffinityRequiredDuringSchedulingIgnoredDuringExecution" =
      {

        options = {
          "nodeSelectorTerms" = mkOption {
            description = "";
            type = types.listOf (
              submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecWorkerAffinityNodeAffinityRequiredDuringSchedulingIgnoredDuringExecutionNodeSelectorTerms"
            );
          };
        };

        config = { };

      };
    "seaweed.seaweedfs.com.v1.SeaweedSpecWorkerAffinityNodeAffinityRequiredDuringSchedulingIgnoredDuringExecutionNodeSelectorTerms" =
      {

        options = {
          "matchExpressions" = mkOption {
            description = "";
            type = types.nullOr (
              types.listOf (
                submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecWorkerAffinityNodeAffinityRequiredDuringSchedulingIgnoredDuringExecutionNodeSelectorTermsMatchExpressions"
              )
            );
          };
          "matchFields" = mkOption {
            description = "";
            type = types.nullOr (
              types.listOf (
                submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecWorkerAffinityNodeAffinityRequiredDuringSchedulingIgnoredDuringExecutionNodeSelectorTermsMatchFields"
              )
            );
          };
        };

        config = {
          "matchExpressions" = mkOverride 1002 null;
          "matchFields" = mkOverride 1002 null;
        };

      };
    "seaweed.seaweedfs.com.v1.SeaweedSpecWorkerAffinityNodeAffinityRequiredDuringSchedulingIgnoredDuringExecutionNodeSelectorTermsMatchExpressions" =
      {

        options = {
          "key" = mkOption {
            description = "";
            type = types.str;
          };
          "operator" = mkOption {
            description = "";
            type = types.str;
          };
          "values" = mkOption {
            description = "";
            type = types.nullOr (types.listOf types.str);
          };
        };

        config = {
          "values" = mkOverride 1002 null;
        };

      };
    "seaweed.seaweedfs.com.v1.SeaweedSpecWorkerAffinityNodeAffinityRequiredDuringSchedulingIgnoredDuringExecutionNodeSelectorTermsMatchFields" =
      {

        options = {
          "key" = mkOption {
            description = "";
            type = types.str;
          };
          "operator" = mkOption {
            description = "";
            type = types.str;
          };
          "values" = mkOption {
            description = "";
            type = types.nullOr (types.listOf types.str);
          };
        };

        config = {
          "values" = mkOverride 1002 null;
        };

      };
    "seaweed.seaweedfs.com.v1.SeaweedSpecWorkerAffinityPodAffinity" = {

      options = {
        "preferredDuringSchedulingIgnoredDuringExecution" = mkOption {
          description = "";
          type = types.nullOr (
            types.listOf (
              submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecWorkerAffinityPodAffinityPreferredDuringSchedulingIgnoredDuringExecution"
            )
          );
        };
        "requiredDuringSchedulingIgnoredDuringExecution" = mkOption {
          description = "";
          type = types.nullOr (
            types.listOf (
              submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecWorkerAffinityPodAffinityRequiredDuringSchedulingIgnoredDuringExecution"
            )
          );
        };
      };

      config = {
        "preferredDuringSchedulingIgnoredDuringExecution" = mkOverride 1002 null;
        "requiredDuringSchedulingIgnoredDuringExecution" = mkOverride 1002 null;
      };

    };
    "seaweed.seaweedfs.com.v1.SeaweedSpecWorkerAffinityPodAffinityPreferredDuringSchedulingIgnoredDuringExecution" =
      {

        options = {
          "podAffinityTerm" = mkOption {
            description = "";
            type = submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecWorkerAffinityPodAffinityPreferredDuringSchedulingIgnoredDuringExecutionPodAffinityTerm";
          };
          "weight" = mkOption {
            description = "";
            type = types.int;
          };
        };

        config = { };

      };
    "seaweed.seaweedfs.com.v1.SeaweedSpecWorkerAffinityPodAffinityPreferredDuringSchedulingIgnoredDuringExecutionPodAffinityTerm" =
      {

        options = {
          "labelSelector" = mkOption {
            description = "";
            type = types.nullOr (
              submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecWorkerAffinityPodAffinityPreferredDuringSchedulingIgnoredDuringExecutionPodAffinityTermLabelSelector"
            );
          };
          "matchLabelKeys" = mkOption {
            description = "";
            type = types.nullOr (types.listOf types.str);
          };
          "mismatchLabelKeys" = mkOption {
            description = "";
            type = types.nullOr (types.listOf types.str);
          };
          "namespaceSelector" = mkOption {
            description = "";
            type = types.nullOr (
              submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecWorkerAffinityPodAffinityPreferredDuringSchedulingIgnoredDuringExecutionPodAffinityTermNamespaceSelector"
            );
          };
          "namespaces" = mkOption {
            description = "";
            type = types.nullOr (types.listOf types.str);
          };
          "topologyKey" = mkOption {
            description = "";
            type = types.str;
          };
        };

        config = {
          "labelSelector" = mkOverride 1002 null;
          "matchLabelKeys" = mkOverride 1002 null;
          "mismatchLabelKeys" = mkOverride 1002 null;
          "namespaceSelector" = mkOverride 1002 null;
          "namespaces" = mkOverride 1002 null;
        };

      };
    "seaweed.seaweedfs.com.v1.SeaweedSpecWorkerAffinityPodAffinityPreferredDuringSchedulingIgnoredDuringExecutionPodAffinityTermLabelSelector" =
      {

        options = {
          "matchExpressions" = mkOption {
            description = "";
            type = types.nullOr (
              types.listOf (
                submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecWorkerAffinityPodAffinityPreferredDuringSchedulingIgnoredDuringExecutionPodAffinityTermLabelSelectorMatchExpressions"
              )
            );
          };
          "matchLabels" = mkOption {
            description = "";
            type = types.nullOr (types.attrsOf types.str);
          };
        };

        config = {
          "matchExpressions" = mkOverride 1002 null;
          "matchLabels" = mkOverride 1002 null;
        };

      };
    "seaweed.seaweedfs.com.v1.SeaweedSpecWorkerAffinityPodAffinityPreferredDuringSchedulingIgnoredDuringExecutionPodAffinityTermLabelSelectorMatchExpressions" =
      {

        options = {
          "key" = mkOption {
            description = "";
            type = types.str;
          };
          "operator" = mkOption {
            description = "";
            type = types.str;
          };
          "values" = mkOption {
            description = "";
            type = types.nullOr (types.listOf types.str);
          };
        };

        config = {
          "values" = mkOverride 1002 null;
        };

      };
    "seaweed.seaweedfs.com.v1.SeaweedSpecWorkerAffinityPodAffinityPreferredDuringSchedulingIgnoredDuringExecutionPodAffinityTermNamespaceSelector" =
      {

        options = {
          "matchExpressions" = mkOption {
            description = "";
            type = types.nullOr (
              types.listOf (
                submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecWorkerAffinityPodAffinityPreferredDuringSchedulingIgnoredDuringExecutionPodAffinityTermNamespaceSelectorMatchExpressions"
              )
            );
          };
          "matchLabels" = mkOption {
            description = "";
            type = types.nullOr (types.attrsOf types.str);
          };
        };

        config = {
          "matchExpressions" = mkOverride 1002 null;
          "matchLabels" = mkOverride 1002 null;
        };

      };
    "seaweed.seaweedfs.com.v1.SeaweedSpecWorkerAffinityPodAffinityPreferredDuringSchedulingIgnoredDuringExecutionPodAffinityTermNamespaceSelectorMatchExpressions" =
      {

        options = {
          "key" = mkOption {
            description = "";
            type = types.str;
          };
          "operator" = mkOption {
            description = "";
            type = types.str;
          };
          "values" = mkOption {
            description = "";
            type = types.nullOr (types.listOf types.str);
          };
        };

        config = {
          "values" = mkOverride 1002 null;
        };

      };
    "seaweed.seaweedfs.com.v1.SeaweedSpecWorkerAffinityPodAffinityRequiredDuringSchedulingIgnoredDuringExecution" =
      {

        options = {
          "labelSelector" = mkOption {
            description = "";
            type = types.nullOr (
              submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecWorkerAffinityPodAffinityRequiredDuringSchedulingIgnoredDuringExecutionLabelSelector"
            );
          };
          "matchLabelKeys" = mkOption {
            description = "";
            type = types.nullOr (types.listOf types.str);
          };
          "mismatchLabelKeys" = mkOption {
            description = "";
            type = types.nullOr (types.listOf types.str);
          };
          "namespaceSelector" = mkOption {
            description = "";
            type = types.nullOr (
              submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecWorkerAffinityPodAffinityRequiredDuringSchedulingIgnoredDuringExecutionNamespaceSelector"
            );
          };
          "namespaces" = mkOption {
            description = "";
            type = types.nullOr (types.listOf types.str);
          };
          "topologyKey" = mkOption {
            description = "";
            type = types.str;
          };
        };

        config = {
          "labelSelector" = mkOverride 1002 null;
          "matchLabelKeys" = mkOverride 1002 null;
          "mismatchLabelKeys" = mkOverride 1002 null;
          "namespaceSelector" = mkOverride 1002 null;
          "namespaces" = mkOverride 1002 null;
        };

      };
    "seaweed.seaweedfs.com.v1.SeaweedSpecWorkerAffinityPodAffinityRequiredDuringSchedulingIgnoredDuringExecutionLabelSelector" =
      {

        options = {
          "matchExpressions" = mkOption {
            description = "";
            type = types.nullOr (
              types.listOf (
                submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecWorkerAffinityPodAffinityRequiredDuringSchedulingIgnoredDuringExecutionLabelSelectorMatchExpressions"
              )
            );
          };
          "matchLabels" = mkOption {
            description = "";
            type = types.nullOr (types.attrsOf types.str);
          };
        };

        config = {
          "matchExpressions" = mkOverride 1002 null;
          "matchLabels" = mkOverride 1002 null;
        };

      };
    "seaweed.seaweedfs.com.v1.SeaweedSpecWorkerAffinityPodAffinityRequiredDuringSchedulingIgnoredDuringExecutionLabelSelectorMatchExpressions" =
      {

        options = {
          "key" = mkOption {
            description = "";
            type = types.str;
          };
          "operator" = mkOption {
            description = "";
            type = types.str;
          };
          "values" = mkOption {
            description = "";
            type = types.nullOr (types.listOf types.str);
          };
        };

        config = {
          "values" = mkOverride 1002 null;
        };

      };
    "seaweed.seaweedfs.com.v1.SeaweedSpecWorkerAffinityPodAffinityRequiredDuringSchedulingIgnoredDuringExecutionNamespaceSelector" =
      {

        options = {
          "matchExpressions" = mkOption {
            description = "";
            type = types.nullOr (
              types.listOf (
                submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecWorkerAffinityPodAffinityRequiredDuringSchedulingIgnoredDuringExecutionNamespaceSelectorMatchExpressions"
              )
            );
          };
          "matchLabels" = mkOption {
            description = "";
            type = types.nullOr (types.attrsOf types.str);
          };
        };

        config = {
          "matchExpressions" = mkOverride 1002 null;
          "matchLabels" = mkOverride 1002 null;
        };

      };
    "seaweed.seaweedfs.com.v1.SeaweedSpecWorkerAffinityPodAffinityRequiredDuringSchedulingIgnoredDuringExecutionNamespaceSelectorMatchExpressions" =
      {

        options = {
          "key" = mkOption {
            description = "";
            type = types.str;
          };
          "operator" = mkOption {
            description = "";
            type = types.str;
          };
          "values" = mkOption {
            description = "";
            type = types.nullOr (types.listOf types.str);
          };
        };

        config = {
          "values" = mkOverride 1002 null;
        };

      };
    "seaweed.seaweedfs.com.v1.SeaweedSpecWorkerAffinityPodAntiAffinity" = {

      options = {
        "preferredDuringSchedulingIgnoredDuringExecution" = mkOption {
          description = "";
          type = types.nullOr (
            types.listOf (
              submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecWorkerAffinityPodAntiAffinityPreferredDuringSchedulingIgnoredDuringExecution"
            )
          );
        };
        "requiredDuringSchedulingIgnoredDuringExecution" = mkOption {
          description = "";
          type = types.nullOr (
            types.listOf (
              submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecWorkerAffinityPodAntiAffinityRequiredDuringSchedulingIgnoredDuringExecution"
            )
          );
        };
      };

      config = {
        "preferredDuringSchedulingIgnoredDuringExecution" = mkOverride 1002 null;
        "requiredDuringSchedulingIgnoredDuringExecution" = mkOverride 1002 null;
      };

    };
    "seaweed.seaweedfs.com.v1.SeaweedSpecWorkerAffinityPodAntiAffinityPreferredDuringSchedulingIgnoredDuringExecution" =
      {

        options = {
          "podAffinityTerm" = mkOption {
            description = "";
            type = submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecWorkerAffinityPodAntiAffinityPreferredDuringSchedulingIgnoredDuringExecutionPodAffinityTerm";
          };
          "weight" = mkOption {
            description = "";
            type = types.int;
          };
        };

        config = { };

      };
    "seaweed.seaweedfs.com.v1.SeaweedSpecWorkerAffinityPodAntiAffinityPreferredDuringSchedulingIgnoredDuringExecutionPodAffinityTerm" =
      {

        options = {
          "labelSelector" = mkOption {
            description = "";
            type = types.nullOr (
              submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecWorkerAffinityPodAntiAffinityPreferredDuringSchedulingIgnoredDuringExecutionPodAffinityTermLabelSelector"
            );
          };
          "matchLabelKeys" = mkOption {
            description = "";
            type = types.nullOr (types.listOf types.str);
          };
          "mismatchLabelKeys" = mkOption {
            description = "";
            type = types.nullOr (types.listOf types.str);
          };
          "namespaceSelector" = mkOption {
            description = "";
            type = types.nullOr (
              submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecWorkerAffinityPodAntiAffinityPreferredDuringSchedulingIgnoredDuringExecutionPodAffinityTermNamespaceSelector"
            );
          };
          "namespaces" = mkOption {
            description = "";
            type = types.nullOr (types.listOf types.str);
          };
          "topologyKey" = mkOption {
            description = "";
            type = types.str;
          };
        };

        config = {
          "labelSelector" = mkOverride 1002 null;
          "matchLabelKeys" = mkOverride 1002 null;
          "mismatchLabelKeys" = mkOverride 1002 null;
          "namespaceSelector" = mkOverride 1002 null;
          "namespaces" = mkOverride 1002 null;
        };

      };
    "seaweed.seaweedfs.com.v1.SeaweedSpecWorkerAffinityPodAntiAffinityPreferredDuringSchedulingIgnoredDuringExecutionPodAffinityTermLabelSelector" =
      {

        options = {
          "matchExpressions" = mkOption {
            description = "";
            type = types.nullOr (
              types.listOf (
                submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecWorkerAffinityPodAntiAffinityPreferredDuringSchedulingIgnoredDuringExecutionPodAffinityTermLabelSelectorMatchExpressions"
              )
            );
          };
          "matchLabels" = mkOption {
            description = "";
            type = types.nullOr (types.attrsOf types.str);
          };
        };

        config = {
          "matchExpressions" = mkOverride 1002 null;
          "matchLabels" = mkOverride 1002 null;
        };

      };
    "seaweed.seaweedfs.com.v1.SeaweedSpecWorkerAffinityPodAntiAffinityPreferredDuringSchedulingIgnoredDuringExecutionPodAffinityTermLabelSelectorMatchExpressions" =
      {

        options = {
          "key" = mkOption {
            description = "";
            type = types.str;
          };
          "operator" = mkOption {
            description = "";
            type = types.str;
          };
          "values" = mkOption {
            description = "";
            type = types.nullOr (types.listOf types.str);
          };
        };

        config = {
          "values" = mkOverride 1002 null;
        };

      };
    "seaweed.seaweedfs.com.v1.SeaweedSpecWorkerAffinityPodAntiAffinityPreferredDuringSchedulingIgnoredDuringExecutionPodAffinityTermNamespaceSelector" =
      {

        options = {
          "matchExpressions" = mkOption {
            description = "";
            type = types.nullOr (
              types.listOf (
                submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecWorkerAffinityPodAntiAffinityPreferredDuringSchedulingIgnoredDuringExecutionPodAffinityTermNamespaceSelectorMatchExpressions"
              )
            );
          };
          "matchLabels" = mkOption {
            description = "";
            type = types.nullOr (types.attrsOf types.str);
          };
        };

        config = {
          "matchExpressions" = mkOverride 1002 null;
          "matchLabels" = mkOverride 1002 null;
        };

      };
    "seaweed.seaweedfs.com.v1.SeaweedSpecWorkerAffinityPodAntiAffinityPreferredDuringSchedulingIgnoredDuringExecutionPodAffinityTermNamespaceSelectorMatchExpressions" =
      {

        options = {
          "key" = mkOption {
            description = "";
            type = types.str;
          };
          "operator" = mkOption {
            description = "";
            type = types.str;
          };
          "values" = mkOption {
            description = "";
            type = types.nullOr (types.listOf types.str);
          };
        };

        config = {
          "values" = mkOverride 1002 null;
        };

      };
    "seaweed.seaweedfs.com.v1.SeaweedSpecWorkerAffinityPodAntiAffinityRequiredDuringSchedulingIgnoredDuringExecution" =
      {

        options = {
          "labelSelector" = mkOption {
            description = "";
            type = types.nullOr (
              submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecWorkerAffinityPodAntiAffinityRequiredDuringSchedulingIgnoredDuringExecutionLabelSelector"
            );
          };
          "matchLabelKeys" = mkOption {
            description = "";
            type = types.nullOr (types.listOf types.str);
          };
          "mismatchLabelKeys" = mkOption {
            description = "";
            type = types.nullOr (types.listOf types.str);
          };
          "namespaceSelector" = mkOption {
            description = "";
            type = types.nullOr (
              submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecWorkerAffinityPodAntiAffinityRequiredDuringSchedulingIgnoredDuringExecutionNamespaceSelector"
            );
          };
          "namespaces" = mkOption {
            description = "";
            type = types.nullOr (types.listOf types.str);
          };
          "topologyKey" = mkOption {
            description = "";
            type = types.str;
          };
        };

        config = {
          "labelSelector" = mkOverride 1002 null;
          "matchLabelKeys" = mkOverride 1002 null;
          "mismatchLabelKeys" = mkOverride 1002 null;
          "namespaceSelector" = mkOverride 1002 null;
          "namespaces" = mkOverride 1002 null;
        };

      };
    "seaweed.seaweedfs.com.v1.SeaweedSpecWorkerAffinityPodAntiAffinityRequiredDuringSchedulingIgnoredDuringExecutionLabelSelector" =
      {

        options = {
          "matchExpressions" = mkOption {
            description = "";
            type = types.nullOr (
              types.listOf (
                submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecWorkerAffinityPodAntiAffinityRequiredDuringSchedulingIgnoredDuringExecutionLabelSelectorMatchExpressions"
              )
            );
          };
          "matchLabels" = mkOption {
            description = "";
            type = types.nullOr (types.attrsOf types.str);
          };
        };

        config = {
          "matchExpressions" = mkOverride 1002 null;
          "matchLabels" = mkOverride 1002 null;
        };

      };
    "seaweed.seaweedfs.com.v1.SeaweedSpecWorkerAffinityPodAntiAffinityRequiredDuringSchedulingIgnoredDuringExecutionLabelSelectorMatchExpressions" =
      {

        options = {
          "key" = mkOption {
            description = "";
            type = types.str;
          };
          "operator" = mkOption {
            description = "";
            type = types.str;
          };
          "values" = mkOption {
            description = "";
            type = types.nullOr (types.listOf types.str);
          };
        };

        config = {
          "values" = mkOverride 1002 null;
        };

      };
    "seaweed.seaweedfs.com.v1.SeaweedSpecWorkerAffinityPodAntiAffinityRequiredDuringSchedulingIgnoredDuringExecutionNamespaceSelector" =
      {

        options = {
          "matchExpressions" = mkOption {
            description = "";
            type = types.nullOr (
              types.listOf (
                submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecWorkerAffinityPodAntiAffinityRequiredDuringSchedulingIgnoredDuringExecutionNamespaceSelectorMatchExpressions"
              )
            );
          };
          "matchLabels" = mkOption {
            description = "";
            type = types.nullOr (types.attrsOf types.str);
          };
        };

        config = {
          "matchExpressions" = mkOverride 1002 null;
          "matchLabels" = mkOverride 1002 null;
        };

      };
    "seaweed.seaweedfs.com.v1.SeaweedSpecWorkerAffinityPodAntiAffinityRequiredDuringSchedulingIgnoredDuringExecutionNamespaceSelectorMatchExpressions" =
      {

        options = {
          "key" = mkOption {
            description = "";
            type = types.str;
          };
          "operator" = mkOption {
            description = "";
            type = types.str;
          };
          "values" = mkOption {
            description = "";
            type = types.nullOr (types.listOf types.str);
          };
        };

        config = {
          "values" = mkOverride 1002 null;
        };

      };
    "seaweed.seaweedfs.com.v1.SeaweedSpecWorkerClaims" = {

      options = {
        "name" = mkOption {
          description = "";
          type = types.str;
        };
        "request" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
      };

      config = {
        "request" = mkOverride 1002 null;
      };

    };
    "seaweed.seaweedfs.com.v1.SeaweedSpecWorkerContainerSecurityContext" = {

      options = {
        "allowPrivilegeEscalation" = mkOption {
          description = "";
          type = types.nullOr types.bool;
        };
        "appArmorProfile" = mkOption {
          description = "";
          type = types.nullOr (
            submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecWorkerContainerSecurityContextAppArmorProfile"
          );
        };
        "capabilities" = mkOption {
          description = "";
          type = types.nullOr (
            submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecWorkerContainerSecurityContextCapabilities"
          );
        };
        "privileged" = mkOption {
          description = "";
          type = types.nullOr types.bool;
        };
        "procMount" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "readOnlyRootFilesystem" = mkOption {
          description = "";
          type = types.nullOr types.bool;
        };
        "runAsGroup" = mkOption {
          description = "";
          type = types.nullOr types.int;
        };
        "runAsNonRoot" = mkOption {
          description = "";
          type = types.nullOr types.bool;
        };
        "runAsUser" = mkOption {
          description = "";
          type = types.nullOr types.int;
        };
        "seLinuxOptions" = mkOption {
          description = "";
          type = types.nullOr (
            submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecWorkerContainerSecurityContextSeLinuxOptions"
          );
        };
        "seccompProfile" = mkOption {
          description = "";
          type = types.nullOr (
            submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecWorkerContainerSecurityContextSeccompProfile"
          );
        };
        "windowsOptions" = mkOption {
          description = "";
          type = types.nullOr (
            submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecWorkerContainerSecurityContextWindowsOptions"
          );
        };
      };

      config = {
        "allowPrivilegeEscalation" = mkOverride 1002 null;
        "appArmorProfile" = mkOverride 1002 null;
        "capabilities" = mkOverride 1002 null;
        "privileged" = mkOverride 1002 null;
        "procMount" = mkOverride 1002 null;
        "readOnlyRootFilesystem" = mkOverride 1002 null;
        "runAsGroup" = mkOverride 1002 null;
        "runAsNonRoot" = mkOverride 1002 null;
        "runAsUser" = mkOverride 1002 null;
        "seLinuxOptions" = mkOverride 1002 null;
        "seccompProfile" = mkOverride 1002 null;
        "windowsOptions" = mkOverride 1002 null;
      };

    };
    "seaweed.seaweedfs.com.v1.SeaweedSpecWorkerContainerSecurityContextAppArmorProfile" = {

      options = {
        "localhostProfile" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "type" = mkOption {
          description = "";
          type = types.str;
        };
      };

      config = {
        "localhostProfile" = mkOverride 1002 null;
      };

    };
    "seaweed.seaweedfs.com.v1.SeaweedSpecWorkerContainerSecurityContextCapabilities" = {

      options = {
        "add" = mkOption {
          description = "";
          type = types.nullOr (types.listOf types.str);
        };
        "drop" = mkOption {
          description = "";
          type = types.nullOr (types.listOf types.str);
        };
      };

      config = {
        "add" = mkOverride 1002 null;
        "drop" = mkOverride 1002 null;
      };

    };
    "seaweed.seaweedfs.com.v1.SeaweedSpecWorkerContainerSecurityContextSeLinuxOptions" = {

      options = {
        "level" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "role" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "type" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "user" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
      };

      config = {
        "level" = mkOverride 1002 null;
        "role" = mkOverride 1002 null;
        "type" = mkOverride 1002 null;
        "user" = mkOverride 1002 null;
      };

    };
    "seaweed.seaweedfs.com.v1.SeaweedSpecWorkerContainerSecurityContextSeccompProfile" = {

      options = {
        "localhostProfile" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "type" = mkOption {
          description = "";
          type = types.str;
        };
      };

      config = {
        "localhostProfile" = mkOverride 1002 null;
      };

    };
    "seaweed.seaweedfs.com.v1.SeaweedSpecWorkerContainerSecurityContextWindowsOptions" = {

      options = {
        "gmsaCredentialSpec" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "gmsaCredentialSpecName" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "hostProcess" = mkOption {
          description = "";
          type = types.nullOr types.bool;
        };
        "runAsUserName" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
      };

      config = {
        "gmsaCredentialSpec" = mkOverride 1002 null;
        "gmsaCredentialSpecName" = mkOverride 1002 null;
        "hostProcess" = mkOverride 1002 null;
        "runAsUserName" = mkOverride 1002 null;
      };

    };
    "seaweed.seaweedfs.com.v1.SeaweedSpecWorkerEnv" = {

      options = {
        "name" = mkOption {
          description = "";
          type = types.str;
        };
        "value" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "valueFrom" = mkOption {
          description = "";
          type = types.nullOr (submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecWorkerEnvValueFrom");
        };
      };

      config = {
        "value" = mkOverride 1002 null;
        "valueFrom" = mkOverride 1002 null;
      };

    };
    "seaweed.seaweedfs.com.v1.SeaweedSpecWorkerEnvValueFrom" = {

      options = {
        "configMapKeyRef" = mkOption {
          description = "";
          type = types.nullOr (
            submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecWorkerEnvValueFromConfigMapKeyRef"
          );
        };
        "fieldRef" = mkOption {
          description = "";
          type = types.nullOr (submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecWorkerEnvValueFromFieldRef");
        };
        "fileKeyRef" = mkOption {
          description = "";
          type = types.nullOr (
            submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecWorkerEnvValueFromFileKeyRef"
          );
        };
        "resourceFieldRef" = mkOption {
          description = "";
          type = types.nullOr (
            submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecWorkerEnvValueFromResourceFieldRef"
          );
        };
        "secretKeyRef" = mkOption {
          description = "";
          type = types.nullOr (
            submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecWorkerEnvValueFromSecretKeyRef"
          );
        };
      };

      config = {
        "configMapKeyRef" = mkOverride 1002 null;
        "fieldRef" = mkOverride 1002 null;
        "fileKeyRef" = mkOverride 1002 null;
        "resourceFieldRef" = mkOverride 1002 null;
        "secretKeyRef" = mkOverride 1002 null;
      };

    };
    "seaweed.seaweedfs.com.v1.SeaweedSpecWorkerEnvValueFromConfigMapKeyRef" = {

      options = {
        "key" = mkOption {
          description = "";
          type = types.str;
        };
        "name" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "optional" = mkOption {
          description = "";
          type = types.nullOr types.bool;
        };
      };

      config = {
        "name" = mkOverride 1002 null;
        "optional" = mkOverride 1002 null;
      };

    };
    "seaweed.seaweedfs.com.v1.SeaweedSpecWorkerEnvValueFromFieldRef" = {

      options = {
        "apiVersion" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "fieldPath" = mkOption {
          description = "";
          type = types.str;
        };
      };

      config = {
        "apiVersion" = mkOverride 1002 null;
      };

    };
    "seaweed.seaweedfs.com.v1.SeaweedSpecWorkerEnvValueFromFileKeyRef" = {

      options = {
        "key" = mkOption {
          description = "";
          type = types.str;
        };
        "optional" = mkOption {
          description = "";
          type = types.nullOr types.bool;
        };
        "path" = mkOption {
          description = "";
          type = types.str;
        };
        "volumeName" = mkOption {
          description = "";
          type = types.str;
        };
      };

      config = {
        "optional" = mkOverride 1002 null;
      };

    };
    "seaweed.seaweedfs.com.v1.SeaweedSpecWorkerEnvValueFromResourceFieldRef" = {

      options = {
        "containerName" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "divisor" = mkOption {
          description = "";
          type = types.nullOr (types.either types.int types.str);
        };
        "resource" = mkOption {
          description = "";
          type = types.str;
        };
      };

      config = {
        "containerName" = mkOverride 1002 null;
        "divisor" = mkOverride 1002 null;
      };

    };
    "seaweed.seaweedfs.com.v1.SeaweedSpecWorkerEnvValueFromSecretKeyRef" = {

      options = {
        "key" = mkOption {
          description = "";
          type = types.str;
        };
        "name" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "optional" = mkOption {
          description = "";
          type = types.nullOr types.bool;
        };
      };

      config = {
        "name" = mkOverride 1002 null;
        "optional" = mkOverride 1002 null;
      };

    };
    "seaweed.seaweedfs.com.v1.SeaweedSpecWorkerImagePullSecrets" = {

      options = {
        "name" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
      };

      config = {
        "name" = mkOverride 1002 null;
      };

    };
    "seaweed.seaweedfs.com.v1.SeaweedSpecWorkerLivenessProbe" = {

      options = {
        "failureThreshold" = mkOption {
          description = "";
          type = types.nullOr types.int;
        };
        "initialDelaySeconds" = mkOption {
          description = "";
          type = types.nullOr types.int;
        };
        "periodSeconds" = mkOption {
          description = "";
          type = types.nullOr types.int;
        };
        "timeoutSeconds" = mkOption {
          description = "";
          type = types.nullOr types.int;
        };
      };

      config = {
        "failureThreshold" = mkOverride 1002 null;
        "initialDelaySeconds" = mkOverride 1002 null;
        "periodSeconds" = mkOverride 1002 null;
        "timeoutSeconds" = mkOverride 1002 null;
      };

    };
    "seaweed.seaweedfs.com.v1.SeaweedSpecWorkerPersistence" = {

      options = {
        "accessModes" = mkOption {
          description = "";
          type = types.nullOr (types.listOf types.str);
        };
        "annotations" = mkOption {
          description = "";
          type = types.nullOr (types.attrsOf types.str);
        };
        "dataSource" = mkOption {
          description = "";
          type = types.nullOr (submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecWorkerPersistenceDataSource");
        };
        "enabled" = mkOption {
          description = "";
          type = types.nullOr types.bool;
        };
        "existingClaim" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "labels" = mkOption {
          description = "";
          type = types.nullOr (types.attrsOf types.str);
        };
        "mountPath" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "resources" = mkOption {
          description = "";
          type = types.nullOr (submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecWorkerPersistenceResources");
        };
        "selector" = mkOption {
          description = "";
          type = types.nullOr (submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecWorkerPersistenceSelector");
        };
        "storageClassName" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "subPath" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "volumeMode" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "volumeName" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
      };

      config = {
        "accessModes" = mkOverride 1002 null;
        "annotations" = mkOverride 1002 null;
        "dataSource" = mkOverride 1002 null;
        "enabled" = mkOverride 1002 null;
        "existingClaim" = mkOverride 1002 null;
        "labels" = mkOverride 1002 null;
        "mountPath" = mkOverride 1002 null;
        "resources" = mkOverride 1002 null;
        "selector" = mkOverride 1002 null;
        "storageClassName" = mkOverride 1002 null;
        "subPath" = mkOverride 1002 null;
        "volumeMode" = mkOverride 1002 null;
        "volumeName" = mkOverride 1002 null;
      };

    };
    "seaweed.seaweedfs.com.v1.SeaweedSpecWorkerPersistenceDataSource" = {

      options = {
        "apiGroup" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "kind" = mkOption {
          description = "";
          type = types.str;
        };
        "name" = mkOption {
          description = "";
          type = types.str;
        };
      };

      config = {
        "apiGroup" = mkOverride 1002 null;
      };

    };
    "seaweed.seaweedfs.com.v1.SeaweedSpecWorkerPersistenceResources" = {

      options = {
        "limits" = mkOption {
          description = "";
          type = types.nullOr (types.attrsOf (types.either types.int types.str));
        };
        "requests" = mkOption {
          description = "";
          type = types.nullOr (types.attrsOf (types.either types.int types.str));
        };
      };

      config = {
        "limits" = mkOverride 1002 null;
        "requests" = mkOverride 1002 null;
      };

    };
    "seaweed.seaweedfs.com.v1.SeaweedSpecWorkerPersistenceSelector" = {

      options = {
        "matchExpressions" = mkOption {
          description = "";
          type = types.nullOr (
            types.listOf (
              submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecWorkerPersistenceSelectorMatchExpressions"
            )
          );
        };
        "matchLabels" = mkOption {
          description = "";
          type = types.nullOr (types.attrsOf types.str);
        };
      };

      config = {
        "matchExpressions" = mkOverride 1002 null;
        "matchLabels" = mkOverride 1002 null;
      };

    };
    "seaweed.seaweedfs.com.v1.SeaweedSpecWorkerPersistenceSelectorMatchExpressions" = {

      options = {
        "key" = mkOption {
          description = "";
          type = types.str;
        };
        "operator" = mkOption {
          description = "";
          type = types.str;
        };
        "values" = mkOption {
          description = "";
          type = types.nullOr (types.listOf types.str);
        };
      };

      config = {
        "values" = mkOverride 1002 null;
      };

    };
    "seaweed.seaweedfs.com.v1.SeaweedSpecWorkerPodSecurityContext" = {

      options = {
        "appArmorProfile" = mkOption {
          description = "";
          type = types.nullOr (
            submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecWorkerPodSecurityContextAppArmorProfile"
          );
        };
        "fsGroup" = mkOption {
          description = "";
          type = types.nullOr types.int;
        };
        "fsGroupChangePolicy" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "runAsGroup" = mkOption {
          description = "";
          type = types.nullOr types.int;
        };
        "runAsNonRoot" = mkOption {
          description = "";
          type = types.nullOr types.bool;
        };
        "runAsUser" = mkOption {
          description = "";
          type = types.nullOr types.int;
        };
        "seLinuxChangePolicy" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "seLinuxOptions" = mkOption {
          description = "";
          type = types.nullOr (
            submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecWorkerPodSecurityContextSeLinuxOptions"
          );
        };
        "seccompProfile" = mkOption {
          description = "";
          type = types.nullOr (
            submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecWorkerPodSecurityContextSeccompProfile"
          );
        };
        "supplementalGroups" = mkOption {
          description = "";
          type = types.nullOr (types.listOf types.int);
        };
        "supplementalGroupsPolicy" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "sysctls" = mkOption {
          description = "";
          type = types.nullOr (
            coerceAttrsOfSubmodulesToListByKey
              "seaweed.seaweedfs.com.v1.SeaweedSpecWorkerPodSecurityContextSysctls"
              "name"
              [ ]
          );
          apply = attrsToList;
        };
        "windowsOptions" = mkOption {
          description = "";
          type = types.nullOr (
            submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecWorkerPodSecurityContextWindowsOptions"
          );
        };
      };

      config = {
        "appArmorProfile" = mkOverride 1002 null;
        "fsGroup" = mkOverride 1002 null;
        "fsGroupChangePolicy" = mkOverride 1002 null;
        "runAsGroup" = mkOverride 1002 null;
        "runAsNonRoot" = mkOverride 1002 null;
        "runAsUser" = mkOverride 1002 null;
        "seLinuxChangePolicy" = mkOverride 1002 null;
        "seLinuxOptions" = mkOverride 1002 null;
        "seccompProfile" = mkOverride 1002 null;
        "supplementalGroups" = mkOverride 1002 null;
        "supplementalGroupsPolicy" = mkOverride 1002 null;
        "sysctls" = mkOverride 1002 null;
        "windowsOptions" = mkOverride 1002 null;
      };

    };
    "seaweed.seaweedfs.com.v1.SeaweedSpecWorkerPodSecurityContextAppArmorProfile" = {

      options = {
        "localhostProfile" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "type" = mkOption {
          description = "";
          type = types.str;
        };
      };

      config = {
        "localhostProfile" = mkOverride 1002 null;
      };

    };
    "seaweed.seaweedfs.com.v1.SeaweedSpecWorkerPodSecurityContextSeLinuxOptions" = {

      options = {
        "level" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "role" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "type" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "user" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
      };

      config = {
        "level" = mkOverride 1002 null;
        "role" = mkOverride 1002 null;
        "type" = mkOverride 1002 null;
        "user" = mkOverride 1002 null;
      };

    };
    "seaweed.seaweedfs.com.v1.SeaweedSpecWorkerPodSecurityContextSeccompProfile" = {

      options = {
        "localhostProfile" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "type" = mkOption {
          description = "";
          type = types.str;
        };
      };

      config = {
        "localhostProfile" = mkOverride 1002 null;
      };

    };
    "seaweed.seaweedfs.com.v1.SeaweedSpecWorkerPodSecurityContextSysctls" = {

      options = {
        "name" = mkOption {
          description = "";
          type = types.str;
        };
        "value" = mkOption {
          description = "";
          type = types.str;
        };
      };

      config = { };

    };
    "seaweed.seaweedfs.com.v1.SeaweedSpecWorkerPodSecurityContextWindowsOptions" = {

      options = {
        "gmsaCredentialSpec" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "gmsaCredentialSpecName" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "hostProcess" = mkOption {
          description = "";
          type = types.nullOr types.bool;
        };
        "runAsUserName" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
      };

      config = {
        "gmsaCredentialSpec" = mkOverride 1002 null;
        "gmsaCredentialSpecName" = mkOverride 1002 null;
        "hostProcess" = mkOverride 1002 null;
        "runAsUserName" = mkOverride 1002 null;
      };

    };
    "seaweed.seaweedfs.com.v1.SeaweedSpecWorkerReadinessProbe" = {

      options = {
        "failureThreshold" = mkOption {
          description = "";
          type = types.nullOr types.int;
        };
        "initialDelaySeconds" = mkOption {
          description = "";
          type = types.nullOr types.int;
        };
        "periodSeconds" = mkOption {
          description = "";
          type = types.nullOr types.int;
        };
        "successThreshold" = mkOption {
          description = "";
          type = types.nullOr types.int;
        };
        "timeoutSeconds" = mkOption {
          description = "";
          type = types.nullOr types.int;
        };
      };

      config = {
        "failureThreshold" = mkOverride 1002 null;
        "initialDelaySeconds" = mkOverride 1002 null;
        "periodSeconds" = mkOverride 1002 null;
        "successThreshold" = mkOverride 1002 null;
        "timeoutSeconds" = mkOverride 1002 null;
      };

    };
    "seaweed.seaweedfs.com.v1.SeaweedSpecWorkerTolerations" = {

      options = {
        "effect" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "key" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "operator" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "tolerationSeconds" = mkOption {
          description = "";
          type = types.nullOr types.int;
        };
        "value" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
      };

      config = {
        "effect" = mkOverride 1002 null;
        "key" = mkOverride 1002 null;
        "operator" = mkOverride 1002 null;
        "tolerationSeconds" = mkOverride 1002 null;
        "value" = mkOverride 1002 null;
      };

    };
    "seaweed.seaweedfs.com.v1.SeaweedSpecWorkerVolumeMounts" = {

      options = {
        "mountPath" = mkOption {
          description = "";
          type = types.str;
        };
        "mountPropagation" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "name" = mkOption {
          description = "";
          type = types.str;
        };
        "readOnly" = mkOption {
          description = "";
          type = types.nullOr types.bool;
        };
        "recursiveReadOnly" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "subPath" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "subPathExpr" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
      };

      config = {
        "mountPropagation" = mkOverride 1002 null;
        "readOnly" = mkOverride 1002 null;
        "recursiveReadOnly" = mkOverride 1002 null;
        "subPath" = mkOverride 1002 null;
        "subPathExpr" = mkOverride 1002 null;
      };

    };
    "seaweed.seaweedfs.com.v1.SeaweedSpecWorkerVolumes" = {

      options = {
        "awsElasticBlockStore" = mkOption {
          description = "";
          type = types.nullOr (
            submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecWorkerVolumesAwsElasticBlockStore"
          );
        };
        "azureDisk" = mkOption {
          description = "";
          type = types.nullOr (submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecWorkerVolumesAzureDisk");
        };
        "azureFile" = mkOption {
          description = "";
          type = types.nullOr (submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecWorkerVolumesAzureFile");
        };
        "cephfs" = mkOption {
          description = "";
          type = types.nullOr (submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecWorkerVolumesCephfs");
        };
        "cinder" = mkOption {
          description = "";
          type = types.nullOr (submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecWorkerVolumesCinder");
        };
        "configMap" = mkOption {
          description = "";
          type = types.nullOr (submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecWorkerVolumesConfigMap");
        };
        "csi" = mkOption {
          description = "";
          type = types.nullOr (submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecWorkerVolumesCsi");
        };
        "downwardAPI" = mkOption {
          description = "";
          type = types.nullOr (submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecWorkerVolumesDownwardAPI");
        };
        "emptyDir" = mkOption {
          description = "";
          type = types.nullOr (submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecWorkerVolumesEmptyDir");
        };
        "ephemeral" = mkOption {
          description = "";
          type = types.nullOr (submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecWorkerVolumesEphemeral");
        };
        "fc" = mkOption {
          description = "";
          type = types.nullOr (submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecWorkerVolumesFc");
        };
        "flexVolume" = mkOption {
          description = "";
          type = types.nullOr (submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecWorkerVolumesFlexVolume");
        };
        "flocker" = mkOption {
          description = "";
          type = types.nullOr (submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecWorkerVolumesFlocker");
        };
        "gcePersistentDisk" = mkOption {
          description = "";
          type = types.nullOr (
            submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecWorkerVolumesGcePersistentDisk"
          );
        };
        "gitRepo" = mkOption {
          description = "";
          type = types.nullOr (submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecWorkerVolumesGitRepo");
        };
        "glusterfs" = mkOption {
          description = "";
          type = types.nullOr (submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecWorkerVolumesGlusterfs");
        };
        "hostPath" = mkOption {
          description = "";
          type = types.nullOr (submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecWorkerVolumesHostPath");
        };
        "image" = mkOption {
          description = "";
          type = types.nullOr (submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecWorkerVolumesImage");
        };
        "iscsi" = mkOption {
          description = "";
          type = types.nullOr (submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecWorkerVolumesIscsi");
        };
        "name" = mkOption {
          description = "";
          type = types.str;
        };
        "nfs" = mkOption {
          description = "";
          type = types.nullOr (submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecWorkerVolumesNfs");
        };
        "persistentVolumeClaim" = mkOption {
          description = "";
          type = types.nullOr (
            submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecWorkerVolumesPersistentVolumeClaim"
          );
        };
        "photonPersistentDisk" = mkOption {
          description = "";
          type = types.nullOr (
            submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecWorkerVolumesPhotonPersistentDisk"
          );
        };
        "portworxVolume" = mkOption {
          description = "";
          type = types.nullOr (submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecWorkerVolumesPortworxVolume");
        };
        "projected" = mkOption {
          description = "";
          type = types.nullOr (submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecWorkerVolumesProjected");
        };
        "quobyte" = mkOption {
          description = "";
          type = types.nullOr (submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecWorkerVolumesQuobyte");
        };
        "rbd" = mkOption {
          description = "";
          type = types.nullOr (submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecWorkerVolumesRbd");
        };
        "scaleIO" = mkOption {
          description = "";
          type = types.nullOr (submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecWorkerVolumesScaleIO");
        };
        "secret" = mkOption {
          description = "";
          type = types.nullOr (submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecWorkerVolumesSecret");
        };
        "storageos" = mkOption {
          description = "";
          type = types.nullOr (submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecWorkerVolumesStorageos");
        };
        "vsphereVolume" = mkOption {
          description = "";
          type = types.nullOr (submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecWorkerVolumesVsphereVolume");
        };
      };

      config = {
        "awsElasticBlockStore" = mkOverride 1002 null;
        "azureDisk" = mkOverride 1002 null;
        "azureFile" = mkOverride 1002 null;
        "cephfs" = mkOverride 1002 null;
        "cinder" = mkOverride 1002 null;
        "configMap" = mkOverride 1002 null;
        "csi" = mkOverride 1002 null;
        "downwardAPI" = mkOverride 1002 null;
        "emptyDir" = mkOverride 1002 null;
        "ephemeral" = mkOverride 1002 null;
        "fc" = mkOverride 1002 null;
        "flexVolume" = mkOverride 1002 null;
        "flocker" = mkOverride 1002 null;
        "gcePersistentDisk" = mkOverride 1002 null;
        "gitRepo" = mkOverride 1002 null;
        "glusterfs" = mkOverride 1002 null;
        "hostPath" = mkOverride 1002 null;
        "image" = mkOverride 1002 null;
        "iscsi" = mkOverride 1002 null;
        "nfs" = mkOverride 1002 null;
        "persistentVolumeClaim" = mkOverride 1002 null;
        "photonPersistentDisk" = mkOverride 1002 null;
        "portworxVolume" = mkOverride 1002 null;
        "projected" = mkOverride 1002 null;
        "quobyte" = mkOverride 1002 null;
        "rbd" = mkOverride 1002 null;
        "scaleIO" = mkOverride 1002 null;
        "secret" = mkOverride 1002 null;
        "storageos" = mkOverride 1002 null;
        "vsphereVolume" = mkOverride 1002 null;
      };

    };
    "seaweed.seaweedfs.com.v1.SeaweedSpecWorkerVolumesAwsElasticBlockStore" = {

      options = {
        "fsType" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "partition" = mkOption {
          description = "";
          type = types.nullOr types.int;
        };
        "readOnly" = mkOption {
          description = "";
          type = types.nullOr types.bool;
        };
        "volumeID" = mkOption {
          description = "";
          type = types.str;
        };
      };

      config = {
        "fsType" = mkOverride 1002 null;
        "partition" = mkOverride 1002 null;
        "readOnly" = mkOverride 1002 null;
      };

    };
    "seaweed.seaweedfs.com.v1.SeaweedSpecWorkerVolumesAzureDisk" = {

      options = {
        "cachingMode" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "diskName" = mkOption {
          description = "";
          type = types.str;
        };
        "diskURI" = mkOption {
          description = "";
          type = types.str;
        };
        "fsType" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "kind" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "readOnly" = mkOption {
          description = "";
          type = types.nullOr types.bool;
        };
      };

      config = {
        "cachingMode" = mkOverride 1002 null;
        "fsType" = mkOverride 1002 null;
        "kind" = mkOverride 1002 null;
        "readOnly" = mkOverride 1002 null;
      };

    };
    "seaweed.seaweedfs.com.v1.SeaweedSpecWorkerVolumesAzureFile" = {

      options = {
        "readOnly" = mkOption {
          description = "";
          type = types.nullOr types.bool;
        };
        "secretName" = mkOption {
          description = "";
          type = types.str;
        };
        "shareName" = mkOption {
          description = "";
          type = types.str;
        };
      };

      config = {
        "readOnly" = mkOverride 1002 null;
      };

    };
    "seaweed.seaweedfs.com.v1.SeaweedSpecWorkerVolumesCephfs" = {

      options = {
        "monitors" = mkOption {
          description = "";
          type = types.listOf types.str;
        };
        "path" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "readOnly" = mkOption {
          description = "";
          type = types.nullOr types.bool;
        };
        "secretFile" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "secretRef" = mkOption {
          description = "";
          type = types.nullOr (
            submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecWorkerVolumesCephfsSecretRef"
          );
        };
        "user" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
      };

      config = {
        "path" = mkOverride 1002 null;
        "readOnly" = mkOverride 1002 null;
        "secretFile" = mkOverride 1002 null;
        "secretRef" = mkOverride 1002 null;
        "user" = mkOverride 1002 null;
      };

    };
    "seaweed.seaweedfs.com.v1.SeaweedSpecWorkerVolumesCephfsSecretRef" = {

      options = {
        "name" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
      };

      config = {
        "name" = mkOverride 1002 null;
      };

    };
    "seaweed.seaweedfs.com.v1.SeaweedSpecWorkerVolumesCinder" = {

      options = {
        "fsType" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "readOnly" = mkOption {
          description = "";
          type = types.nullOr types.bool;
        };
        "secretRef" = mkOption {
          description = "";
          type = types.nullOr (
            submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecWorkerVolumesCinderSecretRef"
          );
        };
        "volumeID" = mkOption {
          description = "";
          type = types.str;
        };
      };

      config = {
        "fsType" = mkOverride 1002 null;
        "readOnly" = mkOverride 1002 null;
        "secretRef" = mkOverride 1002 null;
      };

    };
    "seaweed.seaweedfs.com.v1.SeaweedSpecWorkerVolumesCinderSecretRef" = {

      options = {
        "name" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
      };

      config = {
        "name" = mkOverride 1002 null;
      };

    };
    "seaweed.seaweedfs.com.v1.SeaweedSpecWorkerVolumesConfigMap" = {

      options = {
        "defaultMode" = mkOption {
          description = "";
          type = types.nullOr types.int;
        };
        "items" = mkOption {
          description = "";
          type = types.nullOr (
            types.listOf (submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecWorkerVolumesConfigMapItems")
          );
        };
        "name" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "optional" = mkOption {
          description = "";
          type = types.nullOr types.bool;
        };
      };

      config = {
        "defaultMode" = mkOverride 1002 null;
        "items" = mkOverride 1002 null;
        "name" = mkOverride 1002 null;
        "optional" = mkOverride 1002 null;
      };

    };
    "seaweed.seaweedfs.com.v1.SeaweedSpecWorkerVolumesConfigMapItems" = {

      options = {
        "key" = mkOption {
          description = "";
          type = types.str;
        };
        "mode" = mkOption {
          description = "";
          type = types.nullOr types.int;
        };
        "path" = mkOption {
          description = "";
          type = types.str;
        };
      };

      config = {
        "mode" = mkOverride 1002 null;
      };

    };
    "seaweed.seaweedfs.com.v1.SeaweedSpecWorkerVolumesCsi" = {

      options = {
        "driver" = mkOption {
          description = "";
          type = types.str;
        };
        "fsType" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "nodePublishSecretRef" = mkOption {
          description = "";
          type = types.nullOr (
            submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecWorkerVolumesCsiNodePublishSecretRef"
          );
        };
        "readOnly" = mkOption {
          description = "";
          type = types.nullOr types.bool;
        };
        "volumeAttributes" = mkOption {
          description = "";
          type = types.nullOr (types.attrsOf types.str);
        };
      };

      config = {
        "fsType" = mkOverride 1002 null;
        "nodePublishSecretRef" = mkOverride 1002 null;
        "readOnly" = mkOverride 1002 null;
        "volumeAttributes" = mkOverride 1002 null;
      };

    };
    "seaweed.seaweedfs.com.v1.SeaweedSpecWorkerVolumesCsiNodePublishSecretRef" = {

      options = {
        "name" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
      };

      config = {
        "name" = mkOverride 1002 null;
      };

    };
    "seaweed.seaweedfs.com.v1.SeaweedSpecWorkerVolumesDownwardAPI" = {

      options = {
        "defaultMode" = mkOption {
          description = "";
          type = types.nullOr types.int;
        };
        "items" = mkOption {
          description = "";
          type = types.nullOr (
            types.listOf (submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecWorkerVolumesDownwardAPIItems")
          );
        };
      };

      config = {
        "defaultMode" = mkOverride 1002 null;
        "items" = mkOverride 1002 null;
      };

    };
    "seaweed.seaweedfs.com.v1.SeaweedSpecWorkerVolumesDownwardAPIItems" = {

      options = {
        "fieldRef" = mkOption {
          description = "";
          type = types.nullOr (
            submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecWorkerVolumesDownwardAPIItemsFieldRef"
          );
        };
        "mode" = mkOption {
          description = "";
          type = types.nullOr types.int;
        };
        "path" = mkOption {
          description = "";
          type = types.str;
        };
        "resourceFieldRef" = mkOption {
          description = "";
          type = types.nullOr (
            submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecWorkerVolumesDownwardAPIItemsResourceFieldRef"
          );
        };
      };

      config = {
        "fieldRef" = mkOverride 1002 null;
        "mode" = mkOverride 1002 null;
        "resourceFieldRef" = mkOverride 1002 null;
      };

    };
    "seaweed.seaweedfs.com.v1.SeaweedSpecWorkerVolumesDownwardAPIItemsFieldRef" = {

      options = {
        "apiVersion" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "fieldPath" = mkOption {
          description = "";
          type = types.str;
        };
      };

      config = {
        "apiVersion" = mkOverride 1002 null;
      };

    };
    "seaweed.seaweedfs.com.v1.SeaweedSpecWorkerVolumesDownwardAPIItemsResourceFieldRef" = {

      options = {
        "containerName" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "divisor" = mkOption {
          description = "";
          type = types.nullOr (types.either types.int types.str);
        };
        "resource" = mkOption {
          description = "";
          type = types.str;
        };
      };

      config = {
        "containerName" = mkOverride 1002 null;
        "divisor" = mkOverride 1002 null;
      };

    };
    "seaweed.seaweedfs.com.v1.SeaweedSpecWorkerVolumesEmptyDir" = {

      options = {
        "medium" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "sizeLimit" = mkOption {
          description = "";
          type = types.nullOr (types.either types.int types.str);
        };
      };

      config = {
        "medium" = mkOverride 1002 null;
        "sizeLimit" = mkOverride 1002 null;
      };

    };
    "seaweed.seaweedfs.com.v1.SeaweedSpecWorkerVolumesEphemeral" = {

      options = {
        "volumeClaimTemplate" = mkOption {
          description = "";
          type = types.nullOr (
            submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecWorkerVolumesEphemeralVolumeClaimTemplate"
          );
        };
      };

      config = {
        "volumeClaimTemplate" = mkOverride 1002 null;
      };

    };
    "seaweed.seaweedfs.com.v1.SeaweedSpecWorkerVolumesEphemeralVolumeClaimTemplate" = {

      options = {
        "metadata" = mkOption {
          description = "";
          type = types.nullOr types.attrs;
        };
        "spec" = mkOption {
          description = "";
          type = submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecWorkerVolumesEphemeralVolumeClaimTemplateSpec";
        };
      };

      config = {
        "metadata" = mkOverride 1002 null;
      };

    };
    "seaweed.seaweedfs.com.v1.SeaweedSpecWorkerVolumesEphemeralVolumeClaimTemplateSpec" = {

      options = {
        "accessModes" = mkOption {
          description = "";
          type = types.nullOr (types.listOf types.str);
        };
        "dataSource" = mkOption {
          description = "";
          type = types.nullOr (
            submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecWorkerVolumesEphemeralVolumeClaimTemplateSpecDataSource"
          );
        };
        "dataSourceRef" = mkOption {
          description = "";
          type = types.nullOr (
            submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecWorkerVolumesEphemeralVolumeClaimTemplateSpecDataSourceRef"
          );
        };
        "resources" = mkOption {
          description = "";
          type = types.nullOr (
            submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecWorkerVolumesEphemeralVolumeClaimTemplateSpecResources"
          );
        };
        "selector" = mkOption {
          description = "";
          type = types.nullOr (
            submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecWorkerVolumesEphemeralVolumeClaimTemplateSpecSelector"
          );
        };
        "storageClassName" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "volumeAttributesClassName" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "volumeMode" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "volumeName" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
      };

      config = {
        "accessModes" = mkOverride 1002 null;
        "dataSource" = mkOverride 1002 null;
        "dataSourceRef" = mkOverride 1002 null;
        "resources" = mkOverride 1002 null;
        "selector" = mkOverride 1002 null;
        "storageClassName" = mkOverride 1002 null;
        "volumeAttributesClassName" = mkOverride 1002 null;
        "volumeMode" = mkOverride 1002 null;
        "volumeName" = mkOverride 1002 null;
      };

    };
    "seaweed.seaweedfs.com.v1.SeaweedSpecWorkerVolumesEphemeralVolumeClaimTemplateSpecDataSource" = {

      options = {
        "apiGroup" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "kind" = mkOption {
          description = "";
          type = types.str;
        };
        "name" = mkOption {
          description = "";
          type = types.str;
        };
      };

      config = {
        "apiGroup" = mkOverride 1002 null;
      };

    };
    "seaweed.seaweedfs.com.v1.SeaweedSpecWorkerVolumesEphemeralVolumeClaimTemplateSpecDataSourceRef" = {

      options = {
        "apiGroup" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "kind" = mkOption {
          description = "";
          type = types.str;
        };
        "name" = mkOption {
          description = "";
          type = types.str;
        };
        "namespace" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
      };

      config = {
        "apiGroup" = mkOverride 1002 null;
        "namespace" = mkOverride 1002 null;
      };

    };
    "seaweed.seaweedfs.com.v1.SeaweedSpecWorkerVolumesEphemeralVolumeClaimTemplateSpecResources" = {

      options = {
        "limits" = mkOption {
          description = "";
          type = types.nullOr (types.attrsOf (types.either types.int types.str));
        };
        "requests" = mkOption {
          description = "";
          type = types.nullOr (types.attrsOf (types.either types.int types.str));
        };
      };

      config = {
        "limits" = mkOverride 1002 null;
        "requests" = mkOverride 1002 null;
      };

    };
    "seaweed.seaweedfs.com.v1.SeaweedSpecWorkerVolumesEphemeralVolumeClaimTemplateSpecSelector" = {

      options = {
        "matchExpressions" = mkOption {
          description = "";
          type = types.nullOr (
            types.listOf (
              submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecWorkerVolumesEphemeralVolumeClaimTemplateSpecSelectorMatchExpressions"
            )
          );
        };
        "matchLabels" = mkOption {
          description = "";
          type = types.nullOr (types.attrsOf types.str);
        };
      };

      config = {
        "matchExpressions" = mkOverride 1002 null;
        "matchLabels" = mkOverride 1002 null;
      };

    };
    "seaweed.seaweedfs.com.v1.SeaweedSpecWorkerVolumesEphemeralVolumeClaimTemplateSpecSelectorMatchExpressions" =
      {

        options = {
          "key" = mkOption {
            description = "";
            type = types.str;
          };
          "operator" = mkOption {
            description = "";
            type = types.str;
          };
          "values" = mkOption {
            description = "";
            type = types.nullOr (types.listOf types.str);
          };
        };

        config = {
          "values" = mkOverride 1002 null;
        };

      };
    "seaweed.seaweedfs.com.v1.SeaweedSpecWorkerVolumesFc" = {

      options = {
        "fsType" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "lun" = mkOption {
          description = "";
          type = types.nullOr types.int;
        };
        "readOnly" = mkOption {
          description = "";
          type = types.nullOr types.bool;
        };
        "targetWWNs" = mkOption {
          description = "";
          type = types.nullOr (types.listOf types.str);
        };
        "wwids" = mkOption {
          description = "";
          type = types.nullOr (types.listOf types.str);
        };
      };

      config = {
        "fsType" = mkOverride 1002 null;
        "lun" = mkOverride 1002 null;
        "readOnly" = mkOverride 1002 null;
        "targetWWNs" = mkOverride 1002 null;
        "wwids" = mkOverride 1002 null;
      };

    };
    "seaweed.seaweedfs.com.v1.SeaweedSpecWorkerVolumesFlexVolume" = {

      options = {
        "driver" = mkOption {
          description = "";
          type = types.str;
        };
        "fsType" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "options" = mkOption {
          description = "";
          type = types.nullOr (types.attrsOf types.str);
        };
        "readOnly" = mkOption {
          description = "";
          type = types.nullOr types.bool;
        };
        "secretRef" = mkOption {
          description = "";
          type = types.nullOr (
            submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecWorkerVolumesFlexVolumeSecretRef"
          );
        };
      };

      config = {
        "fsType" = mkOverride 1002 null;
        "options" = mkOverride 1002 null;
        "readOnly" = mkOverride 1002 null;
        "secretRef" = mkOverride 1002 null;
      };

    };
    "seaweed.seaweedfs.com.v1.SeaweedSpecWorkerVolumesFlexVolumeSecretRef" = {

      options = {
        "name" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
      };

      config = {
        "name" = mkOverride 1002 null;
      };

    };
    "seaweed.seaweedfs.com.v1.SeaweedSpecWorkerVolumesFlocker" = {

      options = {
        "datasetName" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "datasetUUID" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
      };

      config = {
        "datasetName" = mkOverride 1002 null;
        "datasetUUID" = mkOverride 1002 null;
      };

    };
    "seaweed.seaweedfs.com.v1.SeaweedSpecWorkerVolumesGcePersistentDisk" = {

      options = {
        "fsType" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "partition" = mkOption {
          description = "";
          type = types.nullOr types.int;
        };
        "pdName" = mkOption {
          description = "";
          type = types.str;
        };
        "readOnly" = mkOption {
          description = "";
          type = types.nullOr types.bool;
        };
      };

      config = {
        "fsType" = mkOverride 1002 null;
        "partition" = mkOverride 1002 null;
        "readOnly" = mkOverride 1002 null;
      };

    };
    "seaweed.seaweedfs.com.v1.SeaweedSpecWorkerVolumesGitRepo" = {

      options = {
        "directory" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "repository" = mkOption {
          description = "";
          type = types.str;
        };
        "revision" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
      };

      config = {
        "directory" = mkOverride 1002 null;
        "revision" = mkOverride 1002 null;
      };

    };
    "seaweed.seaweedfs.com.v1.SeaweedSpecWorkerVolumesGlusterfs" = {

      options = {
        "endpoints" = mkOption {
          description = "";
          type = types.str;
        };
        "path" = mkOption {
          description = "";
          type = types.str;
        };
        "readOnly" = mkOption {
          description = "";
          type = types.nullOr types.bool;
        };
      };

      config = {
        "readOnly" = mkOverride 1002 null;
      };

    };
    "seaweed.seaweedfs.com.v1.SeaweedSpecWorkerVolumesHostPath" = {

      options = {
        "path" = mkOption {
          description = "";
          type = types.str;
        };
        "type" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
      };

      config = {
        "type" = mkOverride 1002 null;
      };

    };
    "seaweed.seaweedfs.com.v1.SeaweedSpecWorkerVolumesImage" = {

      options = {
        "pullPolicy" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "reference" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
      };

      config = {
        "pullPolicy" = mkOverride 1002 null;
        "reference" = mkOverride 1002 null;
      };

    };
    "seaweed.seaweedfs.com.v1.SeaweedSpecWorkerVolumesIscsi" = {

      options = {
        "chapAuthDiscovery" = mkOption {
          description = "";
          type = types.nullOr types.bool;
        };
        "chapAuthSession" = mkOption {
          description = "";
          type = types.nullOr types.bool;
        };
        "fsType" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "initiatorName" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "iqn" = mkOption {
          description = "";
          type = types.str;
        };
        "iscsiInterface" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "lun" = mkOption {
          description = "";
          type = types.int;
        };
        "portals" = mkOption {
          description = "";
          type = types.nullOr (types.listOf types.str);
        };
        "readOnly" = mkOption {
          description = "";
          type = types.nullOr types.bool;
        };
        "secretRef" = mkOption {
          description = "";
          type = types.nullOr (submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecWorkerVolumesIscsiSecretRef");
        };
        "targetPortal" = mkOption {
          description = "";
          type = types.str;
        };
      };

      config = {
        "chapAuthDiscovery" = mkOverride 1002 null;
        "chapAuthSession" = mkOverride 1002 null;
        "fsType" = mkOverride 1002 null;
        "initiatorName" = mkOverride 1002 null;
        "iscsiInterface" = mkOverride 1002 null;
        "portals" = mkOverride 1002 null;
        "readOnly" = mkOverride 1002 null;
        "secretRef" = mkOverride 1002 null;
      };

    };
    "seaweed.seaweedfs.com.v1.SeaweedSpecWorkerVolumesIscsiSecretRef" = {

      options = {
        "name" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
      };

      config = {
        "name" = mkOverride 1002 null;
      };

    };
    "seaweed.seaweedfs.com.v1.SeaweedSpecWorkerVolumesNfs" = {

      options = {
        "path" = mkOption {
          description = "";
          type = types.str;
        };
        "readOnly" = mkOption {
          description = "";
          type = types.nullOr types.bool;
        };
        "server" = mkOption {
          description = "";
          type = types.str;
        };
      };

      config = {
        "readOnly" = mkOverride 1002 null;
      };

    };
    "seaweed.seaweedfs.com.v1.SeaweedSpecWorkerVolumesPersistentVolumeClaim" = {

      options = {
        "claimName" = mkOption {
          description = "";
          type = types.str;
        };
        "readOnly" = mkOption {
          description = "";
          type = types.nullOr types.bool;
        };
      };

      config = {
        "readOnly" = mkOverride 1002 null;
      };

    };
    "seaweed.seaweedfs.com.v1.SeaweedSpecWorkerVolumesPhotonPersistentDisk" = {

      options = {
        "fsType" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "pdID" = mkOption {
          description = "";
          type = types.str;
        };
      };

      config = {
        "fsType" = mkOverride 1002 null;
      };

    };
    "seaweed.seaweedfs.com.v1.SeaweedSpecWorkerVolumesPortworxVolume" = {

      options = {
        "fsType" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "readOnly" = mkOption {
          description = "";
          type = types.nullOr types.bool;
        };
        "volumeID" = mkOption {
          description = "";
          type = types.str;
        };
      };

      config = {
        "fsType" = mkOverride 1002 null;
        "readOnly" = mkOverride 1002 null;
      };

    };
    "seaweed.seaweedfs.com.v1.SeaweedSpecWorkerVolumesProjected" = {

      options = {
        "defaultMode" = mkOption {
          description = "";
          type = types.nullOr types.int;
        };
        "sources" = mkOption {
          description = "";
          type = types.nullOr (
            types.listOf (submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecWorkerVolumesProjectedSources")
          );
        };
      };

      config = {
        "defaultMode" = mkOverride 1002 null;
        "sources" = mkOverride 1002 null;
      };

    };
    "seaweed.seaweedfs.com.v1.SeaweedSpecWorkerVolumesProjectedSources" = {

      options = {
        "clusterTrustBundle" = mkOption {
          description = "";
          type = types.nullOr (
            submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecWorkerVolumesProjectedSourcesClusterTrustBundle"
          );
        };
        "configMap" = mkOption {
          description = "";
          type = types.nullOr (
            submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecWorkerVolumesProjectedSourcesConfigMap"
          );
        };
        "downwardAPI" = mkOption {
          description = "";
          type = types.nullOr (
            submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecWorkerVolumesProjectedSourcesDownwardAPI"
          );
        };
        "podCertificate" = mkOption {
          description = "";
          type = types.nullOr (
            submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecWorkerVolumesProjectedSourcesPodCertificate"
          );
        };
        "secret" = mkOption {
          description = "";
          type = types.nullOr (
            submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecWorkerVolumesProjectedSourcesSecret"
          );
        };
        "serviceAccountToken" = mkOption {
          description = "";
          type = types.nullOr (
            submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecWorkerVolumesProjectedSourcesServiceAccountToken"
          );
        };
      };

      config = {
        "clusterTrustBundle" = mkOverride 1002 null;
        "configMap" = mkOverride 1002 null;
        "downwardAPI" = mkOverride 1002 null;
        "podCertificate" = mkOverride 1002 null;
        "secret" = mkOverride 1002 null;
        "serviceAccountToken" = mkOverride 1002 null;
      };

    };
    "seaweed.seaweedfs.com.v1.SeaweedSpecWorkerVolumesProjectedSourcesClusterTrustBundle" = {

      options = {
        "labelSelector" = mkOption {
          description = "";
          type = types.nullOr (
            submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecWorkerVolumesProjectedSourcesClusterTrustBundleLabelSelector"
          );
        };
        "name" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "optional" = mkOption {
          description = "";
          type = types.nullOr types.bool;
        };
        "path" = mkOption {
          description = "";
          type = types.str;
        };
        "signerName" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
      };

      config = {
        "labelSelector" = mkOverride 1002 null;
        "name" = mkOverride 1002 null;
        "optional" = mkOverride 1002 null;
        "signerName" = mkOverride 1002 null;
      };

    };
    "seaweed.seaweedfs.com.v1.SeaweedSpecWorkerVolumesProjectedSourcesClusterTrustBundleLabelSelector" =
      {

        options = {
          "matchExpressions" = mkOption {
            description = "";
            type = types.nullOr (
              types.listOf (
                submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecWorkerVolumesProjectedSourcesClusterTrustBundleLabelSelectorMatchExpressions"
              )
            );
          };
          "matchLabels" = mkOption {
            description = "";
            type = types.nullOr (types.attrsOf types.str);
          };
        };

        config = {
          "matchExpressions" = mkOverride 1002 null;
          "matchLabels" = mkOverride 1002 null;
        };

      };
    "seaweed.seaweedfs.com.v1.SeaweedSpecWorkerVolumesProjectedSourcesClusterTrustBundleLabelSelectorMatchExpressions" =
      {

        options = {
          "key" = mkOption {
            description = "";
            type = types.str;
          };
          "operator" = mkOption {
            description = "";
            type = types.str;
          };
          "values" = mkOption {
            description = "";
            type = types.nullOr (types.listOf types.str);
          };
        };

        config = {
          "values" = mkOverride 1002 null;
        };

      };
    "seaweed.seaweedfs.com.v1.SeaweedSpecWorkerVolumesProjectedSourcesConfigMap" = {

      options = {
        "items" = mkOption {
          description = "";
          type = types.nullOr (
            types.listOf (
              submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecWorkerVolumesProjectedSourcesConfigMapItems"
            )
          );
        };
        "name" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "optional" = mkOption {
          description = "";
          type = types.nullOr types.bool;
        };
      };

      config = {
        "items" = mkOverride 1002 null;
        "name" = mkOverride 1002 null;
        "optional" = mkOverride 1002 null;
      };

    };
    "seaweed.seaweedfs.com.v1.SeaweedSpecWorkerVolumesProjectedSourcesConfigMapItems" = {

      options = {
        "key" = mkOption {
          description = "";
          type = types.str;
        };
        "mode" = mkOption {
          description = "";
          type = types.nullOr types.int;
        };
        "path" = mkOption {
          description = "";
          type = types.str;
        };
      };

      config = {
        "mode" = mkOverride 1002 null;
      };

    };
    "seaweed.seaweedfs.com.v1.SeaweedSpecWorkerVolumesProjectedSourcesDownwardAPI" = {

      options = {
        "items" = mkOption {
          description = "";
          type = types.nullOr (
            types.listOf (
              submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecWorkerVolumesProjectedSourcesDownwardAPIItems"
            )
          );
        };
      };

      config = {
        "items" = mkOverride 1002 null;
      };

    };
    "seaweed.seaweedfs.com.v1.SeaweedSpecWorkerVolumesProjectedSourcesDownwardAPIItems" = {

      options = {
        "fieldRef" = mkOption {
          description = "";
          type = types.nullOr (
            submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecWorkerVolumesProjectedSourcesDownwardAPIItemsFieldRef"
          );
        };
        "mode" = mkOption {
          description = "";
          type = types.nullOr types.int;
        };
        "path" = mkOption {
          description = "";
          type = types.str;
        };
        "resourceFieldRef" = mkOption {
          description = "";
          type = types.nullOr (
            submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecWorkerVolumesProjectedSourcesDownwardAPIItemsResourceFieldRef"
          );
        };
      };

      config = {
        "fieldRef" = mkOverride 1002 null;
        "mode" = mkOverride 1002 null;
        "resourceFieldRef" = mkOverride 1002 null;
      };

    };
    "seaweed.seaweedfs.com.v1.SeaweedSpecWorkerVolumesProjectedSourcesDownwardAPIItemsFieldRef" = {

      options = {
        "apiVersion" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "fieldPath" = mkOption {
          description = "";
          type = types.str;
        };
      };

      config = {
        "apiVersion" = mkOverride 1002 null;
      };

    };
    "seaweed.seaweedfs.com.v1.SeaweedSpecWorkerVolumesProjectedSourcesDownwardAPIItemsResourceFieldRef" =
      {

        options = {
          "containerName" = mkOption {
            description = "";
            type = types.nullOr types.str;
          };
          "divisor" = mkOption {
            description = "";
            type = types.nullOr (types.either types.int types.str);
          };
          "resource" = mkOption {
            description = "";
            type = types.str;
          };
        };

        config = {
          "containerName" = mkOverride 1002 null;
          "divisor" = mkOverride 1002 null;
        };

      };
    "seaweed.seaweedfs.com.v1.SeaweedSpecWorkerVolumesProjectedSourcesPodCertificate" = {

      options = {
        "certificateChainPath" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "credentialBundlePath" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "keyPath" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "keyType" = mkOption {
          description = "";
          type = types.str;
        };
        "maxExpirationSeconds" = mkOption {
          description = "";
          type = types.nullOr types.int;
        };
        "signerName" = mkOption {
          description = "";
          type = types.str;
        };
        "userAnnotations" = mkOption {
          description = "";
          type = types.nullOr (types.attrsOf types.str);
        };
      };

      config = {
        "certificateChainPath" = mkOverride 1002 null;
        "credentialBundlePath" = mkOverride 1002 null;
        "keyPath" = mkOverride 1002 null;
        "maxExpirationSeconds" = mkOverride 1002 null;
        "userAnnotations" = mkOverride 1002 null;
      };

    };
    "seaweed.seaweedfs.com.v1.SeaweedSpecWorkerVolumesProjectedSourcesSecret" = {

      options = {
        "items" = mkOption {
          description = "";
          type = types.nullOr (
            types.listOf (
              submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecWorkerVolumesProjectedSourcesSecretItems"
            )
          );
        };
        "name" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "optional" = mkOption {
          description = "";
          type = types.nullOr types.bool;
        };
      };

      config = {
        "items" = mkOverride 1002 null;
        "name" = mkOverride 1002 null;
        "optional" = mkOverride 1002 null;
      };

    };
    "seaweed.seaweedfs.com.v1.SeaweedSpecWorkerVolumesProjectedSourcesSecretItems" = {

      options = {
        "key" = mkOption {
          description = "";
          type = types.str;
        };
        "mode" = mkOption {
          description = "";
          type = types.nullOr types.int;
        };
        "path" = mkOption {
          description = "";
          type = types.str;
        };
      };

      config = {
        "mode" = mkOverride 1002 null;
      };

    };
    "seaweed.seaweedfs.com.v1.SeaweedSpecWorkerVolumesProjectedSourcesServiceAccountToken" = {

      options = {
        "audience" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "expirationSeconds" = mkOption {
          description = "";
          type = types.nullOr types.int;
        };
        "path" = mkOption {
          description = "";
          type = types.str;
        };
      };

      config = {
        "audience" = mkOverride 1002 null;
        "expirationSeconds" = mkOverride 1002 null;
      };

    };
    "seaweed.seaweedfs.com.v1.SeaweedSpecWorkerVolumesQuobyte" = {

      options = {
        "group" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "readOnly" = mkOption {
          description = "";
          type = types.nullOr types.bool;
        };
        "registry" = mkOption {
          description = "";
          type = types.str;
        };
        "tenant" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "user" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "volume" = mkOption {
          description = "";
          type = types.str;
        };
      };

      config = {
        "group" = mkOverride 1002 null;
        "readOnly" = mkOverride 1002 null;
        "tenant" = mkOverride 1002 null;
        "user" = mkOverride 1002 null;
      };

    };
    "seaweed.seaweedfs.com.v1.SeaweedSpecWorkerVolumesRbd" = {

      options = {
        "fsType" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "image" = mkOption {
          description = "";
          type = types.str;
        };
        "keyring" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "monitors" = mkOption {
          description = "";
          type = types.listOf types.str;
        };
        "pool" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "readOnly" = mkOption {
          description = "";
          type = types.nullOr types.bool;
        };
        "secretRef" = mkOption {
          description = "";
          type = types.nullOr (submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecWorkerVolumesRbdSecretRef");
        };
        "user" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
      };

      config = {
        "fsType" = mkOverride 1002 null;
        "keyring" = mkOverride 1002 null;
        "pool" = mkOverride 1002 null;
        "readOnly" = mkOverride 1002 null;
        "secretRef" = mkOverride 1002 null;
        "user" = mkOverride 1002 null;
      };

    };
    "seaweed.seaweedfs.com.v1.SeaweedSpecWorkerVolumesRbdSecretRef" = {

      options = {
        "name" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
      };

      config = {
        "name" = mkOverride 1002 null;
      };

    };
    "seaweed.seaweedfs.com.v1.SeaweedSpecWorkerVolumesScaleIO" = {

      options = {
        "fsType" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "gateway" = mkOption {
          description = "";
          type = types.str;
        };
        "protectionDomain" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "readOnly" = mkOption {
          description = "";
          type = types.nullOr types.bool;
        };
        "secretRef" = mkOption {
          description = "";
          type = submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecWorkerVolumesScaleIOSecretRef";
        };
        "sslEnabled" = mkOption {
          description = "";
          type = types.nullOr types.bool;
        };
        "storageMode" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "storagePool" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "system" = mkOption {
          description = "";
          type = types.str;
        };
        "volumeName" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
      };

      config = {
        "fsType" = mkOverride 1002 null;
        "protectionDomain" = mkOverride 1002 null;
        "readOnly" = mkOverride 1002 null;
        "sslEnabled" = mkOverride 1002 null;
        "storageMode" = mkOverride 1002 null;
        "storagePool" = mkOverride 1002 null;
        "volumeName" = mkOverride 1002 null;
      };

    };
    "seaweed.seaweedfs.com.v1.SeaweedSpecWorkerVolumesScaleIOSecretRef" = {

      options = {
        "name" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
      };

      config = {
        "name" = mkOverride 1002 null;
      };

    };
    "seaweed.seaweedfs.com.v1.SeaweedSpecWorkerVolumesSecret" = {

      options = {
        "defaultMode" = mkOption {
          description = "";
          type = types.nullOr types.int;
        };
        "items" = mkOption {
          description = "";
          type = types.nullOr (
            types.listOf (submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecWorkerVolumesSecretItems")
          );
        };
        "optional" = mkOption {
          description = "";
          type = types.nullOr types.bool;
        };
        "secretName" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
      };

      config = {
        "defaultMode" = mkOverride 1002 null;
        "items" = mkOverride 1002 null;
        "optional" = mkOverride 1002 null;
        "secretName" = mkOverride 1002 null;
      };

    };
    "seaweed.seaweedfs.com.v1.SeaweedSpecWorkerVolumesSecretItems" = {

      options = {
        "key" = mkOption {
          description = "";
          type = types.str;
        };
        "mode" = mkOption {
          description = "";
          type = types.nullOr types.int;
        };
        "path" = mkOption {
          description = "";
          type = types.str;
        };
      };

      config = {
        "mode" = mkOverride 1002 null;
      };

    };
    "seaweed.seaweedfs.com.v1.SeaweedSpecWorkerVolumesStorageos" = {

      options = {
        "fsType" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "readOnly" = mkOption {
          description = "";
          type = types.nullOr types.bool;
        };
        "secretRef" = mkOption {
          description = "";
          type = types.nullOr (
            submoduleOf "seaweed.seaweedfs.com.v1.SeaweedSpecWorkerVolumesStorageosSecretRef"
          );
        };
        "volumeName" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "volumeNamespace" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
      };

      config = {
        "fsType" = mkOverride 1002 null;
        "readOnly" = mkOverride 1002 null;
        "secretRef" = mkOverride 1002 null;
        "volumeName" = mkOverride 1002 null;
        "volumeNamespace" = mkOverride 1002 null;
      };

    };
    "seaweed.seaweedfs.com.v1.SeaweedSpecWorkerVolumesStorageosSecretRef" = {

      options = {
        "name" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
      };

      config = {
        "name" = mkOverride 1002 null;
      };

    };
    "seaweed.seaweedfs.com.v1.SeaweedSpecWorkerVolumesVsphereVolume" = {

      options = {
        "fsType" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "storagePolicyID" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "storagePolicyName" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "volumePath" = mkOption {
          description = "";
          type = types.str;
        };
      };

      config = {
        "fsType" = mkOverride 1002 null;
        "storagePolicyID" = mkOverride 1002 null;
        "storagePolicyName" = mkOverride 1002 null;
      };

    };
    "seaweed.seaweedfs.com.v1.SeaweedStatus" = {

      options = {
        "admin" = mkOption {
          description = "";
          type = types.nullOr (submoduleOf "seaweed.seaweedfs.com.v1.SeaweedStatusAdmin");
        };
        "backupMirrors" = mkOption {
          description = "";
          type = types.nullOr (
            types.listOf (submoduleOf "seaweed.seaweedfs.com.v1.SeaweedStatusBackupMirrors")
          );
        };
        "conditions" = mkOption {
          description = "";
          type = types.nullOr (types.listOf (submoduleOf "seaweed.seaweedfs.com.v1.SeaweedStatusConditions"));
        };
        "filer" = mkOption {
          description = "";
          type = types.nullOr (submoduleOf "seaweed.seaweedfs.com.v1.SeaweedStatusFiler");
        };
        "master" = mkOption {
          description = "";
          type = types.nullOr (submoduleOf "seaweed.seaweedfs.com.v1.SeaweedStatusMaster");
        };
        "observedGeneration" = mkOption {
          description = "";
          type = types.nullOr types.int;
        };
        "s3" = mkOption {
          description = "";
          type = types.nullOr (submoduleOf "seaweed.seaweedfs.com.v1.SeaweedStatusS3");
        };
        "sftp" = mkOption {
          description = "";
          type = types.nullOr (submoduleOf "seaweed.seaweedfs.com.v1.SeaweedStatusSftp");
        };
        "volume" = mkOption {
          description = "";
          type = types.nullOr (submoduleOf "seaweed.seaweedfs.com.v1.SeaweedStatusVolume");
        };
        "worker" = mkOption {
          description = "";
          type = types.nullOr (submoduleOf "seaweed.seaweedfs.com.v1.SeaweedStatusWorker");
        };
      };

      config = {
        "admin" = mkOverride 1002 null;
        "backupMirrors" = mkOverride 1002 null;
        "conditions" = mkOverride 1002 null;
        "filer" = mkOverride 1002 null;
        "master" = mkOverride 1002 null;
        "observedGeneration" = mkOverride 1002 null;
        "s3" = mkOverride 1002 null;
        "sftp" = mkOverride 1002 null;
        "volume" = mkOverride 1002 null;
        "worker" = mkOverride 1002 null;
      };

    };
    "seaweed.seaweedfs.com.v1.SeaweedStatusAdmin" = {

      options = {
        "readyReplicas" = mkOption {
          description = "";
          type = types.nullOr types.int;
        };
        "replicas" = mkOption {
          description = "";
          type = types.nullOr types.int;
        };
      };

      config = {
        "readyReplicas" = mkOverride 1002 null;
        "replicas" = mkOverride 1002 null;
      };

    };
    "seaweed.seaweedfs.com.v1.SeaweedStatusBackupMirrors" = {

      options = {
        "deploymentName" = mkOption {
          description = "";
          type = types.nullOr types.str;
        };
        "ready" = mkOption {
          description = "";
          type = types.nullOr types.bool;
        };
        "storageName" = mkOption {
          description = "";
          type = types.str;
        };
      };

      config = {
        "deploymentName" = mkOverride 1002 null;
        "ready" = mkOverride 1002 null;
      };

    };
    "seaweed.seaweedfs.com.v1.SeaweedStatusConditions" = {

      options = {
        "lastTransitionTime" = mkOption {
          description = "";
          type = types.str;
        };
        "message" = mkOption {
          description = "";
          type = types.str;
        };
        "observedGeneration" = mkOption {
          description = "";
          type = types.nullOr types.int;
        };
        "reason" = mkOption {
          description = "";
          type = types.str;
        };
        "status" = mkOption {
          description = "";
          type = types.str;
        };
        "type" = mkOption {
          description = "";
          type = types.str;
        };
      };

      config = {
        "observedGeneration" = mkOverride 1002 null;
      };

    };
    "seaweed.seaweedfs.com.v1.SeaweedStatusFiler" = {

      options = {
        "readyReplicas" = mkOption {
          description = "";
          type = types.nullOr types.int;
        };
        "replicas" = mkOption {
          description = "";
          type = types.nullOr types.int;
        };
      };

      config = {
        "readyReplicas" = mkOverride 1002 null;
        "replicas" = mkOverride 1002 null;
      };

    };
    "seaweed.seaweedfs.com.v1.SeaweedStatusMaster" = {

      options = {
        "readyReplicas" = mkOption {
          description = "";
          type = types.nullOr types.int;
        };
        "replicas" = mkOption {
          description = "";
          type = types.nullOr types.int;
        };
      };

      config = {
        "readyReplicas" = mkOverride 1002 null;
        "replicas" = mkOverride 1002 null;
      };

    };
    "seaweed.seaweedfs.com.v1.SeaweedStatusS3" = {

      options = {
        "readyReplicas" = mkOption {
          description = "";
          type = types.nullOr types.int;
        };
        "replicas" = mkOption {
          description = "";
          type = types.nullOr types.int;
        };
      };

      config = {
        "readyReplicas" = mkOverride 1002 null;
        "replicas" = mkOverride 1002 null;
      };

    };
    "seaweed.seaweedfs.com.v1.SeaweedStatusSftp" = {

      options = {
        "readyReplicas" = mkOption {
          description = "";
          type = types.nullOr types.int;
        };
        "replicas" = mkOption {
          description = "";
          type = types.nullOr types.int;
        };
      };

      config = {
        "readyReplicas" = mkOverride 1002 null;
        "replicas" = mkOverride 1002 null;
      };

    };
    "seaweed.seaweedfs.com.v1.SeaweedStatusVolume" = {

      options = {
        "readyReplicas" = mkOption {
          description = "";
          type = types.nullOr types.int;
        };
        "replicas" = mkOption {
          description = "";
          type = types.nullOr types.int;
        };
      };

      config = {
        "readyReplicas" = mkOverride 1002 null;
        "replicas" = mkOverride 1002 null;
      };

    };
    "seaweed.seaweedfs.com.v1.SeaweedStatusWorker" = {

      options = {
        "readyReplicas" = mkOption {
          description = "";
          type = types.nullOr types.int;
        };
        "replicas" = mkOption {
          description = "";
          type = types.nullOr types.int;
        };
      };

      config = {
        "readyReplicas" = mkOverride 1002 null;
        "replicas" = mkOverride 1002 null;
      };

    };

  };
in
{
  # all resource versions
  options = {
    resources = {
      "seaweed.seaweedfs.com"."v1"."AdminScript" = mkOption {
        description = "";
        type = types.attrsOf (
          submoduleForDefinition "seaweed.seaweedfs.com.v1.AdminScript" "adminscripts" "AdminScript"
            "seaweed.seaweedfs.com"
            "v1"
        );
        default = { };
      };
      "seaweed.seaweedfs.com"."v1"."Bucket" = mkOption {
        description = "";
        type = types.attrsOf (
          submoduleForDefinition "seaweed.seaweedfs.com.v1.Bucket" "buckets" "Bucket" "seaweed.seaweedfs.com"
            "v1"
        );
        default = { };
      };
      "seaweed.seaweedfs.com"."v1"."BucketLifecyclePolicy" = mkOption {
        description = "";
        type = types.attrsOf (
          submoduleForDefinition "seaweed.seaweedfs.com.v1.BucketLifecyclePolicy" "bucketlifecyclepolicies"
            "BucketLifecyclePolicy"
            "seaweed.seaweedfs.com"
            "v1"
        );
        default = { };
      };
      "seaweed.seaweedfs.com"."v1"."ResourceReferenceGrant" = mkOption {
        description = "";
        type = types.attrsOf (
          submoduleForDefinition "seaweed.seaweedfs.com.v1.ResourceReferenceGrant" "resourcereferencegrants"
            "ResourceReferenceGrant"
            "seaweed.seaweedfs.com"
            "v1"
        );
        default = { };
      };
      "seaweed.seaweedfs.com"."v1"."S3Credentials" = mkOption {
        description = "";
        type = types.attrsOf (
          submoduleForDefinition "seaweed.seaweedfs.com.v1.S3Credentials" "s3credentials" "S3Credentials"
            "seaweed.seaweedfs.com"
            "v1"
        );
        default = { };
      };
      "seaweed.seaweedfs.com"."v1"."S3Identity" = mkOption {
        description = "";
        type = types.attrsOf (
          submoduleForDefinition "seaweed.seaweedfs.com.v1.S3Identity" "s3identities" "S3Identity"
            "seaweed.seaweedfs.com"
            "v1"
        );
        default = { };
      };
      "seaweed.seaweedfs.com"."v1"."S3OIDCProvider" = mkOption {
        description = "";
        type = types.attrsOf (
          submoduleForDefinition "seaweed.seaweedfs.com.v1.S3OIDCProvider" "s3oidcproviders" "S3OIDCProvider"
            "seaweed.seaweedfs.com"
            "v1"
        );
        default = { };
      };
      "seaweed.seaweedfs.com"."v1"."S3Policy" = mkOption {
        description = "";
        type = types.attrsOf (
          submoduleForDefinition "seaweed.seaweedfs.com.v1.S3Policy" "s3policies" "S3Policy"
            "seaweed.seaweedfs.com"
            "v1"
        );
        default = { };
      };
      "seaweed.seaweedfs.com"."v1"."S3PolicyBinding" = mkOption {
        description = "";
        type = types.attrsOf (
          submoduleForDefinition "seaweed.seaweedfs.com.v1.S3PolicyBinding" "s3policybindings"
            "S3PolicyBinding"
            "seaweed.seaweedfs.com"
            "v1"
        );
        default = { };
      };
      "seaweed.seaweedfs.com"."v1"."Seaweed" = mkOption {
        description = "";
        type = types.attrsOf (
          submoduleForDefinition "seaweed.seaweedfs.com.v1.Seaweed" "seaweeds" "Seaweed"
            "seaweed.seaweedfs.com"
            "v1"
        );
        default = { };
      };
      "seaweed.seaweedfs.com"."v1"."SeaweedBackup" = mkOption {
        description = "";
        type = types.attrsOf (
          submoduleForDefinition "seaweed.seaweedfs.com.v1.SeaweedBackup" "seaweedbackups" "SeaweedBackup"
            "seaweed.seaweedfs.com"
            "v1"
        );
        default = { };
      };
      "seaweed.seaweedfs.com"."v1"."SeaweedCSIDriver" = mkOption {
        description = "";
        type = types.attrsOf (
          submoduleForDefinition "seaweed.seaweedfs.com.v1.SeaweedCSIDriver" "seaweedcsidrivers"
            "SeaweedCSIDriver"
            "seaweed.seaweedfs.com"
            "v1"
        );
        default = { };
      };
      "seaweed.seaweedfs.com"."v1"."SeaweedRestore" = mkOption {
        description = "";
        type = types.attrsOf (
          submoduleForDefinition "seaweed.seaweedfs.com.v1.SeaweedRestore" "seaweedrestores" "SeaweedRestore"
            "seaweed.seaweedfs.com"
            "v1"
        );
        default = { };
      };

    }
    // {
      "adminScripts" = mkOption {
        description = "";
        type = types.attrsOf (
          submoduleForDefinition "seaweed.seaweedfs.com.v1.AdminScript" "adminscripts" "AdminScript"
            "seaweed.seaweedfs.com"
            "v1"
        );
        default = { };
      };
      "buckets" = mkOption {
        description = "";
        type = types.attrsOf (
          submoduleForDefinition "seaweed.seaweedfs.com.v1.Bucket" "buckets" "Bucket" "seaweed.seaweedfs.com"
            "v1"
        );
        default = { };
      };
      "bucketLifecyclePolicies" = mkOption {
        description = "";
        type = types.attrsOf (
          submoduleForDefinition "seaweed.seaweedfs.com.v1.BucketLifecyclePolicy" "bucketlifecyclepolicies"
            "BucketLifecyclePolicy"
            "seaweed.seaweedfs.com"
            "v1"
        );
        default = { };
      };
      "resourceReferenceGrants" = mkOption {
        description = "";
        type = types.attrsOf (
          submoduleForDefinition "seaweed.seaweedfs.com.v1.ResourceReferenceGrant" "resourcereferencegrants"
            "ResourceReferenceGrant"
            "seaweed.seaweedfs.com"
            "v1"
        );
        default = { };
      };
      "s3Credentials" = mkOption {
        description = "";
        type = types.attrsOf (
          submoduleForDefinition "seaweed.seaweedfs.com.v1.S3Credentials" "s3credentials" "S3Credentials"
            "seaweed.seaweedfs.com"
            "v1"
        );
        default = { };
      };
      "s3Identities" = mkOption {
        description = "";
        type = types.attrsOf (
          submoduleForDefinition "seaweed.seaweedfs.com.v1.S3Identity" "s3identities" "S3Identity"
            "seaweed.seaweedfs.com"
            "v1"
        );
        default = { };
      };
      "s3OIDCProviders" = mkOption {
        description = "";
        type = types.attrsOf (
          submoduleForDefinition "seaweed.seaweedfs.com.v1.S3OIDCProvider" "s3oidcproviders" "S3OIDCProvider"
            "seaweed.seaweedfs.com"
            "v1"
        );
        default = { };
      };
      "s3Policies" = mkOption {
        description = "";
        type = types.attrsOf (
          submoduleForDefinition "seaweed.seaweedfs.com.v1.S3Policy" "s3policies" "S3Policy"
            "seaweed.seaweedfs.com"
            "v1"
        );
        default = { };
      };
      "s3PolicyBindings" = mkOption {
        description = "";
        type = types.attrsOf (
          submoduleForDefinition "seaweed.seaweedfs.com.v1.S3PolicyBinding" "s3policybindings"
            "S3PolicyBinding"
            "seaweed.seaweedfs.com"
            "v1"
        );
        default = { };
      };
      "seaweeds" = mkOption {
        description = "";
        type = types.attrsOf (
          submoduleForDefinition "seaweed.seaweedfs.com.v1.Seaweed" "seaweeds" "Seaweed"
            "seaweed.seaweedfs.com"
            "v1"
        );
        default = { };
      };
      "seaweedBackups" = mkOption {
        description = "";
        type = types.attrsOf (
          submoduleForDefinition "seaweed.seaweedfs.com.v1.SeaweedBackup" "seaweedbackups" "SeaweedBackup"
            "seaweed.seaweedfs.com"
            "v1"
        );
        default = { };
      };
      "seaweedCSIDrivers" = mkOption {
        description = "";
        type = types.attrsOf (
          submoduleForDefinition "seaweed.seaweedfs.com.v1.SeaweedCSIDriver" "seaweedcsidrivers"
            "SeaweedCSIDriver"
            "seaweed.seaweedfs.com"
            "v1"
        );
        default = { };
      };
      "seaweedRestores" = mkOption {
        description = "";
        type = types.attrsOf (
          submoduleForDefinition "seaweed.seaweedfs.com.v1.SeaweedRestore" "seaweedrestores" "SeaweedRestore"
            "seaweed.seaweedfs.com"
            "v1"
        );
        default = { };
      };

    };
  };

  config = {
    # expose resource definitions
    inherit definitions;

    # register resource types
    types = [
      {
        name = "adminscripts";
        group = "seaweed.seaweedfs.com";
        version = "v1";
        kind = "AdminScript";
        attrName = "adminScripts";
      }
      {
        name = "buckets";
        group = "seaweed.seaweedfs.com";
        version = "v1";
        kind = "Bucket";
        attrName = "buckets";
      }
      {
        name = "bucketlifecyclepolicies";
        group = "seaweed.seaweedfs.com";
        version = "v1";
        kind = "BucketLifecyclePolicy";
        attrName = "bucketLifecyclePolicies";
      }
      {
        name = "resourcereferencegrants";
        group = "seaweed.seaweedfs.com";
        version = "v1";
        kind = "ResourceReferenceGrant";
        attrName = "resourceReferenceGrants";
      }
      {
        name = "s3credentials";
        group = "seaweed.seaweedfs.com";
        version = "v1";
        kind = "S3Credentials";
        attrName = "s3Credentials";
      }
      {
        name = "s3identities";
        group = "seaweed.seaweedfs.com";
        version = "v1";
        kind = "S3Identity";
        attrName = "s3Identities";
      }
      {
        name = "s3oidcproviders";
        group = "seaweed.seaweedfs.com";
        version = "v1";
        kind = "S3OIDCProvider";
        attrName = "s3OIDCProviders";
      }
      {
        name = "s3policies";
        group = "seaweed.seaweedfs.com";
        version = "v1";
        kind = "S3Policy";
        attrName = "s3Policies";
      }
      {
        name = "s3policybindings";
        group = "seaweed.seaweedfs.com";
        version = "v1";
        kind = "S3PolicyBinding";
        attrName = "s3PolicyBindings";
      }
      {
        name = "seaweeds";
        group = "seaweed.seaweedfs.com";
        version = "v1";
        kind = "Seaweed";
        attrName = "seaweeds";
      }
      {
        name = "seaweedbackups";
        group = "seaweed.seaweedfs.com";
        version = "v1";
        kind = "SeaweedBackup";
        attrName = "seaweedBackups";
      }
      {
        name = "seaweedcsidrivers";
        group = "seaweed.seaweedfs.com";
        version = "v1";
        kind = "SeaweedCSIDriver";
        attrName = "seaweedCSIDrivers";
      }
      {
        name = "seaweedrestores";
        group = "seaweed.seaweedfs.com";
        version = "v1";
        kind = "SeaweedRestore";
        attrName = "seaweedRestores";
      }
    ];

    resources = {
      "seaweed.seaweedfs.com"."v1"."AdminScript" = mkAliasDefinitions options.resources."adminScripts";
      "seaweed.seaweedfs.com"."v1"."Bucket" = mkAliasDefinitions options.resources."buckets";
      "seaweed.seaweedfs.com"."v1"."BucketLifecyclePolicy" =
        mkAliasDefinitions
          options.resources."bucketLifecyclePolicies";
      "seaweed.seaweedfs.com"."v1"."ResourceReferenceGrant" =
        mkAliasDefinitions
          options.resources."resourceReferenceGrants";
      "seaweed.seaweedfs.com"."v1"."S3Credentials" = mkAliasDefinitions options.resources."s3Credentials";
      "seaweed.seaweedfs.com"."v1"."S3Identity" = mkAliasDefinitions options.resources."s3Identities";
      "seaweed.seaweedfs.com"."v1"."S3OIDCProvider" =
        mkAliasDefinitions
          options.resources."s3OIDCProviders";
      "seaweed.seaweedfs.com"."v1"."S3Policy" = mkAliasDefinitions options.resources."s3Policies";
      "seaweed.seaweedfs.com"."v1"."S3PolicyBinding" =
        mkAliasDefinitions
          options.resources."s3PolicyBindings";
      "seaweed.seaweedfs.com"."v1"."Seaweed" = mkAliasDefinitions options.resources."seaweeds";
      "seaweed.seaweedfs.com"."v1"."SeaweedBackup" =
        mkAliasDefinitions
          options.resources."seaweedBackups";
      "seaweed.seaweedfs.com"."v1"."SeaweedCSIDriver" =
        mkAliasDefinitions
          options.resources."seaweedCSIDrivers";
      "seaweed.seaweedfs.com"."v1"."SeaweedRestore" =
        mkAliasDefinitions
          options.resources."seaweedRestores";

    };

    # make all namespaced resources default to the
    # application's namespace
    defaults = [
      {
        group = "seaweed.seaweedfs.com";
        version = "v1";
        kind = "AdminScript";
        default.metadata.namespace = lib.mkDefault config.namespace;
      }
      {
        group = "seaweed.seaweedfs.com";
        version = "v1";
        kind = "Bucket";
        default.metadata.namespace = lib.mkDefault config.namespace;
      }
      {
        group = "seaweed.seaweedfs.com";
        version = "v1";
        kind = "BucketLifecyclePolicy";
        default.metadata.namespace = lib.mkDefault config.namespace;
      }
      {
        group = "seaweed.seaweedfs.com";
        version = "v1";
        kind = "ResourceReferenceGrant";
        default.metadata.namespace = lib.mkDefault config.namespace;
      }
      {
        group = "seaweed.seaweedfs.com";
        version = "v1";
        kind = "S3Credentials";
        default.metadata.namespace = lib.mkDefault config.namespace;
      }
      {
        group = "seaweed.seaweedfs.com";
        version = "v1";
        kind = "S3Identity";
        default.metadata.namespace = lib.mkDefault config.namespace;
      }
      {
        group = "seaweed.seaweedfs.com";
        version = "v1";
        kind = "S3OIDCProvider";
        default.metadata.namespace = lib.mkDefault config.namespace;
      }
      {
        group = "seaweed.seaweedfs.com";
        version = "v1";
        kind = "S3Policy";
        default.metadata.namespace = lib.mkDefault config.namespace;
      }
      {
        group = "seaweed.seaweedfs.com";
        version = "v1";
        kind = "S3PolicyBinding";
        default.metadata.namespace = lib.mkDefault config.namespace;
      }
      {
        group = "seaweed.seaweedfs.com";
        version = "v1";
        kind = "Seaweed";
        default.metadata.namespace = lib.mkDefault config.namespace;
      }
      {
        group = "seaweed.seaweedfs.com";
        version = "v1";
        kind = "SeaweedBackup";
        default.metadata.namespace = lib.mkDefault config.namespace;
      }
      {
        group = "seaweed.seaweedfs.com";
        version = "v1";
        kind = "SeaweedCSIDriver";
        default.metadata.namespace = lib.mkDefault config.namespace;
      }
      {
        group = "seaweed.seaweedfs.com";
        version = "v1";
        kind = "SeaweedRestore";
        default.metadata.namespace = lib.mkDefault config.namespace;
      }
    ];
  };
}
