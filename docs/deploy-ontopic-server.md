# Deploy Ontopic Server

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

If you want to use the Ontopic Server in a standalone way, you can directly use the dedicated Helm chart.

In case you want to use the Ontopic Server with Ontopic Suite, you can follow the instructions in the [Ontopic Suite documentation](./deploy-ontopic-suite.md).

### Standalone

To install the `ontopic-server` chart without extra configuration:

```sh
helm install ontopic-server ontopic/ontopic-server
```

To install the `ontopic-server` chart with the configuration `values-server.yaml` for materialization:

```sh
helm install -f values-server.yaml ontopic-server ontopic/ontopic-server
```

To uninstall the chart:

```sh
helm delete ontopic-server
```

### Custom JDBC drivers (optional)

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

Create or add to the values file `values-server.yaml` that will be used by the `ontopic-server` chart:

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

## Enable materialization (optional)
Ontopic Server supports materialization to RDF in different storage providers, such as S3 and Azure Blob Storage. Additionally, local storage can also be used for materialization.

By default, materialization is disabled. To enable it, you need to set the environment variable `ONTOPIC_SERVER_ENABLE_MATERIALIZATION` to `true`.

### S3 Storage

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

Save `S3_ACCESS_KEY_ID` in a file in the secrets folder.

```sh
# Create folder secret if it has not already been created
mkdir -p ./secrets

# Save secret in file s3-access-key-id
echo "<S3_ACCESS_KEY_ID>" > ./secrets/s3-access-key-id
```

Create a secret for this file.

```sh
kubectl create secret generic s3-access-key-id \
  --from-file=s3-access-key-id=./secrets/s3-access-key-id
```

Save `S3_ACCESS_KEY_SECRET` in a file in the secrets folder.

```sh
echo "<S3_ACCESS_KEY_SECRET>" > ./secrets/s3-access-key-secret
```

Create a secret for this file.

```sh
kubectl create secret generic s3-access-key-secret \
  --from-file=s3-access-key-secret=./secrets/s3-access-key-secret
```

Create a new values file `values-server.yaml` with the s3 configuration that will be used by the `ontopic-server` chart:

```yaml
storageProvider: s3

env:
  ONTOPIC_SERVER_ENABLE_MATERIALIZATION: true
  ONTOPIC_SERVER_S3_ACCESS_KEY_ID_FILE: /run/secrets/s3-access-key-id/s3-access-key-id
  ONTOPIC_SERVER_S3_ACCESS_KEY_SECRET_FILE: /run/secrets/s3-access-key-secret/s3-access-key-secret
  ONTOPIC_SERVER_S3_BUCKET: <S3_BUCKET>
  ONTOPIC_SERVER_S3_REGION: <S3_REGION>
  ONTOPIC_SERVER_S3_ENDPOINT_URL: <S3_ENDPOINT_URL> # Optional, default is https://s3.amazonaws.com
```

### Azure Blob Storage
The necessary Azure Blob Storage parameters are:

- `AZURE_ACCOUNT_NAME`
  Obtain your Azure Storage account name from your Azure portal.
  This name uniquely identifies your storage account.
- `AZURE_ACCOUNT_KEY`
  Retrieve your Azure Storage account key from your Azure portal.
  Keep this key confidential and secure. Can be used instead of SAS token.
- `AZURE_ACCOUNT_SAS_TOKEN`
  Retrieve your Azure Storage account SAS token from your Azure portal.
  Keep this token confidential and secure. Can be used instead of account key.
- `AZURE_CONTAINER_NAME`
  Choose a unique name for your Azure Blob Storage container.
  Containers are used to organize blobs within your storage account.

For more detailed information, refer to the [Azure Blob Storage documentation](https://learn.microsoft.com/en-us/azure/storage/blobs/).

Example:
- `AZURE_ACCOUNT_NAME`: `mystorageaccount`
- `AZURE_ACCOUNT_KEY`: `myAccountKey`
- `AZURE_CONTAINER_NAME`: `my-materialization-container`

Save `AZURE_ACCOUNT_NAME` in a file in the secrets folder.

```sh
# Create folder secret if it has not already been created
mkdir -p ./secrets

# Save secret in file azure-account-name
echo "<AZURE_ACCOUNT_NAME>" > ./secrets/azure-account-name
```

Create a secret for this file.

```sh
kubectl create secret generic azure-account-name \
  --from-file=azure-account-name=./secrets/azure-account-name
```

Save `AZURE_ACCOUNT_KEY` in a file in the secrets folder.

```sh
echo "<AZURE_ACCOUNT_KEY>" > ./secrets/azure-account-key
```

Create a secret for this file.

```sh
kubectl create secret generic azure-account-key \
  --from-file=azure-account-key=./secrets/azure-account-key
```

Alternatively, save `AZURE_SAS_TOKEN` in a file in the secrets folder.

```sh
echo "<AZURE_SAS_TOKEN>" > ./secrets/azure-sas-token
```

Create a secret for this file.

```sh
kubectl create secret generic azure-sas-token \
  --from-file=azure-sas-token=./secrets/azure-sas-token
```

Create a new values file `values-server.yaml` with the azure configuration that will be used by the `ontopic-server` chart:

```yaml
storageProvider: azure

env:
  ONTOPIC_SERVER_ENABLE_MATERIALIZATION: true
  ONTOPIC_SERVER_AZURE_ACCOUNT_NAME_FILE: /run/secrets/azure-account-name/azure-account-name
  ONTOPIC_SERVER_AZURE_ACCOUNT_KEY_FILE: /run/secrets/azure-account-key/azure-account-key
  # Or if you use SAS token instead of account key
  # ONTOPIC_SERVER_AZURE_ACCOUNT_SAS_TOKEN_FILE: /run/secrets/azure-sas-token/azure-sas-token
  ONTOPIC_SERVER_AZURE_CONTAINER_NAME: <AZURE_CONTAINER_NAME>
  ONTOPIC_SERVER_AZURE_ENDPOINT_URL_FILE: <AZURE_ENDPOINT_URL> # Optional, default is https://<ACCOUNT_NAME>.blob.core.windows.net/
```

### File Storage
Ontopic Server also supports materialization to local file storage. By default, the materialization results are stored at the path `/opt/ontopic-server/materialization-result/yyyy-mm-dd/` .

```yaml
storageProvider: fileSystem

env:
  ONTOPIC_SERVER_ENABLE_MATERIALIZATION: true
  ONTOPIC_SERVER_MATERIALIZATION_RESULT_DIR: # Optional, default is materialization-results
```


## With Ontopic Suite

If you want to use the Ontopic Server with Ontopic Suite, you can follow the instructions in the [Ontopic Suite documentation](./deploy-ontopic-suite.md).

The Ontopic Server is already included in the Ontopic Suite Helm chart, as a subchart.
