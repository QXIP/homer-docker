#!/bin/sh
# run.sh

# HOMER Options, defaults
DB_USER=homer_user
DB_PASS=homer_password
DB_HOST=127.0.0.1
LISTEN_PORT=9060
# HOMER MySQL Options, defaults
sqluser=root
sqlpassword=secret

DOCK_IP=127.0.0.1;

# HOMER API CONFIG
PATH_HOMER_CONFIG=/var/www/html/api/configuration.php

# Replace values in template
perl -p -i -e "s/\{\{ DB_PASS \}\}/$DB_PASS/" $PATH_HOMER_CONFIG
perl -p -i -e "s/\{\{ DB_HOST \}\}/$DB_HOST/" $PATH_HOMER_CONFIG
perl -p -i -e "s/\{\{ DB_USER \}\}/$DB_USER/" $PATH_HOMER_CONFIG

# Argh permission giving me hell. Needed for legacy support.
mkdir /var/www/html/api/tmp
chmod -R 0777 /var/www/html/api/tmp/

# MYSQL SETUP
SQL_LOCATION=/homer-api/sql

DATADIR=/var/lib/mysql
mysql_install_db --user=mysql --datadir="$DATADIR"

chown -R mysql:mysql "$DATADIR"

echo 'Starting mysqld'
#mysqld_safe &
mysqld &

#echo 'Waiting for mysqld to come online'
## The sleep 1 is there to make sure that inotifywait starts up before the socket is created
while [ ! -x /var/run/mysqld/mysqld.sock ]; do
    sleep 1
done

echo 'Setting root password....'
/usr/bin/mysqladmin -u root password "$sqlpassword"

echo "Creating Databases..."
# mysql --host "$DOCK_IP" -u "$sqluser" -p"$sqlpassword" < $SQL_LOCATION/homer_databases.sql
mysql --host "$DOCK_IP" -u "$sqluser"  < $SQL_LOCATION/homer_databases.sql
mysql --host "$DOCK_IP" -u "$sqluser"  < $SQL_LOCATION/homer_user.sql

mysql --host "$DOCK_IP" -u "$sqluser"  -e "GRANT ALL ON *.* TO '$DB_USER'@'%' IDENTIFIED BY '$DB_PASS'; FLUSH PRIVILEGES;";
echo "Creating Tables..."
mysql --host "$DOCK_IP" -u "$sqluser"  homer_data < $SQL_LOCATION/schema_data.sql
mysql --host "$DOCK_IP" -u "$sqluser"  homer_configuration < $SQL_LOCATION/schema_configuration.sql
mysql --host "$DOCK_IP" -u "$sqluser"  homer_statistic < $SQL_LOCATION/schema_statistic.sql

# echo "Creating local DB Node..."
mysql --host "$DOCK_IP" -u "$sqluser"  homer_configuration -e "INSERT INTO node VALUES(1,'mysql','homer_data','3306','"$DB_USER"','"$DB_PASS"','sip_capture','node1', 1);"

# Start the cron service in the background for rotation
cron -f &

# KAMAILIO CONFIG
export PATH_KAMAILIO_CFG=/etc/kamailio/kamailio.cfg

awk '/max_while_loops=100/{print $0 RS "mpath=\"//usr/lib/x86_64-linux-gnu/kamailio/modules/\"";next}1' $PATH_KAMAILIO_CFG >> $PATH_KAMAILIO_CFG.tmp && mv $PATH_KAMAILIO_CFG.tmp $PATH_KAMAILIO_CFG

# Replace values in template
perl -p -i -e "s/\{\{ LISTEN_PORT \}\}/$LISTEN_PORT/" $PATH_KAMAILIO_CFG
perl -p -i -e "s/\{\{ DB_PASS \}\}/$DB_PASS/" $PATH_KAMAILIO_CFG
perl -p -i -e "s/\{\{ DB_HOST \}\}/$DB_HOST/" $PATH_KAMAILIO_CFG
perl -p -i -e "s/\{\{ DB_USER \}\}/$DB_USER/" $PATH_KAMAILIO_CFG

# Make an alias, kinda.
kamailio=$(which kamailio)

# Test the syntax.
$kamailio -f $PATH_KAMAILIO_CFG -c

# Now, kick it off.
$kamailio -f $PATH_KAMAILIO_CFG -DD -E -e

# Foreground apache.
apachectl -DFOREGROUND
#apachectl start
