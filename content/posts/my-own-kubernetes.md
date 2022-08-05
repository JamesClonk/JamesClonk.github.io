---
title: "My own personal Kubernetes"
description: "How I setup my own personal Kubernetes cluster on Hetzner Cloud"
tags: [kubernetes,hetzner,continuous deployment,github actions,github,containers,k3s]
author: Fabio Berchtold
date: 2020-11-30T12:49:34+02:00
draft: false
---

## Managed Kubernetes?

On my journey where I was (unfortunately) forced to migrate from [Cloud Foundry](https://www.cloudfoundry.org/) to Kubernetes, I first went with a "Managed Kubernetes-as-a-Service" offering. You can read about that [here](/posts/migrating-from-cloud-foundry-to-kubernetes/).

But it didn't take long for problems and issues to start emerging. The cluster not being on exactly the version I wanted it to be, pre-installed components that didn't behave they way I wanted (nginx ingress controller for example), price hikes and occasional outages, not really a lot of insight into the behind the scenes of my cluster, etc.

Also, I was continuously adding and deploying more additional components onto the cluster, like Prometheus, Grafana, Loki, etc.. The resource requirements kept creeping upwards, I had to add more nodes (or beef-up the existing ones), which again meant further cost increases than anticipated.

At some point I was simply too fed up with the lack of direct control I had over this situation and bit the bullet: It's time to deploy and manage my own K8s cluster! After all, I'm a relentless DevOps engineer.. 😎

To install and manage your own Kubernetes cluster you will need some (well, at least one) VMs. Now, where can I find some of these?

## Hetzner Cloud

While looking for the ideal place to host my Kubernetes cluster I was going through all of the usual cloud providers to see which one would fit my use case best.

The 3 big ones are just way too expensive to host VMs with my small-ish vCPU and RAM requirements (I was looking for something with around 4+ vCPUs and 8GB RAM), so that's a no-go.
DigitalOcean, Linode and Vultr were still a bit too pricey for my taste, I really didn't care too much about performance. The most important factor really was just how much RAM does the VM have, as that will determine what K8s deployments and pods, etc. I can cram onto the cluster at once. 4 vCPUs and 8GB RAM was around $50 per month on these, that was still more than I was willing to pay.

The winner in the end was [Hetzner Cloud](https://www.hetzner.com/cloud). They offer such a 4/8 VM for as low as $15 per month.
This turned out to be so cheap that I actually ended up choosing a much beefier VM, the CPX41, which has 8 vCPUs and 16GB of RAM for just $28 per month. Wow! 😲

Looking through all the features of Hetzner Cloud I saw that they also provide all the other things I might need for my Kubernetes cluster. They've got attachable, persistent block storage volumes for their VMs and provide a Kubernetes [CSI driver](https://github.com/hetznercloud/csi-driver) for them. They've got Floating IPs I can attach to VMs (to have a persistent IP thats decoupled from the VMs lifecycle), HTTP(S)/TLS Load Balancers (I don't need one but the fact it's available is a big plus!), custom private networks for my VMs, configurable firewalls, and everything fully accessible via an [API](https://developers.hetzner.com/cloud/) (with Terraform plugins available for it) or the handy hcloud[^1] CLI.

A bit of googling revealed that I seem to be not the only one making that choice, there's loads of projects and tools out there that provision Kubernetes on Hetzner Cloud one way or another.

In the end my setup ended up rather simple:
- Provision a CPX41 VM
- Attach a Floating IP to it
- Configure my DNS entries to point to said IP
- Configure the Hetzner Cloud Firewall for the VM
- ... aaaand that's it. Nothing else left to do here.

## K3s

Now, how do we install and setup Kubernetes on this VM? What "*distribution*" do we want to use?

Using plain [`kubeadm`](https://kubernetes.io/docs/setup/production-environment/tools/kubeadm/) would be way too cumbersome, I certainly did not want to invest that much time in setting up my cluster and having to maintain and babysit it on such a low level.

[Minikube](https://minikube.sigs.k8s.io/) or [kind](https://kind.sigs.k8s.io/)? Nope. These are fantastic tools for local K8s development, but I do not want to use them for running a production cluster (and neither should you!). [kOps](https://kops.sigs.k8s.io/)? Meh, tries to do too many things at once while still being quite fiddly.

[MicroK8s](https://microk8s.io/)? Hmm, now we're getting closer. MicroK8s ticks a lot of the right boxes, but it is from Canonical and unfortunately distributed as a Snap install, and that's something that can go burn in hell! 🔥

In the end it was a showdown between [K0s](https://k0sproject.io/) and [K3s](https://k3s.io/), both being very similar to each other and focused on small, self-contained single binaries with low resource usage. I went with K3s, because ultimately it had an edge in terms resource consumption and usability. Plus I'm fond of Rancher Labs products, so that was a plus already.

So what is [**K3s**](https://k3s.io/)?

> *K3s is a lightweight, CNCF certified Kubernetes distribution created by Rancher Labs, that is highly available and designed for production workloads in unattended, resource-constrained, remote locations or inside IoT appliances. It is built and packaged into a single small binary with low resource requirements and very easy to install, run and auto-update a production-grade Kubernetes cluster with.*

In short, it is exactly what I need, perfect for my use case! Especially the low resource requirements make it perfect for my purpose, after all the single VM I'm going to use will not be super large and powerful, I only need to run some of the usual suspects (Prometheus, Grafana, Loki, etc.) plus my own applications on that Kubernetes cluster.

Installing K3s turned out to be as simple as running this:

```bash
curl -sfL https://get.k3s.io | \
	INSTALL_K3S_VERSION='v1.20.8+k3s1' \
	INSTALL_K3S_EXEC='--disable=traefik --disable=servicelb' \
	sh -
```

Using the installation script, it will install K3s as a systemd service and start it. If the service already exists it will update if necessary and check if it is running.

I've explicitely specified and pinned the Kubernetes version that I want via `$INSTALL_K3S_VERSION` environment variable, and also disabled the default installation of Traefik and Klipper through `$INSTALL_K3S_EXEC` and `--disable`. These and many more options are all described in the excellent [K3s documentation](https://rancher.com/docs/k3s/latest/en/installation/).

The reason for disabling those two components was that I intend to use the much simpler and more common [Ingress-NGINX](https://kubernetes.github.io/ingress-nginx/) as my ingress controller instead of Traefik, and also have no need for Load Balancer support since I'm going to deploy Ingress-NGINX with **hostPort**'s 80 and 443 assigned to it directly. After all it is only a single VM Kubernetes "cluster".

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
| [Hetzner Cloud CSI driver](https://github.com/hetznercloud/csi-driver) | Kubernetes Container Storage Interface driver for Hetzner Cloud Volumes | https://github.com/hetznercloud/csi-driver |
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

##### .github/workflows/pipeline.yml
```yaml
name: kubernetes production

on:
  push:
    branches: [ master ]

env:
  AWS_ACCESS_KEY_ID: ${{ secrets.AWS_ACCESS_KEY_ID }}
  AWS_SECRET_ACCESS_KEY: ${{ secrets.AWS_SECRET_ACCESS_KEY }}
  ENVIRONMENT: production

jobs:
  hetzner-k3s: # pipeline entry job, installs k3s on hetzner cloud VM
    name: kubernetes
    runs-on: ubuntu-latest
    steps:
    - uses: actions/checkout@v2
    - name: install and upgrade k3s on hetzner cloud
      working-directory: hetzner-k3s
      run: ./deploy.sh

  kube-system: # do some modifications to kube-system namespace
    name: kube-system
    needs: [ hetzner-k3s ] # depends on installed k3s, obviously
    runs-on: ubuntu-latest
    steps:
    - uses: actions/checkout@v2
    - name: prepare kube-system namespace
      working-directory: kube-system
      run: ./deploy.sh

  hcloud-csi: # install the hetzner cloud CSI driver for Kubernetes
    name: hcloud-csi
    needs: [ kube-system ] # depends on kube-system namespace
    runs-on: ubuntu-latest
    steps:
    - uses: actions/checkout@v2
    - name: install hetzner csi driver
      working-directory: hcloud-csi
      run: ./deploy.sh

  ingress-nginx: # install nginx ingress controller, we want to use Ingress resources!
    name: ingress-nginx
    needs: [ kube-system ] # depends on kube-system namespace
    runs-on: ubuntu-latest
    steps:
    - uses: actions/checkout@v2
    - name: deploy kubernetes ingress controller
      working-directory: ingress-nginx
      run: ./deploy.sh

  cert-manager: # install cert-manager for certificate handling of ingress routes
    name: cert-manager
    needs: [ ingress-nginx ] # depends on ingress-nginx being installed already
    runs-on: ubuntu-latest
    steps:
    - uses: actions/checkout@v2
    - name: deploy cert-manager for let's encrypt
      working-directory: cert-manager
      run: ./deploy.sh

... and much more
```
![GitHub Actions Pipeline](/images/k8s-github-actions.png)

Each of the components corresponds to a GitHub Actions [job](https://docs.github.com/en/actions/using-jobs/using-jobs-in-a-workflow) within the same [workflow](https://docs.github.com/en/actions/using-workflows/about-workflows), defining its dependencies / prerequisites if it has any. All a job has to do is simply run `./deploy.sh`. The whole workflow in turn gets triggered by any new `git push` on the `master` branch, and goes through all these jobs as defined.

I've also added several on-demand workflows to the repository, so I could for example restart the K3s systemd service on the VM if I want to via manually triggering that on GitHub Actions:

##### .github/workflows/restart-k3s.yml
```yaml
name: restart k3s service

on: # workflow_dispatch means on-demand / manual triggering on GitHub web UI
  workflow_dispatch:

env:
  AWS_ACCESS_KEY_ID: ${{ secrets.AWS_ACCESS_KEY_ID }}
  AWS_SECRET_ACCESS_KEY: ${{ secrets.AWS_SECRET_ACCESS_KEY }}
  ENVIRONMENT: production

jobs:
  restart-k3s: # restart k3s systemd service on hetzner cloud VM
    name: kubernetes
    runs-on: ubuntu-latest
    steps:
    - uses: actions/checkout@v2
    - name: restart k3s service
      working-directory: hetzner-k3s
      run: ./restart.sh
```
![On-Demand Workflows](/images/k8s-github-actions-dispatch.png)

Now I don't even have to log-in anymore to the Hetzner Cloud VM, I can control most of what I need to do through the GitHub web UI. 😄

For my actual applications that I want to host on Kubernetes (the reason why I have a K8s cluster in the first place) I did pretty much the same, they are all bundled together in [https://github.com/JamesClonk/k8s-deployments](https://github.com/JamesClonk/k8s-deployments), and are automatically deployed via GitHub Actions too.

[^1]: [hcloud](https://github.com/hetznercloud/cli) - A command-line interface for Hetzner Cloud
[^2]: [vendir](https://carvel.dev/vendir/) - Declaratively state what files should be in a directory
[^3]: [ytt](https://carvel.dev/ytt/) - Template and overlay Kubernetes configuration via YAML structures
[^4]: [kapp](https://carvel.dev/kapp/) - Deploy and view groups of Kubernetes resources as applications
