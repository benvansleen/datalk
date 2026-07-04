{
  perSystem = { pkgs, ... }: {
    packages.cleanKubectlDiff =
      pkgs.writers.writePython3Bin "clean-kubectl-diff"
        {
          libraries = [ pkgs.python3Packages.pyyaml ];
        }
        /* python */ ''
          import difflib
          from pathlib import Path
          import os
          import sys
          import yaml

          RED = "\033[31m"
          GREEN = "\033[32m"
          CYAN = "\033[36m"
          DIM = "\033[2m"
          RESET = "\033[0m"
          USE_COLOR = sys.stdout.isatty() and not os.environ.get("NO_COLOR")

          NOISY_METADATA_KEYS = {
            "creationTimestamp",
            "generation",
            "managedFields",
            "resourceVersion",
            "uid",
          }
          NOISY_ANNOTATIONS = {
            "kubectl.kubernetes.io/last-applied-configuration"
          }
          NOISY_LABEL_PREFIXES = (
            "apps.nixidy.dev/",
          )


          def clean(value):
              match value:
                  case list():
                      return [clean(item) for item in value]
                  case dict():
                      value = {key: clean(item) for key, item in value.items()}
                      metadata = value.get("metadata")
                      if isinstance(metadata, dict):
                          for key in NOISY_METADATA_KEYS:
                              metadata.pop(key, None)
                          annotations = metadata.get("annotations")
                          if isinstance(annotations, dict):
                              for key in NOISY_ANNOTATIONS:
                                  annotations.pop(key, None)
                              if not annotations:
                                  metadata.pop("annotations", None)
                          labels = metadata.get("labels")
                          if isinstance(labels, dict):
                              for key in list(labels):
                                  if key.startswith(NOISY_LABEL_PREFIXES):
                                      labels.pop(key, None)
                              if not labels:
                                  metadata.pop("labels", None)
                      value.pop("status", None)
                      return value
                  case _:
                      return value


          def load(path):
              if not path.exists():
                  return []
              with open(path) as f:
                  docs = list(yaml.safe_load_all(f))
              return [clean(doc) for doc in docs if doc is not None]


          def dump(docs):
              return yaml.safe_dump_all(
                docs,
                default_flow_style=False,
                explicit_start=len(docs) > 1,
                sort_keys=False,
              ).splitlines(keepends=True)


          def paths(root: Path) -> set[Path]:
              if root.is_file():
                  return {Path(".")}
              if root.is_dir():
                  return {
                    path.relative_to(root)
                    for path in root.rglob("*")
                    if path.is_file()
                  }
              return set()


          def resolve(root: Path, relpath: Path) -> Path:
              if root.is_file():
                  return root
              return root / relpath


          def colorize(line):
              if USE_COLOR:
                  def apply(color):
                      return f"{color}{line}{RESET}"

                  if line.startswith("--- ") or line.startswith("+++ "):
                      return apply(CYAN)
                  if line.startswith("@@"):
                      return apply(DIM)
                  if line.startswith("+") and not line.startswith("+++"):
                      return apply(GREEN)
                  if line.startswith("-") and not line.startswith("---"):
                      return apply(RED)
              return line


          def main():
              if len(sys.argv) < 3:
                  print("usage: clean-kubectl-diff LIVE MERGED", file=sys.stderr)
                  return 2
              live_root = Path(sys.argv[-2])
              merged_root = Path(sys.argv[-1])
              all_paths = sorted(paths(live_root) | paths(merged_root))
              if not all_paths:
                  return 0

              found_diff = False
              for relpath in all_paths:
                  live_path = resolve(live_root, relpath)
                  merged_path = resolve(merged_root, relpath)

                  try:
                      live = dump(load(live_path))
                      merged = dump(load(merged_path))
                  except Exception as e:
                      print(f"clean-kubectl-diff failed: {e}", file=sys.stderr)
                      return 2

                  diff = list(difflib.unified_diff(
                    live,
                    merged,
                    fromfile=str(live_path),
                    tofile=str(merged_path),
                  ))

                  if diff:
                      found_diff = True
                      sys.stdout.writelines(colorize(line) for line in diff)

              return 1 if found_diff else 0


          if __name__ == "__main__":
              raise SystemExit(main())
        '';
  };
}
