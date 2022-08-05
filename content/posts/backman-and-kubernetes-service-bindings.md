---
title: "Using Kubernetes Service Bindings in Backman"
description: "How to use Backman on Kubernetes and automatically configure databases through service bindings"
tags: [database,backups,backman,kubernetes,service binding]
author: Fabio Berchtold
date: 2022-07-10T19:22:51+02:00
draft: false
---

## What is Backman again?

I mentioned [Backman](https://github.com/JamesClonk/backman) already once in a [previous post](/posts/database-backups-with-backman/), but in short it's an application for managing database backups. Backman can be deployed on Cloud Foundry or Kubernetes and automatically detects and configures your databases through bindings, creates backups and stores these on an S3-compatible object storage. Backups can later be restored on-demand or downloaded.

## Run Backman on Kubernetes

Deploying and running Backman on Kubernetes has gotten fairly straightforward these days. I wrote new [documentation](https://github.com/JamesClonk/backman/tree/master/docs/kubernetes) about it, added multiple [example deployment manifests](https://github.com/JamesClonk/backman/blob/master/kubernetes/deploy), and there's also a bit of [ytt templates and kapp magic](https://github.com/JamesClonk/backman/blob/master/kubernetes/build) included if you want to dig deeper into it.

The main issue I had to overcome was that since Backman was originally written specifically to run on Cloud Foundry, it had a few hardcoded assumptions and idiosyncrasies about its runtime environment, and those didn't translate all too well over to Kubernetes.

In Cloud Foundry Backman is configured mainly through a single large environment variable, `$BACKMAN_CONFIG`, which contains an entire JSON configuration file. While this of course works as well on Kubernetes it is rather unwieldy and not very K8s-idiomatic. Also in order to auto-discover databases and their bindings in Cloud Foundry there is the special environment variable `$VCAP_SERVICES` that gets automatically injected into the running container by the platform. Since there's no such thing on Kubernetes I had to recreate that entire variable and its contents and add it to the deployment. The whole thing was very cumbersome.

So I did a big code refactor in Backman and also added the following new features:
- Can read a configuration file from the local filesystem via `-config <file>`
- Can have service bindings fully expressed within the configuration file
- Supports the [servicebinding.io](https://servicebinding.io/) specification

### Configuration file

Armed with those new abilities the configuration of Backman on Kubernetes now looks as simple as this:

```yaml
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: backman
spec:
  selector:
    matchLabels:
      app: backman
  replicas: 1
  strategy:
    type: Recreate
  template:
    metadata:
      labels:
        app: backman
    spec:
      containers:
      - name: backman
        image: jamesclonk/backman:latest
        ports:
        - containerPort: 8080
        command:
        - backman
        args:
        - -config
        - /backman/config.json
        volumeMounts:
        - mountPath: /backman/config.json
          name: configuration
          subPath: config.json
      volumes:
      - name: configuration
        secret:
          secretName: configuration

---
apiVersion: v1
kind: Secret
metadata:
  name: configuration
type: Opaque
stringData:
  config.json: |
    {
      "log_level": "info",
      "logging_timestamp": true,
      "disable_metrics_logging": true,
      "disable_health_logging": true,
      "unprotected_metrics": true,
      "unprotected_health": true,
      "username": "john.doe",
      "password": "foobar",
      "s3": {
        "service_label": "s3",
        "bucket_name": "backman-storage",
        "host": "s3.amazonaws.com",
        "access_key": "BKIKJAA5BMMU2RHO6IBB",
        "secret_key": "V7f1CwQqAcwo80UEIJEjc5gVQUSSx5ohQ9GSrr12"
      }
    }
```

All we needed to do was define a [`config.json`](https://github.com/JamesClonk/backman/blob/master/docs/configuration.md) key in a K8s **Secret**, and then mount it as a file into the Backman container.

Pretty neat huh? This is much more K8s-idiomatic than before.

## Service Bindings

> *"Now what about those service bindings you keep talking about, how do I get Backman to know about my databases?"* 🤔

While it would be possible to configure service bindings or credentials also directly in the `config.json`, one other major feature that I added to Backman was support for the [servicebinding.io](https://servicebinding.io/) specification.

Backman on Kubernetes can then use this specification to automatically detect your databases. All you need to do is create and mount **Secret**'s whose contents conform to the spec. I've explained this in detail in the [service bindings](https://github.com/JamesClonk/backman/blob/master/docs/kubernetes/configuration.md#service_binding_root---service-bindings) section in the new Backman documentation.

But to give you a short overview what this means: Basically you'll need to either create a new **Secret** containing all necessary binding data and credentials of your database instance, or if you are using an Operator that already supports the spec it should create such a secret for you automatically.

```yaml
---
apiVersion: v1
kind: Secret
metadata:
  name: my-production-db
type: Opaque
stringData:
  type: mysql
  provider: bitnami
  uri: mysql://root:root-pw@productdb.mysql.svc.cluster.local:3306/productdb
  username: root
  password: root-pw
  database: productdb
```

And then all you have to do is mount the contents of that secret under `/bindings/*` inside the Backman container, thus allowing Backman to automatically detect the service bindings.

```yaml
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: backman
spec:
  template:
    spec:
      containers:
      - name: backman
        volumeMounts:
        - mountPath: /bindings/my-production-db
          name: my-production-db
        - mountPath: /bindings/session-cache
          name: session-cache
      volumes:
      - name: my-production-db
        secret:
          secretName: my-production-db
      - name: session-cache
        secret:
          secretName: session-cache
```

Mounting these secrets under `/bindings/*` will result in the following directory and file structure being present within the Backman container:

```plain
/bindings/
├── my-production-db/
│   ├── type
│   ├── provider
│   ├── uri
│   ├── username
│   ├── password
│   └── database
└── session-cache/
    ├── type
    ├── provider
    ├── host
    ├── port
    └── password
```

Backman then can read and parse all of these files and their contents and use it for its service instance configuration.

This makes service bindings an elegant and simple way to provide service configuration and credentials to your workload.

### servicebinding.io

Check out the whole [Service Binding for Kubernetes specification](https://servicebinding.io/) for more details on how to benefit from it as an [app developer](https://servicebinding.io/application-developer/) and how exactly this [workload projection](https://servicebinding.io/spec/core/1.0.0/#workload-projection) should work.
