---
title: "Aiming for High Availability"
description: ""
tags: [high availability,digital ocean,haproxy]
authors: []
author: Fabio Berchtold
date: 2015-02-03T10:42:34+02:00
draft: false
---

## From Old to New

A bit over a year ago I have rewritten my entire personal website from PHP into Golang. Before that I was using a typical [LAMP stack](https://en.wikipedia.org/wiki/LAMP_(software_bundle)) hoster to host my website, where all you usually do is upload your PHP files via FTP and everything is hosted there for you, the most simple entry in the world of "web development".

This old PHP based code has been archived on GitHub and can still be found here in case you're interested:
- https://github.com/JamesClonk/php-website-frontend
- https://github.com/JamesClonk/php-website-backend
- https://github.com/JamesClonk/PDO_DB

This traditional setup has served its purpose very well since over 10 years already, but it was time to take a dive into more advanced stuff. Having recently learned Golang this provided me with the opportunity to put my newfound Go programming skills to the test, and also figure out what other ways there are to host your own websites.

I've also split up the new Golang based website into multiple components and repositories, hosted within its own GitHub project: https://github.com/jamesclonk-io
- [jcio-frontend](https://github.com/jamesclonk-io/jcio-frontend) is the main frontend website, acting like a CMS and reading data from [content](https://github.com/jamesclonk-io/content)
- [moviedb-frontend](https://github.com/jamesclonk-io/moviedb-frontend) is the web frontend to my movie database
- and [moviedb-backend](https://github.com/jamesclonk-io/moviedb-backend) the backend, providing an API for the frontend and querying data from a database (SQLite or Postgres)
- all these components make use of [stdlib](https://github.com/jamesclonk-io/stdlib) for shared code / libraries

Since Golang compiles your code into binaries it is not as simple as uploading these files via FTP to a hoster anymore, I needed a place where my code can actually run now.

### My own VM on the Internet?

So, where can I now run my Golang binaries?

This is where I discovered [Digital Ocean](https://www.digitalocean.com/).

Unlike a traditional hosting provider Digital Ocean allows users to create entire virtual machines, to which you can then SSH into and install and run whatever software you want. This was my first contact with a so-called "Cloud" provider.

All you need to do is create an account on Digital Ocean, login and fill in your billing details, and the next thing you know you can create new virtual machines on demand, and they only take a few minutes to start up and be ready to use. 😃

## High Availability Design

But having everything running together on this single VM poses another new problem, what if this VM goes down? My website would go down with it! 😱
Of course I need my personal website to be highly available, distributed among multiple instances / VMs!

So I designed my own [High-Availability architecture](https://en.wikipedia.org/wiki/High_availability), to keep my website up and running at all times:

![JCIO architecture](https://raw.githubusercontent.com/JamesClonk/jcio/master/jcio.png)

- https://github.com/JamesClonk/jcio

The idea of this is to completely automate the deployment of a fully HA setup of my own personal infrastructure on Digital Ocean. It spins up all the VMs needed, installs the software and configures everything to be up and running. Also I'm going to use [RQLite](https://github.com/rqlite/rqlite) (basically a distributed version of SQLite) to have as the database backend for my applications.

For the orchestration of all the necessary Docker containers between these VMs I rely on using [Shipyard](https://github.com/ehazlett/shipyard/tree/7bf471c0832c3772c9b041607dbc42017012fa1e). It's a tool that allows you to manage containers on "nodes" via a graphical user interface / dashboard:

![Docker Shipyard](/images/shipyard.jpg)

Here are the two repositories needed to deploy "master" and "slave" nodes:
- https://github.com/JamesClonk/jcio-nginx-master
- https://github.com/JamesClonk/jcio-nginx-slave

In the end all I need to do is run *[./provision.sh](https://github.com/JamesClonk/jcio/blob/master/provision.sh)* and it will spin up my entire setup have everything running afterwards without me having to do any manual configuration, etc.

---

## Addendum - 2021.08.01

Since I've recently started porting all my old blog posts onto my new blog (this very thing here you are reading 😂), I've stumbled upon this old beauty of a crazy self-made HA architecture. What a monstrosity!

This thing was so bloody unnecessarily complicated, no wonder I abandoned it as soon as I could when I learned of [Cloud Foundry](https://www.cloudfoundry.org/). I more or less immediately just started deploying all my Golang web apps directly onto the [Swisscom Application Cloud](developer.swisscom.com) back, it greatly simplified everything.

And these days I have everything automated with [GitHub Actions](https://github.com/features/actions) and running on [my own Kubernetes](/posts/my-own-kubernetes/) cluster anyway..
