#!/bin/bash

echo "Setting ownership/permissions on ${BARMAN_DATA_DIR} and ${BARMAN_LOG_DIR}"

install -d -m 0700 -o barman -g barman ${BARMAN_DATA_DIR}

# Ensure Barman log file is writable
install -d -m 0755 -o barman -g barman ${BARMAN_LOG_DIR}
touch ${BARMAN_LOG_DIR}/barman.log
chown barman:barman ${BARMAN_LOG_DIR}/barman.log
chmod 644 ${BARMAN_LOG_DIR}/barman.log

echo "Generating cron schedules"
echo "BARMAN_CRON_SCHEDULE=$BARMAN_CRON_SCHEDULE"
echo "BARMAN_BACKUP_SCHEDULE=$BARMAN_BACKUP_SCHEDULE"
echo "SHELL=/bin/bash" > /etc/cron.d/barman
echo "PATH=/usr/local/bin:/usr/bin:/bin" >> /etc/cron.d/barman
echo "${BARMAN_CRON_SCHEDULE} barman barman receive-wal pg; barman cron" >> /etc/cron.d/barman
echo "${BARMAN_BACKUP_SCHEDULE} barman barman backup all" >> /etc/cron.d/barman
echo "" >> /etc/cron.d/barman

echo "Generating Barman configurations"
if [ ! -f /etc/barman.conf ]; then
    cat /etc/barman.conf.template | envsubst >/etc/barman.conf;
fi
cat /etc/barman/barman.d/pg.conf.template | envsubst >/etc/barman/barman.d/pg.conf
echo "${DB_HOST}:${DB_PORT}:*:${DB_SUPERUSER}:${DB_SUPERUSER_PASSWORD}" >/home/barman/.pgpass
echo "${DB_HOST}:${DB_PORT}:*:${DB_REPLICATION_USER}:${DB_REPLICATION_PASSWORD}" >>/home/barman/.pgpass
chown barman:barman /home/barman/.pgpass
chmod 600 /home/barman/.pgpass

echo "Checking/Creating replication slot"
barman replication-status pg --minimal --target=wal-streamer | grep barman || barman receive-wal --create-slot pg
barman replication-status pg --minimal --target=wal-streamer | grep barman || barman receive-wal --reset pg

if [[ -f /home/barman/.ssh/id_rsa ]]; then
    echo "Setting up Barman private key"
    chmod 700 ~barman/.ssh
    chown barman:barman -R ~barman/.ssh
    chmod 600 ~barman/.ssh/id_rsa
fi

echo "Initializing done"

# run barman exporter every hour
exec /usr/local/bin/barman-exporter -l ${BARMAN_EXPORTER_LISTEN_ADDRESS}:${BARMAN_EXPORTER_LISTEN_PORT} -c ${BARMAN_EXPORTER_CACHE_TIME} &
echo "Started Barman exporter on ${BARMAN_EXPORTER_LISTEN_ADDRESS}:${BARMAN_EXPORTER_LISTEN_PORT}"

exec "$@"
