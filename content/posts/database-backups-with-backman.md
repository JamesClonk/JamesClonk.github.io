---
title: "Automatic database backups with Backman"
description: "Creating Postgres backups with Backman, a Cloud Foundry application that can backup and restore your databases"
tags: [database,postgres,backups,backman,cloud foundry,kubernetes]
authors: []
author: Fabio Berchtold
date: 2020-03-17T11:17:37+02:00
draft: false
---

I've always been a big fan of using Postgres as my main database backend for all my applications, but I've also always been paranoid about losing data and the need for backups. So when I started pushing my applications onto the [Swisscom Application Cloud](http://developer.swisscom.com/) and attaching Postgres databases to them (hosted by [ElephantSQL](https://www.elephantsql.com/)), I needed a way to ensure there will always be backups, that they are under my control and supervision and hosted externally / off-site from the Postgres-provider itself, preferably on an S3 object store.

What do you do in that situation? Well of course you start writing your own backup solution! 😂

And that is how [Backman](https://github.com/JamesClonk/backman) was born.

## 💽 Backman

Backman is a backup manager application for [Cloud Foundry](https://www.cloudfoundry.org/) (and Kubernetes), that can be used to periodically backup all your databases and stores all backup files onto an S3-compatible object storage of your choice.

While it started out as a Cloud Foundry specific application, I've later also added [ytt](https://github.com/vmware-tanzu/carvel-ytt) templates and a ready-made Kubernetes [deployment](https://github.com/swisscom/backman/blob/master/kubernetes/example/deploy.yml) to it.
And of course once we've entered Kubernetes territory it didn't take long to also add a Prometheus [`/metrics`](https://github.com/JamesClonk/backman/blob/master/README.md#metrics) endpoint to it, which will show you information about backups and restores.

In its current state Backman supports backup and restore operations of the following databases:
- MariaDB / MySQL
- PostgreSQL
- MongoDB
- Elasticsearch
- Redis (backup-only, no restore)

Backman can be used either as an entirely self-running application without needing any user interaction, but it also provides an [API](https://petstore.swagger.io/?url=https://raw.githubusercontent.com/JamesClonk/backman/master/swagger.yml) and a web UI through which you can manually trigger backup or restore operations.

(Yes, I completely overdid it. Originally this project was only supposed to periodically backup my Postgres databases onto S3 in the background, now look at it... 😂)

### Service listing

![Service Listing](https://raw.githubusercontent.com/JamesClonk/backman/master/static/images/backman_services_listing.png)

Each service Backman knows about either via autodiscovery or got configured otherwise will show up in this service listing / overview.

### Service view

![Service View](https://raw.githubusercontent.com/JamesClonk/backman/master/static/images/backman_service_view.png)

Here you can see all the information about this particular database and its backups, such as the current backup schedule and the backup file retention settings. According to the schedule Backman will create a backup on a daily basis for this database, every day at 22:14:42 (the cron specification of Backman is in a 6-digit format with the first digit being "`Seconds`", similar to the format used by the [Quartz Scheduler](http://www.quartz-scheduler.org/documentation/quartz-2.3.0/tutorials/tutorial-lesson-06.html)).

You could also trigger a backup immediately with the *"Trigger Backup"* button, download or delete each of the backups if necessary, or trigger a restore by clicking *"Restore"*.

Each service can have its own configuration in Backman and if no such specific configuration is provided it will assume a set of sane default settings, such as for example a randomized daily backup schedule, just like you can see in the screenshot above.

### More...

Check out the [README.md](https://github.com/JamesClonk/backman/blob/master/README.md) to learn all about its many other configuration and usage options.
