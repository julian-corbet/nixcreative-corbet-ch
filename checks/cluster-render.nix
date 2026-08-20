# Reads the tier's promises back off the RENDERED BYTES, not off the options that produced them.
#
# The eval check proves the module resolves and refuses. This one proves the manifests that come
# out say what the module claims — which is a different question, and the only one a cluster ever
# sees. An option can be correct and the rendering still wrong.
{ pkgs, lib, nixidy, appsModule, clusterModule, values }:

let
  env = nixidy.lib.mkEnv {
    inherit pkgs;
    modules = [ appsModule clusterModule (import values) ];
  };
in
pkgs.runCommand "nixcreative-cluster-render"
{
  nativeBuildInputs = [ pkgs.yq-go ];
  manifests = env.environmentPackage;
} ''
  set -euo pipefail
  fail=0
  check() { # name expected actual
    if [ "$2" = "$3" ]; then echo "  ok   $1: $3"
    else echo "  FAIL $1: expected '$2', got '$3'"; fail=1; fi
  }
  y() { yq -r "$1" "$2"; }

  echo "== the environment renders both workloads and nothing else =="
  rendered=$(ls "$manifests" | sort | tr '\n' ' ' | sed 's/ $//')
  check "rendered apps" "apps example-graphs example-studio" "$rendered"

  graphs="$manifests/example-graphs/Deployment-example-graphs.yaml"
  studio="$manifests/example-studio/Deployment-example-studio.yaml"

  echo "== the catalogue's port reaches every container, and no declaration stated one =="
  check "graphs port" "8188" "$(y '.spec.template.spec.containers[0].ports[0].containerPort' $graphs)"
  check "studio port" "8188" "$(y '.spec.template.spec.containers[0].ports[0].containerPort' $studio)"

  echo "== one card, one holder: durable directories AND a device mean the pod may not roll =="
  check "graphs strategy" "Recreate" "$(y '.spec.strategy.type' $graphs)"
  check "studio strategy" "Recreate" "$(y '.spec.strategy.type' $studio)"
  # An absent `replicas` IS one -- Kubernetes' own default. Asserting it is unset is the honest
  # form: the grammar deliberately stamps no count on a sleeping workload, because its count
  # belongs to whatever wakes it.
  check "graphs replicas unset (the wake front owns it)" "null" "$(y '.spec.replicas' $graphs)"
  check "studio replicas" "1" "$(y '.spec.replicas' $studio)"

  echo "== needing the card is visible in the bytes, and is requested exactly once per pod =="
  check "graphs gpu label" "true" "$(y '.metadata.labels."nixk3s.dev/gpu"' $graphs)"
  check "studio gpu label" "true" "$(y '.metadata.labels."nixk3s.dev/gpu"' $studio)"
  check "graphs containers" "1" "$(y '.spec.template.spec.containers | length' $graphs)"
  check "graphs device limit"   "1" "$(y '.spec.template.spec.containers[0].resources.limits."example.com/example-device"' $graphs)"
  check "graphs device request" "1" "$(y '.spec.template.spec.containers[0].resources.requests."example.com/example-device"' $graphs)"
  # The catalogue names no device and no count. Proving that means proving the string only ever
  # appears where the CONSUMER's own value put it -- so it must not be findable in this repository.
  check "device name absent from the catalogue" "0" \
    "$(grep -c 'example-device' ${../lib/applications.nix} || true)"

  echo "== a deployment's own sizing lands, and the catalogue supplied none of it =="
  check "graphs memory limit"   "2Gi" "$(y '.spec.template.spec.containers[0].resources.limits.memory' $graphs)"
  check "graphs memory request" "1Gi" "$(y '.spec.template.spec.containers[0].resources.requests.memory' $graphs)"
  check "studio memory limit"   "null" "$(y '.spec.template.spec.containers[0].resources.limits.memory' $studio)"
  # A CPU ceiling throttles rather than kills, so nothing here renders one unasked.
  check "graphs no cpu limit" "null" "$(y '.spec.template.spec.containers[0].resources.limits.cpu' $graphs)"

  echo "== the parent mount is emitted before the directory nested inside it =="
  check "graphs mount 0" "/root"                  "$(y '.spec.template.spec.containers[0].volumeMounts[0].mountPath' $graphs)"
  check "graphs mount 1" "/root/ComfyUI/models"   "$(y '.spec.template.spec.containers[0].volumeMounts[1].mountPath' $graphs)"
  check "graphs mount 2" "/images-out"            "$(y '.spec.template.spec.containers[0].volumeMounts[2].mountPath' $graphs)"

  echo "== what backs each directory is the declaration's half, and both backings render =="
  check "graphs weights path" "/example/weights" \
    "$(y '.spec.template.spec.volumes[] | select(.name == "models") | .hostPath.path' $graphs)"
  # `Directory` refuses to start on a missing path. That is the whole guard: an auto-created model
  # directory is a workload that comes up healthy and can render nothing.
  check "graphs weights type" "Directory" \
    "$(y '.spec.template.spec.volumes[] | select(.name == "models") | .hostPath.type' $graphs)"
  check "graphs home type" "DirectoryOrCreate" \
    "$(y '.spec.template.spec.volumes[] | select(.name == "home") | .hostPath.type' $graphs)"
  check "studio weights claim" "example-weights" \
    "$(y '.spec.template.spec.volumes[] | select(.name == "models") | .persistentVolumeClaim.claimName' $studio)"
  check "studio weights read-only" "true" \
    "$(y '.spec.template.spec.containers[0].volumeMounts[] | select(.name == "models") | .readOnly' $studio)"

  echo "== the argument that routes the product still points at the directory that is backed =="
  # NOT `out`: that name is the derivation's own output path, and shadowing it here made this
  # check pass every assertion and then fail on `touch $out`.
  outmount=$(y '.spec.template.spec.containers[0].volumeMounts[] | select(.name == "output") | .mountPath' $graphs)
  cli=$(y '.spec.template.spec.containers[0].env[] | select(.name == "CLI_ARGS") | .value' $graphs)
  check "renders routed into the backed directory" "true" \
    "$(case "$cli" in *"--output-directory $outmount"*) echo true;; *) echo false;; esac)"
  echo "== and a card's own quirk arrives as the declaration's environment, never the catalogue's =="
  check "graphs card override" "0.0.0" \
    "$(y '.spec.template.spec.containers[0].env[] | select(.name == "HSA_OVERRIDE_GFX_VERSION") | .value' $graphs)"
  check "studio has no card override" "" \
    "$(y '.spec.template.spec.containers[0].env[] | select(.name == "HSA_OVERRIDE_GFX_VERSION") | .value' $studio)"

  echo "== the image is a tag when a version was given and a whole reference when one was =="
  check "graphs image" "yanwk/comfyui-boot:0.0.0" "$(y '.spec.template.spec.containers[0].image' $graphs)"
  check "studio digest-pinned" "true" "$(y '.spec.template.spec.containers[0].image' $studio | grep -q '@sha256:' && echo true || echo false)"

  echo "== fifteen minutes of tolerated start, and no guessed liveness probe =="
  check "graphs probe period"  "5"   "$(y '.spec.template.spec.containers[0].readinessProbe.periodSeconds' $graphs)"
  check "graphs probe budget"  "180" "$(y '.spec.template.spec.containers[0].readinessProbe.failureThreshold' $graphs)"
  check "graphs no liveness"   "null" "$(y '.spec.template.spec.containers[0].livenessProbe' $graphs)"
  check "studio no liveness"   "null" "$(y '.spec.template.spec.containers[0].livenessProbe' $studio)"

  echo "== no address is invented here: the Service is a plain ClusterIP with nothing pinned =="
  for f in $manifests/example-graphs/Service-example-graphs.yaml $manifests/example-studio/Service-example-studio.yaml; do
    check "$(basename $f) type" "ClusterIP" "$(y '.spec.type' $f)"
    check "$(basename $f) no pinned IP" "null" "$(y '.spec.clusterIP' $f)"
    check "$(basename $f) no nodePort" "null" "$(y '.spec.ports[0].nodePort' $f)"
  done

  # `-L` is load-bearing: the rendered tree is SYMLINKS into the store, so a plain `-type f`
  # matches nothing and returns a confident zero. A count that can only ever be zero is worse than
  # no check, because it passes the moment somebody expects zero.
  echo "== exactly one workload anchors the shared namespace, and only one =="
  check "namespaces rendered" "1" "$(find -L $manifests -name 'Namespace-*.yaml' -type f | wc -l)"
  check "which namespace"    "example-generative" \
    "$(y '.metadata.name' $manifests/example-graphs/Namespace-example-generative.yaml)"
  check "studio joined it"   "example-generative" "$(y '.metadata.namespace' $studio)"

  if [ "$fail" -ne 0 ]; then
    echo "rendered output does not match the tier's promises" >&2
    exit 1
  fi
  echo "nixcreative: the rendered tree matches every promise asserted here"
  touch $out
''
