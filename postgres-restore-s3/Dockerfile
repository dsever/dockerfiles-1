FROM alpine:3.11
LABEL maintainer="Orignal: Johannes Schickling <schickling.j@gmail.com>, Update: dubravko.sever@gmail.com"

RUN apk add --update openssl && \
    rm -rf /var/cache/apk/*

ADD install.sh install.sh
RUN sh install.sh && rm install.sh

ENV POSTGRES_DATABASE **None**
ENV POSTGRES_HOST **None**
ENV POSTGRES_PORT 5432
ENV POSTGRES_USER **None**
ENV POSTGRES_PASSWORD **None**
ENV S3_ACCESS_KEY_ID **None**
ENV S3_SECRET_ACCESS_KEY **None**
ENV S3_BUCKET **None**
ENV S3_REGION us-west-1
ENV S3_PATH 'backup'
ENV DROP_PUBLIC 'no'
ENV AES_KEY **None**
ENV RESTORE_TO latest

ADD restore.sh restore.sh

CMD ["sh", "restore.sh"]
