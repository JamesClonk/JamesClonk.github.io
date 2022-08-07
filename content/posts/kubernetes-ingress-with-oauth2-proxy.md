---
title: "Web applications with automatic TLS certificates and GitHub OAuth2"
description: "How to setup a Kubernetes Ingress with automatic TLS certificates from Let's Encrypt and GitHub authentication via oauth2-proxy"
tags: [kubernetes,ingress,oauth2-proxy,github,cert-manager,lets-encrypt]
author: Fabio Berchtold
date: 2022-01-11T19:22:49+02:00
draft: true
---

// TODO: explain k8s ingress-nginx with cert-manager and oauth2-proxy with github auth

## Ingress Controller

```bash
$ kubectl -n ingress-nginx get all
NAME                                READY   STATUS      RESTARTS   AGE
pod/ingress-nginx-7de24cbef-sdv9q   1/1     Running     1          234d

NAME                    TYPE        CLUSTER-IP      EXTERNAL-IP   PORT(S)                      AGE
service/ingress-nginx   NodePort    10.43.134.29    <none>        80:31370/TCP,443:31422/TCP   423d

NAME                            READY   UP-TO-DATE   AVAILABLE   AGE
deployment.apps/ingress-nginx   1/1     1            1           423d
```

## Cert-Manager

```bash
$ kubectl -n cert-manager get all
NAME                                           READY   STATUS    RESTARTS   AGE
pod/cert-manager-webhook-f88ccb77f-xctfm       1/1     Running   1          234d
pod/cert-manager-6f6bd879b7-npbtc              1/1     Running   1          234d
pod/cert-manager-cainjector-55b4759d9c-znz6m   1/1     Running   1          234d

NAME                           TYPE        CLUSTER-IP     EXTERNAL-IP   PORT(S)    AGE
service/cert-manager           ClusterIP   10.43.44.0     <none>        9402/TCP   617d
service/cert-manager-webhook   ClusterIP   10.43.254.39   <none>        443/TCP    617d

NAME                                      READY   UP-TO-DATE   AVAILABLE   AGE
deployment.apps/cert-manager-webhook      1/1     1            1           617d
deployment.apps/cert-manager              1/1     1            1           617d
deployment.apps/cert-manager-cainjector   1/1     1            1           617d
```

#### cluster-issuer.yml
```yaml
---
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: lets-encrypt
  namespace: cert-manager
spec:
  acme:
    # use Let's Encrypt
    server: https://acme-v02.api.letsencrypt.org/directory
    email: my-email@my-domain.com
    privateKeySecretRef:
      name: lets-encrypt
    solvers:
    # use a http01 solver with our ingress-nginx (https://cert-manager.io/docs/configuration/acme/http01/)
    - http01:
        ingress:
          class: nginx
```

## GitHub OAuth2

https://docs.github.com/en/developers/apps/building-oauth-apps/creating-an-oauth-app

![GitHub OAuth2 Application](/images/oauth2_github_new_app.png)

![GitHub OAuth2 Client](/images/oauth2_github_new_client.png)

## oauth2-proxy

https://github.com/oauth2-proxy/oauth2-proxy

https://oauth2-proxy.github.io/oauth2-proxy/

https://oauth2-proxy.github.io/oauth2-proxy/docs/configuration/oauth_provider#github-auth-provider

```bash
$ kubectl -n oauth2-proxy get all
NAME                               READY   STATUS    RESTARTS   AGE
pod/oauth2-proxy-5cd58b4dd-8bn2m   1/1     Running   1          287d

NAME                   TYPE        CLUSTER-IP   EXTERNAL-IP   PORT(S)              AGE
service/oauth2-proxy   ClusterIP   10.43.48.9   <none>        4180/TCP,44180/TCP   287d

NAME                           READY   UP-TO-DATE   AVAILABLE   AGE
deployment.apps/oauth2-proxy   1/1     1            1           287d
```

```bash
$ curl https://oauth2-proxy.my-domain.com/ping
OK

$ curl https://oauth2-proxy.my-domain.com/ping -I
HTTP/2 200
```

## Ingress annotations

```bash
$ kubectl -n grafana get all
NAME                          READY   STATUS    RESTARTS   AGE
pod/grafana-d546f875b-8whml   1/1     Running   4          471d

NAME              TYPE        CLUSTER-IP      EXTERNAL-IP   PORT(S)   AGE
service/grafana   ClusterIP   10.43.220.120   <none>        80/TCP    617d

NAME                      READY   UP-TO-DATE   AVAILABLE   AGE
deployment.apps/grafana   1/1     1            1           617d
```

#### grafana-ingress.yml
```yaml
---
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: grafana
  namespace: grafana
  annotations:
    # enforce TLS/HTTPS
    nginx.ingress.kubernetes.io/ssl-redirect: "true"
    nginx.ingress.kubernetes.io/force-ssl-redirect: "true"
    # instruct ingress-nginx to use oauth2-proxy for traffic authentication/authorization
    nginx.ingress.kubernetes.io/auth-signin: "https://oauth2-proxy.my-domain.com/oauth2/start"
    nginx.ingress.kubernetes.io/auth-url: "https://oauth2-proxy.my-domain.com/oauth2/auth"
    # instruct ingress-nginx and cert-manager to use the clusterissuer we've created earlier for TLS certificates
    cert-manager.io/cluster-issuer: "lets-encrypt"
spec:
  ingressClassName: nginx
  tls:
  - secretName: grafana-ingress-tls
    hosts:
    - grafana.my-domain.com # what certificate should cert-manager request from Let's Encrypt
  rules:
  - host: grafana.my-domain.com
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: grafana
            port:
              number: 80
```

![GitHub OAuth2 Login](/images/oauth2_github_login.png)

![Grafana](/images/oauth2_grafana.png)
