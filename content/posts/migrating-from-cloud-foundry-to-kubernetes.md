---
title: "Migrating from Cloud Foundry to Kubernetes"
description: ""
tags: [cloud foundry,kubernetes,app cloud,containers]
authors: []
author: Fabio Berchtold
date: 2020-06-29T17:28:34+02:00
draft: false
---

For quite a few years now I've been hosting and running all my personal projects on [Cloud Foundry](https://www.cloudfoundry.org/). It's an open-source, highly-available, highly scalable, super comfortable to use platform-as-a-service for web applications and developers. Deploying your Ruby, Python or Golang apps is as simple as just typing `cf push`. Your source code will be uploaded, compiled into a runnable image, and scheduled and be running as container on the platform. Really, in terms of developer experience there is nothing else remotely like it (Except maybe [Heroku](https://www.heroku.com/), from which it drew a lot of inspiration in its early days).

But just like dark and grey clouds looming ever so threatening in the sky, I was suddenly facing a problem this year. ⛈      
The preferred provider I was using until now, the Swisscom Application Cloud - [developer.swisscom.com](https://developer.swisscom.com), out of the blue announced the end of life for its managed Cloud Foundry based hosting.

Blimey! What do I do now? 😱

## Alternatives to Cloud Foundry?

Well, my first thought was to have a look at Heroku. It would be an obvious choice, given that as mentioned before Cloud Foundry took _a lot_ of inspiration from Heroku and is pretty much an open-source version of it.
There's only one problem: Heroku is expensive! The costs of running all my little app projects are much higher than it was on developer.swisscom.com, by quite a bit actually. Since all my apps are just personal projects for fun, I really cannot spend over $100 per month just to run them. Never mind the not even yet factored in additional costs of managed database services like Postgres.

What else? IBM Bluemix? It would be based on Cloud Foundry, but while not as expensive as Heroku its documentation and website is rather opaque and chaotic. It was really hard to get a hold of any useful information, so scratch that.

Pivotal Web Services? That one was unfortunately shut down too due to Pivotal being back under VMware's thumb, which was/is yeeting all its working cloud-native products out the window.

Do I cave-in and start using one of the big 3's runtimes or products, like Google Cloud Run for example? (Certainly not AWS Beanstalk, that thing is a joke...  and too pricey anyway.) But I absolutely do not want vendor (or technology) lock-in, and again it still costs too much for just personal projects.

So, what could I do? Well, while I'm generally not a fan of it due to its obscene amount of unnecessary complexity and operational overhead, it looked like the only possibility remaining to avoid any vendor lock-in was to repackage my apps to run on Kubernetes. At the very least it is a somewhat standardised infrastructure commodity.

## Kubernetes

The problem with Kubernetes is that despite what some (many?!) people think it is not really a Platform-as-a-Service, but rather more of a fancy and advanced infrastructure layer. You still need to do a lot of architectural design, development work, refactoring to accomodate it, deployment and operational work, and also figure out monitoring and "business continuity" of your applications entirely on your own. It just provides you with the building blocks for your projects, but doesn't come with any of the batteries-included a PaaS like Cloud Foundry or Heroku has. Never mind any backend or database services you also might need. Basically if you're a team of app developers that has relied on something like Cloud Foundry before, you now _absolutely will_ have to hire at least one or more additional DevOps engineer(s) to keep babysitting your deployments on K8s, taking care of all possible day 2 operations in such an environment.

Knowing that, I wanted to at least make it as painless as possible and not also have to deal with operating and managing a Kubernetes cluster itself.
Looking for a Managed-K8s-as-a-Service offering I stumbled upon [Scaleway](https://www.scaleway.com/en/kubernetes-kapsule/).

## Scaleway K8s

Scaleway offers an easy-to-use, fully CNCF-certified managed Kubernetes service at a low cost. It doesn't charge you for the management plane, just the worker node VMs each. Its web UI is simple and functional, K8s comes with an already pre-installed NGINX ingress controller, everything is easy to configure and operatre overall, and its also pretty cheap too. Perfect! 😀

## Of deployments and batteries 🔋

While working on refactoring/repackaging my apps for Kubernetes, I also went ahead and bundled them all together into one large deployment monorepo. Check out [https://github.com/JamesClonk/deployments](https://github.com/JamesClonk/deployments).
Everything is entirely automated via CircleCI and gets deployed automatically and reproducible onto the targeted K8s cluster, via [kapp](https://carvel.dev/kapp/) and [ytt](https://carvel.dev/ytt/).

To add the missing batteries needed for Kubernetes I've included the following in my deployment collection:
- cert-manager, for handling automatic Let's Encrypt certificates
- backman, for automatic Postgres database backups
- grafana, displaying dashboards
- loki, log collection and storage
- prometheus, metric collection and storage
- alert-manager, monitoring and alerting
- postgres, with a standalone database instead of using a managed offering

With all of these it finally started coming together and Kubernetes was getting somewhere. After adding and deploying so many things though, I started wondering if I might have taken the wrong road and got lost somewhere along the way. 🙈

Check out my next blog post where its getting even more insane:
[Why use a managed K8s when you can be your own admin and waste all your free time?!](/posts/my-own-kubernetes/) 🤣

