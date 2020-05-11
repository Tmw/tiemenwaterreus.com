---
title: Deleting ranges of Docker images using filters
date: 2019-09-10T22:30:03+02:00
draft: false
description: After working with Docker for a while, the output of `docker images` most likely spans many, many lines. Here's how to make it clean and tidy again
tags: Docker, images, clean, purge
icon: 📦
---

If the output of `docker images` spans too many lines and you want to tidy it up, but you think [`docker system prune`](https://docs.docker.com/engine/reference/commandline/system_prune/) is like using C4 to open a can of tuna, maybe take `docker images`'s `-f` flag for a spin!

`docker images -f` utilises the [filter option](https://docs.docker.com/engine/reference/commandline/images/#filtering) and it lets you specify some extra search options to select exactly the images you're interested in!

# Filter Options

Currently Docker supports a list of filter options, but in this write-up we're only focussing on the `before` and `since` filters - go for a full overview of the available filter options to the [Docker Docs on Filtering](https://docs.docker.com/engine/reference/commandline/images/#filtering)

**-f since={image id}**
The filter option since takes an image ID and selects all the images that are newer than the given image.

**-f before={image id}**
Much like since, this tag selects all the images that are older than the given image id.

And to select a whole range of Docker Images, simply stick 'em together!

# Example

Enough talking; show me the money! So - imagine the output of `docker images` looks like the following:

```bash
REPOSITORY          TAG                 IMAGE ID            CREATED             SIZE
hippo-fe            latest              ec8ec381807d        55 minutes ago      455MB
hippo-backend_api   latest              88a08f954c9f        4 days ago          47.4MB
<none>              <none>              66ee4e399b4a        4 days ago          423MB
<none>              <none>              098006369e17        4 days ago          449MB
<none>              <none>              7010975558a2        4 days ago          449MB
<none>              <none>              75ecd4cee8ef        4 days ago          47.4MB
<none>              <none>              d3942b2482a2        4 days ago          449MB
<none>              <none>              88676747d621        4 days ago          449MB
<none>              <none>              eb522755627b        4 days ago          445MB
<none>              <none>              d62380cf625f        5 days ago          86.3MB
<none>              <none>              21bce955c85b        5 days ago          474MB
spacevim/spacevim   latest              a6b4bb27c4e9        2 weeks ago         1.36GB
<none>              <none>              abf507ccc201        2 weeks ago         106MB
<none>              <none>              79a409b99ca5        2 weeks ago         530MB
<none>              <none>              5fd5b5859b37        3 weeks ago         106MB
<none>              <none>              d93260d7abc3        3 weeks ago         530MB
node                10.16.3-alpine      b95baba1cfdb        3 weeks ago         76.4MB
<none>              <none>              2c62a47471d1        4 weeks ago         106MB
<none>              <none>              3de57027cc18        4 weeks ago         523MB
elixir              1.9.1-alpine        33a0cf122cf7        5 weeks ago         87.6MB
<none>              <none>              e5196ef97445        6 weeks ago         104MB
elixir              1.8.1-alpine        447a8dff23a8        5 months ago        91.1MB
alpine              3.9                 5cb3aa00f899        6 months ago        5.53MB
```

That's quite the list! Let's say we're no longer interested in the images below the image tagged as `hippo-backend_api` with image id `88a08f954c9f` and the images above `spacevim/spacevim` with image id `a6b4bb27c4e9`, how would we go about that using the filters described above?

```bash
$ docker images -f before=88a08f954c9f
```

Would give us all the images that are created _before_ the _hippo-backend_api_ one. Next step would be to select all the Docker images up-to a given image in history:

```bash
$ docker images -f before=88a08f954c9f -f since=a6b4bb27c4e9
```

Gives us all the images in a given range:

```bash
<none>              <none>              66ee4e399b4a        4 days ago          423MB
<none>              <none>              098006369e17        4 days ago          449MB
<none>              <none>              7010975558a2        4 days ago          449MB
<none>              <none>              75ecd4cee8ef        4 days ago          47.4MB
<none>              <none>              d3942b2482a2        4 days ago          449MB
<none>              <none>              88676747d621        4 days ago          449MB
<none>              <none>              eb522755627b        4 days ago          445MB
<none>              <none>              d62380cf625f        5 days ago          86.3MB
<none>              <none>              21bce955c85b        5 days ago          474MB
```

As you can see we're now only given the images in the selected range!

Soo - all we have to do now is tag on the `-q` flag to solely get a list of image ID's and pipe it into `xargs` to use them as arguments in the `docker rmi -f` command...

```bash
$ docker images -f before=a6b4bb27c4e9 -f since=88a08f954c9f -q | xargs docker rmi -f

```

... and voila! If we then run the docker images command again, we'll see that the given range has been deleted:

```bash
REPOSITORY          TAG                 IMAGE ID            CREATED             SIZE
hippo-fe            latest              ec8ec381807d        2 hours ago         455MB
hippo-backend_api   latest              88a08f954c9f        4 days ago          47.4MB
spacevim/spacevim   latest              a6b4bb27c4e9        2 weeks ago         1.36GB
<none>              <none>              abf507ccc201        2 weeks ago         106MB
<none>              <none>              79a409b99ca5        2 weeks ago         530MB
<none>              <none>              5fd5b5859b37        3 weeks ago         106MB
<none>              <none>              d93260d7abc3        3 weeks ago         530MB
node                10.16.3-alpine      b95baba1cfdb        3 weeks ago         76.4MB
<none>              <none>              2c62a47471d1        4 weeks ago         106MB
<none>              <none>              3de57027cc18        4 weeks ago         523MB
elixir              1.9.1-alpine        33a0cf122cf7        5 weeks ago         87.6MB
<none>              <none>              e5196ef97445        6 weeks ago         104MB
elixir              1.8.1-alpine        447a8dff23a8        5 months ago        91.1MB
alpine              3.9                 5cb3aa00f899        6 months ago        5.53MB
```

🙌
