FROM arigaio/atlas:1.1.6

WORKDIR /data

COPY ./migrations /data/migrations

CMD ["migrate", "apply", "--url", "$DATABASE_URL"]
