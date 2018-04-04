FROM centos:7
LABEL version="0.6a"
LABEL description="Subversion to GitHub Migrator"

MAINTAINER Jared Murrell <primetheus@github.com>

COPY _functions.sh /root/_functions.sh
COPY svn2github.sh /root/svn2github.sh
COPY settings.ini /root/settings.ini

RUN yum -y localinstall https://centos7.iuscommunity.org/ius-release.rpm && \
    yum -y install git2u-svn git2u git-lfs bc && yum clean all && \
    rm -fr /var/cache/yum && chmod +x /root/svn2github.sh && \
    git config --global user.name "SVN to GitHub" && git config --global \
    user.email "svn2github@example.com"

WORKDIR /root

CMD [ "bash" ]
