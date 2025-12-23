# Helm Chart

Ontopic Helm Charts repository.

## Requirements

You need to install :

- [kubectl](https://kubernetes.io/docs/tasks/tools/)
- [helm](https://helm.sh/docs/intro/install/)

## Getting started

### Create a cluster

See the [k3d cluster example](./docs/k3d-cluster-example.md) if you want to install it locally.

You can also directly use [Docker Desktop](https://docs.docker.com/desktop/kubernetes/) to quickly create a local cluster.

### Create the namespace

Here is how you can create a namespace and set it as the current context:

```sh
kubectl create namespace <your-namespace>
kubectl config set-context --current --namespace=<your-namespace>
```

Make sure to replace `<your-namespace>` with the name of the namespace you want to use.

### Add the repository

[Helm](https://helm.sh) must be installed to use the charts.

Add the repo as follows:

```sh
helm repo add ontopic https://ontopic-vkg.github.io/ontopic-helm/
```

If you had already added this repo earlier, run `helm repo update` to retrieve the latest versions of the packages.
You can then run `helm search repo ontopic` to see the charts.

## Charts

### Ontop Endpoint

See the [Ontop Endpoint documentation](./docs/deploy-ontop-endpoint.md).
In case you want to use the Ontop Endpoint with Ontopic Studio, you can follow the instructions in the [Ontopic Studio documentation](./docs/deploy-ontopic-studio.md) instead, as it is included as a subchart.

### Ontopic Suite

See the [Ontopic Studio documentation](./docs/deploy-ontopic-studio.md).

# Limitations

- The embedded Git repository (Gitea) is not provided.
- No sample database is provided.
