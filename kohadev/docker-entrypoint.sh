#!/bin/bash
set -e

#########################
# KOHA INSTANCE VARIABLES
#########################

# ENV KOHA_ADMINUSER admin
# ENV KOHA_ADMINPASS secret
# ENV KOHA_INSTANCE  name
# ENV KOHA_ZEBRAUSER zebrauser
# ENV KOHA_ZEBRAPASS lkjasdpoiqrr

################################
# KOHA DEV ENVIRONMENT VARIABLES
################################

# ENV AUTHOR_NAME  john_doe
# ENV AUTHOR_EMAIL john@doe.com
# ENV BUGZ_USER    bugsquasher
# ENV BUGZ_PASS    bugspass
# ENV KOHA_REPO    https://github.com/Koha-Community/Koha.git
# ENV MY_REPO      https://github.com/digibib/koha-work
# ENV GITBZ_REPO   https://github.com/digibib/git-bz.git
# ENV QATOOLS_REPO https://github.com/Koha-Community/qa-test-tools.git


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

# Configure bugzilla login
RUN git config --global bz.default-tracker bugs.koha-community.org && \
    git config --global bz.default-product Koha && \
    git config --global bz-tracker.bugs.koha-community.org.path /bugzilla3 && \
    git config --global bz-tracker.bugs.koha-community.org.bz-user $BUGZ_USER && \
    git config --global bz-tracker.bugs.koha-community.org.bz-password $BUGZ_PASS

# Apache Koha instance config
salt-call --local state.sls koha.apache2 pillar="{koha: {instance: $KOHA_INSTANCE}}"

# Koha Sites global config
salt-call --local state.sls koha.sites-config \
  pillar="{koha: {instance: $KOHA_INSTANCE, adminuser: $KOHA_ADMINUSER, adminpass: $KOHA_ADMINPASS}}"

# If not linked to an existing mysql container, use local mysql server
if [[ -z "$DB_PORT" ]] ; then
  /etc/init.d/mysql start
  echo "127.0.0.1  db" >> /etc/hosts
  echo "CREATE USER '$KOHA_ADMINUSER'@'%' IDENTIFIED BY '$KOHA_ADMINPASS' ;
        CREATE DATABASE IF NOT EXISTS koha_$KOHA_INSTANCE ; \
        CREATE DATABASE IF NOT EXISTS koha_restful_test ; \
        GRANT ALL ON koha_$KOHA_INSTANCE.* TO '$KOHA_ADMINUSER'@'%' WITH GRANT OPTION ; \
        GRANT ALL ON koha_restful_test.* TO '$KOHA_ADMINUSER'@'%' WITH GRANT OPTION ; \
        FLUSH PRIVILEGES ;" | mysql -u root
fi

# Request and populate DB
salt-call --local state.sls koha.createdb \
  pillar="{koha: {instance: $KOHA_INSTANCE, adminuser: $KOHA_ADMINUSER, adminpass: $KOHA_ADMINPASS}}"

# Local instance config
salt-call --local state.sls koha.config \
  pillar="{koha: {instance: $KOHA_INSTANCE, adminuser: $KOHA_ADMINUSER, adminpass: $KOHA_ADMINPASS, \
  zebrauser: $KOHA_ZEBRAUSER, zebrapass: $KOHA_ZEBRAPASS}}"

# Run webinstaller to autoupdate/validate install
salt-call --local state.sls koha.webinstaller \
 pillar="{koha: {instance: $KOHA_INSTANCE, adminuser: $KOHA_ADMINUSER, adminpass: $KOHA_ADMINPASS}}"

/etc/init.d/koha-common restart
/etc/init.d/apache2 restart
/etc/init.d/cron restart

exec "$@"