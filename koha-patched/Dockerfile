###########################
# KOHA DEBIAN BUILDER IMAGE
#
# this docker image takes a given koha release,
# applys patches, runs tests and builds debian packages
###########################

FROM debian:wheezy

MAINTAINER Oslo Public Library "digitalutvikling@gmail.com"

ENV DEBIAN_FRONTEND noninteractive
ENV DEBIAN_PRIORITY critical
ENV DEBCONF_NOWARNINGS yes
ENV REFRESHED_AT 2015-06-26

RUN apt-get update && \
    apt-get install --no-install-recommends -q -y vim.tiny telnet screen htop curl git \
            devscripts equivs && \
    apt-get clean

#######################
# KOHA SOURCES AND DEPS
#######################

# Install Koha deps
RUN echo "deb http://debian.koha-community.org/koha stable main" > /etc/apt/sources.list.d/koha.list
RUN curl -L http://debian.koha-community.org/koha/gpg.asc | apt-key add -
RUN apt-get update && \
    apt-get install -y koha-deps koha-perldeps make build-essential && \
    apt-get clean

RUN apt-get install -y libdbix-connector-perl libtest-perl-critic-perl && apt-get clean

ENV KOHA_VERSION 3.20.01

# Download Koha from tarball
RUN mkdir -p /koha && cd /koha && \
  curl -O http://download.koha-community.org/koha-${KOHA_VERSION}.tar.gz && \
  tar -C /koha --strip-components=1 -xzf koha-${KOHA_VERSION}.tar.gz && \
  rm -rf koha-${KOHA_VERSION}.tar.gz


##########
# GIT-BZ, PATCHLIBS AND BUILDSCRIPT
##########

# modified and stripped git-bz for patching non-git source
ADD ./git-bz /usr/bin/git-bz

# bugzilla user and pass needed for git-bz to apply patches
# can safely be left untouched
ENV BUGZ_USER    bugsquasher
ENV BUGZ_PASS    bugspass

ENV DEBEMAIL     digitalutvikling@gmail.com
ENV DEBFULLNAME  Oslo Public Library
ENV KOHABUGS     ""
ENV TEST_QA      0

RUN mkdir -p /debian
WORKDIR /koha
VOLUME ["/patches", "/debian"]

ADD ./applypatch.sh /root/applypatch.sh
ADD ./build.sh /root/build.sh

ENTRYPOINT ["/root/build.sh"]