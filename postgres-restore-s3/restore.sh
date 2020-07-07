#! /bin/sh

set -e
set -o pipefail

if [ "${S3_ACCESS_KEY_ID}" = "**None**" ]; then
  echo "You need to set the S3_ACCESS_KEY_ID environment variable."
  exit 1
fi

if [ "${S3_SECRET_ACCESS_KEY}" = "**None**" ]; then
  echo "You need to set the S3_SECRET_ACCESS_KEY environment variable."
  exit 1
fi

if [ "${S3_BUCKET}" = "**None**" ]; then
  echo "You need to set the S3_BUCKET environment variable."
  exit 1
fi

if [ "${POSTGRES_DATABASE}" = "**None**" ]; then
  echo "You need to set the POSTGRES_DATABASE environment variable."
  exit 1
fi

if [ "${POSTGRES_HOST}" = "**None**" ]; then
  if [ -n "${POSTGRES_PORT_5432_TCP_ADDR}" ]; then
    POSTGRES_HOST=$POSTGRES_PORT_5432_TCP_ADDR
    POSTGRES_PORT=$POSTGRES_PORT_5432_TCP_PORT
  else
    echo "You need to set the POSTGRES_HOST environment variable."
    exit 1
  fi
fi

if [ "${POSTGRES_USER}" = "**None**" ]; then
  echo "You need to set the POSTGRES_USER environment variable."
  exit 1
fi

if [ "${POSTGRES_PASSWORD}" = "**None**" ]; then
  echo "You need to set the POSTGRES_PASSWORD environment variable or link to a container named POSTGRES."
  exit 1
fi

# env vars needed for aws tools
export AWS_ACCESS_KEY_ID=$S3_ACCESS_KEY_ID
export AWS_SECRET_ACCESS_KEY=$S3_SECRET_ACCESS_KEY
export AWS_DEFAULT_REGION=$S3_REGION
export PGPASSWORD=$POSTGRES_PASSWORD
POSTGRES_HOST_OPTS="-h $POSTGRES_HOST -p $POSTGRES_PORT -U $POSTGRES_USER"

export PIT=$(echo ${RESTORE_TO} | tr  '[:lower:]' '[:upper:]' )

echo "Finding latest backup"

generateAWSPath(){

  if [ "$RESTORE_FILE" != "**None**" ]; then
    aws s3api head-object --bucket $S3_BUCKET --key $RESTORE_FILE || not_exist=true
    if [ $not_exist ]; then
       echo "Wrong filename or file doesn't exist"
       exit 1
    else
       BACKUP=$(aws s3 ls s3://$S3_BUCKET/$RESTORE_FILE  --recursive | tail -n 1  | awk '{print $4}')

    fi

  elif [ "$PIT" = "LATEST" ]; then
    if [ "$AES_KEY" = "**None**" ]; then
      BACKUP=$(aws s3 ls s3://$S3_BUCKET/$S3_PREFIX/ --recursive  | tail -n 1 | awk '{print $4}')
    else
      BACKUP=$(aws s3 ls s3://$S3_BUCKET/$S3_PREFIX/ --recursive  | tail -n 1| grep dat | awk '{print $4}')
    fi
  else
    echo "Can be absolute path or LATEST"
fi

}
generateAWSPath

echo "Fetching ${BACKUP} from S3"

if [ "AES_KEY" != "**None**" ]; then
  aws s3 cp s3://$S3_BUCKET/${BACKUP} dump.sql.gz.dat
  openssl enc -in dump.sql.gz.dat  -out dump.sql.gz -d -aes256 -md sha256 -pbkdf2 -k $AES_KEY
else
  aws s3 cp s3://$S3_BUCKET/${BACKUP} dump.sql.gz
fi

gzip -d dump.sql.gz

if [ "${DROP_PUBLIC}" == "yes" ]; then
	echo "Recreating the public schema"
	psql $POSTGRES_HOST_OPTS -d $POSTGRES_DATABASE -c "drop schema public cascade; create schema public;"
fi

echo "Restoring ${BACKUP}"

#psql $POSTGRES_HOST_OPTS -d $POSTGRES_DATABASE < dump.sql
psql $POSTGRES_HOST_OPTS -d $POSTGRES_DATABASE < dump.sql
echo "Restore complete"
