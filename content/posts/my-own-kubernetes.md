---
title: "My own personal Kubernetes"
description: ""
tags: [kubernetes,hetzner,continuous deployment,github actions,github,containers,k3s]
authors: []
author: Fabio Berchtold
date: 2020-11-30T12:49:34+02:00
draft: true
---

## Managed Kubernetes?

On my journey where I was (unfortunately) forced to migrate from [Cloud Foundry](https://www.cloudfoundry.org/) to Kubernetes, I first went with a "Managed Kubernetes-as-a-Service" offering. You can read about that [here](/posts/migrating-from-cloud-foundry-to-kubernetes/).

But it didn't take long for problems and issues to start emerging. The cluster not being on exactly the version I wanted it to be, pre-installed components that didn't behave they way I wanted (nginx ingress controller for example), price hikes and occasional outages, not really a lot of insight into the behind the scenes of my cluster, etc.

Also, I was continuously adding and deploying more additional components onto the cluster, like Prometheus, Grafana, Loki, etc.. The resource requirements kept creeping upwards, I had to add more nodes (or beef-up the existing ones), which again meant further cost increases than anticipated.

At some point I was simply too fed up with the lack of direct control I had over this situation and bit the bullet: It's time to deploy and manage my own K8s cluster! After all, I'm a relentless DevOps engineer.. 😎

>>>>>> #### TODO: mention cf-to-k8s migration here, went to scaleway cause cheap and simple. but problems, issues, price hikes.
>>>>>> too expensive, what now? other providers? nope
>>>>>> manage your own k8s? oof, but okay, we have to do it..
>>>>>> but where?

## Hetzner Cloud

>>>>>> #### TODO: cheap VMs, simple to use, has CLI / API, has floating IPs and loadbalancers, has block storage, has K8s CSI driver for said block storage, has firewalls, good community support for running self-managed K8s on it
>>>>>> #### hcloud[^1] CLI

## K3s

>>>>>> #### TODO: kubeadm to cumbersome, but what else? Minikube or kind? Nope, meant for dev not prod. K3s? Yes!

## Batteries included? 🔋

We've got our cluster up and running! But what now?
The problem is that plain Kubernetes alone is not really useful yet and still a far cry away from a PaaS like Cloud Foundry. 🤷

This is where the "Batteries included" part comes into play.

To turn this Kubernetes cluster into something more of a PaaS we will need to add and deploy several more components, to have things like **route and certificate management**, **metrics**, **log collection**, **databases**, **dashboards**, **monitoring and alerting**, etc.. Kubernetes unfortunately does not provide any of these things out of the box, you're on your own.

Now this is where the real work happens. I had to spend quite a bit of effort in figuring out the best way to solve each of these problems, and integrate everything together into one coherent solution.

Another thing at this point was that I also wanted to have the whole installation of K3s onto the Hetzner Cloud VM and even provisioning the VM to be completely automated and reproducible, if I ever need to spin up a new or another cluster quickly.

The result is this: [https://github.com/JamesClonk/k8s-infrastructure](https://github.com/JamesClonk/k8s-infrastructure)
### [My Kubernetes infrastructure repository](https://github.com/JamesClonk/k8s-infrastructure)


![Architecture](https://github.com/JamesClonk/k8s-infrastructure/raw/master/docs/architecture.png)

I've decided to install the following additional *system components* onto my Kubernetes cluster, to turn it into a PaaS-like experience:

| Name | Description | URL |
| --- | --- | --- |
| [NGINX Ingress Controller](https://kubernetes.github.io/ingress-nginx) | An Ingress controller for Kubernetes using NGINX as a reverse proxy and load balancer | https://github.com/kubernetes/ingress-nginx |
| [oauth2-proxy](https://oauth2-proxy.github.io/oauth2-proxy/) | A proxy that provides authentication with Google, Azure, OpenID Connect and many more identity providers | https://github.com/oauth2-proxy/oauth2-proxy |
| [cert-manager](https://cert-manager.io) | Automatic certificate management on top of Kubernetes, using [Let's Encrypt](https://letsencrypt.org) | https://github.com/jetstack/cert-manager |
| [Kubernetes Dashboard](https://kubernetes.io/docs/tasks/access-application-cluster/web-ui-dashboard) | General-purpose web UI for Kubernetes clusters | https://github.com/kubernetes/dashboard |
| [kube-state-metrics](https://github.com/kubernetes/kube-state-metrics) | Add-on agent to generate and expose cluster-level metrics | https://github.com/kubernetes/kube-state-metrics |
| [Prometheus](https://prometheus.io) | Monitoring & alerting system, and time series database for metrics | https://github.com/prometheus |
| [Loki](https://grafana.com/oss/loki) | A horizontally-scalable, highly-available, multi-tenant log aggregation system | https://github.com/grafana/loki |
| [Grafana](https://grafana.com/grafana) | Monitoring and metric analytics & dashboards for Prometheus and Loki | https://github.com/grafana/grafana |
| [PostgreSQL](https://www.postgresql.org) | The world's most advanced open source relational database | https://www.postgresql.org/docs |

I've added each of these components vendored with vendir[^2] into a subdirectory in the main k8s-infrastructure repository, containing upstream deployment templates (be it a Helm chart, kustomize templates, release.yaml's, or in whatever other format the component is made available by its maintainers).

Each of them has its own `deploy.sh` shellscript, which uses the vendired upstream templates together with additional ytt[^3] overlay templates to deploy against Kubernetes with kapp[^4]. Whenever I want to deploy let's say for example `oauth2-proxy`, all I need to do is go into that directoy and run the shellscript.

The idea behind this is that it must be entirely reproducable and idempotent, I want to be able to re-run the `deploy.sh` as often as I like and it should just do its thing and ensure the same components with the same configuration get applied to the cluster each time as expected.

After all of these components are installed, it allows me to focus on the actual applications I want to develop and run "*in the cloud*". Let's assume I have a simple website app, what I now can do to deploy and run it on my cluster is this:

- define a K8s **Deployment** and **Service** resource for my app container / image
- define a K8s **Ingress** resource

And that's it. The Deployment and Service are as per usual, but the magic happens thanks to the Ingress. The Ingress resource will instruct the ingress-nginx controller to create and handle all traffic for a "route", for example ht<span>tps://</span>my-app.my-k8s-cluster.com, and cert-manager will automatically issue a [Let's Encrypt certificate](https://letsencrypt.org/) for it. Also thanks to oauth2-proxy all I need to do is add a specific annotation on the Ingress resource to instruct the ingress controller to redirect all traffic for this particular route through oauth2-proxy, which will then in turn authenticate against my [GitHub OAuth2 app](https://docs.github.com/en/developers/apps/building-oauth-apps/creating-an-oauth-app) configuration.

It's still a lot more involved than a simple `cf push` on Cloud Foundry, but it's worlds apart from having to deal with just plain Kubernetes as an app developer.

With Prometheus and Alertmanager being installed on the cluster I've now also got the benefit of being able to monitor everything with Grafana dashboards and set up automated alerts that ping me on Slack.

## Automation via GitHub Actions

But why run a `deploy.sh` shellscript manually for all of these components if you can automate it, right? Same with installing or updating K3s on the Hetzner Cloud VM, I can't be bothered to do that myself. Let's automate everything with GitHub Actions! 😁

Since I've already insisted on having everything fully scripted idempotently within shellscripts, and each component having its own set of them, I had no trouble turning this into GitHub Actions pipeline:

![GitHub Actions Pipeline](/images/k8s-github-actions.png)

Each of the components corresponds to a GitHub Actions [job](https://docs.github.com/en/actions/using-jobs/using-jobs-in-a-workflow) within the same [workflow](https://docs.github.com/en/actions/using-workflows/about-workflows), defining its dependencies / prerequisites if it has any. All a job has to do is simply run `./deploy.sh`. The whole workflow in turn gets triggered by any new `git push` on the `master` branch, and goes through all these jobs as defined.

I've also added several on-demand workflows to the repository, so I could for example restart the K3s systemd service on the VM if I want to via manually triggering that on GitHub Actions:

![On-Demand Workflows](/images/k8s-github-actions-dispatch.png)

Now I don't even have to log-in anymore to the Hetzner Cloud VM, I can control most of what I need to do through the GitHub web UI. 😄

[^1]: [hcloud](https://github.com/hetznercloud/cli) - A command-line interface for Hetzner Cloud
[^2]: [vendir](https://carvel.dev/vendir/) - Declaratively state what files should be in a directory
[^3]: [ytt](https://carvel.dev/ytt/) - Template and overlay Kubernetes configuration via YAML structures
[^4]: [kapp](https://carvel.dev/kapp/) - Deploy and view groups of Kubernetes resources as applications
