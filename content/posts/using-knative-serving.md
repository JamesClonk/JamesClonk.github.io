---
title: "Using Knative Serving on Kubernetes"
description: "How to use Knative Serving for your applications"
tags: [kubernetes,knative,containers]
author: Fabio Berchtold
date: 2021-03-13T13:54:27+02:00
draft: true
---

## Serverless Computing?

We probably all heard of AWS Lambda, Function-as-a-Service (FaaS) or [Serverless Computing](https://en.wikipedia.org/wiki/Serverless_computing) in general before. And while I find the term "serverless" rather silly, its actual meaning of executing compute processes or containers only on-demand in the cloud and allow for a simplified, no capacitiy planning required, pay-only-what-you-use model of running your applications or code is not be easily dismissed and can be quite valuable.

Since allowing yourself to be captured and locked-in into any particular vendor, escpecially like when going for AWS Lambda, is a big mistake however, what options are there if we want to avoid such folly? Are there any self-hosted serverless computing or Function-as-a-Service solutions out there?

Yes, of course! 😄

The two most well known in this area are:
- [OpenFaaS](https://www.openfaas.com/)
- [Knative](https://knative.dev)

Both are open-source projects, can provide you with event-driven Function-as-a-Service and Serverless Computing functionality, are installed on top of Kubernetes, and allow you to build, deploy and manage modern cloud-native serverless workloads.

I highly recommend you to check out at least one (if not both) of these two, install them in a playground environment and tinker a bit with them to learn about their use cases. Both are relatively easy to install on Kubernetes and have extensive documentation to get you started.

OpenFaaS is mainly focused on providing you with the event-driven Function-as-a-Service experience, and requires you to adapt your code specifically to use it. It is directly comparable to AWS Lambda.

Knative on the other hand while providing the same event-driven concepts, also offers a more generalistic approach in running any code or containers on its platform, not just "functions". Thus it can be used in a more Platform-as-a-Service fashion and run your normal web applications too.

## Knative Serving


https://knative.dev/docs/serving/
