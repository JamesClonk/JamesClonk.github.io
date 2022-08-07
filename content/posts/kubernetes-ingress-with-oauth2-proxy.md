---
title: "Ingress with automatic TLS certificates and GitHub OAuth2"
description: "How to setup a K8s Ingress with automatic TLS certificates from Let's Encrypt and GitHub authentication via oauth2-proxy"
tags: [kubernetes,ingress,oauth2-proxy,github,cert-manager,lets-encrypt]
author: Fabio Berchtold
date: 2022-01-11T19:22:49+02:00
draft: true
---

// TODO: explain k8s ingress-nginx with oauth2-proxy with github auth

## Ingress Controller

## Cert-Manager

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

## oauth2-proxy

## GitHub OAuth2

## Ingress annotations

#### grafana-ingress.yml
```yaml
---
apiVersion: networking.k8s.io/v1beta1
kind: Ingress
metadata:
  name: grafana
  namespace: grafana
  annotations:
    kubernetes.io/ingress.class: "nginx"
    # enforce TLS/HTTPS
    nginx.ingress.kubernetes.io/ssl-redirect: "true"
    nginx.ingress.kubernetes.io/force-ssl-redirect: "true"
    # instruct ingress-nginx to use oauth2-proxy for traffic authentication/authorization
    nginx.ingress.kubernetes.io/auth-signin: "https://oauth2-proxy.my-domain.com/oauth2/start"
    nginx.ingress.kubernetes.io/auth-url: "https://oauth2-proxy.my-domain.com/oauth2/auth"
    # instruct ingress-nginx and cert-manager to use the clusterissuer we've created earlier for TLS certificates
    cert-manager.io/cluster-issuer: "lets-encrypt"
spec:
  tls:
  - secretName: grafana-ingress-tls
    hosts:
    - grafana.my-domain.com # what certificate should cert-manager request from Let's Encrypt
  rules:
  - host: grafana.my-domain.com
    http:
      paths:
      - backend:
          serviceName: grafana
          servicePort: 80
```
