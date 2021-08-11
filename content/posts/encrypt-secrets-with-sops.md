---
title: "Using Mozilla/SOPS for secret management"
description: "Learn how to encrypt your secrets with Mozilla/SOPS"
tags: [continuous deployment,github actions,secrets,github]
authors: []
author: Fabio Berchtold
date: 2021-07-25T19:51:09+02:00
draft: true
---

## Enviroment variables

When I was originally contemplating on how to run all my personal projects and applications on [my own Kubernetes](/posts/my-own-kubernetes/) cluster, one of the problems was how would I store secrets? Where would I store them?

Since I intended to have all my [infrastructure-as-code](https://www.youtube.com/watch?v=RO7VcUAsf-I), deployment and application repositories publicly accessible on GitHub (to be able to benefit from all the nice free services it provides for public / open-source projects), I needed to figure out how I should do this.

Initially I went for the simple and obvious way of having all my pipeline code relying on injected environment variables, a typical principle of the [12-factor](https://12factor.net/config) approach on how to store configuration data.

Since at that point I was also migrating from [CircleCI](https://circleci.com/) to [GitHub Actions](https://docs.github.com/en/actions), all I had to do was store all needed environment variables as "Secrets" on the particular Github repository where the Github Actions workflows are running:

![Cloud Foundry](/images/sops-github-secrets.png)

Now I could simply inject them as environment variables into a workflow and its job steps, by referring to these GitHub repository secrets via *`${{ .secret.<SECRET_NAME> }}`*:

```yaml
name: minecraft server on k8s

jobs:
  minecraft:
    name: minecraft
    runs-on: ubuntu-latest
    steps:
    - uses: actions/checkout@v2
    - name: deploy minecraft server to k8s
      working-directory: minecraft
      run: ./deploy.sh
      env:
        KUBECONFIG: ${{ secrets.KUBECONFIG }}
        MINECRAFT_SERVER_PASSWORD: ${{ secrets.MINECRAFT_SERVER_PASSWORD }}
        MINECRAFT_RCON_PASSWORD: ${{ secrets.MINECRAFT_RCON_PASSWORD }}
        S3_BACKUP_BUCKET: ${{ secrets.S3_BACKUP_BUCKET }}
        S3_BACKUP_ACCESS_KEY: ${{ secrets.S3_BACKUP_ACCESS_KEY }}
        S3_BACKUP_SECRET_KEY: ${{ secrets.S3_BACKUP_SECRET_KEY }}
```

Great, this works reasonably well!

#### Could it be better though?

While I always felt a bit uneasy about storing these raw secrets on GitHub, I was never bothered enough by it to seek out better solutions. What was however starting to bother me was that after a while this collection of GitHub repo secrets started to grow more and more. As I added more applications to my infrastructure-as-code monorepo and its number of deployment workflows grew, so did the number of secrets I had to configure and store.
