FROM        sqitch/sqitch:1.0.0

COPY        . /database

WORKDIR     /database

ENTRYPOINT  ./docker-entrypoint.sh
