export GITHUB_TOKEN=<your-github-access-token>
export GITHUB_USER=<your-github-username>

k3d cluster create fluxcd-01

flux bootstrap github --owner=sasanbabai --repository=k3d-fleet --personal=true --private=false --branch=main --read-write-key --path=clusters/fluxcd-01

git pull

flux create kustomization infrastructure --source=flux-system --path=./infrastructure --prune=true --interval=5m --export > clusters/fluxcd-01/infrastructure.yaml

mkdir -p infrastructure/kyverno

# syncs with git repo, container registry, bucket (checksum is used as artifact id)
# polls the source in specified interval
# artifact is created in the cluster and cached
# sync will happen even if the source is disconnected
# image sync involves image reflector and image automation controllers
# image reflector will watch registry for changes
# image automation watches image reflector and applies the image policy and patches the repo
flux create source git kyverno --url=ssh://git@github.com/sasanbabai/kyverno --tag-semver=">=1.0.0" --secret-ref=flux-system --interval=5m --export > infrastructure/kyverno/source.yaml

git add -A && git commit -m "added keverno git repo" && git push origin main

flux get sources all

flux reconcile source git flux-system

flux create kustomization kyverno --source=kyverno --path=./config/release --prune=true --interval=5m --export > infrastructure/kyverno/release.yaml

flux get sources all

flux reconcile kustomization flux-system --with-source

flux get kustomizations

# kustomizations also allow you to define dependency trees (depends-on)
flux create kustomization apps --depends-on=infrastructure --source=flux-system --path=./apps --prune=true --interval=5m --export > clusters/fluxcd-01/apps.yaml

mkdir -p tenants/tenant-01

# create tenant-01 namespace
# create tenant-01 service account
# bind tenant-01 with cluster-admin in tenant-01 namespace
# create podinfo gitrepo in tenant-01 namespace
flux create tenant tenant-01 --with-namespace=tenant-01 --export > tenants/tenant-01.yaml

kubectl create secret generic tenant-01 --namespace=tenant-01 --from-file=/home/sbabai/.ssh/identity --from-file=/home/sbabai/.ssh/identity.pub --from-file=/home/sbabai/.ssh/known_hosts

flux create source git podinfo --namespace=tenant-01 --url=ssh://git@github.com/sasanbabai/podinfo --branch=master --secret-ref=tenant-01 --interval=5m --export > tenants/tenant-01/podinfo-repo.yaml

flux reconcile kustomization flux-system --with-source

flux create kustomization podinfo --namespace=tenant-01 --target-namespace=tenant-01 --service-account=tenant-01 --source=podinfo --path=./kustomize --prune=true --interval=5m --health-check=Deployment/podinfo.apps --export > tenants/tenant-01/podinfo-kustomiztion.yaml
