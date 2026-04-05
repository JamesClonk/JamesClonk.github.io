---
title: "Back to K3s ???"
description: "Why I ditched my HA KubeOne cluster and went back to a single-node K3s setup with SQLite, and why etcd is overrated"
tags: [kubernetes,k3s,etcd,kine,sqlite,hetzner,continuous deployment,github actions]
author: Fabio Berchtold
date: 2025-05-05T18:02:00
draft: false
---

## I did it again -heavy sigh-

So remember how I [deployed a proper HA Kubernetes cluster with KubeOne](/posts/deploying-kubernetes-with-kubeone/)? Three control plane nodes, two workers, load balancer in front, the whole production-grade setup?

Yeah, I tore it all down. 😂

I'm back on a single-node [K3s](https://k3s.io/) cluster on [Hetzner Cloud](https://www.hetzner.com/cloud), just like [before](/posts/my-own-kubernetes/). And honestly? It's just better for my use-case. Let me explain why.

## The HA experiment

Don't get me wrong, [KubeOne](/posts/deploying-kubernetes-with-kubeone/) is a fantastic tool. It does exactly what it promises: give it some VMs and it'll set up a proper, CNCF-conformant, highly-available Kubernetes cluster. The upgrade process is smooth, the Terraform integration is useful (for suckers who keep using that pile of 💩 software), and the machine-controller for managing worker nodes is genuinely impressive (🥰).

But after running it for a while I started asking myself a very important question: *"do I actually need any of this?"*

Three control plane nodes. That's three VMs I'm paying for, just for the control plane. Plus two worker nodes. That's five VMs total. On Hetzner Cloud that's still relatively cheap compared to the other cloud providers, but it's a lot more than the single CPX32 VM I was running before. And for what? So that my personal blog infrastructure and hobby projects can survive the theoretical failure of a control plane node? 🤔🤣

The honest answer is: no. I don't need HA for my personal stuff. If my single VM goes down, I can have a new one up and running in 15 minutes thanks to everything being automated with [Plato](/posts/template-rendering-with-plato/) and GitHub Actions.

## The etcd problem

But the cost wasn't even the main reason I went back. The real issue was **etcd**.

Oh, etcd. Where do I even begin. 🤦

Etcd is the distributed key-value store that standard Kubernetes uses as its backing datastore. It's the thing that stores all your cluster state, every pod, every deployment, every secret, every configmap. And it is without a doubt the single most annoying software component in the entire effin world.

Here's the thing about etcd: it's designed for distributed consensus. It uses the [Raft protocol](https://raft.github.io/) to maintain consistency across multiple nodes. This is great if you're Google running thousands of clusters at massive scale, but for a personal Kubernetes cluster? It's just absurd overkill that brings nothing but pain and grief.

Let me list some of the joys of operating etcd:

- **It needs an odd number of members** (typically 3 or 5) for quorum. Lose quorum and your entire cluster is effed. Not degraded or slow, just completely non-functional. Might as well spin-up a new cluster at that point, since etcd recovery is a mythical beast on its own.
- **It's extremely sensitive to disk latency**. If your disk is too slow (and "too slow" for etcd is surprisingly fast), you'll get leader election timeouts and your cluster will start misbehaving in weird and wonderful ways.
- **It consumes a surprising amount of resources** for what is essentially a key-value store. Memory usage grows with the database size and if you don't regularly compact and defragment it, then things get reeeal ugly quick.
- **Backup and restore is its own adventure**. You need to snapshot etcd separately from everything else, and restoring from a snapshot is a multi-step process that can easily go wrong.
- **Debugging etcd issues is a nightmare**. The error messages are cryptic, the logs are verbose but unhelpful, and half the time the "fix" is to just blow away the member and re-join it. 🙄

I've spent more hours debugging etcd issues than I care to admit. Corrupted members and split-brain scenarios, WAL file corruption, compaction failures... it's just a never-ending source of operational headaches. And all of this complexity exists to solve a problem I don't have: distributed consensus across multiple nodes.

## Enter Kine, aka K3s Kubernetes without etcd

This is where [Kine](https://github.com/k3s-io/kine) comes in, and it's one of the most underappreciated pieces of software in the Kubernetes ecosystem.

Kine is a shim that translates the etcd API into calls to other databases. It was created by the K3s team at Rancher Labs and it's what allows K3s to use alternative datastores instead of etcd. Kine supports:

- **SQLite** (the default in K3s)
- **PostgreSQL**
- **MySQL / MariaDB**
- **NATS**

The genius of Kine is that it presents itself as an etcd endpoint to the Kubernetes API server. As far as kube-apiserver is concerned it's talking to etcd. But behind the scenes Kine is translating all those calls into SQL queries against a regular database. The Kubernetes components don't know and don't care.

This means you get all the benefits of Kubernetes without any of the etcd operational burden. No Raft consensus, no quorum requirements, no WAL files (well, no etcd WAL files. SQLite does have them too), no compaction, no defragmentation. Just a database doing database things.

## SQLite

K3s uses SQLite as its default datastore via Kine, and I know what you're thinking: *"SQLite? For a Kubernetes cluster? Are you insane?"*

*"Bro, hear me out."* 🤘

SQLite is one of the most battle-tested, reliable pieces of software ever written. It's used in literally billions of devices worldwide. It handles concurrent reads beautifully, it's incredibly fast for the kind of workload Kubernetes generates (mostly reads with occasional writes) and it stores everything in a single file that's trivially easy to back up.

For a single-node cluster like mine, SQLite is genuinely perfect:

- **Zero operational overhead**: no database server to manage, no connections to configure, no credentials to rotate
- **Backup is just copying a file**: `cp /var/lib/rancher/k3s/server/db/state.db state.db.backup` and you're done. Compare that to the etcd snapshot dance! Add some upload-to-S3-sidecar-container and you're golden!
- **Tiny resource footprint**: SQLite uses barely any memory compared to an etcd cluster
- **Rock solid reliability**: SQLite doesn't corrupt, doesn't need compaction, doesn't need defragmentation, doesn't lose quorum because there is no quorum

Now obviously SQLite doesn't work for multi-node control planes because it's a file-based database with no network access, but that's fine! If you need multiple control plane nodes you can point Kine at PostgreSQL instead and get the same benefits over etcd, just with a proper networked database.

## The beauty of a single node

So here I am, back on a single Hetzner Cloud VM running K3s with SQLite, and it's beautiful in its simplicity.

My entire Kubernetes "cluster" is:
- One CPX32 VM (4 vCPUs, 8GB RAM, ~€15/month)
- K3s installed with a single command
- SQLite as the datastore (via Kine, transparently)
- All my [infrastructure components](/posts/my-own-kubernetes/#batteries-included-) deployed on top

That's it. No load balancer for the control plane, no etcd cluster to babysit, no worker node management, no machine-controller. Just one VM running everything.

```bash
curl -sfL https://get.k3s.io | \
    INSTALL_K3S_VERSION='v1.34.5+k3s1' \
    INSTALL_K3S_EXEC='--disable=traefik --disable=servicelb' \
    sh -
```

One command and I have a fully functional Kubernetes cluster. The whole thing takes about 30 seconds. Try doing that with kubeadm and etcd. 😏

### But what about availability?

*"But JamesClonk, what if your single VM dies?!"*

Then I spin up a new one. My entire infrastructure is automated:
1. [Plato](/posts/template-rendering-with-plato/) renders all my templates with secrets injected
2. A [Taskfile](https://taskfile.dev/) orchestrates the deployment
3. GitHub Actions runs the whole pipeline

From zero to a fully running cluster with all components deployed takes about 15 minutes. That's my "disaster recovery plan" and it's more than sufficient for personal projects. I don't need five-nines availability for my Grafana dashboards. 😂

At this point if I'd ever need actual HA for something serious I'll use K3s with an external PostgreSQL database and multiple server nodes. Still no etcd in sight, still simpler than the kubeadm/etcd approach, and I'd get to use a database I actually understand and enjoy operating.

## Lessons learned

After going from K3s → managed K8s → K3s → KubeOne → K3s again, here's what I've learned:

1. **Complexity is not a feature**: Just because you *can* run a multi-node HA cluster doesn't mean you *should*. Match your infrastructure to your actual requirements, not to what looks impressive on a CV.

2. **etcd is the worst part of Kubernetes**: If you can avoid it, avoid it. Kine with SQLite or PostgreSQL is simpler, more reliable, and easier to operate for the vast majority of use cases.

3. **Single-node K3s is criminally underrated**: For personal projects, small teams, development environments, edge deployments, etc.. It's genuinely all you need and the resource efficiency is incredible compared to a full kubeadm/KubeOne cluster.

4. **Automation is your HA**: If you can rebuild your entire cluster from scratch in minutes, you don't need three redundant control plane nodes. Invest in automation instead of infrastructure redundancy.

5. **Cost matters**: One VM at €15/month vs. five VMs at €75/month for the same workload. That's a 5x difference for zero practical benefit in my use case.

## Full circle

It's funny how these things go in circles. I started with a [single VM on DigitalOcean](/posts/aiming-for-high-availability/) running my Go apps directly, then went through Cloud Foundry, managed Kubernetes, self-hosted Kubernetes with all the bells and whistles, and now I'm back to... a single VM (but with K8s of course, I'm not *that* mad!). Just this time it's running K3s instead of my apps directly.

K3s is one of those rare things in the Kubernetes world that actually reduces complexity instead of adding more of it. If you're running etcd for a small cluster and constantly fighting with it, do yourself a favour and give K3s a try.

Future-you will thank you. 🙇
