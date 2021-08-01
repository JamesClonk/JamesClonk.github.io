
---
title: "Building a Simracing rig"
description: ""
tags: [simracing,iracing,diy]
authors: []
author: Fabio Berchtold
date: 2018-11-27T15:56:39+02:00
draft: true
---

## What is Sim-Racing / iRacing?



## And a motion rig?

https://opensfx.com/

https://github.com/SimFeedback/SimFeedback-AC-Servo

https://github.com/JamesClonk/simracing-rig

### Telemetry data is not working?

Oh no, after I finally got everything up and running I discovered a major problem. You see, iRacing has 2 different output modes for telemetry data. It can be in either 60hz mode (the default) or in an increased 360hz mode (providing more accurate, albeit somewhat interpolated data). The problem I discovered though was that the majority of my software that I already was using to read telemetry data and do useful things with it, like simulating wind / air flow via Arduino-controlled fans or control bass-shakers to simulate vibrations and road texture, was operating in 60hz mode only. The iRacing plugin provided by SimFeedback on the other hand was expecting 360hz telemetry input and you can only use either one of these modes in iRacing, not both at the same time! 😱

Good thing I know my way around software a bit, more or less anyway. 
It was time to dig into the source code of SimFeedback or rather its plugin interface. Having never before worked with C# this turned out to be quite the adventure, having to learn my way around an entirely new language just for the sake of writing a 60hz telemetry plugin for myself might sound a bit like overkill. 😂

In the end though I figured out what was needed and managed to create the [iR60 Telemetry Provider](https://github.com/JamesClonk/iR60TelemetryProvider) plugin and put it on GitHub to let everybody else profit from my work too. (As it turns out a lot of people use 60hz mode given that it's iRacings default)

Now I could finally hook up all my gadgets at the same time and get back to actual racing on track.
Here you can see the final thing in action:
{{< youtube M1Aam-OnV7w >}}

