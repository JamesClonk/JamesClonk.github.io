---
title: "My own personal Kubernetes"
description: ""
tags: [kubernetes,hetzner,continuous deployment,github actions,github,containers,k3s]
authors: []
author: Fabio Berchtold
date: 2020-11-30T12:49:34+02:00
draft: true
---

#### TODO: show k8s-infra repo here (and mention you now migrated k8s-deployment repo (migrating-from-cloud-foundry-to-kubernetes.md) to be deployed onto this k8s cluster)

## Managed Kubernetes?

## Hetzner Cloud

## K3s

## Batteries included? 🔋

We've got our K8s cluster up and running! But what now?
The problem is that plain Kubernetes alone is not really useful yet and still a far cry away from a PaaS like [Cloud Foundry](https://www.cloudfoundry.org/). 🤷

This is where the "Batteries included" part comes into play.

To turn this Kubernetes cluster into something more of a PaaS we will need to add and deploy several more components, to have things like **route and certificate management**, **metrics**, **log collection**, **databases**, **dashboards**, **monitoring and alerting**, etc.. Kubernetes unfortunately does not provide any of these things out of the box, you're on your own.

Now this is where the real work happens. I had to spend quite a bit of effort in figuring out the best way to solve each of these problems, and integrate everything together into one coherent solution.

The result is this:

![Architecture](https://github.com/JamesClonk/k8s-infrastructure/raw/master/docs/architecture.png)

I've decided to install the following additional *system components* onto my Kubernetes cluster, to turn it into a PaaS-like experience:

| Name | Description | URL |
|-|-|-|
| [NGINX Ingress Controller](https://kubernetes.github.io/ingress-nginx) | An Ingress controller for Kubernetes using NGINX as a reverse proxy and load balancer | https://github.com/kubernetes/ingress-nginx |
| [oauth2-proxy](https://oauth2-proxy.github.io/oauth2-proxy/) | A proxy that provides authentication with Google, Azure, OpenID Connect and many more identity providers | https://github.com/oauth2-proxy/oauth2-proxy |
| [cert-manager](https://cert-manager.io) | Automatic certificate management on top of Kubernetes, using [Let's Encrypt](https://letsencrypt.org) | https://github.com/jetstack/cert-manager |
| [Kubernetes Dashboard](https://kubernetes.io/docs/tasks/access-application-cluster/web-ui-dashboard) | General-purpose web UI for Kubernetes clusters | https://github.com/kubernetes/dashboard |
| [kube-state-metrics](https://github.com/kubernetes/kube-state-metrics) | Add-on agent to generate and expose cluster-level metrics | https://github.com/kubernetes/kube-state-metrics |
| [Prometheus](https://prometheus.io) | Monitoring & alerting system, and time series database for metrics | https://github.com/prometheus |
| [Loki](https://grafana.com/oss/loki) | A horizontally-scalable, highly-available, multi-tenant log aggregation system | https://github.com/grafana/loki |
| [Grafana](https://grafana.com/grafana) | Monitoring and metric analytics & dashboards for Prometheus and Loki | https://github.com/grafana/grafana |
| [PostgreSQL](https://www.postgresql.org) | The world's most advanced open source relational database | https://www.postgresql.org/docs |

I've added each of these components into a [vendired](https://carvel.dev/vendir/) subdirectory in the main k8s-infrastructure repository, containing upstream deployment templates (be it a Helm chart, kustomize templates, release.yaml's, or in whatever other format the component is made available by its maintainers).

Each of them has its own `deploy.sh` shellscript, which uses the vendired upstream templates together with additional [ytt overlay templates](https://carvel.dev/ytt/) to deploy against Kubernetes with [kapp](https://carvel.dev/kapp/). Whenever I want to deploy let's say for example `oauth2-proxy`, all I need to do is go into that directoy and run the shellscript.

The idea behind this is that it must be entirely reproducable and idempotent, I want to be able to re-run the `deploy.sh` as often as I like and it should just do its thing and ensure the same components with the same configuration get applied to the cluster each time as expected.

After all of these components are installed, it allows me to focus on the actual applications I want to develop and run "*in the cloud*". Let's assume I have a simple website app, what I now can do to deploy and run it on my cluster is this:

- define a K8s **Deployment** and **Service** resource for my app container / image
- define a K8s **Ingress** resource

And that's it. The Deployment and Service are as per usual, but the magic happens thanks to the Ingress. The Ingress resource will instruct the ingress-nginx controller to create and handle all traffic for a "route", for example ht<span>tps://</span>my-app.my-k8s-cluster.com, and cert-manager will automatically issue a [Let's Encrypt certificate](https://letsencrypt.org/) for it. Also thanks to oauth2-proxy all I need to do is add a specific annotation on the Ingress resource to instruct the ingress controller to redirect all traffic for this particular route through oauth2-proxy, which will then in turn authenticate against my [GitHub OAuth2 app](https://docs.github.com/en/developers/apps/building-oauth-apps/creating-an-oauth-app) configuration.

It's still a lot more involved than a simple `cf push` on Cloud Foundry, but it's worlds apart from having to deal with just plain Kubernetes as an app developer.

## Automation via GitHub Actions

But why run a `deploy.sh` shellscript manually for all of these components if you can automate it, right? Same with installing or updating K3s on the Hetzner Cloud VM, I can't be bothered to do that myself. Let's automate everything with GitHub Actions! 😁
