---
title: "Continuous Integration with Concourse"
description: "A brief introduction to Concourse, a software for building Continuous Integration / Continuous Delivery pipelines"
tags: [concourse,continuous integration,continuous deployment,continuous delivery,pipelines]
authors: []
author: Fabio Berchtold
date: 2016-01-11T19:22:35+02:00
draft: false
---

##### edit @ 2020.12.01
These days there are many different platforms and systems out there that can be used to automate all your CI/CD needs.

Software-as-a-Service / hosted solutions:
- TravisCI
- CircleCI
- Drone.io
- GitHub Actions

Open Source / self-hosted:
- Jenkins
- GoCD
- Concourse
- ArgoCD
- Tekton

One the SaaS side after I was initially using TravisCI, then gradually transitioning to CircleCI. But eventually I ended up using GitHub Actions, they seem to provide a reasonable amount of flexibility and customization at a low price (free!).

When it comes to self-hosted CI/CD software Jenkins is probably the most commonly used one. But I'd strongly advise not use it, it is a very old and crufty project back from a time when the word "pipeline" or microservices architecture did not exist yet.

Instead, lets have a look at the king of them all when it comes to the ability to tackle complex pipelines and dependency flows: [Concourse](https://concourse-ci.org)

## Concourse - the continuous thing-doer

Concourse is an open source CI/CD platform, focused on allowing you to build and work with pipelines. It's freely available and can be installed in various ways, be it with Docker, on Kubernetes with Helm, via BOSH, or manually via its single binary.

https://concourse-ci.org/docs.html

### Pipelines

Concourse pipelines are built around Resources, which represent external state, and Jobs, which interact with them and can be combined into a pipeline. A pipeline in Concourse represents a dependency flow, going from one Job to the next, carrying over state in Resources if necessary. Each Job step spawns an isolated container on its own and all Job work is running in such a container.

Here's how such a pipeline might look like:

![Pipeline](/images/concourse-pipeline.png)

### Components

Concourse itself is built around 3 main components:
- Its [database](https://concourse-ci.org/postgresql-node.html), using PostgreSQL
- The [web node](https://concourse-ci.org/concourse-web.html) which provides the user interface, contains all the logic and is the central piece of Concourse
- Any number of [worker nodes](https://concourse-ci.org/concourse-worker.html). These run tasks / Jobs that are part of a Concourse pipeline inside containers

### Tutorial

Concourse has a somewhat steeper learning curve than traditional build systems like Jenkins due to its focus on building pipelines and compartmentalization into basic modular resources, so it makes sense if you are first starting out to have a look at the excellent [Concourse tutorial](https://concoursetutorial.com/) from by Stark & Wayne or the [Getting Started](https://tanzu.vmware.com/developer/guides/ci-cd/concourse-gs/) guide from VMware.

These will give you a good first look at how Concourse works and can be used to build your pipelines.

### Installation

The easiest way to get started with running your own Concourse instance would probably be to run it inside a Kubernetes cluster. There's an easy-to-use Helm chart available to deploy Concourse: https://github.com/concourse/concourse-chart

With this chart you can install Concourse into any Kubernetes cluster. If you want to give it a try locally I'd recommend using [kind](https://kind.sigs.k8s.io/docs/user/quick-start/).

### Video introduction

{{< youtube 0bi_EWzhPvs >}}


