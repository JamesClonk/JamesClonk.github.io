---
title: "Deploy a K3s cluster with Terraform"
description: "How to deploy a K3s Kubernetes cluster with Terraform on VMware vCloud Director"
tags: [kubernetes,vmware,vcloud,continuous deployment,github actions,github,containers,k3s,terraform]
author: Fabio Berchtold
date: 2022-10-24T17:55:21
draft: true
---

Since [Infrastructure-as-Code](https://en.wikipedia.org/wiki/Infrastructure_as_code) is all the rage out there (and for good reason, you're a fool if your entire tech stack is not 100% rebuildable and reproducible in an idempotent way!), I've always wondered if I should write and open-source a project that's written entirely as a Terraform module only and that would spin up a Kubernetes cluster on Swisscom's public VMware vCloud Director offering ([DCS+ / Dynamic Computing Services](https://www.swisscom.ch/en/business/enterprise/offer/cloud/cloudservices/dynamic-computing-services.html)).

Behold: ✨ [https://github.com/JamesClonk/terraform-vcloud-kubernetes](https://github.com/JamesClonk/terraform-vcloud-kubernetes) 🎉

The resulting Terraform module supports you in creating a Kubernetes cluster with K3s on Swisscom DCS+ infrastructure. It sets up all necessary infrastructure on DCS+ through the [vCloud provider](https://www.terraform.io/docs/providers/vcd/), then installs K3s on all VMs and joins them into a Kubernetes cluster, and finally also installs and manages additional [Helm](https://helm.sh/) charts on the cluster, such as [cilium](https://cilium.io/), [ingress-nginx](https://kubernetes.github.io/ingress-nginx/), [cert-manager](https://cert-manager.io/), [longhorn](https://longhorn.io/), and a whole set of logging/metrics/monitoring related components.

## K3s

A quick recap: What is [**K3s**](https://k3s.io/)?

> *K3s is a lightweight, CNCF certified Kubernetes distribution created by Rancher Labs, that is highly available and designed for production workloads in unattended, resource-constrained, remote locations or inside IoT appliances. It is built and packaged into a single small binary with low resource requirements and very easy to install, run and auto-update a production-grade Kubernetes cluster with.*

If you want to know more about how I've used K3s before, have a look at my previous blog post about [my own personal Kubernetes, with K3s](/posts/my-own-kubernetes/#k3s).

## Terraform

Another quick recap: What is [**Terraform**](https://www.terraform.io/)?

> *Terraform is (arguably) the most popular open-source Infrastructure-as-Code tool out there. It allows to easily define, provision and manage your entire infrastructure using a declarative configuration language. It works out-of-the-box with most of the well-known infrastructure provider like GCP, AWS, Azure, etc. and all of their services. Terraform functionality and support for different infrastructure platforms and resources can also easily be extended by installing additional Terraform [provider plugins](https://registry.terraform.io/).*

If you want to know more about Terraform, have a look at another one of my previous blog posts: [Setting up NSX-T Distributed Firewall with Terraform](/posts/setting-up-nsx-t-with-terraform/#terraform).

## VMware vCloud Director

[VMware vCloud Director](https://www.vmware.com/products/cloud-director.html) (vCD) is a tool with which you can build your own Infrastructure-as-a-Service platform, that can provide and manage on-premise infrastructure and virtual data centers, containing all the necessary building blocks for a *"cloud"* service, such virtual machines, disks, networks, firewalls, loadbalancers, deployments and automation.

vCD allows you to turn existing data centers into scalable and elastic software-defined virtual data centers (so called VDCs).
With it you can convert and combine all your physical data center resources, VMware vSphere and vCenters, NSX networks, storage, etc., into VDC resources which you then make available to developers and users through a web portal or API.

In short, it basically enables you to have your own on-premise *"cloud"*, analogous to medium-scalers like **DigitalOcean, Linode, Hetzer, Exoscale, Scaleway,** etc..

It provides a solid web UI, a mostly modern and useful API (for VMware or typical enterprisey-sluggish standards anyway), and has an official [Terraform provider for vCloud](https://github.com/vmware/terraform-provider-vcd) that allows full control over all its resources and features with Terraform.
And while I'm not privy to the efforts needed behind the scenes to run and operate it (having to deal with VMware vSphere, vCenter, NSX-V/T, etc. is not something I would particularly envy), I can say that at least vCD from a developer and end-user perspective it is very nice and productive to work with.
It provides you with all the basic components you'd usually expect from an Infrastructure-as-a-Service provider and allows you to build and deploy your own platform and software solutions on top of it.

## Putting it all together

// TODO: write..

![vCloud UI](https://raw.githubusercontent.com/JamesClonk/terraform-vcloud-kubernetes/data/dcs_dashboard.png)

![Architecture](https://raw.githubusercontent.com/JamesClonk/terraform-vcloud-kubernetes/data/dcs_k8s.png)

![K3s on vCloud](https://raw.githubusercontent.com/JamesClonk/terraform-vcloud-kubernetes/data/dcs_k8s_dashboard.png)

## Automated testing

// TODO: write..
