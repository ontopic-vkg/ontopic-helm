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

### Custom JDBC drivers (optional)

It's possible to add additional jdbc drivers from an external Git repository by configuring the `jdbcExternal` section:

```yaml
jdbcExternal:
  enabled: true
  repository: git@github.com:my-user/my-repo
  folder: my-folder
```

If you use a deploy key to access the git repo, you need to create a secret:

```sh
kubectl create secret generic jdbc-private-key \
  --from-file=jdbc-private-key=./secrets/jdbc-private-key
```

The secret name must be `jdbc-private-key` with a key named `jdbc-private-key`.

Complete example in `values-server.yaml`:

```yaml
jdbcExternal:
  enabled: true
  repository: git@github.com:my-user/my-repo
  folder: my-folder
```

## Enable materialization (optional)
Ontopic Server supports materialization to RDF in different storage providers, such as S3 and Azure Blob Storage. Additionally, local storage can also be used for materialization.

By default, materialization is disabled. To enable it, you need to set the environment variable `enableMaterialization` to `true`.

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
enableMaterialization: true

objectStorage:
  s3:
    bucket: <S3_BUCKET>
    region: <S3_REGION>
    endpoint: # Optional, default is https://s3.amazonaws.com
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

Create a new values file `values-server.yaml` with the azure configuration that will be used by the `ontopic-server` chart. Note that if both `AZURE_ACCOUNT_KEY` and `AZURE_ACCOUNT_SAS_TOKEN` are provided, the account key will be used by default.

```yaml
enableMaterialization: true

objectStorage:
  azure:
    container: <AZURE_CONTAINER_NAME>
    endpoint: # Optional, default is https://<ACCOUNT_NAME>.blob.core.windows.net/
```

### File Storage
By default, Ontopic Server uses local file storage for materialization. The materialization results are stored at the path `/opt/ontopic-server/materialization-results/yyyy-mm-dd/` inside the container and can be configured to use a different directory.

```yaml
enableMaterialization: true

env:
  ONTOPIC_SERVER_MATERIALIZATION_RESULT_DIR: # Optional, default is materialization-results
```


## With Ontopic Suite

If you want to use the Ontopic Server with Ontopic Suite, you can follow the instructions in the [Ontopic Suite documentation](./deploy-ontopic-suite.md).

The Ontopic Server is already included in the Ontopic Suite Helm chart, as a subchart.

## PostgreSQL Wire Protocol

Ontopic Server supports a PostgreSQL wire protocol on port 4300, allowing you to query your virtual knowledge graph using standard PostgreSQL clients. This port is exposed externally via NodePort (30430) by default.

### Connect to the PostgreSQL wire protocol

Get any node's external IP:

```sh
kubectl get nodes -o wide
```

Connect using a PostgreSQL client:

```sh
psql -h <NODE-IP> -p <NODE-PORT> -U <username> -d <database>
```

Or using any PostgreSQL-compatible tool (DBeaver, DataGrip, etc.) with:
- Host: `<NODE-IP>` or your DNS name pointing to the cluster
- Port: `30430` (default NodePort)

### Configuration

To change the external port:

```yaml
service:
  postgresNodePort: 31234  # custom port
```

To disable external access:

```yaml
service:
  type: ClusterIP
```

### Notes

- NodePort exposes the service on the same port across all cluster nodes
- You can use the same DNS name for both HTTP (via Ingress) and PostgreSQL (via NodePort)
- Ensure your firewall allows traffic to the NodePort (default: 30430)


## Public IP for Postgres (AKS)

```bash
az network public-ip create --resource-group <RESOURCE_GROUP> --name pg-public-ip --sku Standard --allocation-method static
```




