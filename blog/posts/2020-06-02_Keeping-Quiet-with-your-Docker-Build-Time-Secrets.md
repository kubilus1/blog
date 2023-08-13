---
title: Keeping Quiet with your Docker Build Time Secrets
description: >-
  It’s surprisingly easy to accidentally leak secrets in Docker images that
  require build time logins. By taking some care and following a…
date: 02/06/2020
categories: []
tags: ['docker', 'build', 'leak', 'credentials']
slug: /@mattkubilus/keeping-quiet-with-your-docker-build-time-secrets-7893ae438490
featured_image: img/1__MKFSNj1OAEnU2YyyQsxx2A.jpeg
---


It’s surprisingly easy to accidentally leak secrets in Docker images that require build time logins. By taking some care and following a few techniques, this can be avoided entirely.

Good micro-services design indicates that we should keep our stateless components separate from our stateful components and from our configuration. For example, you may have a web app service we’ll call WebApp developed as a Docker container.

The stateless part would be the code and files themselves inside the Docker image, that perhaps runs a process that serves out interactive WebApp. This app may need to hold information such as user input that can be retrieved later, and would connect to an external database in order to store that. This is the separate ‘stateful’ component. This could be a local MySQL database or an Aurora instance in AWS. The nature of Docker containers makes it pretty clear that these two should be two separate ‘things’.

In order to connect the two, you would use configuration in the form of credentials and the database FQDN. It’s pretty obvious you would not want to hard code those parameters into the image itself, and instead would provide blank, or generic variables that would be filled in during run time. For instance:

```bash
FROM ubuntu

ENV DBFQDN=  
ENV DBUSER=  
ENV DBPASS=

COPY webapp /webapp  
CMD /webapp
```

There are several ways to pass these parameters in, but the simplest case may be something like:

```
$ docker run -d \\  
  -e DBFQDN=$PRODDB \\  
  -e DBUSER=$PRODUSER \\  
  -e DBPASS=$PRODPASS \\  
  webapp
```

All of that seems pretty obvious and well understood. But what about configuration that needs to be sent at build time of the image? For instance, what if WebApp needs an internal library on a private FTP server within your company to run?

You may be tempted to use build arguments to pass these build time variables in. For instance the following likely would work:

```
FROM ubuntu

ENV DBFQDN=  
ENV DBUSER=  
ENV DBPASS=

ARG FTPUSER=  
ARG FTPPASS=

ENV FTPSTRING=ftp://$FTPUSER:$FTPPASS@ftp.mycompany.com

COPY webapp /webapp  
RUN wget -O $FTPSTRING/areq && cp areq /

CMD /webapp
```

The build command would look like:

```
$ docker build --build-arg FTPUSER=$PRODFTP\_USER --build-arg FTPPASS=$PRODFTP\_PASS -t webapp .
```

The FTPUSER and FTPPASS parameters are not turned into environment variables with ENV, but in this case the FTPSTRING environment variable will show the ftp secrets in the plain text in the running image.

Okay, then, just don’t expose this as an environment variable and everything should be okay, right? Not so fast!

```
FROM ubuntu

ENV DBFQDN=  
ENV DBUSER=  
ENV DBPASS=

ARG FTPUSER=  
ARG FTPPASS=

COPY webapp /webapp  
RUN wget -O ftp://$FTPUSER:$FTPPASS@ftp.mycompany.com/areq && cp areq /

CMD /webapp
```

The above Dockerfile would not show the ftp creds in the environment. But, they are easily visible in the layers of the image itself. By using a simple:

```
docker history --no-trunc webapp

I can see our FTP credentials in plain text:

sha256:5487d5ca8c262ddc8a2878308c9210c355b5bfcd46bb314470579b6d0af6f323   4 seconds ago       |2 FTPPASS=secret FTPUSER=me /bin/sh -c wget -O ftp://$FTPUSER:$FTPPASS@ftp.mycompany.com/areq
```

Not good. Anyone with access to this image would have access to our FTP server.

You can go through hoops such as export containers, turning them into tarballs, reimporting, etc in order to flatten an image. But this is an expensive process that removes some of the advantages of using Docker images to begin with. Instead, you can enable some newer Docker build features to safely pass in secrets at build time.

A safer Dockerfile for our case would look like:

```
\# syntax = docker/dockerfile:1.0-experimental

FROM ubuntu

ENV DBFQDN=  
ENV DBUSER=  
ENV DBPASS=

RUN apt-get update && apt-get install -y wget

COPY webapp /webapp  
RUN --mount=type=secret,id=ftpuser \\  
    --mount=type=secret,id=ftppass \\  
    FTPUSER=$(cat /run/secrets/ftpuser) && \\  
    FTPPASS=$(cat /run/secrets/ftppass) && \\  
    wget -O ftp://$FTPUSER:$FTPPASS@ftp.mycompany.com/areq && cp areq /

CMD /webapp
```

And this would be built with the following command:

```
$ DOCKER\_BUILDKIT=1 docker build -t webapp \\  
    --secret id=ftpuser,src=<( echo $PRODFTP\_USER ) \\  
    --secret id=ftppass,src=<( echo $PRODFTP\_PASS ) \\  
    .
```

With this setup, the FTP creds are neither in the image itself, or in any of the layers. Using the `history` command verifies that there are no secrets in places we don’t want them.

Let me break down the above.

Let’s start from the build command. First, we need a relatively modern version of Docker. Version 18.09 or newer. This allows us to use the new DOCKER\_BUILDKIT switch that we enable with `DOCKER_BUILDKIT=1`. The `--build-arg` arguments are replaced with `--secret`. For instance `--secret id=ftpuser,src=<( echo $PRODFTP_USER )` is saying create a secret with id `ftpuser`, as a source, this secret will use process redirection to get the results of `echo $PRODFTP_USER`. The sources are in fact files. By using process redirection, we prevent our secrets from ever actually touching the filesystem!

Okay at this point we’ve created two secrets with ids `ftpuser` and `ftppass` let’s take a look at our Dockerfile.

The very first line is important, at least for now:

```
\# syntax = docker/dockerfile:1.0-experimental
```

This indicates that we will allow new, experimental syntax with this Dockerfile.

Note, that our secrets were considered files above. In order to access these secrets we then mount each secret:

```
\--mount=type=secret,id=ftpuser
```

And then read the ‘file’ into an inline variable.

```
FTPUSER=$(cat /run/secrets/ftpuser)
```

Our WebApp image we’ve developed is now safe and secure!

With this setup we can both leverage secrets during image build time, and prevent any leakage of secrets in the final image, or in any image layer.

It’s important to remain vigilant with your Docker images as these can provide many vectors to attack your organization, if not well cared for. We can conclude that any usage of `--build-arg` when building docker images is insecure and can be easily viewed in plain text and should be considered a red-flag for potential credential leakage vulnerabilities.
