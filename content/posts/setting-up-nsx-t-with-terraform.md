---
title: "Setting up NSX-T Distributed Firewall with Terraform"
description: "How to setup NSX-T DFW rules with Terraform, the Infrastructure-as-Code way"
tags: [terraform,nsx-t,vmware,firewall]
author: Fabio Berchtold
date: 2022-07-31T12:33:24+02:00
draft: true
---

## NSX-T

// TODO: explain what is NSX-T/sdn here very briefly, mention DFW..
// TODO: https://docs.vmware.com/en/VMware-NSX-T-Data-Center/3.2/administration/GUID-6AB240DB-949C-4E95-A9A7-4AC6EF5E3036.html

## Infrastructure-as-Code (IaC)

[Infrastructure-as-Code](https://www.redhat.com/en/topics/automation/what-is-infrastructure-as-code-iac) is the process of defining, provisioning and managing infrastructure resources like VMs, networks, load-balancers, Kubernetes clusters, disks and storage, etc. through code, rather than manual work or interactive configuration tools.
With IaC you write configuration files, or code, that then can repeatably be run to create all your infrastructure resources in a 100% reproducible and idempotent way. These configuration files are usually also store in a version control repository, like git, and can then further be used to setup automated GitOps deployment pipelines that will update your infrastructure everytime there is a new commit or change in the configuration files. It is best practice to not _ever_ manually manage any infrastructure like for example VMs through any manual interaction or tampering with them in any way, all work should be done through the automated deployment and provisioning process only.

One of the most popular and commonly used tools for IaC is HashiCorp [Terraform](https://www.terraform.io/).

## Terraform

// TODO: quick explanation of what Terraform is/does, etc.. not too much, there's enough docs/posts out there already
// TODO: show quick example of using TF for provisioning SKS cluster
// TODO: also show quick example of using TF for helm deployment on SKS cluster

## Define your NSX-T DFW rules

Now let's go back to our NSX-T firewall rules we want to setup.

// TODO: go through example DFW rules, services, ipsets, segments, etc..
// TODO: show howto write it in tf nsx-t plugin format..
// TODO: tf init, tf plan, tf apply..
// TODO: show screenshots from UI
