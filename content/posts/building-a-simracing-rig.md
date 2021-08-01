
---
title: "Building a Sim-racing motion rig"
description: "How to build a DIY motion rig for sim-racing"
tags: [simracing,iracing,diy,simulator]
authors: []
author: Fabio Berchtold
date: 2018-11-27T15:56:39+02:00
draft: false
---

## What is Sim-racing?

Sim-racing is short for *"simulated racing"*. Basically it means you are using racing simulator software to try and simulate real world racing as accurately as possible. This includes all the real-world variables such as fuel usage, damage to the car, tire wear, grip, suspension settings, etc., which is unlike the more well-known arcade racing games like Forza Motorsport or Gran Turismo. The goal is to provide the most realistic depiction of real world racing as much as possible. Sim-racing software on PC is often times accompanied by special purpose hardware, like steering wheels, pedals, *"rigs"* with bucket seats, triple-screen monitor setups or Virtual Reality headsets, bass-shakers, etc.

The most common sim-racing titles are:
- [iRacing](https://en.wikipedia.org/wiki/IRacing)
- [Assetto Corsa](https://en.wikipedia.org/wiki/Assetto_Corsa)
- [rFactor 2](https://en.wikipedia.org/wiki/RFactor_2)
- [RaceRoom](https://en.wikipedia.org/wiki/RaceRoom)

## iRacing

To quote from iRacings website:
> *iRacing is the leading sim-racing game for your PC. Developed as a centralized racing and competition service, iRacing organizes, hosts and officiates online racing on virtual tracks all around the world. In the fast-paced world of eSports, iRacing is a one-stop-shop for online racing. We utilize the latest technologies to recreate our ever-expanding lineup of famed race cars and tracks from the comfort of your home. Simulate what a professional NASCAR driver experiences inside the seat of a stock car, or a Grand Prix driver sees over the dash. All of the details add up to a lineup of cars and tracks that are virtually indistinguishable from the real thing. This creates unmatched immersion when sim racers take the green flag in our online racing simulator. Although iRacing is an online racing simulator at heart, the value as a training tool is just as real. The best sim racers in the world compete on iRacing and you can watch the race broadcasts live on the iRacing eSports Network.*

[iRacing](https://www.iracing.com/) is probably my favourite out of all the sim-racing software out there, thanks to its fantastic online component. It is entirely focused on competitive online racing in various championship series and leagues. One of the many great things about it is that due to its simulation accuracy it very popular especially among racing enthusiasts and also attracts a lot of actual real world drivers to the service. It is not uncommon to see the likes of Max Verstappen or Lando Norris appearing in these races, both of them being fans of iRacing.

{{< youtube aK2-nlfnPys >}}

## And a motion rig?

https://opensfx.com/

https://github.com/SimFeedback/SimFeedback-AC-Servo

https://github.com/JamesClonk/simracing-rig

https://imgur.com/a/8NfyycK

### SimFeedback

The software used to control the servos and motors is called [SimFeedback](https://github.com/SimFeedback/SimFeedback-AC-Servo), written by the same person who open-sourced the OpenSFX100 plans in the first place.

![SimFeedback](/images/simfeedback.png)

### Telemetry data is not working?

Oh no, what's wrong?!

After I finally got everything up and running I discovered a major problem. You see, iRacing has 2 different output modes for telemetry data. It is a memory-mapped file that refreshes provides data in either 60hz mode (the default) or in an increased 360hz mode (providing more accurate, albeit somewhat interpolated data). The problem I discovered though was that the majority of my software that I already was using to read telemetry data and do useful things with it, like [simulating wind / air flow via Arduino-controlled fans](https://www.youtube.com/watch?v=7fEaeoBWdHo) or control [bass-shakers](https://thebuttkicker.com/buttkicker-lfe/) to simulate vibrations and road texture, was operating in 60hz mode only. The iRacing plugin provided by SimFeedback on the other hand was expecting 360hz telemetry input and you can only use either one of these modes in iRacing, not both at the same time! 😱

Good thing I know my way around software a bit, more or less anyway. 
It was time to dig into the source code of SimFeedback or rather its plugin interface. Having never before worked with C# this turned out to be quite the adventure, having to learn my way around an entirely new language just for the sake of writing a 60hz telemetry plugin for myself might sound a bit like overkill. 😂

In the end though I figured out what was needed and managed to create the [iR60 Telemetry Provider](https://github.com/JamesClonk/iR60TelemetryProvider) plugin and put it on GitHub to let everybody else profit from my work too. (As it turns out a lot of people use 60hz mode given that it's iRacings default)

Now I could finally hook up all my gadgets and get back to actual racing on track.

## The result

Here you can see the final thing in action:
{{< youtube M1Aam-OnV7w >}}

