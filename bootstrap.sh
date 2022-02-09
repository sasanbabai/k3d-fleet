export GITHUB_TOKEN=<your-github-access-token>
export GITHUB_USER=<your-github-username>

k config use-context k3d-sbabai-01

flux bootstrap github --owner=sasanbabai --repository=k3d-fleet --personal=true --private=false --branch=main --read-write-key --path=clusters/sbabai-01

flux create kustomization infrastructure --source=flux-system --path=./infrastructure --prune=true --interval=5m --export > clusters/sbabai-01/infrastructure.yaml

mkdir -p infrastructure/kyverno

flux create source git kyverno --url=ssh://git@github.com/kyverno/kyverno --tag-semver=">=1.0.0" --secret-ref=flux-system --interval=5m --export > infrastructure/kyverno/source.yaml

git add -A && git commit -m "added keverno git repo" && git push origin main

flux get sources all

flux reconcile source git flux-system

flux create kustomization kyverno --source=kyvernom --path=./config/release --prune=true --interval=5m --export > infrastructure/kyverno/release.yaml

flux get sources all

flux reconcile kustomization flux-system --with-source

flux get kustomizations