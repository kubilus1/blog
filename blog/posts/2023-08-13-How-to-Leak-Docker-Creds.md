---
title: How to Leak Credentials with Docker, and a few strategies to avoid doing so
date: 13/08/2023
tags: [docker, credentials, CICD]
featured_image: images/pexels-luis-quintero-2339722.jpg
---

When building Docker images, it's possible you may need to access privately manage repositories.  This is pretty common in development organizations that leverage artifact management tooling such as Artifactory or Nexus.

It may be tempting to simply treat the Dockerfile much like a shell script where you have input parameters that are used within the script.  Afterall, `docker build` has a `--build-args` script, so that seems like the way to go.

```
ARG A_USER
ENV A_USER=${A_USER}
ARG A_PASS
ENV A_PASS=${A_PASS}
```

Then a build occurs like so:

```
$ docker build --build-arg A_USER=$AUSER --build-arg A_PASS=$APASS -t leaktest1 .
```

Our CICD system can provide the AUSER and APASS env vars only during build time, so this should be a nice secure way to handle things.  Right??

Well let's take a look at the image in more detail.  Recall that a docker image is made up of a number of layers.  The container that you run is an instantiation of this layered image. 

We can take a look at the steps that built each layer of an image, including base images with the `docker history` command.

```
$ docker history --no-trunc leaktest1
IMAGE                                                                     CREATED         CREATED BY                                                                                          SIZE      COMMENT
sha256:bd8bbdc38ee8f344790890d9d08b7251f998268d70b8940990185875e240c5d8   2 minutes ago   RUN |2 A_USER=me A_PASS=secret /bin/sh -c /install.sh # buildkit                                    0B        buildkit.dockerfile.v0
<missing>                                                                 4 minutes ago   COPY install.sh / # buildkit                                                                        39B       buildkit.dockerfile.v0
<missing>                                                                 4 minutes ago   ENV A_PASS=secret                                                                                   0B        buildkit.dockerfile.v0
<missing>                                                                 4 minutes ago   ARG A_PASS                                                                                          0B        buildkit.dockerfile.v0
<missing>                                                                 4 minutes ago   ENV A_USER=me                                                                                       0B        buildkit.dockerfile.v0
<missing>                                                                 4 minutes ago   ARG A_USER                                                                                          0B        buildkit.dockerfile.v0
<missing>                                                                 8 months ago    /bin/sh -c #(nop)  CMD ["bash"]                                                                     0B        
<missing>                                                                 8 months ago    /bin/sh -c #(nop) ADD file:29c72d5be8c977acaeb6391aeb23ec27559b594e25a0bb3a6dd280bac2847b7f in /    77.8MB    
```

Woops!  Our creds are right there in plaintext to see!  Anyone with access to this image now has these credentials.  Depending on your security stance, this is likely not ideal.

This same information can be shown via `docker inspect` as well:

```
$ docker inspect leaktest1 | jq '.[].Config.Env'
[
  "PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin",
  "A_USER=me",
  "A_PASS=secret"
]
```

Luckily we have some approaches at our disposal to avoid this situation.

## Inline Mounted Secrets

Docker now supports the ability to mount secrets into the build environment.  These secrets are ephemeral and only available during the build process, so they do not end up in plain text in the build history.  By 'mounted' these secrets show up effectively as files under `/run/secrets` at build time.

So for our example above we could adjust a few things.  Our new Dockerfiles looks like this:

```
FROM ubuntu:jammy 

COPY configure.sh /
COPY install.sh /

RUN --mount=type=secret,id=a_user --mount=type=secret,id=a_pass /configure.sh && /install.sh
```

The build syntax changes a bit as well:

```
$ docker build --secret id=a_user,env=AUSER --secret id=a_pass,env=APASS -t leaktest2 .
```

Note that we indcate we are using `env` vars for AUSER and APASS and assigning these an `id`.  That same `id` is then referenced as a mount within the Dockerfile.  Let's take a look at the history of the resultant image to check for leaks like we did before:

```
$ docker history --no-trunc leaktest2
IMAGE                                                                     CREATED         CREATED BY                                                                                          SIZE     
 COMMENT
sha256:460511147c9a4debcfa5e3b68706112f8d68d844aae5b816a0a81986a58884ce   2 minutes ago   RUN /bin/sh -c /configure.sh && /install.sh # buildkit                                              45B      
 buildkit.dockerfile.v0
<missing>                                                                 2 minutes ago   COPY install.sh / # buildkit                                                                        39B      
 buildkit.dockerfile.v0
<missing>                                                                 2 minutes ago   COPY configure.sh / # buildkit                                                                      205B     
 buildkit.dockerfile.v0
<missing>                                                                 8 months ago    /bin/sh -c #(nop)  CMD ["bash"]                                                                     0B       
 
<missing>                                                                 8 months ago    /bin/sh -c #(nop) ADD file:29c72d5be8c977acaeb6391aeb23ec27559b594e25a0bb3a6dd280bac2847b7f in /    77.8MB   
 
```

Checking `docker inspect` also looks good: 
```
$ docker inspect leaktest2 | jq '.[].Config.Env'
[
  "PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"
]
```


Excellent!  Looks like we are in the clear!

Not so fast.

While we are not leaking credentials in the build history, that's not the only way that protected information can escape.  What _exactly_ does the `configure.sh` script here do.  Let's take a look:

```
#!/bin/bash

A_USER=$(cat /run/secrets/a_user)
A_PASS=$(cat /run/secrets/a_pass)

echo "Setting up access..."
echo >>~/.netrc "machine my.repo.com login ${A_USER} password ${A_PASS}" && chmod 600 ~/.netrc
```

We see the pattern of accessing our mounted secrets as files and then setting a local env var from these.  That then is used to setup a local configuration file, which presumably will be used by the next phase of setup and installation.

The issue here is that the .netrc file now exists within the docker image itself and can these creds can be viewed in plaintext.

```
$ docker run --rm leaktest2 /bin/bash -c "cat /root/.netrc"
machine my.repo.com login me password secret
```

While this is a contrived example, you can see how various types of configuration can be baked in to various configuration files.  This is a common way that certificates are leaked as well.

## Config and delete

A simple tweak to the above would be to make sure we delete the configuration file on the same line that we setup the config file.  We can change the installation line in the Dockerfile to the following:

```
RUN --mount=type=secret,id=a_user --mount=type=secret,id=a_pass /configure.sh && /install.sh && rm /root/.netrc
```

And we check the results:

```
$ docker run --rm leaktest2 /bin/bash -c "cat /root/.netrc"
cat: /root/.netrc: No such file or directory
```

This is good, and in some cases enough.  However there are a couple gotchas with this approach.  For one, are you _sure_ your configure.sh script does not have any other side effects?  How about when it is edited in 6 months by the intern?

Also, if a user is not aware of how Docker builds images in layers, what if the above is done in two steps:

```
RUN --mount=type=secret,id=a_user --mount=type=secret,id=a_pass /configure.sh && /install.sh
RUN rm /root/.netrc
```

May seem like a tiny change, but now the intermediary layer has credentials in plain text.  Tools like [dive](https://github.com/wagoodman/dive) make it pretty trivial to look into these intermediate layers.

## One liner

In some simple cases, a useful approach can be to put the credential retrieval and usage all on one line.  As an example:

```
RUN --mount=type=secret,id=a_user --mount=type=secret,id=a_pass \
    /bin/bash -c "export A_USER=$(cat /run/secrets/a_user) && \
    export A_PASS=$(cat /run/secrets/a_pass) && \
    curl -O https://$A_USER:$A_PASS@www.w3.org/WAI/ER/tests/xhtml/testfiles/resources/pdf/dummy.pdf && \
    ls"
```

This can get messy, however, particularly for more complicated use cases.
## The vanishing config file approach

Sometimes you really want to leverage a configuration file.  As we have shown above, this can be a bit tricky and there are several ways to subtly embed information into either the build history of the Docker image, or within the filesystem of the Docker image itself.

The Docker buildkit secret mounting isn't just for environment variable, and is in fact capable of mounting complete files in safe way.

The syntax looks like the following:

```
docker build --secret id=netrc,src=./mynetrc -t mountconfig .
```

The above will mount the local mynetrc file at build time only to the location `/run/secrets/netrc` .  The contents of that file will not be in the history of the build or within an image layer.

This could be used like the following: 
```
RUN --mount=type=secret,id=netrc curl -O --netrc-file /run/secrets/netrc https://my.repourl.com/thingtodownload.pkg
```

However, it may not be desirable to have a configuration file created on the filesystem at all.  We can tweak the above slightly:

```
docker build --secret id=netrc,src=<( createnetrc.sh ) -t mountconfig .
```

Where `createnetrc.sh` could be a simple shell script that will return to stdout a complete netrc file based on env vars from a build system.

---

I previously covered how avoiding --build-args and using buildkit's ability to ephemerally pull in secrets into the environment allows for avoiding credentials being pulled into your Docker images. https://mattkubilus.medium.com/keeping-quiet-with-your-docker-build-time-secrets-7893ae438490

That approach is useful for when secrets as env vars fits your needs, however sometimes it is necessary to have a configuration file based on secrets that a docker build may need access to.

It may be tempting to do something like the following in your Dockerfile using buildkit:

```
docker build --secret id=user,env=A_USER --secret id=pass,env=A_PASS
```


```
RUN --mount=type=secret,id=user --mount=type=secret,id=pass /app/config/makeaconfigfile.sh && install.sh
```




