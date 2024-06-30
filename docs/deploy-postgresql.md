Deploy a PostgreSQL database
============================

Here is the command to deploy a PostgreSQL database using the [Bitnami Helm Chart](https://artifacthub.io/packages/helm/bitnami/postgresql).

```sh
helm repo add bitnami https://charts.bitnami.com/bitnami
helm install store-server-db bitnami/postgresql --wait
```

Wait for the DB to be ready.

Create the database and users
-----------------------------

```bash
kubectl exec -i store-server-db-postgresql-0 -- /opt/bitnami/scripts/postgresql/entrypoint.sh /bin/bash -c 'PGPASSWORD=$POSTGRES_PASSWORD psql' < create-db-and-users.sql
```

Create the database secret file
-------------------------------

```bash
# Create the new secret
kubectl create secret generic database-password-file \
  --from-literal=database-password-file="$(kubectl get secret store-server-db-postgresql -o jsonpath="{.data.postgres-password}" | base64 -d)"
```
