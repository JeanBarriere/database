FROM        postgres:9.6.14-alpine

# copy patched pg_dump (sorted output)
COPY        pg_dumps /usr/local/bin/

# install dependencies for sqitch
RUN         apk add --update wget make gcc musl-dev tzdata \
                             perl perl-dev perl-module-build perl-app-cpanminus

# install sqitch and postgres driver
RUN         cpanm --quiet --notest App::Sqitch DBD::Pg

# set timezone (required for sqitch)
RUN         cp /usr/share/zoneinfo/Europe/Amsterdam /etc/localtime

# install bash to run scripts
RUN         apk add --update bash

ENTRYPOINT  /bin/bash
