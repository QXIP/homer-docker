#!/bin/bash
# HOMER 5 Docker (http://sipcapture.org)
# run.sh {parameters}

# HOMER Options, defaults
DB_USER=homer_user
DB_PASS=homer_password
DB_HOST="127.0.0.1"
LISTEN_PORT=9060

# HOMER MySQL Options, defaults
sqluser=root
sqlpassword=secret

# Container
DOCK_IP="127.0.0.1"

show_help() {
cat << EOF
Usage: ${0##*/} [--hep 9060]
Homer5 Docker parameters:

    --dbpass -p             MySQL password (homer_password)
    --dbuser -u             MySQL user (homer_user)
    --dbhost -h             MySQL host (127.0.0.1 [docker0 bridge])
    --mypass -P             MySQL root local password (secret)
    --hep    -H             Kamailio HEP Socket port (9060)

EOF
exit 0;
}

# Set container parameters
while true; do
  case "$1" in
    -p | --dbpass )
      if [ "$2" == "" ]; then show_help; fi;
      DB_PASS=$2;
      echo "DB_PASS set to: $DB_PASS";
      shift 2 ;;
    -P | --mypass )
      if [ "$2" == "" ]; then show_help; fi;
      sqlpassword=$2;
      echo "MySQL Pass set to: $sqlpassword";
      shift 2 ;;
    -h | --dbhost )
      if [ "$2" == "" ]; then show_help; fi;
      DB_HOST=$2;
      echo "DB_HOST set to: $DB_HOST";
      shift 2 ;;
    -u | --dbuser )
      if [ "$2" == "" ]; then show_help; fi;
      DB_USER=$2;
      echo "DB_USER set to: $DB_USER";
      shift 2 ;;
    -H | --hep )
      if [ "$2" == "" ]; then show_help; fi;
      LISTEN_PORT=$2;
      echo "HEP Port set to: $LISTEN_PORT";
      shift 2 ;;
    --help )
       	show_help;
       	exit 0 ;;
    -- ) shift; break ;;
    * ) break ;;
  esac
done

# HOMER API CONFIG
PATH_HOMER_CONFIG=/var/www/html/api/configuration.php
chmod 775 $PATH_HOMER_CONFIG

# Replace values in template
perl -p -i -e "s/\{\{ DB_PASS \}\}/$DB_PASS/" $PATH_HOMER_CONFIG
perl -p -i -e "s/\{\{ DB_HOST \}\}/$DB_HOST/" $PATH_HOMER_CONFIG
perl -p -i -e "s/\{\{ DB_USER \}\}/$DB_USER/" $PATH_HOMER_CONFIG

# Set Permissions for webapp
mkdir /var/www/html/api/tmp
chmod -R 0777 /var/www/html/api/tmp/
chmod -R 0775 /var/www/html/store/dashboard*

#MySQL Reconfig defaults
PATH_MYSQL_CONFIG=/etc/mysql/my.cnf
perl -p -i -e "s/sql_mode=NO_ENGINE_SUBSTITUTION,STRICT_TRANS_TABLES/sql_mode=NO_ENGINE_SUBSTITUTION/" $PATH_MYSQL_CONFIG
sed '/\[mysqld\]/a max_connections = 1024\' -i $PATH_MYSQL_CONFIG

# MYSQL SETUP
SQL_LOCATION=/homer-api/sql
DATADIR=/var/lib/mysql
# Internal Container?
if [ "$DB_HOST" == "$DOCK_IP" ]; then
    mysql_install_db --user=mysql --datadir="$DATADIR"
    chown -R mysql:mysql "$DATADIR"
    echo 'Starting mysqld'
    #mysqld_safe &
    mysqld &
    #echo 'Waiting for mysqld to come online'
    while [ ! -x /var/run/mysqld/mysqld.sock ]; do
        sleep 1
    done

    echo "Creating Databases..."
    mysql --host "$DB_HOST" -u "$sqluser" < $SQL_LOCATION/homer_databases.sql
    mysql --host "$DB_HOST" -u "$sqluser" < $SQL_LOCATION/homer_user.sql
    
    mysql --host "$DB_HOST" -u "$sqluser" -e "GRANT ALL ON *.* TO '$DB_USER'@'%' IDENTIFIED BY '$DB_PASS'; FLUSH PRIVILEGES;";
    echo "Creating Tables..."
    mysql --host "$DB_HOST" -u "$sqluser" homer_data < $SQL_LOCATION/schema_data.sql
    mysql --host "$DB_HOST" -u "$sqluser" homer_configuration < $SQL_LOCATION/schema_configuration.sql
    mysql --host "$DB_HOST" -u "$sqluser" homer_statistic < $SQL_LOCATION/schema_statistic.sql
    
    # echo "Creating local DB Node..."
    mysql --host "$DB_HOST" -u "$sqluser" homer_configuration -e "INSERT INTO node VALUES(1,'mysql','homer_data','3306','"$DB_USER"','"$DB_PASS"','sip_capture','node1', 1);"
    
    echo 'Setting root password....'
    mysql -u root -e "SET PASSWORD = PASSWORD('$sqlpassword');" 
        
    # Reconfigure rotation
    export PATH_ROTATION_SCRIPT=/opt/homer_rotate
    chmod 775 $PATH_ROTATION_SCRIPT
    chmod +x $PATH_ROTATION_SCRIPT
    perl -p -i -e "s/homer_user/$DB_USER/" $PATH_ROTATION_SCRIPT
    perl -p -i -e "s/homer_password/$DB_PASS/" $PATH_ROTATION_SCRIPT
    # Init rotation
    /opt/homer_rotate > /dev/null 2>&1
    
    # Start the cron service in the background for rotation
    cron -f &

fi

# KAMAILIO CONFIG
export PATH_KAMAILIO_CFG=/etc/kamailio/kamailio.cfg

awk '/max_while_loops=100/{print $0 RS "mpath=\"//usr/lib/x86_64-linux-gnu/kamailio/modules/\"";next}1' $PATH_KAMAILIO_CFG >> $PATH_KAMAILIO_CFG.tmp | 2&>1 >/dev/null
mv $PATH_KAMAILIO_CFG.tmp $PATH_KAMAILIO_CFG

# Replace values in template
perl -p -i -e "s/\{\{ LISTEN_PORT \}\}/$LISTEN_PORT/" $PATH_KAMAILIO_CFG
perl -p -i -e "s/\{\{ DB_PASS \}\}/$DB_PASS/" $PATH_KAMAILIO_CFG
perl -p -i -e "s/\{\{ DB_HOST \}\}/$DB_HOST/" $PATH_KAMAILIO_CFG
perl -p -i -e "s/\{\{ DB_USER \}\}/$DB_USER/" $PATH_KAMAILIO_CFG

# Change kamailio datestamp for sql tables
sed -i -e 's/# $var(a) = $var(table) + "_" + $timef(%Y%m%d);/$var(a) = $var(table) + "_" + $timef(%Y%m%d);/' $PATH_KAMAILIO_CFG
sed -i -e 's/$var(a) = $var(table) + "_%Y%m%d";/# runscript removed -- $var(a) = $var(table) + "_%Y%m%d";/' $PATH_KAMAILIO_CFG

# Make an alias, kinda.
kamailio=$(which kamailio)

# Test the syntax.
$kamailio -f $PATH_KAMAILIO_CFG -c

#enable apache mod_php and mod_rewrite
a2enmod php5
a2enmod rewrite 

# Start Apache
# apachectl -DFOREGROUND
apachectl start

# It's Homer time!
$kamailio -f $PATH_KAMAILIO_CFG -DD -E -e

