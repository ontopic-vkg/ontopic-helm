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

When `users.enabled` is `false`, no local password file is created and the identity-service will not have local user authentication. This is useful when you only want to use an OAuth2 provider (Azure, Okta, Keycloak) for authentication.

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

Use or create a registered app from Microsoft Entra (Azure Active Directory).
Follow the instruction on [how to register Ontopic Suite in Microsoft Entra](https://docs.ontopic.ai/suite/administrate/access-control/azure.html#register-ontopic-suite).

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

The `client-secret` is pre-configured as an optional secret. When the Kubernetes secret exists, it will be automatically mounted and the corresponding environment variables (`ONTOPIC_IDENTITY_SERVICE_CLIENT_SECRET_FILE` and `ONTOPIC_IDENTITY_SERVICE_AZURE_API_CLIENT_SECRET_FILE`) will be set. You don't need to add it to the `secrets` section or configure the file paths manually.

In your `values.yaml`, configure the OIDC settings:

```yaml
identity-service:
  oidc:
    provider: azure
    clientId: <Application (client) ID>
    audience: <Application (client) ID>
    session:
      scope: openid,email,profile,offline_access,<Application ID URI>
    azure:
      tenantId: <Directory (tenant) ID>
```

> **Note**: The optional secret detection uses Helm's `lookup` function, which requires cluster access. When using `helm template` for dry-run rendering, optional secrets won't be included in the output since the command doesn't connect to the cluster.


### OIDC Configuration Reference

The `oidc` section supports the following options:

| Parameter | Description |
|-----------|-------------|
| `provider` | OIDC provider: `azure`, `okta`, or `keycloak` |
| `clientId` | OAuth2 client ID |
| `session.scope` | OIDC scopes to request (e.g., `openid,email,profile,offline_access`) |
| `session.prompt` | OIDC prompt parameter (e.g., `consent`, `login`) |
| `audience` | Expected token audience |
| `scopes` | Required token scopes for authorization |
| `roles` | Required roles for authorization |
| `claims.email` | Custom claim name for email |
| `claims.group` | Custom claim name for groups |
| `claims.role` | Custom claim name for roles |
| `azure.tenantId` | Azure Directory (tenant) ID |
| `okta.issuerUrl` | Okta issuer URL |
| `keycloak.host` | Keycloak server URL |
| `keycloak.realm` | Keycloak realm name |
| `keycloak.adminApplication` | Keycloak admin client ID (for user management) |
| `keycloak.adminUser` | Keycloak admin username (for user management) |

## Enable materialization (optional)

Ontopic Server supports materialization to RDF in different storage providers, such as S3 and Azure Blob Storage. Additionally, local storage can also be used for materialization.

Follow the instructions in the [Ontopic Server documentation](./deploy-ontopic-server.md) to configure the parameters, but instead of creating a `values-server.yaml` file, you can add the configuration directly to the `values.yaml` file, under the `ontopic-server`. For example, for S3:

```yaml
ontopic-server:
  enabled: true

  enableMaterialization: true

  objectStorage:
    s3:
      bucket: <S3_BUCKET>
      region: <S3_REGION>
      endpoint: # Optional, default is https://s3.amazonaws.com
```

## Update host name

Edit the `values.yaml` file with the chosen host name (replace `ontopic.local` with your domain):

```yaml
web:
  env:
    virtual_host: ontopic.local

ingress:
  host: ontopic.local
```

## Enable TLS with Let's Encrypt (optional)

To enable HTTPS with automatic certificate management using Let's Encrypt, you need to install cert-manager and configure the ClusterIssuer.

### Install cert-manager

cert-manager is a Kubernetes add-on that automates the management and issuance of TLS certificates.

Add the Jetstack Helm repository:

```sh
helm repo add jetstack https://charts.jetstack.io
helm repo update
```

Install cert-manager with CRDs:

```sh
helm install cert-manager jetstack/cert-manager \
  --namespace cert-manager \
  --create-namespace \
  --set crds.enabled=true
```

Verify the installation:

```sh
kubectl get pods -n cert-manager
```

All pods should be in the `Running` state.

### Configure the ClusterIssuer

The Ontopic Suite chart can create a Let's Encrypt ClusterIssuer for you. Enable it in your `values.yaml`:

```yaml
clusterIssuer:
  enabled: true
  name: letsencrypt-prod
  email: your-email@example.com  # Required: your email for Let's Encrypt notifications
  ingressClass: nginx            # Your ingress controller class
```

For testing, you can use the Let's Encrypt staging server to avoid rate limits:

```yaml
clusterIssuer:
  enabled: true
  name: letsencrypt-staging
  server: https://acme-staging-v02.api.letsencrypt.org/directory
  email: your-email@example.com
  privateKeySecretRef: letsencrypt-staging
  ingressClass: nginx
```

### Configure ingress for TLS

Update your ingress configuration to use TLS:

```yaml
ingress:
  host: ontopic.example.com
  className: nginx
  tls: true
  secretName: ontopic-tls
  annotations:
    cert-manager.io/cluster-issuer: letsencrypt-prod
```

## Azure Application Gateway for Containers (optional)

Azure Application Gateway for Containers (AGC) is a next-generation application load balancing solution for AKS. It supports both Ingress API and Gateway API.

See `values.azure-agc.yaml` in the repository root for a complete example configuration.

### Prerequisites

1. **ALB Controller** installed on your AKS cluster:
   ```sh
   # Install ALB Controller via Helm
   helm install alb-controller oci://mcr.microsoft.com/application-lb/charts/alb-controller \
     --namespace azure-alb-system \
     --create-namespace \
     --set albController.namespace=azure-alb-system
   ```

2. **Application Gateway for Containers** provisioned in Azure (can be managed by ALB Controller or pre-provisioned)

3. **cert-manager** installed for TLS certificates (see [Enable TLS with Let's Encrypt](#enable-tls-with-lets-encrypt-optional))

### Using Ingress API

Configure your `values.yaml` to use AGC with the Ingress API:

```yaml
ingress:
  enabled: true
  host: ontopic.example.com
  ingressClassName: azure-alb-external
  annotations: {}
    # To use a specific AGC instance:
    # alb.networking.azure.io/alb-id: /subscriptions/<subscription-id>/resourceGroups/<rg>/providers/Microsoft.ServiceNetworking/trafficControllers/<alb-name>
  tls:
    - secretName: ontopic-suite-tls
      hosts:
        - ontopic.example.com
```

### Exposing PostgreSQL with AGC

AGC does not support TCP/Layer 4 traffic, so the PostgreSQL wire protocol port (4300) must be exposed via a direct Azure LoadBalancer:

```yaml
ontopic-server:
  service:
    type: ClusterIP
    port: 8080

  postgresService:
    enabled: true
    type: LoadBalancer
    port: 4300
    annotations: {}
```

After deployment, get the PostgreSQL LoadBalancer IP:

```sh
kubectl get svc -l app.kubernetes.io/name=ontopic-server -o wide
```

Clients can then connect to `<loadbalancer-ip>:4300` for Semantic SQL queries.

## Traefik Ingress Controller (optional)

Traefik is a modern HTTP reverse proxy and load balancer that supports both Layer 7 (HTTP/HTTPS) and Layer 4 (TCP) traffic. This makes it ideal for Ontopic Suite as it can handle both the web interface and the PostgreSQL wire protocol through a single ingress controller.

See `values.traefik.yaml` in the repository root for a complete example configuration.

### Install Traefik

Add the Traefik Helm repository:

```sh
helm repo add traefik https://traefik.github.io/charts
helm repo update
```

#### Option 1: Install with Dynamic IP

```sh
helm install traefik traefik/traefik \
  --namespace traefik \
  --create-namespace \
  --set ports.postgres.port=4300 \
  --set ports.postgres.expose.default=true \
  --set ports.postgres.exposedPort=4300 \
  --set ports.postgres.protocol=TCP
```

#### Option 2: Install with Static IP (Azure)

First, create a static public IP in Azure:

```sh
# Use the AKS node resource group (starts with MC_)
RESOURCE_GROUP="MC_<your-rg>_<your-aks-cluster>_<region>"
IP_NAME="traefik-public-ip"
LOCATION="westeurope"

# Create the static IP
az network public-ip create \
  --resource-group $RESOURCE_GROUP \
  --name $IP_NAME \
  --sku Standard \
  --allocation-method Static \
  --location $LOCATION

# Get the IP address
az network public-ip show \
  --resource-group $RESOURCE_GROUP \
  --name $IP_NAME \
  --query ipAddress -o tsv
```

Then install Traefik with the static IP:

```sh
STATIC_IP="<your-static-ip>"

helm install traefik traefik/traefik \
  --namespace traefik \
  --create-namespace \
  --set service.spec.loadBalancerIP=$STATIC_IP \
  --set ports.postgres.port=4300 \
  --set ports.postgres.expose.default=true \
  --set ports.postgres.exposedPort=4300 \
  --set ports.postgres.protocol=TCP
```

This configures Traefik with:
- Default HTTP (port 80) and HTTPS (port 443) entrypoints
- A custom `postgres` entrypoint on port 4300 for the PostgreSQL wire protocol
- (Optional) A static IP for stable DNS configuration

Verify the installation:

```sh
kubectl get pods -n traefik
kubectl get svc -n traefik
```

### Configure Ingress for HTTP/HTTPS

Update your `values.yaml` to use Traefik:

```yaml
ingress:
  enabled: true
  host: ontopic.example.com
  className: traefik
  annotations:
    traefik.ingress.kubernetes.io/router.entrypoints: websecure
    traefik.ingress.kubernetes.io/router.tls: "true"
  tls: true
  secretName: ontopic-suite-tls

clusterIssuer:
  enabled: true
  name: letsencrypt-prod
  email: your-email@example.com
  ingressClass: traefik
```

### Expose PostgreSQL with Traefik IngressRouteTCP

Traefik can route TCP traffic using the `IngressRouteTCP` custom resource. First, configure the Ontopic Server PostgreSQL service as ClusterIP:

```yaml
ontopic-server:
  service:
    type: ClusterIP
    port: 8080

  postgresService:
    enabled: true
    type: ClusterIP
    port: 4300
```

After deploying the Helm chart, create an `IngressRouteTCP` resource to expose PostgreSQL through Traefik. Save the following to `postgres-ingressroute.yaml`:

```yaml
apiVersion: traefik.io/v1alpha1
kind: IngressRouteTCP
metadata:
  name: ontopic-postgres
spec:
  entryPoints:
    - postgres
  routes:
    - match: HostSNI(`*`)
      services:
        - name: ontopic-server-postgres
          port: 4300
```

Apply the resource:

```sh
kubectl apply -f postgres-ingressroute.yaml
```

Get the Traefik LoadBalancer IP:

```sh
kubectl get svc traefik -n traefik -o jsonpath='{.status.loadBalancer.ingress[0].ip}'
```

Clients can then connect to PostgreSQL at `<traefik-ip>:4300` for Semantic SQL queries.

### Alternative: Direct LoadBalancer for PostgreSQL

If you prefer not to use Traefik for TCP routing, you can expose PostgreSQL directly via a LoadBalancer:

```yaml
ontopic-server:
  postgresService:
    enabled: true
    type: LoadBalancer
    port: 4300
    # Restrict access to specific IPs (recommended):
    # loadBalancerSourceRanges:
    #   - 10.0.0.0/8
```

## Expose PostgreSQL port via Azure Application Gateway with AGIC (optional)

Ontopic Server exposes a PostgreSQL wire protocol port (default 4300) for Semantic SQL queries. If you're using the older Azure Application Gateway with AGIC (Application Gateway Ingress Controller), you can expose this port externally by configuring a TCP listener on the Application Gateway.

Since AGIC only manages HTTP/HTTPS ingress resources, the TCP backend must be configured manually on the Application Gateway.

### Configure Ontopic Server with Internal Load Balancer

After deploying, get the assigned internal IP:

```sh
kubectl get svc ontopic-server -o jsonpath='{.status.loadBalancer.ingress[0].ip}'
```

### Configure Application Gateway TCP Backend

In the Azure Portal, configure the following:

1. **Backend Pool**
   - Go to **Application Gateway** → **Backend pools** → **+ Add**
   - Name: `postgres-backend`
   - Target type: **IP address or FQDN**
   - Target: The internal LoadBalancer IP (e.g., `10.224.0.6`)

2. **Backend Settings**
   - Go to **Backend settings** → **+ Add**
   - Name: `postgres-settings`
   - Protocol: **TCP**
   - Port: `4300`

3. **Listener**
   - Go to **Listeners** → **+ Add**
   - Name: `postgres-listener`
   - Frontend IP: Select your frontend (public or private)
   - Protocol: **TCP**
   - Port: Select `postgres-port`

4. **Routing Rule**
   - Go to **Rules** → **+ Request routing rule**
   - Name: `postgres-rule`
   - Priority: `100`
   - **Listener tab**: Select `postgres-listener`
   - **Backend targets tab**:
     - Target type: **Backend pool**
     - Backend target: `postgres-backend`
     - Backend settings: `postgres-settings`

After saving, clients can connect to PostgreSQL at `<application-gateway-ip>:5432`.

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
