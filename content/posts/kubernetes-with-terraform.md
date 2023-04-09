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

The resulting Terraform module I've written supports you in creating a Kubernetes cluster with K3s on Swisscom DCS+ infrastructure. It sets up all necessary infrastructure on DCS+ through the [vCloud provider](https://www.terraform.io/docs/providers/vcd/), then installs K3s on all VMs and joins them into a Kubernetes cluster, and finally also installs and manages additional [Helm](https://helm.sh/) charts on the cluster, such as [cilium](https://cilium.io/), [ingress-nginx](https://kubernetes.github.io/ingress-nginx/), [cert-manager](https://cert-manager.io/), [longhorn](https://longhorn.io/), and a whole set of logging/metrics/monitoring related components.

## K3s

A quick recap: What is [**K3s**](https://k3s.io/)?

> *K3s is a lightweight, CNCF certified Kubernetes distribution created by Rancher Labs, that is highly available and designed for production workloads in unattended, resource-constrained, remote locations or inside IoT appliances. It is built and packaged into a single small binary with low resource requirements and very easy to install, run and auto-update a production-grade Kubernetes cluster with.*

If you want to know more about how I've used K3s before, have a look at my previous blog post about [my own personal Kubernetes, with K3s](/posts/my-own-kubernetes/#k3s).

## Terraform

Another quick recap: What is [**Terraform**](https://www.terraform.io/)?

> *Terraform is (arguably) the most popular open-source Infrastructure-as-Code tool out there. It allows to easily define, provision and manage your entire infrastructure using a declarative configuration language. It works out-of-the-box with most of the well-known infrastructure provider like GCP, AWS, Azure, etc. and all of their services. Terraform functionality and support for different infrastructure platforms and resources can also easily be extended by installing additional Terraform [provider plugins](https://registry.terraform.io/).*

If you want to know more about Terraform, have a look at another one of my previous blog posts: [Setting up NSX-T Distributed Firewall with Terraform](/posts/setting-up-nsx-t-with-terraform/#terraform).

## VMware vCloud Director

// TODO: write..

## Putting it all together

// TODO: write..

## Automated testing

// TODO: write..
