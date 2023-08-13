---
title: 'Pip — extra-index-url, Considered Dangerous'
description: "Bad advice around the usage of Python’s pip configuration could expose your organization to attackers. Here’s what you can do instead\_…"
date: 19/05/2020
categories: []
tags: ['pip','leak','python','extra-index-url']
slug: pip-extra-index-url-considered-dangerous
featured_image: /img/1____xRDSmUgNyQru__zU8Ks__zA.jpeg
---


Python is an extremely powerful programming language. The language itself includes just about every tool or feature you would need to develop anything from quick and dirty scripts, to powerful and fast servers, to awesome data visualizations.

The Python ecosystem, like most modern programming languages, includes a public repository of packages and tools, Pypi. Users typically use the `pip`command to interact with the Pypi repository, and to setup packages on their local systems. With no other configuration a user’s pip command will point to this public repository.

---

But what if you want to develop packages, but not publish to the public Pypi repo? Can you still use ‘pip’? Certainly! But despite how easy some basic tools and instructions make it seem, this may not be as straightforward as it sounds at first blush.

Typically these instructions for self-hosted repos, or even some pay-for cloud solutions ask that you point to the private repository using the `— extra-index-url` flag. This effectively combines your own private Pypi like repo with the public Pypi repo. It’s typically important to have both setup like this otherwise standard requirements for your tooling won’t be able to be found if you only pointed to your private repo, without retaining the public repo.

---

This setup is actually a pretty serious security concern and could allow attackers to inject arbitrary code in any environment that attempts to use your private repo. This attack will work regardless of where you host your private repo, or if your private repo is protected with access credentials.

The issues arises with how the package selections are made when a pip command is executed. The pip command will gather available packages from both the standard `index-url` and the `extra-index-url` you added for your private repo. If a user attempts to install the latest version of your package:

```
pip install myawesomeprogram
```

Pip will find any packages called ‘myawesomeprogram’ and attempt to download and install the latest version. So if an attacker were to register ‘myawesomeprogram’ on Pypi, and release a version 1000000 of this tool, you will pull down the attacker’s fake version of the package, not the one from your private repo!

---

Can we work around this?

Certainly!

_With the right tools._

The trick is, that we want to both control the packages that we develop, while still allowing pulling of typical public packages. In order to do this, it’s important to have pip point to a single `index-url` that we control, without adding an `extra-index-url`.

The repository itself must be able to proxy public Pypi, and should have controls to restrict nefarious name hijacking. Repositories like Sonatype’s Nexus and JFrog’s Artifactory provide the ability to combine a hosted python repo, along with a proxied repo, like Pypi. Importantly, both tools also allow us to block packages from proxied repositories via regular expressions.

In this case we could setup a proxy of pypi that specifically blocks packages that match our naming convention, while still allowing pulling other typical public packages. The name hijacked package on the public Pypi would be ignored, protecting our users.

---

Often simple and easy solutions come with caveats and concerns. In the case of `extra-index-url` there are few, if any cases where this feature can be safely used. Package management, while seemingly simple at first glance, requires careful consideration to both protect your assets, but also your users.
