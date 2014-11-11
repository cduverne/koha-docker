#######
# DEVELOPMENT IMAGE OF KOHA - PROVISIONED BY SALT
# Baser on debian wheezy vanilla Koha
#######

FROM digibib/koha:latest

MAINTAINER Oslo Public Library "digitalutvikling@gmail.com"

ENV REFRESHED_AT 2015-01-20

RUN DEBIAN_FRONTEND=noninteractive apt-get update && \
    sudo apt-get install -q -y cpanminus vim git-email && \
    apt-get clean

#########################
# KOHA INSTANCE VARIABLES
#########################

ENV KOHA_ADMINUSER admin
ENV KOHA_ADMINPASS secret
ENV KOHA_INSTANCE name
ENV KOHA_ZEBRAUSER zebrauser
ENV KOHA_ZEBRAPASS lkjasdpoiqrr

################################
# KOHA DEV ENVIRONMENT VARIABLES
################################

ENV AUTHOR_NAME  john_doe
ENV AUTHOR_EMAIL john@doe.com
ENV BUGZ_USER    bugsquasher
ENV BUGZ_PASS    bugspass
ENV KOHA_REPO    https://github.com/Koha-Community/Koha.git
ENV MY_REPO      https://github.com/digibib/koha-work
ENV GITBZ_REPO   https://github.com/digibib/git-bz.git
ENV QATOOLS_REPO https://github.com/Koha-Community/qa-test-tools.git

RUN mkdir -p /kohadev && cd /kohadev && \
    git clone --depth=1 $KOHA_REPO kohaclone

# kohadev dependencies
RUN apt-get install -y libtemplate-plugin-json-escape-perl libtext-bidi-perl && \
    apt-get clean

# Configure Git and some repos
RUN git config --global user.name "$AUTHOR_NAME" && \
    git config --global user.email "$AUTHOR_EMAIL" && \
    git config --global color.status auto && \
    git config --global color.branch auto && \
    git config --global color.diff auto && \
    git config --global diff.tool vimdiff && \
    git config --global difftool.prompt false && \
    git config --global alias.d difftool && \
    git config --global alias.update "fetch origin master --depth=1" && \
    # Allows usage like git qa <bugnumber> to set up a branch based on master and fetch patches for <bugnumber> from bugzilla
    git config --global alias.qa '!sh -c "git fetch origin master --depth=1 && git rebase origin/master && git checkout -b qa-$1 origin/master && git bz apply $1"' - && \
    # Allows usage like git qa-tidy <bugnumber> to remove a qa branch when you are through with it
    git config --global alias.qa-tidy '!sh -c "git checkout master && git branch -D qa-$1"' - && \
    git config --global core.whitespace trailing-space,space-before-tab && \
    git config --global apply.whitespace fix

# Git bz
# http://wiki.koha-community.org/wiki/Git_bz_configuration
RUN cd /kohadev && \
    git clone $GITBZ_REPO gitbz && \
    cd gitbz && git checkout -b fishsoup origin/fishsoup && \
    sudo ln -s /kohadev/gitbz/git-bz /usr/local/bin/git-bz

# Apache dev settings
ADD apache-kohadev.conf /srv/salt/koha/files/apache.tmpl
ADD koha-conf.xml.tmpl /srv/salt/koha/files/koha-conf.xml.tmpl

ENV HOME /root
WORKDIR /root

COPY docker-entrypoint.sh /root/entrypoint.sh
ENTRYPOINT ["/root/entrypoint.sh"]

EXPOSE 8080 8081

VOLUME ["/kohadev"]

# Might be koha-common (Zebra) should be stand-alone container
CMD ["/usr/bin/tail", "-f", "/var/log/apache2/access.log", "/var/log/koha/name/intranet-error.log", "/var/log/koha/name/opac-error.log", "/var/log/koha/name/zebra-error.log", "/var/log/apache2/other_vhosts_access.log"]
