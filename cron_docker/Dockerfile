FROM postgres:17

RUN apt-get update && apt-get -y install postgresql-17-cron

ENV POSTGRES_CRON_DB="postgres"

COPY runtime/ /

RUN chmod +x /docker-entrypoint-initdb.d/000_bash.sh
