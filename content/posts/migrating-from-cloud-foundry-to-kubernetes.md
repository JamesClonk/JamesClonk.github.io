---
title: "Migrating from Cloud Foundry to Kubernetes"
description: ""
tags: [cloud foundry,kubernetes,app cloud,containers]
authors: []
author: Fabio Berchtold
date: 2020-06-29T17:28:34+02:00
draft: true
---

For quite a few years now I've been hosting and running all my personal projects on [Cloud Foundry](https://www.cloudfoundry.org/). It's an open-source, highly-available, highly scalable, super comfortable to use platform-as-a-service for web applications and developers. Deploying your Ruby, Python or Golang apps is as simple as just typing `cf push`. Your source code will be uploaded, compiled into a runnable image, and scheduled and be running as container on the platform. Really, in terms of developer experience there is nothing else remotely like it (Except maybe [Heroku](https://www.heroku.com/), from which it drew a lot of inspiration in its early days).

But with dark and grey clouds looming ever so threatening in the sky, I was suddenly facing a problem this year. ⛈      
The preferred provider I was using until now, [developer.swisscom.com](https://developer.swisscom.com), out of the blue announced the end of life for its managed Cloud Foundry based hosting.

Blimey! What do I do now? 😱

>>>>>> #### TODO: developer.swisscom.com EOL, what now?
>>>>>> Heroku? too expensive
>>>>>> Other CF? IBM Bluemix? nope
>>>>>> AWS or GCP specific things? nope, don't want vendor lock-in!
>>>>>> K8s? hmmm.. maybe, but very complicated, not PaaS-like at all, requires a lot of initial effort, etc.
>>>>>> Managed K8s, but where? Scaleway! cheap and simple! includes ingress-nginx.
>>>>>> show old k8s-deployments repo, explain why adding to much stuff, to make it more CF-like

>>>>>> #### TODO: show old k8s-deployments repo here (deployed onto scaleway managed k8s, your own k8s will be shown later in my-own-kubernetes)
