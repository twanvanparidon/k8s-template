# k8s-template

A GitOps starter for Kubernetes: a local [k3d](https://k3d.io) cluster run by [Flux](https://fluxcd.io), with the manifests in this repo. Flux pulls the manifests from a local OCI registry, so edits reach the cluster without a Git push.

What you get on the dev cluster:

| Component | Purpose |
|---|---|
| [Traefik](https://traefik.io) | Gateway API controller, serves `*.localhost` on port 8080 |
| [Gateway API](https://gateway-api.sigs.k8s.io) CRDs | Standard channel, installed from upstream |
| [local-path-provisioner](https://github.com/rancher/local-path-provisioner) | Default StorageClass for PersistentVolumeClaims |
| [metrics-server](https://github.com/kubernetes-sigs/metrics-server) | `kubectl top` and HorizontalPodAutoscalers |
| [SOPS](https://getsops.io) + [age](https://age-encryption.org) | Encrypted secrets that are safe to commit, decrypted by Flux |
| nginx-test | Example app at <http://nginx-test.localhost:8080> |

## Requirements

- Docker (Docker Desktop, OrbStack, Colima, ...)
- [devbox](https://www.jetify.com/devbox); it installs every other tool at a pinned version (k3d, kubectl, flux, kustomize, task, ...). With [direnv](https://direnv.net) the tools load when you `cd` into the repo, otherwise run `devbox shell`.

## Quick start

```sh
devbox shell
task cluster:init   # create the cluster, install Flux, push and reconcile the manifests
task flux:watch     # optional: sync on every manifest change
```

Then open <http://nginx-test.localhost:8080>. Run `task` for a menu of every task.

Apps are served over plain HTTP: browsers treat `*.localhost` as a secure context, so Secure cookies and similar features work without certificates or changes to your trust store.

## Layout

| Path | Contents |
|---|---|
| `clusters/dev/` | Flux entry point: the source and the Kustomizations below, in dependency order |
| `infrastructure/controllers/` | Helm releases for the cluster services; `base/` per controller, `dev/` picks and patches them |
| `infrastructure/configs/` | Resources that need the controllers first, such as the Gateway |
| `apps/` | Your workloads; `base/` per app, `dev/` and `prod/` overlays |
| `k3d.yaml` | Cluster config: k3s version, local registry, port mappings |
| `.taskfiles/` | Task includes: `k3d`, `flux`, `sops` and `k8s-lint` |

Flux applies them in order: Gateway API CRDs, then `infrastructure/controllers`, then `infrastructure/configs`, then `apps`.

## How syncing works

`task flux:sync` pushes `apps/`, `clusters/` and `infrastructure/` as an OCI artifact to the registry k3d runs on `localhost:5050`, then tells Flux to reconcile. It skips the push when nothing changed. `task flux:watch` runs it on every change to a manifest, so uncommitted edits reach the cluster too.

## Adding an app

1. Add the manifests to `apps/base/<app>/` with a `kustomization.yaml`.
2. Add an overlay in `apps/dev/<app>/` and list it in `apps/dev/kustomization.yaml`.
3. Expose it with an `HTTPRoute` on the `gateway` in namespace `traefik` and a `<app>.localhost` hostname; see `apps/base/nginx-test/`.
4. Run `task lint`, then `task flux:sync` (or let `flux:watch` pick it up).

## Secrets

Secrets are encrypted with [SOPS](https://getsops.io) and an [age](https://age-encryption.org) key, and Flux decrypts them when it applies them. `task cluster:init` creates the key at `~/.config/sops/age/keys.txt` (once) and loads it into the cluster, so the same secrets work after every cluster rebuild. Back that key up; without it the secrets can't be decrypted.

Write a Secret to a file ending in `.sops.yaml`, list it in the app's `kustomization.yaml`, then encrypt it in place:

```sh
task sops:encrypt FILE=apps/base/<app>/my-secret.sops.yaml
sops edit apps/base/<app>/my-secret.sops.yaml   # change it later
```

Only `data` and `stringData` are encrypted, so the rest stays readable in diffs. To share secrets with a team, add a [`.sops.yaml`](https://getsops.io/docs/#using-sops-yaml-conf-to-select-kms-pgp-and-age-for-new-files) with everyone's public key (`age-keygen -y ~/.config/sops/age/keys.txt`).

## Lint and CI

`task lint` renders every kustomization, checks the result against the Kubernetes and CRD schemas with kubeconform, and lints it with kube-linter. CI ([`.github/workflows/k8s-lint.yml`](.github/workflows/k8s-lint.yml)) runs the same steps in the [ci-runner](https://github.com/twanvanparidon/ci-runner) `k8s` image, from its `pipelines/k8s/lint`.

[Renovate](https://docs.renovatebot.com) keeps the charts, images, k3s, devbox packages and actions up to date ([config](.github/renovate.json5)).

## Cleaning up

```sh
task k3d:stop      # stop, keep the data
task k3d:destroy   # delete the cluster
```

## License

[MIT](LICENSE)
