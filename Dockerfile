FROM        sqitch/sqitch:1.0.0

COPY        . /database

WORKDIR     /database

ENTRYPOINT  sqitch deploy $DATABASE_URL
