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

In case you want to use the Ontopic Server with Ontopic Studio, you can follow the instructions in the [Ontopic Studio documentation](./deploy-ontopic-studio.md).

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

Create a new values file `values-server.yaml` with the s3 configuration that will be used by the `ontopic-server` chart:

```yaml
env:
  ONTOPIC_SERVER_ENABLE_MATERIALIZATION: true
  ONTOPIC_SERVER_S3_ACCESS_KEY_ID_FILE: /run/secrets/s3-id/access-key-id
  ONTOPIC_SERVER_S3_ACCESS_KEY_SECRET_FILE: /run/secrets/s3-secret/access-key-secret
  ONTOPIC_SERVER_S3_BUCKET: <S3_BUCKET>
  ONTOPIC_SERVER_S3_REGION: <S3_REGION>
  ONTOPIC_SERVER_S3_ENDPOINT_URL: <S3_ENDPOINT_URL> # Optional
```

### With Ontopic Studio

If you want to use the Ontopic Server with Ontopic Studio, you can follow the instructions in the [Ontopic Studio documentation](./deploy-ontopic-studio.md).

The Ontopic Server is already included in the Ontopic Studio Helm chart, as a subchart.
