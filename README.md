# Helm Chart

Ontopic Helm Charts repository.

## Requirements

You need to install :

- [kubectl](https://kubernetes.io/docs/tasks/tools/)
- [helm](https://helm.sh/docs/intro/install/)

## Getting started

### Create a cluster

See the [k3d cluster example](./k3d-example/k3d-cluster-example.md) if you want to install it locally.

### Create the namespace

```sh
kubectl create namespace <your-namespace>
kubectl config set-context --current --namespace=<your-namespace>
```

## Create custom values.yaml

Ontopic Studio needs to be configured with a custom `values.yaml` file.
An example is provided in the folder.
It can be adapted to your scenario.

```sh
cp values.example.yaml values.yaml
```

## Deploy a PostgreSQL database

Here is the command to deploy a PostgreSQL database using the [Bitnami Helm Chart](https://artifacthub.io/packages/helm/bitnami/postgresql).

```sh
helm repo add bitnami https://charts.bitnami.com/bitnami
helm install store-server-db bitnami/postgresql --wait
```

Wait for the DB to be ready.

### Create the database and users

```sh
kubectl exec -i store-server-db-postgresql-0 -- /opt/bitnami/scripts/postgresql/entrypoint.sh /bin/bash -c 'PGPASSWORD=$POSTGRES_PASSWORD psql' < create-db-and-users.sql
```

### Create the database secret file

```sh
# Create the new secret
kubectl create secret generic database-password-file \
  --from-literal=database-password-file="$(kubectl get secret store-server-db-postgresql -o jsonpath="{.data.postgres-password}" | base64 -d)"
```

Make sure you have the following part in your custom `values.yaml` file:

```yaml
store-server:
  secrets:
    database-password-file: /run/secrets/database-password-file
```

### Change the default cookie secret (optional)

By default, the cookie secret is created with a **non-random** value.

For providing a custom value:

```sh
# Create folder secret if it has not already been created
mkdir -p ./secrets

docker run ghcr.io/ontopic-vkg/ontopic-helm/identity-service:helm-v2024.1.2 generate cookie > ./secrets/cookie-secret

kubectl create secret generic custom-cookie \
  --from-file=cookie-secret=./secrets/cookie-secret
```

Then edit the `values.yaml` file adding `custom-cookie`:

```yaml
identity-service:
  secrets:
    # ...
    custom-cookie: /run/secrets/cookie-secret
```

### Create a user and set password as secret (optional)

Ontopic Studio has a default user `test` with password `test`.
If you want to use the default user and didn't create an `identity-service` section in `values.yaml` (e.g. when using a custom cookie), you can skip this section.

#### Use default user

To use the default user in an existing `identity-service` section, add the following entry:

```yaml
identity-service:
  secrets:
    # ...
    password-file-db: /run/secrets/password-file-db
```

#### Create new user

To create a new user and secret use the script _./create-user.sh_. A new file with the chosen password will be generated in a new folder _secrets_:

```sh
./create-user.sh
```

<details>
 <summary><b>NOTE:</b> Troubleshooting the script</summary>

---

In case of permission issues running the script (as user root), change ownership of the secrets folder and execute again the script

```sh
sudo chown 1000 ./secrets
./create-user.sh
```

---

</details>
</br>

```sh
# Create the secret
kubectl create secret generic identity-password-db \
    --from-file=password-file-db=./secrets/password-file-db
```

And then you need to add the created secret in your values file:

```yaml
identity-service:
  secrets:
    # ...
    identity-password-db: /run/secrets/password-file-db
```

If you didn't specify a custom cookie secret, please also include the following entry:

```yaml
identity-service:
  secrets:
    # ...
    cookie-secret: /run/secrets/cookie-secret
```

### Use Azure as identity service provider (optional)

Use or create a registered app from the Azure Active Directory (Microsoft Entra ID).
Follow the instruction on [how to register Ontopic Studio in Azure Active Directory](https://docs.ontopic.ai/studio/administrate/access-control/azure.html#register-ontopic-studio).

You will need the _Application (client) ID_, the _Directory (tenant) ID_, the _client secret_, and the _Application ID URI_ of the registered app.

Save the client secret in a file in the secrets folder.

```sh
# Create folder secret if it has not already been created
mkdir -p ./secrets

# Save secret in file client-secret
echo "<client secret>" > ./secrets/client-secret
```

Create a secret for the Azure _client secret_.

```sh
kubectl create secret generic client-secret \
    --from-file=client-secret=./secrets/client-secret
```

In the `env` section of `identity_service`:

- insert the _Application (client) ID_ for `ONTOPIC_IDENTITY_SERVICE_CLIENT_ID` and `ONTOPIC_IDENTITY_SERVICE_AZURE_API_CLIENT_ID`.
- add the _Directory (tenant) ID_ as `ONTOPIC_IDENTITY_SERVICE_AZURE_TENANT_ID`.
- add the _Application ID URI_ in `ONTOPIC_IDENTITY_SERVICE_SESSION_SCOPE` after the predefined settings _openid,email,profile,offline_access_.
- use the created _client-secret_ for `ONTOPIC_IDENTITY_SERVICE_AZURE_API_CLIENT_SECRET_FILE` and `ONTOPIC_IDENTITY_SERVICE_CLIENT_SECRET_FILE`

See the example below on how to edit the `values.yaml` file to add the environment variables and secret.

```yaml
identity-service:
   env:
      ONTOPIC_IDENTITY_SERVICE_PROVIDER_OAUTH2: azure
      ONTOPIC_IDENTITY_SERVICE_AZURE_TENANT_ID: <Directory (tenant) ID>
      ONTOPIC_IDENTITY_SERVICE_AZURE_API_CLIENT_ID: <Application (client) ID>
      ONTOPIC_IDENTITY_SERVICE_CLIENT_ID: <Application (client) ID>
      ONTOPIC_IDENTITY_SERVICE_SESSION_SCOPE: openid,email,profile,offline_access,<Application ID URI>
      ONTOPIC_IDENTITY_SERVICE_AZURE_API_CLIENT_SECRET_FILE: /run/secrets/client-secret/client-secret
      ONTOPIC_IDENTITY_SERVICE_CLIENT_SECRET_FILE: /run/secrets/client-secret/client-secret

    secrets:
      # ...
      client-secret: /run/secrets/client-secret
```

### Add the license as secret

Add the provided ontopic-studio license as secret.

Create the secret:

```sh
kubectl create secret generic user-license-file \
  --from-file=user-license=./user-license
```

And then you add it in your values file:

```yaml
process-server:
  secrets:
    user-license-file: /run/secrets/user-license
```

## Change DNS

Edit `values.yaml` file with the chosen host name:

```yaml
web:
  env:
    virtual_host: ontopic.local

ingress:
  host: ontopic.local
```

## Enable materialization with S3 (optional)

Ontopic Studio supports materialization to RDF using S3 as storage, but it is disabled by default.

The necessary S3 parameters are:

- `S3_ACCESS_KEY_ID`
  Obtain your S3 access key ID from your AWS account.
  This key uniquely identifies your account and grants access to your S3 resources.
- `S3_ACCESS_KEY_SECRET`
  Retrieve your S3 access key secret (also known as the secret key) from your AWS account.
  Keep this secret key confidential and secure.
- `S3_BUCKET`
  Choose a unique name for your S3 bucket.
  Buckets are containers for storing objects (files) in S3.
- `S3_REGION`
  Determine the AWS region where your S3 bucket will reside.
  Common regions include us-east-1 (North Virginia), us-west-2 (Oregon), and others.

For more detailed information, refer to the [Amazon S3 documentation](https://docs.aws.amazon.com/AmazonS3/latest/userguide/GetStartedWithS3.html).

Example:

- `S3_ACCESS_KEY_ID`: `AKIAY1234567890`
- `S3_ACCESS_KEY_SECRET`: `mySecretAccessKey`
- `S3_BUCKET`: `my-materialization-bucket`
- `S3_REGION`: `us-west-2`

Edit the `values.yaml` file and set `enable_materialization` to `true` in the `store-server` section:

```yaml
store-server:
  env:
    # ...
    enable_materialization: true
```

Save `S3_ACCESS_KEY_ID` in a file in the secrets folder.

```sh
# Create folder secret if it has not already been created
mkdir -p ./secrets

# Save secret in file client-secret
echo "<S3_ACCESS_KEY_ID>" > ./secrets/access-key-id
```

Create a secret for this file.

```sh
kubectl create secret generic s3-id \
  --from-file=s3-id=./secrets/access-key-id

```

Save `S3_ACCESS_KEY_SECRET` in a file in the secrets folder.

```sh
echo "<S3_ACCESS_KEY_SECRET>" > ./secrets/access-key-secret
```

Create a secret for this file.

```sh
kubectl create secret generic s3-secret \
  --from-file=s3-secret=./secrets/access-key-secret
```

Create a new values file `values-server.yaml` with the s3 configuration that will be used by the `ontop-endpoint` chart:

```yaml
env:
  ONTOPIC_SERVER_ENABLE_MATERIALIZATION: true
  ONTOPIC_SERVER_S3_ACCESS_KEY_ID_FILE: /run/secrets/s3-id/access-key-id
  ONTOPIC_SERVER_S3_ACCESS_KEY_SECRET_FILE: /run/secrets/s3-secret/access-key-secret
  ONTOPIC_SERVER_S3_BUCKET: <S3_BUCKET>
  ONTOPIC_SERVER_S3_REGION: <S3_REGION>

secrets:
  s3-secret: /run/secrets/s3-secret
  s3-id: /run/secrets/s3-id

```

## Install Helm Charts with the repository

[Helm](https://helm.sh) must be installed to use the charts.

Add the repo as follows:

```sh
helm repo add ontopic https://ontopic-vkg.github.io/ontopic-helm/
```

If you had already added this repo earlier, run `helm repo update` to retrieve the latest versions of the packages.
You can then run `helm search repo ontopic` to see the charts.

### Ontop Endpoint

To install the `ontop-endpoint` chart without extra configuration:

```sh
helm install ontop-endpoint-release ontopic/ontop-endpoint
```

To install the `ontop-endpoint` chart with the configuration `values-server.yaml` for materialization:

```sh
helm install -f values-server.yaml ontop-endpoint-release ontopic/ontop-endpoint
```

To uninstall the chart:

```sh
helm delete ontop-endpoint-release
```

### Ontopic Studio

To install the `ontopic-studio` chart a `values.yaml` file is needed to override the configurations:

```sh
helm install -f values.yaml ontopic-studio-release ontopic/ontopic-studio
```

To uninstall the chart:

```sh
helm delete ontopic-studio-release
```

# Limitations

- Currently JDBC drivers are embedded in the containers and are therefore not customizable.
- The embedded Git repository (Gitea) is not provided.
- No sample database is provided.
