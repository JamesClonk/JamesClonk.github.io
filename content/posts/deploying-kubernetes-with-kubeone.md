---
title: "Deploying Kubernetes with KubeOne"
description: "Using Kubermatic KubeOne to deploy and manage a production-ready, highly-available Kubernetes cluster on Hetzner Cloud"
tags: [kubernetes,kubeone,hetzner,terraform,continuous deployment,containers]
author: Fabio Berchtold
date: 2024-01-02T16:00:00
draft: false
---

## My Kubernetes journey so far

If you've been reading this blog you know I've been through quite the odyssey when it comes to running Kubernetes. It started with a [managed K8s on Scaleway](/posts/migrating-from-cloud-foundry-to-kubernetes/), then I got fed up with the lack of control and built [my own personal K3s cluster](/posts/my-own-kubernetes/) on Hetzner Cloud, later automated the whole thing with [Terraform on vCloud Director](/posts/kubernetes-with-terraform/), and most recently started using [Plato](/posts/template-rendering-with-plato/) for templating and secret management.

K3s has served me incredibly well for my personal projects. It's lightweight, easy to install, and runs happily on a single VM. But what if you need something more... proper? What if you want a real, highly-available, multi-node, CNCF-conformant Kubernetes cluster with a proper control plane? What if you're not just running your personal hobby projects but actually need production-grade infrastructure?

That's where [Kubermatic KubeOne](https://github.com/kubermatic/kubeone) enters the picture. 😎

## What is KubeOne?

KubeOne is an open-source cluster lifecycle management tool by [Kubermatic](https://www.kubermatic.com/). It automates the deployment, upgrading, and repair of Kubernetes clusters on pretty much any infrastructure you can think of, be it cloud, on-prem, edge, bare-metal, etc..

The key thing that sets KubeOne apart from other Kubernetes installers is its approach:
1. **You** provision the infrastructure (VMs, load balancers, networks)
2. **KubeOne** takes that infrastructure and turns it into a production-ready, highly-available Kubernetes cluster
3. **Worker nodes** are managed declaratively via [Kubermatic machine-controller](https://github.com/kubermatic/machine-controller), which is based on the Cluster-API

This separation of concerns is actually quite elegant. KubeOne doesn't try to be everything at once. It doesn't try to manage your VMs or your cloud provider resources. It just takes whatever infrastructure you give it and installs Kubernetes on it. Then via the aforementioned machine-controller it can dynamically create and join new worker nodes to the cluster.

### Natively supported providers

KubeOne has native support for a bunch of providers:
- AWS
- Azure
- DigitalOcean
- GCP
- **Hetzner Cloud** ← this is the one I care about! 😄
- Nutanix
- OpenStack
- VMware Cloud Director
- VMware vSphere

"Native support" means KubeOne comes with ready-made Terraform configs for these providers, integrates with their Cloud-Controller managers, and the machine-controller knows how to provision worker nodes on them automatically.

But even if your provider isn't on this list, KubeOne can still work. You just provision the VMs yourself and point KubeOne at them, it will handle them as baremetal machines.

### What you get out of the box

When KubeOne provisions a cluster, it installs and configures:
- **containerd** as the container runtime
- **Cilium** as the CNI
- **metrics-server** for resource metrics
- **NodeLocal DNSCache** for improved DNS performance
- **Kubermatic machine-controller** for declarative worker node management, akin to Cluster-API

It's *"Kubernetes Conformance Certified"* by the CNCF, so you know you're getting a proper and standards-compliant cluster, not some half-baked custom distribution.

## How does it work?

The workflow is straightforward and consists of a few steps:

### Install KubeOne

```bash
$ curl -sfL get.kubeone.io | sh
```

That's it. Its just a single binary, downloaded and installed. The script also unpacks example Terraform configs for all supported providers. (Though personally I have no need for Terraform anymore these days)

### Provision infrastructure with Terraform

KubeOne includes example Terraform configs for each supported provider. For Hetzner Cloud, you can then do something like this:

```bash
$ cd kubeone_1.12.0_linux_amd64/examples/terraform/hetzner
$ cat > terraform.tfvars <<EOF
cluster_name = "my-k8s-cluster"
ssh_public_key_file = "~/.ssh/id_rsa.pub"
EOF

$ terraform init
$ terraform apply
$ terraform output -json > tf.json
```

The Terraform configs create everything needed: VMs for the control plane nodes, a load balancer in front of them, networks, firewalls, SSH keys, etc.. The `tf.json` output file captures all this information in a format KubeOne can then consume for further steps.

For Hetzner Cloud specifically, you'll need to export your API token first:
```bash
$ export HCLOUD_TOKEN="your-hetzner-api-token"
```

### Create the KubeOne manifest

This is a simple YAML file that describes your desired cluster configuration:

```yaml
apiVersion: kubeone.k8c.io/v1beta2
kind: KubeOneCluster

versions:
  kubernetes: '1.34.1'

cloudProvider:
  hetzner: {}
  external: true
```

That's the entire manifest for a Hetzner Cloud cluster. The `external: true` flag tells KubeOne to deploy the [Hetzner Cloud Controller Manager](https://github.com/hetznercloud/hcloud-cloud-controller-manager), which handles things like node metadata and LoadBalancer services.

You can of course customize this much further. Run `kubeone config print --full` to see all available options.

### Provision the cluster

```bash
$ kubeone apply -m kubeone.yaml -t tf.json
```

KubeOne will analyze the infrastructure described in `tf.json`, SSH into the control plane nodes, and set up a highly-available Kubernetes cluster using kubeadm under the hood. It also deploys the machine-controller which will then automatically create and join the worker nodes.

The output looks something like this:
```
INFO[11:37:21 CEST] Determine hostname…
INFO[11:37:28 CEST] Determine operating system…
INFO[11:37:30 CEST] Running host probes…
The following actions will be taken:
 + initialize control plane node "cp-1" (10.0.0.1) using 1.34.1
 + join control plane node "cp-2" (10.0.0.2) using 1.34.1
 + join control plane node "cp-3" (10.0.0.3) using 1.34.1
 + ensure machinedeployment "workers-pool-a" with 2 replica(s) exists

Do you want to proceed (yes/no): yes
```

After about 5-10 minutes you'll have a fully functional, HA Kubernetes cluster. KubeOne automatically downloads the kubeconfig for you:

```bash
$ export KUBECONFIG=$PWD/my-k8s-cluster-kubeconfig
$ kubectl get nodes
NAME    STATUS   ROLES           AGE   VERSION
cp-1    Ready    control-plane   10m   v1.34.1
cp-2    Ready    control-plane   8m    v1.34.1
cp-3    Ready    control-plane   8m    v1.34.1
w-1     Ready    <none>          5m    v1.34.1
w-2     Ready    <none>          5m    v1.34.1
```

Three control plane nodes, two workers, all running and healthy. 🎉

## Upgrading your cluster

One of the things I really appreciate about KubeOne is how it handles upgrades. If you've ever dealt with Kubernetes then you know how upgrading it can be a nerve-wracking experience, but with KubeOne it's almost boringly simple.

Just change the version in your manifest:
```yaml
versions:
  kubernetes: '1.34.5'
```

And run apply again:
```bash
$ kubeone apply -m kubeone.yaml -t tf.json
```

KubeOne will detect that the running cluster version doesn't match the desired version and perform a rolling upgrade of all control plane nodes, one by one. After the control plane is upgraded, the machine-controller takes care of rolling out new worker nodes with the updated version. The result will be a complete upgrade with zero downtime and fully automated.

KubeOne uses the same `apply` command for everything: initial provisioning, upgrades, configuration changes, repairs. It figures out what needs to be done by comparing the desired state (the manifest file) with the actual state (what's running on the cluster).

## KubeOne vs. K3s

"But James, you've been happily running K3s for years, why would you even look at KubeOne? 🙎‍♀"

Well... it depends! As always in IT 😂

They both have pros and cons:

**K3s:**
- You want a single-node or small cluster for personal projects
- You need minimal resource usage (K3s runs happily on 1 vCPU / 2GB RAM)
- You want the simplest possible setup with zero ceremony
- You're fine managing everything yourself with shell scripts

**KubeOne:**
- You need a proper HA cluster with multiple control plane nodes
- You want CNCF-conformant, production-grade Kubernetes
- You need automated worker node management via machine-controller
- You want a standardized upgrade and lifecycle management process
- You're running workloads that actually matter and need reliability guarantees

K3s is perfect for my personal blog infrastructure and hobby projects. But if I were setting up Kubernetes for a team or a company, I'd reach for KubeOne without hesitation. The much easier to setup HA control plane alone is worth it, nevermind the automatic provisioning and management of dynamic worker nodes via machine-controller!

## So what's this all about?

KubeOne fills a nice gap in the Kubernetes tooling landscape. It's a focused, well-designed cluster lifecycle management tool that does one thing and does it well: take your infrastructure and turn it into a production-ready Kubernetes cluster, then keep it healthy and up-to-date. With dynamic worker node scaling!

If you're currently managing Kubernetes clusters with a pile of shell scripts and prayers, then I'd suggest to give KubeOne a serious look. It might just save you a lot of headaches.

Check out the project on [GitHub](https://github.com/kubermatic/kubeone)
And the documentation: https://docs.kubermatic.com/kubeone/

Happy HA-clustering! 🚀
