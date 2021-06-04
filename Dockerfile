FROM ubuntu:18.04
LABEL version="0.6a"
LABEL description="Subversion to GitHub Migrator"

MAINTAINER Jared Murrell <primetheus@github.com>

COPY _functions.sh /root/_functions.sh
COPY svn2github.sh /root/svn2github.sh
COPY settings.ini /root/settings.ini

RUN apt-get update && \
    apt-get -y --no-install-recommends install \
    git git-svn git-lfs subversion bc curl && \
    rm -fr /var/cache/apt && \
    chmod +x /root/svn2github.sh && \
    git config --global user.name "SVN to GitHub" && git config --global \
    user.email "svn2github@example.com"

WORKDIR /root

CMD [ "bash" ]
