---
title: 'Embracing Churn: Preventing Docker Container Rot'
description: >-
  Docker images, like any other piece of software, can bit rot if not regularly
  maintained.
date: 10/08/2020
categories: []
tags: ['docker', 'entropy']
slug: /@mattkubilus/embracing-churn-preventing-docker-container-rot-dbe2b0708d9
featured_image: images/dumpster_1.jpg
---

Software rot, or bit rot, is a term to describe entropy causing a code base to degrade over time. The decay is usually in small ways that are non critical on their own but can add up to real problems over time if not dealt with. A similar problem can occur with Docker images that are not regularly maintained.

Docker images are supposed to be static and complete, so how can this be?

Let’s start by examining how a classical server setup in a mutable architecture environment might be setup. A server, virtual or otherwise, would run a full operating system and a number of server software components required to do it’s thing. A set of tools like Chef, Ansible, or Greg in IT would then keep the server software up to date, and keep the underlying Operating System components up to date.

It’s intuitive that the safety and security of this setup requires keeping the full system up to date, both the server software and the underlying OS. We expect this full stack to be regularly altered.

When we start using immutable architectures, such as Docker, we now have broken out out server software into it’s own little black box of magic that runs more-or-less independently from the host. This tends to imply a few things:

*   Updates to our server software drive the updates to the image itself
*   There is a security aspect of our host separate from our server software

This can lead to a situation where software projects that have a high amount of churn will have their images built frequently and often deployed without any extra considerations. Slowly churning projects, though, will tend not to be rebuilt and deployed that often.

---

Since we may already keep our container platform well updated and we have vetted our Docker images when they are built, what’s the danger?

Drift for one.

A project may be built to utilize libraries and tools pinned to a particular version. A major security issue may require pulling in updates to a project even though no code changes have occurred at all. If a long time has passed since this project was last rebuilt, those changes can be quite large. Often changes may be a requirement that itself pins to a more up to date version of a library than what is compatible with your project.

The long and short is that even though no changes at all have happened to a project, there can be an unknown and potentially large amount of surprise work that arises with a ‘stable’ code base. Security issues, for one, can occur without warning and require swift actions, i.e. heartbleed. An issues such as this would require updating every single image that has OpenSSL libraries, and quickly.

Another potential issue is our reliance on open source and other third party repositories. Dockerfiles are great in that they provide a repeatable way to go from concise instructions to a built image, but even with version pinning, sometimes things go awry. It’s not unusual to see a particular version of a pre-requisite removed from a repository, or a particular release of package _replaced_ by a same named and versioned, but different, release of a package. Yeah, that’s all terrible practice, but it happens.

Would you rather find out about these things when you have to write an emergency patch to stop the bleeding or during a routine ‘freshen up’ rebuild when the alarms are **not** blaring?

#### Always build, always

A lot of this can be automated using the same CICD tooling you are currently using. A regularly scheduled rebuild time can be a simple and effective way to keep things up to date.

Rebuilding when upstream images change is another important consideration so you are not caught by surprise. Some registry platforms, like Dockerhub, make this particularly easy since you can setup your images to be rebuilt when dependencies are updated automatically. Without that feature, a staggered scheduled rebuild can keep things updated.

Another consideration is to watch your version pins. Pinning is great for keeping a particular release stable for later rebuilds, but neglected can lead to large hurdles for keeping projects from rotting. Tools like Dependabot are great for helping keep this in check.

---

The lesson here is that even ‘completed’ projects should be rebuilt regularly and that changes should be taken in small chunks.

Embrace the churn.
