# Helm Chart

Ontopic Helm Charts repository.

## Requirements

You need to install :

- [kubectl](https://kubernetes.io/docs/tasks/tools/)
- [helm](https://helm.sh/docs/intro/install/)

## Getting started

### Create a cluster

See the [k3d cluster example](./docs/k3d-cluster-example.md) if you want to install it locally.

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

## Prepare the database

You need a **PostgreSQL** database with a dedicated owner.

In case you don't have one, you can use the provided helm chart to test it.  You can find detailed instructions in the [dedicated documentation](./docs/deploy-postgresql.md).

### Create the database secret file

You need to provide the database password as a secret. You have to [create a secret](https://kubernetes.io/docs/reference/kubectl/generated/kubectl_create/kubectl_create_secret_generic/) with the key `database-password-file` entry.

For example, if you have a PostgreSQL database deployed with the helm chart, you can create the secret with the following command:

```sh
kubectl create secret generic database-password-file \
  --from-literal=database-password-file="$(kubectl get secret store-server-db-postgresql -o jsonpath="{.data.postgres-password}" | base64 -d)"
```

Make sure you have the following part in your custom `values.yaml` file:

```yaml
store-server:
  secrets:
    # database-password-file is the name of the secret
    database-password-file: /run/secrets/database-password-file
```

### Cookie secret

By default, the cookie secret is created with a **random** value when the chart is installed.

The helm chart create a secret with the key `cookie-secret` entry.

### Create a user and set password as secret

Ontopic Studio has no default users.

You need to provide your users by creating a secret named `password-db-users` with a json representation of the users.

You can find a sample in the [samples folder](./samples/users.json) :

```json
{
    "users": [
      {
        "username": "admin",
        "password": "$aprBe1/",
        "email": "test@email.it",
        "fullname": "test",
        "groups": ["developers", "admin"]
      },
      {
        "username": "test",
        "password": "$apr1$C.",
        "email": "test@email.it",
        "fullname": "test",
        "groups": ["developers"]
      }
    ]
  }

```

And then create the secret :

```sh
# Create the secret
kubectl create secret generic password-db-users \
    --from-file=users=./samples/users.json
```

#### Update users

The chart add a job to handle this secret. This secret is managed at each installation and upgrade.

If you need to only reload the users, you can upgrade the release like this :

```sh
helm upgrade ontopic-studio ontopic/ontopic-studio --reuse-values --force
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
```

## Custom JDBC drivers (optional)

It's possible to add additional jdbc drivers to `ontop-endpoint` and `ontopic-studio` by adding some env vars :



| Name                        | Description                                      |
| --------------------------- | ------------------------------------------------ |
| `JDBC_EXTERNAL_REPO`        | The path of the git repo                         |
| `JDBC_EXTERNAL_REPO_FOLDER` | The folder within the repo                       |
| `JDBC_EXTERNAL_REPO_KEY_PATH` | The path where the SSH key is mounted (optional) |


If you use a deploy key to access the git repo, you need to create a secret and then provide `JDBC_EXTERNAL_REPO_KEY_PATH` if needed.

The default path is : `/run/secrets/jdbc-external-repo/private_key`

So you can create a secret like :

```sh
kubectl create secret generic jdbc-external-repo \
  --from-file=private_key=./my-private-key
```
Create or add to the values file `values-server.yaml` that will be used by the `ontop-endpoint` chart:

```sh
env:
  JDBC_EXTERNAL_REPO: git@github.com:my-user/my-repo
  JDBC_EXTERNAL_REPO_FOLDER: my-folder

secrets:
  # If you use s3, you have to specify the values or it will be overridden
  # ...
  # JDBC
  jdbc-external-repo: /run/secrets/jdbc-external-repo
```

And to the `values.yaml` :

```sh
process-server:
  env:
    # ...
    JDBC_EXTERNAL_REPO: git@github.com:my-user/my-repo
    JDBC_EXTERNAL_REPO_FOLDER: my-folder

  secrets:
    # ...
    jdbc-external-repo: /run/secrets/jdbc-external-repo
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
helm install ontop-endpoint ontopic/ontop-endpoint
```

To install the `ontop-endpoint` chart with the configuration `values-server.yaml` for materialization:

```sh
helm install -f values-server.yaml ontop-endpoint ontopic/ontop-endpoint
```

To uninstall the chart:

```sh
helm delete ontop-endpoint
```

### Ontopic Studio

To install the `ontopic-studio` chart a `values.yaml` file is needed to override the configurations:

```sh
helm install -f values.yaml ontopic-studio ontopic/ontopic-studio
```

To uninstall the chart:

```sh
helm delete ontopic-studio
```

# Limitations

- The embedded Git repository (Gitea) is not provided.
- No sample database is provided.
