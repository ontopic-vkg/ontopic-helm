Helm Chart
==========

Requirements
------------

You need to install :

* [kubectl](https://kubernetes.io/docs/tasks/tools/)
* [helm](https://helm.sh/docs/intro/install/)
* [k3d](https://k3d.io/stable/#installation)

Optionally, you can install :

* [kubectx](https://github.com/ahmetb/kubectx) if you want to switch easily between context and namespaces


Getting started
---------------

### DNS resolving
To access Ontopic Studio locally on http://ontopic.local/ should modify your hosts file with:

```bash
127.0.0.1  ontopic.local
```

### Create the cluster

```bash
k3d cluster create -c k3d-example/ontopic-cluster.yaml
```

### Install helm charts
Follow the steps in the [Readme file](../README.md).

### Access Ontopic Studio

You should be able to access Ontopic Studio at http://ontopic.local:8080