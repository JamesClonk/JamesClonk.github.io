---
title: "Scheduling Tasks in Cloud Foundry"
description: "The Task-Scheduler service on the Swisscom Application Cloud allows you to schedule and automatically run tasks for your applications. You can use it to schedule periodical execution of any tasks on the Application Cloud, including database migrations, emails, batch jobs, etc."
tags: [cloud foundry, scheduling]
authors: []
author: Fabio Berchtold
date: 2019-09-03T14:23:30+02:00
draft: false
---

> *The Task-Scheduler service on the Swisscom Application Cloud allows you to schedule and automatically run tasks for your applications. You can use it to schedule periodical execution of any tasks on the Application Cloud, including database migrations, emails, batch jobs, etc.*

## What are Tasks?

While most of the time you are probably using the [Swisscom Application Cloud](http://developer.swisscom.com/) (A managed Cloud Foundry platform-as-a-service) to push long running processes or *"apps"* as they are commonly called, there is the occasional use case for tasks.

Now tasks in Cloud Foundry are defined as a process that runs only for a finite amount of time, and then stops. A task runs in its own container, inheriting memory and disk limits from its parent app, and should be designed to use minimal resources while executing a *"task"*. After such a task exits Cloud Foundry will destroy and remove this container again. Tasks can also be checked for their current state and for a success or failure message after they finished.

Tasks are an example of a one-off or on-demand single use job that needs to do some kind of work and then exit, like:
- Running a database migration
- Sending emails
- Running batch jobs
- Processing data input/output
- Running backups
- etc..

Documentation on using tasks in Cloud Foundry can be found here: https://docs.developer.swisscom.com/devguide/using-tasks.html


## What is the Task-Scheduler?

While tasks are a great tool to run short running processes or batch jobs, triggering them manually can be quite tedious. You might want to run your daily database backup every at two o'clock in the morning perhaps, or processing some data every 15 minutes? With any of these the need for some way of automatic scheduling arises..

### Enter the Task-Scheduler service

On the Swisscom Application Cloud there is the Task-Scheduler service available in the marketplace to help you with all your task-scheduling needs.

It is a distributed, highly-available system running in the backend that accepts scheduling requests coming from Cloud Foundry users, creates and manages jobs and their schedule, and executes these jobs as tasks on Cloud Foundry at the scheduled time and date.

Integration into the marketplace is done via the standardized [Open Service Broker API](https://www.openservicebrokerapi.org/), to make the experience seamless for all users of the Swisscom Application Cloud.
Thanks to this a user can simply create service instances, bind these to his apps and define tasks to be scheduled all through the [CF CLI](https://docs.developer.swisscom.com/cf-cli/) without the need for any additional tools.

### Task-Scheduler architecture overview

![Loggregator](/images/task-scheduler.png)

## Great, how do I use it?

To use the Task-Scheduler you must first create a service instance of it.

Check the marketplace and you should see the Task-Scheduler service listed there, then create a new service instance:
```shell
$ cf marketplace
Getting services from marketplace in org swisscom / space examples as fabio.berchtold@swisscom.com...
OK
service          plans      description
task-scheduler   free       Task-Scheduler to schedule periodical runs of tasks
$ cf create-service task-scheduler free my-scheduler
Creating service instance my-scheduler in org swisscom / space examples as fabio.berchtold@swisscom.com...
OK
$ cf services
Getting services in org swisscom / space examples as fabio.berchtold@swisscom.com...
name                         service          plan    bound apps
my-scheduler                 task-scheduler   free
```

Once the service instance has been created you can then bind it to an existing app. During binding you specify via binding parameters the requested schedule, task, and optionally memory/disk limit overwrites. The service can be bound to as many different apps as you wish, the binding only acts as a registration action for the Task-Scheduler service:
```shell
$ cf bind-service my-app my-scheduler -c '{"schedule":"0 2 * * *", "task":"rake cleanup-db", "memory_in_mb":128, "disk_in_mb":512}'
Binding service my-scheduler to my-app in org swisscom / space examples as fabio.berchtold@swisscom.com...
OK
```

After binding a Task-Scheduler instance to your app, the configured task will be executed automatically according to the provided cron schedule. To remove the scheduled task again simply unbind the service from the app.

Running or finished tasks can be checked with the CF CLI:
```shell
$ cf tasks my-app
Getting tasks for app my-app in org swisscom / space examples as fabio.berchtold@swisscom.com...
OK
id  name                                   state       start time                      command
3   2f458b3f-c383-4422-866f-31bd7fda9ac3   SUCCEEDED   Thu, 29 Aug 2019 02:00:05 UTC   rake cleanup-db
2   2f458b3f-c383-4422-866f-31bd7fda9ac3   SUCCEEDED   Wed, 28 Aug 2019 02:00:19 UTC   rake cleanup-db
1   2f458b3f-c383-4422-866f-31bd7fda9ac3   SUCCEEDED   Tue, 27 Aug 2019 02:00:03 UTC   rake cleanup-db
```

And that's all there is to it..  We wish you a happy scheduling! ⏲️


### See also:

[Task-Scheduler documentation](https://docs.developer.swisscom.com/service-offerings/task-scheduler.html)
