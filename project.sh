#!/bin/bash

### TODO: add DB selection + MySQL support.

### Set default parameters
action=$1
name=$2
owner=$(who am i | awk '{print $1}')
userDir='/var/www/project'
hostname="$(hostname)"
sitedataRoot='/var/lib/sitedata'
virtualhost="$(which virtualhost)"

if [ "$(whoami)" != 'root' ]; then
	echo $"You have no permission to run $0 as non-root user. Use sudo"
	exit 1;
fi

if [ "$virtualhost" == "" ]; then
	echo -e $"Virtualhost script is not found, please install it. See https://github.com/RoverWire/virtualhost"
	exit;
fi

if [ "$action" != 'create' ] && [ "$action" != 'delete' ]
	then
		echo $"You need to prompt for action (create or delete)"
		exit 1;
fi

while [ "$name" == "" ]
do
	echo -e $"Please provide project name. It should match a name of the folder in $userDir"
	read name
done

rootDir=$userDir/$name
sitedataDir=$sitedataRoot/$name
sitedataDirTest=$sitedataRoot/$name-test
configPhpFile=$rootDir/config.php
configPhpFileBackup=$rootDir/config.php.backup

configText="
<?php \n

unset(\$CFG);\n 
global \$CFG;\n
\$CFG = new stdClass();\n\n

\$CFG->dbtype    = 'pgsql';\n
\$CFG->dblibrary = 'native';\n
\$CFG->dbhost    = 'localhost';\n
\$CFG->dbname    = '$name';\n
\$CFG->dbuser    = '$name';\n
\$CFG->dbpass    = '$name';\n
\$CFG->prefix    = 'mdl_';\n
\$CFG->dboptions = array (\n
    'dbpersist' => 0,\n
    'dbport' => '',\n
    'dbsocket' => '',\n
);\n\n

\$CFG->wwwroot   = 'http://$name.$hostname.local';\n
\$CFG->dataroot  = '/var/lib/sitedata/$name';\n\n

\$CFG->phpunit_dataroot = '/var/lib/sitedata/$name-test';\n
\$CFG->phpunit_prefix = 'phputest_';\n\n

\$CFG->admin = 'admin';\n\n

\$CFG->directorypermissions = 0777;\n
\$CFG->divertallemailsto = 'dmitriim@catalyst-au.net';\n\n

// Force a debugging mode regardless the settings in the site administration\n
 @error_reporting(E_ALL | E_STRICT); // NOT FOR PRODUCTION SERVERS!\n
 @ini_set('display_errors', '1');    // NOT FOR PRODUCTION SERVERS!\n
 \$CFG->debug = (E_ALL | E_STRICT);   // === DEBUG_DEVELOPER - NOT FOR PRODUCTION SERVERS!\n
 \$CFG->debugdisplay = 1;             // NOT FOR PRODUCTION SERVERS!\n\n

require_once(dirname(__FILE__) . '/lib/setup.php');\n

// There is no php closing tag in this file,\n
// it is intentional because it prevents trailing whitespace problems!\n"


if [ "$action" == 'create' ]
	then
		### create a new project
		if ! [ -d $rootDir ]; then
			echo $"You need to create project directory in $userDir"
			exit 1;
		fi

		if ! [ -d $sitedataRoot ]; then
			mkdir $sitedataRoot
		fi

		if ! [ -d $sitedataDir ]; then
			mkdir $sitedataDir
		fi

		if ! [ -d $sitedataDirTest ]; then
			mkdir $sitedataDirTest
		fi

		chown -R www-data:www-data $sitedataDir
		chmod 777 $sitedataDir
		chmod 777 $sitedataDirTest
		
		echo -e $"Sitedata directories created: $sitedataDir and $sitedataDirTest"
		
		su postgres bash -c "psql -c \"CREATE USER $name WITH PASSWORD '$name';\""
		su postgres bash -c "psql -c \"CREATE DATABASE $name OWNER $name ENCODING 'UTF8';\""

		if [ -e $configPhpFile ]; then
			cp $configPhpFile $configPhpFileBackup
			echo -e $"File $configPhpFile is already exist. Saved it up as $configPhpFileBackup"
		fi 

		echo -e $configText > $configPhpFile
		echo -e $"Generated new $configPhpFile"

		$virtualhost create $name.$hostname.local $rootDir
	else
		### delete existing project 
		$virtualhost delete $name.$hostname.local $rootDir

		if [ -d $sitedataDir ] || [ -d $sitedataDirTest ]; then
			echo -e $"Delete sitedata directories ? (y/n)"
			read deldir

			if [ "$deldir" == 'y' -o "$deldir" == 'Y' ]; then	
				rm -rf $sitedataDir
				rm -rf $sitedataDirTest
				echo -e $"Sitedata directories deleted"
			else
				echo -e $"Sitedata directories conserved"
			fi
		else
			echo -e $"Sitedata directories not found."
		fi

		echo -e $"Delete database ? (y/n)"
		read deldb

		if [ "$deldb" == 'y' -o "$deldb" == 'Y' ]; then	
			su postgres bash -c "psql -c \"DROP DATABASE $name;\""
			su postgres bash -c "psql -c \"DROP USER $name;\""
		else
			echo -e $"Database conserved"
		fi

fi

