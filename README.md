Helm Chart
==========

Ontopic helm chart repository

Requirements
------------

You need to install :

* [kubectl](https://kubernetes.io/docs/tasks/tools/)
* [helm](https://helm.sh/docs/intro/install/)

Optionally, you can install :

* [kubectx](https://github.com/ahmetb/kubectx) if you want to switch easily between context and namespaces


Getting started
---------------

### Create a cluster, see k3d example
[k3d cluster example](./k3d-example/k3d-cluster-example.md)


### Create the namespace

```bash
kubectl create ns <your-namespace>
kubens <your-namespace> # if you have kubectx installed
# or
kubectl ns <your-namespace> # if you installed it with krew
# or
kubectl-ns <your-namespace>
```

### Deploy a postgresql database

Here is the command to deploy a postgresql database using the [bitnami helm chart](https://artifacthub.io/packages/helm/bitnami/postgresql).

```bash
helm repo add bitnami https://charts.bitnami.com/bitnami
helm install store-server-db bitnami/postgresql --wait
```

Wait for the DB to be ready

### Create the database and users

```bash
kubectl exec -i store-server-db-postgresql-0 -- /opt/bitnami/scripts/postgresql/entrypoint.sh /bin/bash -c 'PGPASSWORD=$POSTGRES_PASSWORD psql' < create-db-and-users.sql
```

### Create the database secret file


# Extract the postgres password
```bash
# Create the new secret
kubectl create secret generic database-password-file \
  --from-literal=database-password-file="$(kubectl get secret store-server-db-postgresql -o jsonpath="{.data.postgres-password}" | base64 -d)"
```

Add in your values file :
```yaml
store-server:
  secrets:
    database-password-file: /run/secrets/database-password-file

```

### Create a user and set password as secret

Ontopic Studio has a default user _test_ with password _test_. You can skip this section or customize this value, creating a new user and secret using the script _./create-user.sh_

Create the secret with the script, a new file with the chosen password will be generated in a new folder _secrets_
```bash
./create-user.sh

# Create the secret
kubectl create secret generic identity-password-db \
    --from-file=password-file-db=./secrets/password-file-db
```

And then you customize your values file with the secrets (all necessary secrets need to be passed not only the edited one)  :
```yaml
identity-service:
  secrets:
    identity-password-db: /run/secrets/password-file-db
    client-secret: /run/secrets/client-secret
    cookie-secret: /run/secrets/cookie-secret
    azure-api-client-secret: /run/secrets/azure-api-client-secret
    okta-ssws-token: /run/secrets/okta-ssws-token
    keycloak-admin-password-file: /run/secrets/keycloak-admin-password-file
```

In case of permission issues running the script, change ownership of the secrets folder and rexecute the script
```bash
sudo chown 1000 ./secrets
./create-user.sh
```

### Add the license as secret
Add the provided ontopic-studio license.

Create the secret:
```bash
kubectl create secret generic user-license-file \
    --from-file=user-license=./user-license
```

And then you add it in your values file :
```yaml
process-server:
  secrets:
    user-license-file: /run/secrets/user-license
```

## Install helm charts with the repository

[Helm](https://helm.sh) must be installed to use the charts.  Please refer to
Helm's [documentation](https://helm.sh/docs) to get started.

Once Helm has been set up correctly, add the repo as follows:

  helm repo add ontopic-helm  https://ontopic-vkg.github.io/ontopic-helm

If you had already added this repo earlier, run `helm repo update` to retrieve
the latest versions of the packages.  You can then run `helm search repo
ontopic-helm` to see the charts.

To install the ontop-endpoint chart:

    helm install ontop-endpoint ontopic-helm/ontop-endpoint

To uninstall the chart:

    helm delete ontop-endpoint

To install the ontopic-studio chart a values.yaml file is needed to override configurations:

    helm install -f values.yaml ontopic-studio ontopic-helm/ontopic-studio

To uninstall the chart:

    helm delete ontopic-studio

## Change DNS
Edit values.yaml file with the chosen host

```yaml
web:
  env:
    virtual_host: ontopicosse.local

ingress:
  host: ontopicosse.local
```