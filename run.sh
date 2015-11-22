#!/bin/sh
# run.sh

# HOMER Options, defaults
DB_USER=homer
DB_PASS=homersecret
DB_HOST=mysql
LISTEN_PORT=9060
# HOMER MySQL Options, defaults
sqluser=root
sqlpassword=secret


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

echo 'Starting mysqld'
sudo mysql_install_db --user=mysql --basedir=/usr/ --ldata=/var/lib/mysql/
mysqld_safe &

echo 'Waiting for mysqld to come online'
# The sleep 1 is there to make sure that inotifywait starts up before the socket is created
while [ ! -x /var/run/mysqld/mysqld.sock ]; do
    sleep 1
done

echo 'Setting root password....'
/usr/bin/mysqladmin -u root password '$sqlpassword'

echo "Creating Databases..."
mysql --host mysql -u "$sqluser" -p"$sqlpassword" -e < $SQL_LOCATION/sql/homer_databases.sql
mysql --host mysql -u "$sqluser" -p"$sqlpassword" -e < $SQL_LOCATION/sql/homer_user.sql

mysql --host mysql -u "$sqluser" -p"$sqlpassword" -e "GRANT ALL ON *.* TO '$DB_USER'@'%' IDENTIFIED BY '$DB_PASS'; FLUSH PRIVILEGES;";
echo "Creating Tables..."
mysql --host mysql -u "$sqluser" -p"$sqlpassword" homer_data < $SQL_LOCATION/sql/schema_data.sql
mysql --host mysql -u "$sqluser" -p"$sqlpassword" homer_configuration < $SQL_LOCATION/sql/schema_configuration.sql
mysql --host mysql -u "$sqluser" -p"$sqlpassword" homer_statistic < $SQL_LOCATION/sql/schema_statistic.sql
# mysql --host mysql -u "$sqluser" -p"$sqlpassword" homer_users -e "TRUNCATE TABLE homer_nodes;"

# echo "Creating local DB Node..."
mysql --host mysql -u "$sqluser" -p"$sqlpassword" homer_configuration -e "INSERT INTO node VALUES(1,'mysql','homer_data','3306','"$DB_USER"','"$DB_PASS"','sip_capture','node1', 1);"

# Start the cron service in the background for rotation
cron -f &


# KAMAILIO CONFIG
PATH_KAMAILIO_CFG=/etc/kamailio/kamailio.cfg

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
