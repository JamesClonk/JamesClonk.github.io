---
title: "A blog with Hugo on GitHub"
description: Deploying a Hugo blog as personal GitHub-Pages via GitHub Actions
tags: [github,github actions,hugo,deployment]
author: Fabio Berchtold
date: 2021-07-28T20:57:18+02:00
draft: false
---

# I want to do some blogging

So I wanted to migrate all of my existing blog posts (and create some new ones of course) to a new self-hosted system.
My requirements for this have been the following:
- Simple and easy to use (I ***hate*** complicated UI editors!)
	- Preferably Markdown or similar format support
- Open source
- Self-hosted
- Easily runnable on my personal K8s cluster
	- Tucked away behind an Ingress-Nginx controller, it must not try to do its own TLS / HTTPS handling
- Preferably no need for a database
	- If it needs to have a database, then it must be Postgres (as that is what I already manage on my K8s infrastructure)
- Secure
- Preferably written in Golang
	- PHP based software is out of the question by default! 🙄

After a bit of googling and some research this gave me the following options to choose from at the end:
- [Journey](https://kabukky.github.io/journey/)
	- Looked interesting at first, but seems to not be maintained anymore
- [WriteFreely](https://writefreely.org/)
	- Quickly dismissed for being unnecessarily complicated and needing a MySQL database
	- It seemed fine initially, but the whole software being the webserver itself that needs to be hosted to serve content proved to be something I ultimately didn't want. (More on that when looking at the final solution below: Hugo)
- [Vertigo](https://github.com/jhvst/vertigo)
	- Unmaintained and unfinished
- [golang.org/x/tools/blog](https://pkg.go.dev/golang.org/x/tools/blog)
	- Part of the extended stdlib of Golang, used by the Golang website itself to host its blogs. Why not, would be fun to use it seemed. But requires coding and work first. Meh, for this project I just want to write blog posts and get started doing so immediately
- [Hugo](https://gohugo.io/)
	- Popular static site generator, requires no database
- [Jekyll](https://jekyllrb.com/), [Hexo](https://hexo.io/), [VuePress](https://vuepress.vuejs.org/), [Pelican](https://github.com/getpelican/pelican)
	- All similar to Hugo but none of them is written in Golang. I don't want to deal with runtimes of dynamic languages and their package managers 🤷

## Hugo

[Hugo](https://gohugo.io/) is a static website generator written in Golang (yay!). It consists of a single binary that can generate all my blog posts and website content on-demand, or additionally also serve the content itself. It boosts great performance and easy of use, tons of themes and templates and a big community around it.

Content for pages/post/etc. can be written in Markdown or other simplified formats and is then rendered into static HTML files. Thus it has no need for a backend database or datastore of any kind. All your pages are just files.

I choose Hugo because of all of the above qualities. Being able to write just Markdown is simple and efficient, and no annoying WYSISWYG editor getting in my way. Having everything being "compiled" down into static HTML files is a big plus in my book and makes the blog extremely easy to maintain with a lot possible options on how to approach hosting and deployments.

## Hosting on GitHub Pages

GitHub provides free static hosting over SSL (using [Let's Encrypt](https://letsencrypt.org/)) directly from a GitHub repository via its [GitHub Pages service](https://help.github.com/articles/what-is-github-pages/) and automating the deployment workflow of Hugo with [GitHub Actions](https://docs.github.com/en/actions).

### Using GitHub Pages

There are two types of GitHub Pages:

- User/Organization Pages (`https://<USERNAME|ORGANIZATION>.github.io/`)
- Project Pages (`https://<USERNAME|ORGANIZATION>.github.io/<PROJECT>/`)

For my personal blog I decided to use the `<USERNAME>.github.io` approach and host Hugo itself and all of its generated files in the repository [JamesClonk/JamesClonk.github.io](https://github.com/JamesClonk/JamesClonk.github.io)

1. The `master` branch hosts all Hugo configuration, assets and content
2. The  `gh-pages` branch hosts the Hugo generated output, which GitHub will display under [blog.jamesclonk.io](https://blog.jamesclonk.io)
3. A GitHub Actions workflow will trigger on commit to the `master` branch, run Hugo to generate all site content and commit this into the `gh-pages` branch
4. The repository is configured to serve its GitHub Pages from the `gh-pages` branch root `/`

![GitHub Pages](/images/github-pages.png)

### Build Hugo with a GitHub Actions

GitHub Actions allows you to define workflows that can build your software or otherwise execute various steps as part of a CI/CD pipeline. With this setup I have a workflow which will build and publish this blog automatically everytime I push / create a new commit on the `master` branch of my Hugo Github repository.

All I needed for this was to create `.github/workflows/gh-pages.yml` containing the following content (based on [actions-hugo](https://github.com/marketplace/actions/hugo-setup)):

```yml
name: github pages

on:
  push:
    branches: [ master ]

jobs:
  deploy:
    name: deploy Hugo to gh-pages
    runs-on: ubuntu-latest
    steps:
    - uses: actions/checkout@v2
      with:
        submodules: true
        fetch-depth: 0

    - name: Setup Hugo
      uses: peaceiris/actions-hugo@v2
      with:
        hugo-version: 'latest'
        extended: true

    - name: Build
      run: hugo --minify

    - name: Deploy
      uses: peaceiris/actions-gh-pages@v3
      if: github.ref == 'refs/heads/master'
      with:
        github_token: ${{ secrets.GITHUB_TOKEN }}
        publish_dir: ./public
```

The steps being executed by this workflow are as follows:
1. If we get a push on branch `master`
2. Then checkout the repository (with submodules, since we have a theme in here as a submodule)
3. Setup the Hugo binary (using the latest version of `hugo_extended`)
4. Run `hugo --minify`, which will generate the site content under `publish/`
5. Commit and push the generated `publish/` folder into `gh-pages`

The result being that every time a commit happens on `master` branch this workflow will be trigger, generate the site content and publish it by pushing it into the `gh-pages` branch.

For more advanced settings see [actions-hugo](https://github.com/marketplace/actions/hugo-setup) and [actions-gh-pages](https://github.com/marketplace/actions/github-pages-action).

### Use a custom domain with GitHub Pages

Since I wanted to use a [custom domain](https://docs.github.com/en/pages/configuring-a-custom-domain-for-your-github-pages-site/managing-a-custom-domain-for-your-github-pages-site) for this blog ([blog.jamesclonk.io](https://blog.jamesclonk.io)) I needed to create the file `static/CNAME` in the `master` branch, containing the custom domain name as the only contents inside that file. This `CNAME` file is used to inform GitHub Pages about the DNS entry it's going to use. Since it's inside Hugo's `static` directory, the `CNAME` file will be contained at the root of the published site generated by Hugo, to fulfill this requirement of GitHub Pages.

## Other hosting options

### Hosting on S3

I briefly considered deploying my Hugo blog on AWS S3, but since Amazon does not provide any effective means of cost control ultimately I decided against this solution. While it would be very easy and is supported out of the box by Hugo ([Deploy to S3](https://gohugo.io/hosting-and-deployment/hugo-deploy/)) I would have no way to prevent my AWS bill from potentially exploding if a malicious actor were to cause excessive traffic on my S3 bucket.

Given that I would use GitHub Actions anyway already to build the content and then run `hugo deploy`, it made sense for me to also use GitHub for hosting the blog itself. It's free after all!

### Hosting on Kubernetes

The other option, which I actually thought I'd be doing first before researching into various blogging software, was to deploy the blog on my personal Kubernetes.
(More on that here: [My own Kubernetes](/posts/my-own-kubernetes/))

Since Hugo generates just static HTML files and doesn't actually need any runtime or container environment to run and serve content itself this obviously greatly expanded on how I could approach the hosting. I was still thinking about coding a very simple static file webserver in Golang, that upon startup would download the Hugo generated content from either S3 or GitHub and just serve those files. But it boiled down to the same again as with hosting directly from S3, why even bother if GitHub itself can serve those HTML files?

GitHub Pages is free, no need to use resources on my K8s cluster for hosting this blog then.
If GitHub ever chooses to not make Pages hosting free anymore, this however would likely be the solution I'd go for as I value the control over costs and technical implementation details compared to just plain S3 hosting. 👨‍🏭
