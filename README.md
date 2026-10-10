# k8s-template

## CI

`.github/workflows/k8s-lint.yml` runs the `k8s:lint` tasks (from [ci-runner](https://github.com/twanvanparidon/ci-runner) `pipelines/k8s/lint`) in the ci-runner `k8s` image: render every kustomization, schema check with kubeconform, lint with kube-linter. Run the same steps locally with the devbox tools:

```sh
task k8s:lint
```
