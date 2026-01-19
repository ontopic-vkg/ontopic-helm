# Deploy Ontopic Suite

## Requirements

You need to have:

- [kubectl](https://kubernetes.io/docs/tasks/tools/)
- [helm](https://helm.sh/docs/intro/install/)

And you will need to configure the `ontopic` Helm repository:

```sh
helm repo add ontopic https://ontopic-vkg.github.io/ontopic-helm/
```

Make sure that you have a Kubernetes cluster running, and that the namespace where you want to deploy the resources exists.

Here is how you can create a namespace and set it as the current context:

```sh
kubectl create namespace <your-namespace>
kubectl config set-context --current --namespace=<your-namespace>
```

Make sure to replace `<your-namespace>` with the name of the namespace you want to use.

## Getting started

### Create a custom `values.yaml` file

Ontopic Suite needs to be configured with a custom `values.yaml` file.
An example is provided in the folder.
It can be adapted to your scenario.

```sh
cp values.example.yaml values.yaml
```

### Add the license as secret

Add the provided Ontopic Suite license as secret.
You can put the license in a file named `user-license` at the root of this repository.

Create the secret from the `user-license` file:

```sh
kubectl create secret generic user-license-file \
  --from-file=user-license=./user-license
```

The secret is referenced like this in the `values.yaml` file:

```yaml
process-server:
  secrets:
    user-license-file: /run/secrets/user-license
```

### Prepare the database

You need a **PostgreSQL** database with a dedicated owner.

By default, a PostgreSQL database is deployed.
You can disable this by setting `postgresql.enabled` to `false` in the `values.yaml` file.

In case you want to deploy it yourself, you can find detailed instructions in the [dedicated documentation](./deploy-postgresql.md).

### Cookie secret

By default, the cookie secret is created with a **random** value when the chart is installed.

The Helm chart create a secret with the key `cookie-secret` entry.

### Create users

Some simple users are defined by default in this chart.
You can see the list in the `users.list` key in the `values.yaml` file.
To disable the creation of these users, set `users.enabled` to `false`.

In case you want to create the users yourself, here are some useful instructions (if you use the users from the chart, you can skip the rest of this section).

You need to provide your users by creating a secret named `password-db-users` with a JSON representation of the users.

You can find a sample in the [samples folder](./samples/users.json) :

And then create the secret :

```sh
# Create the secret
kubectl create secret generic password-db-users \
  --from-file=users=./samples/users.json
```

### Update users

The chart add a job to handle the creation of the secret that contains all the different users.
This secret is managed at each installation and upgrade.

In the future, if you need to only reload the users, you can upgrade the release like this:

```sh
helm upgrade ontopic-suite ontopic/ontopic-suite --reuse-values --force
```

But since the chart is not deployed, you don't have to run this command, as the users will be created at the first installation automatically.

### Use Azure as identity service provider (optional)

Use or create a registered app from the Azure Active Directory (Microsoft Entra ID).
Follow the instruction on [how to register Ontopic Suite in Azure Active Directory](https://docs.ontopic.ai/studio/administrate/access-control/azure.html#register-ontopic-suite).

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

## Enable materialization with S3 (optional)

Ontopic Suite supports materialization to RDF using S3 as storage, but it is disabled by default.

Edit the `values.yaml` file and set `enable_materialization` to `true` in the `store-server` section:

```yaml
store-server:
  env:
    # ...
    enable_materialization: true
```

Follow the instructions in the [Ontopic Server documentation](./deploy-ontopic-server.md) to configure the S3 parameters, but instead of creating a `values-server.yaml` file, you can add the configuration directly to the `values.yaml` file, under the `ontopic-server` section, like this:

```yaml
# If you use the Ontopic Server subchart
ontopic-server:
  env:
    ONTOPIC_SERVER_ENABLE_MATERIALIZATION: true
    ONTOPIC_SERVER_S3_ACCESS_KEY_ID_FILE: /run/secrets/s3-id/access-key-id
    ONTOPIC_SERVER_S3_ACCESS_KEY_SECRET_FILE: /run/secrets/s3-secret/access-key-secret
    ONTOPIC_SERVER_S3_BUCKET: <S3_BUCKET>
    ONTOPIC_SERVER_S3_REGION: <S3_REGION>
    ONTOPIC_SERVER_S3_ENDPOINT_URL: <S3_ENDPOINT_URL> # Optional
```

### Update host name

Edit the `values.yaml` file with the chosen host name (replace `ontopic.local` with your domain):

```yaml
web:
  env:
    virtual_host: ontopic.local

ingress:
  host: ontopic.local
```

## Custom JDBC drivers (optional)

It's possible to add additional jdbc drivers by adding some env vars:

| Name                          | Description                                      |
| ----------------------------- | ------------------------------------------------ |
| `JDBC_EXTERNAL_REPO`          | The path of the git repo                         |
| `JDBC_EXTERNAL_REPO_FOLDER`   | The folder within the repo                       |
| `JDBC_EXTERNAL_REPO_KEY_PATH` | The path where the SSH key is mounted (optional) |

If you use a deploy key to access the git repo, you need to create a secret and then provide `JDBC_EXTERNAL_REPO_KEY_PATH` if needed.

The default path is : `/run/secrets/jdbc-external-repo/private_key`

So you can create a secret like :

```sh
kubectl create secret generic jdbc-external-repo \
  --from-file=private_key=./my-private-key
```

Create or add to the values file `values.yaml` that will be used by the Helm chart:

```sh
process-server:
  env:
    # ...
    JDBC_EXTERNAL_REPO: git@github.com:my-user/my-repo
    JDBC_EXTERNAL_REPO_FOLDER: my-folder

  secrets:
    # ...
    jdbc-external-repo: /run/secrets/jdbc-external-repo

# If you use the Ontopic Server subchart
ontopic-server:
  env:
    JDBC_EXTERNAL_REPO: git@github.com:my-user/my-repo
    JDBC_EXTERNAL_REPO_FOLDER: my-folder

  secrets:
    # If you use s3, you have to specify the values or it will be overridden
    # ...
    # JDBC
    jdbc-external-repo: /run/secrets/jdbc-external-repo
```

### Deploy the Helm chart

To install the `ontopic-suite` chart a `values.yaml` file is needed to override the configurations:

```sh
helm install -f values.yaml ontopic-suite ontopic/ontopic-suite
```

To uninstall the chart:

```sh
helm delete ontopic-suite
```
