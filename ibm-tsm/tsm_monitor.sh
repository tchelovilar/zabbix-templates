#!/bin/bash

source /opt/Scripts/etc/general.conf
source /opt/Scripts/lib/lib_tsm.sh



if [ "$1" == "qtd" ]
then
	LANG=en_US dsmadmc -id=$TSM_USER -password=$TSM_PASS -out -dataonly=yes -displaymode=table -tab 'q ev * * begind=-1 endd=today' \
		| awk -F'\t' '{print $5}' \
		| egrep "(Failed|Missed|Severed)" \
		| wc -l
fi

if [ "$1" == "sched" ]
then
	LINHAS=`LANG=en_US dsmadmc -id=$TSM_USER -password=$TSM_PASS -out -dataonly=yes -displaymode=table -tab 'q ev * * begind=-1 endd=today' \
		| egrep "(Failed|Missed|Severed)"`

	while read i
	do
		echo "$i" | awk -F"\t" '{printf ($4"("$5"), ")}'
	done <<< "$LINHAS"
	echo ""
fi

if [ "$1" == "html" ]
then
	LINHAS=`LANG=en_US dsmadmc -id=$TSM_USER -password=$TSM_PASS -out -dataonly=yes -displaymode=table -tab 'q ev * * begind=-1 endd=today' \
		| egrep "(Failed|Missed|Severed)"`

	echo "<table style=\"width:100%; font-size:130%\">"
	echo " <tr>"
	echo "  <td>Data/Hora de in&iacute;cio</td><td>Data/Hora de t&eacute;rmino</td><td>Node</td><td>Mensagem</td>"
	echo " </tr>"

    if [ ! -z "$LINHAS" ]
    then
        while read i
        do
            echo " <tr style=\"color:red\">"
            echo "$i" | awk -F"\t" '{printf ("  <td>%s</td><td>%s</td><td>%s</td><td>%s</td>\n", $1, $2, $4, $5)}'
            echo " </tr>"
        done <<< "$LINHAS"
    else
	    echo " <tr>"
        echo "  <td colspan=\"4\" style=\"color:green; font-size:150%; text-align:center\">Nenhuma falha</td>"
        echo " </tr>"
    fi
	echo "</table>"
fi

if [ "$1" == "vol" ]
then
        PCT_UTILIZED=45

        LINHAS=`LANG=en_US dsmadmc -id=${ID} -password=${PASSWORD} -tab -out -dataonly=yes \
                "select VOLUME_NAME,STGPOOL_NAME,PCT_UTILIZED from volumes where devclass_name in (select devclass_name from devclasses where devtype='LTO') and status='FULL' and pct_utilized < ${PCT_UTILIZED}  order by pct_utilized" \
        | egrep -v '^AN'`

        echo "<table style=\"width:100%\">"
        echo " <tr>"
        echo "  <td>Volume</td><td>Pool</td><td>% Utilizado</td>"
        echo " </tr>"

        if [ ! -z "${LINHAS}" ]
        then
                while read i
                do
                        echo " <tr>"
                        echo "$i" | awk -F"\t" '{printf ("  <td>%s</td><td>%s</td><td>%s</td>\n", $1, $2, $3)}'
                        echo " </tr>"
                done <<<  "${LINHAS}"
        fi

        echo "</table>"
fi


if [ "$1" == "scratch" ]
then
        LINHAS=`LANG=en_US dsmadmc -id=${ID} -password=${PASSWORD} -tab -out -dataonly=yes \
                "select library_name, count(*) from libvolumes where status='Scratch' group by library_name" \
        | egrep -v '^AN'`

        echo "<table style=\"width:100%; font-size:130%\">"
        echo " <tr>"
        echo "  <td>Library</td><td>Qtd de fitas Scratch</td>"
        echo " </tr>"

        if [ ! -z "${LINHAS}" ]
        then
                while read i
                do
                        echo " <tr>"
                        echo "$i" | awk -F"\t" '{printf ("  <td>%s</td><td>%s</td>\n", $1, $2)}'
                        echo " </tr>"
                done <<< "${LINHAS}"
        else
            echo " <tr>"
            echo "  <td colspan=\"2\" style=\"color:red; font-size:150%; text-align:center\">Sem fitas scratch</td>"
            echo " </tr>"
        fi
        echo "</table>"

fi

if [ "$1" == "stg" ]
then

        PCT_UTILIZED=80

        LINHAS=`LANG=en_US dsmadmc -id=${ID} -password=${PASSWORD} -tab -out -dataonly=yes \
                "select tab1.stgpool_name,tab1.qtd,tab2.total from (select stgpool_name,count(*) as qtd from volumes where pct_utilized >= ${PCT_UTILIZED} and devclass_name='DC_FILE' group by stgpool_name) as tab1, (select stgpool_name,count(*) as total from volumes where devclass_name='DC_FILE' group by stgpool_name) as tab2 where tab1.stgpool_name==tab2.stgpool_name" \
        | egrep -v '^AN'`

        echo "<table style=\"width:100%\">"
        echo " <tr>"
        echo "  <td>Storage Poll</td><td>Volumes com utiliza&ccedil;&atilde;o >= ${PCT_UTILIZED}%</td><td>Total de Volumes</td>"
        echo " </tr>"

        if [ ! -z "${LINHAS}" ]
        then
                while read i
                do
                        echo " <tr>"
                        echo "$i" | awk -F"\t" '{printf ("  <td>%s</td><td>%s</td><td>%s</td>\n", $1, $2, $3)}'
                        echo " </tr>"
                done <<< "${LINHAS}"
        fi

        echo "</table>"

fi

if [ "$1" == "relatorio" ]
then

	LANG=en_US dsmadmc -id=$TSM_USER -password=$TSM_PASS -out -dataonly=yes -displaymode=table -tab 'q ev * * begind=-8 endd=today' \
	| egrep -v 'Future$|Pending$'

fi


if [ "$1" == "nonrwvolumes" ]
then
	LANG=en_US dsmadmc -id=$TSM_USER -password=$TSM_PASS -out -dataonly=yes -displaymode=table -tab "select libvolumes.LIBRARY_NAME, cast((volumes.VOLUME_NAME) as char(20)), cast((volumes.ACCESS) as char(20)) from volumes inner join libvolumes on volumes.VOLUME_NAME = libvolumes.VOLUME_NAME where ACCESS<>'READWRITE'" \
	| sed 's/ //g' \
	| egrep -v '^AN'
fi


if [ "$1" == "nonrwvolumeshtml" ]
then
	LINHAS=`LANG=en_US dsmadmc -id=$TSM_USER -password=$TSM_PASS -out -dataonly=yes -displaymode=table -tab "select libvolumes.LIBRARY_NAME, cast((volumes.VOLUME_NAME) as char(20)), cast((volumes.ACCESS) as char(20)) from volumes inner join libvolumes on volumes.VOLUME_NAME = libvolumes.VOLUME_NAME where ACCESS<>'READWRITE'" \
	| sed 's/ //g' \
	| egrep -v '^AN'`

        echo "<table style=\"width:100%\">"
        echo " <tr>"
        echo "  <td>Library</td><td>Volume</td><td>Status</td>"
        echo " </tr>"

        if [ ! -z "${LINHAS}" ]
        then
                while read i
                do
                        echo " <tr>"
                        echo "$i" | awk -F"\t" '{printf ("  <td>%s</td><td>%s</td><td>%s</td>\n", $1, $2, $3)}'
                        echo " </tr>"
                done <<< "${LINHAS}"
        fi

        echo "</table>"

fi

if [ "$1" == "errorsvolumeshtml" ]
then
        LINHAS=`LANG=en_US dsmadmc -id=$TSM_USER -password=$TSM_PASS -out -dataonly=yes -displaymode=table -tab "select cast((volumes.VOLUME_NAME) as char(20)),WRITE_ERRORS,READ_ERRORS from volumes where read_errors>0 or write_errors>0" \
        | sed 's/ //g' \
        | egrep -v '^AN'`

        echo "<table style=\"width:100%\">"
        echo " <tr>"
        echo "  <td>Volume</td><td>Write Errors</td><td>Read Errors</td>"
        echo " </tr>"

        if [ ! -z "${LINHAS}" ]
        then
                while read i
                do
                        echo " <tr>"
                        echo "$i" | awk -F"\t" '{printf ("  <td>%s</td><td>%s</td><td>%s</td>\n", $1, $2, $3)}'
                        echo " </tr>"
                done <<< "${LINHAS}"
        fi

        echo "</table>"

fi


###
### Discover Library
if [ "$1" == "disc_library" ]; then
	lista=$(DSMC 'q libr')
	if [ $? -gt 0 ] ; then
		echo "disc_library: Error"
		exit 1
	fi


	#
	echo -e -n "{\n  \"data\":[ \n\t"
	#
	while read linha ; do
		info=($linha)
		echo -n -e "${SEP}{ \"{#TSM_LIBNAME}\":\"${info[0]}\" , \"{#TSM_LIBTYPE}\":\"${info[1]}\"  }"
		SEP=",\n\t"
	done <<< "$lista"
	#
	echo -e "\n  ] \n}"
fi


###
### Contador fitas na Library
if [ "$1" == "qnt_libv" ]; then
	#DSMC "q libv ${2}" | grep "$3" | wc -l
	case $2 in
		DbBackup)
			#DSMC "q libv" | grep "${3}" | wc -l
			DSMC "select count(*) from libvolumes where LAST_USE='DbBackup'"
		;;
		*)
			DSMC "q libv ${2}" | grep "$3" | wc -l		
		;;
	esac
fi


###
###
### Uso: qnt_access <library> <access_status>
if [ "$1" == "qnt_access" ]; then
	case $3 in
		UNAVAILABLE)
			DSMC "select count(*) from devclasses dev inner join volumes vol on vol.DEVCLASS_NAME=dev.DEVCLASS_NAME  where LIBRARY_NAME='${2}' and ACCESS='UNAVAILABLE'"
		;;
		READONLY)
			DSMC "select count(*) from devclasses dev inner join volumes vol on vol.DEVCLASS_NAME=dev.DEVCLASS_NAME  where LIBRARY_NAME='${2}' and ACCESS='READONLY'"
		;;
		READWRITE)
			DSMC "select count(*) from devclasses dev inner join volumes vol on vol.DEVCLASS_NAME=dev.DEVCLASS_NAME  where LIBRARY_NAME='${2}' and ACCESS='READWRITE'"
		;;
		DESTROYED)
			DSMC "select count(*) from devclasses dev inner join volumes vol on vol.DEVCLASS_NAME=dev.DEVCLASS_NAME  where LIBRARY_NAME='${2}' and ACCESS='DESTROYED'"
		;;
		OFFSITE)
			DSMC "select count(*) from devclasses dev inner join volumes vol on vol.DEVCLASS_NAME=dev.DEVCLASS_NAME  where LIBRARY_NAME='${2}' and ACCESS='OFFSITE'"
		;;
		*)
			echo ERRO		
		;;
	esac
	
fi


###
### Discover Drives
if [ "$1" == "disc_drives" ]; then
	lista=$(DSMC "SELECT DRIVE_NAME, LIBRARY_NAME FROM drives")
	if [ $? -gt 0 ] ; then
		echo "disc_drives: Select Error"
		exit 1
	fi

	#
	echo -e -n "{\n  \"data\":[ \n\t"
	#
	while read linha ; do
		info=($linha)
		echo -n -e "${SEP}{ \"{#TSM_DRIVENAME}\":\"${info[0]}\" , \"{#TSM_LIB}\":\"${info[1]}\"  }"
		SEP=",\n\t"
	done <<< "$lista"
	#
	echo -e "\n  ] \n}"
fi


###
### Status do Drive
if [ "$1" == "drv_status" ]; then
	status=$(DSMC "select ONLINE from drives where DRIVE_NAME = '${2}'")
	case $status in
		YES)
			echo -n 1
		;;
		NO)
			echo -n 0
		;;
		*)
			echo -n 3		
		;;
	esac
fi


###
### Contador de eventos dia anterior
if [ "$1" == "ev_qnt" ]; then
	if [ -n "$3" ] && [ "$3" -gt 0 ] ; then
		from=$(date --date="$3 days ago" +"%Y-%m-%d")" 00:00:00"
		to=$(date +"%Y-%m-%d")" 00:00:00"
	else
		from=$(date +"%Y-%m-%d")" 00:00:00"
		to=$(date --date="next day" +"%Y-%m-%d")" 00:00:00"
	fi
	case $2 in
		failed)
			status="and status in ('Failed','Missed','Severed')"
		;;
		completed)
			status="and status = 'Completed'"
		;;
		started)
			status="and status = 'Started'"
		;;
		progress)
			status="and status = 'In Progress'"
		;;
		other)
			status="and status not in ('Failed','Missed','Severed','Completed','Started','In Progress')"
		;;
		*)
			status=""
		;;
	esac
	DSMC "SELECT count(*) FROM events WHERE scheduled_start> '$from' and scheduled_start< '$to' and node_name <> '' $status"
	exit 0
fi


###
### Retorna lista de eventos em HTML
if [ "$1" == "ev_html" ]; then
	lineColor=''
	if [ -n "$3" ] && [ "$3" -gt 0 ] ; then
		from=$(date --date="$3 days ago" +"%Y-%m-%d")" 00:00:00"
		to=$(date +"%Y-%m-%d")" 23:59:59"
	else
		from=$(date +"%Y-%m-%d")" 00:00:00"
		to=$(date --date="next day" +"%Y-%m-%d")" 00:00:00"
	fi
	case $2 in
		failed)
			status="and status in ('Failed','Missed','Severed')"
			lineColor=' style=\"color:red;\" '
		;;
		completed)
			status="and status = 'Completed'"
		;;
		started)
			status="and status = 'Started'"
		;;
		progress)
			status="and status = 'In Progress'"
		;;
		other)
			status="and status not in ('Failed','Missed','Severed','Completed','Started','In Progress')"
		;;
		*)
			status=""
		;;
	esac

	lista=$(DSMC "SELECT TO_CHAR(CHAR(scheduled_start),'DD-MM-YYYY HH24:MI') as SCHED_START, TRANSLATE('a bc:de:fg', DIGITS(completed - actual_start), '_______abcdefgh_____',' ') as \"ELAPTIME (D HHMMSS)\", schedule_name, node_name, status FROM events WHERE scheduled_start> '$from' and scheduled_start< '$to' and node_name <> '' $status ORDER BY scheduled_start DESC" )
	if [ "$?" -eq 0 ] ; then
		tabela=$( echo "$lista" | awk -F"\t" -v x="$lineColor" '{printf ("<tr>  <td"x">%s</td><td"x">%s</td><td"x">%s</td><td"x">%s</td><td"x">%s</td> </tr>\n", $1, $2, $3, $4, $5)}')
	else
		tabela="<tr><td colspan=5  style=\"color:green;\">Sem registros de falhas para o per&iacute;odo</td></tr>"
	fi
	
        echo "<table style=\"width:100%; text-align:left\">"
        echo " <tr>"
        echo "  <th>Data</th><th>Dura&ccedil;&atilde;o</th><th>Agendamento</th><th>Host</th><th>Status</th>"
        echo " </tr>"
	###
	echo "$tabela"
	echo " </table>"
	
fi


###
### Discover Storage Pools 
if [ "$1" == "disc_stg" ]; then
	# select STGPOOL_NAME, DEVTYPE from stgpools stg inner join devclasses dev on stg.DEVCLASS = dev.DEVCLASS_NAME
	# select STGPOOL_NAME, dev.DEVCLASS_NAME from stgpools stg inner join devclasses dev on stg.DEVCLASS = dev.DEVCLASS_NAME where DEVTYPE = 'LTO'
	case $2 in
		lto)
			lista=$(DSMC "select STGPOOL_NAME, dev.LIBRARY_NAME from stgpools stg inner join devclasses dev on stg.DEVCLASS = dev.DEVCLASS_NAME where DEVTYPE = 'LTO'")
		;;
		file)
			lista=$(DSMC "select STGPOOL_NAME, dev.LIBRARY_NAME from stgpools stg inner join devclasses dev on stg.DEVCLASS = dev.DEVCLASS_NAME where DEVTYPE = 'FILE'")
		;;
		*)
			lista=$(DSMC "select STGPOOL_NAME, dev.LIBRARY_NAME from stgpools stg inner join devclasses dev on stg.DEVCLASS = dev.DEVCLASS_NAME")
		;;
	esac
	
	

	#
	echo -e -n "{\n  \"data\":[ \n\t"
	#
	while read linha ; do
		info=($linha)
		echo -n -e "${SEP}{ \"{#TSM_STGPOOL}\":\"${info[0]}\" , \"{#TSM_LIB}\":\"${info[1]}\"  }"
		SEP=",\n\t"
	done <<< "$lista"
	#
	echo -e "\n  ] \n}"
fi


###
### Retorna o uso do storagepool
if [ "$1" == "stg_used" ]; then
	DSMC "select sum(logical_mb)*1048576 as usage_bytes from occupancy occ where STGPOOL_NAME = '$2' GROUP BY stgpool_name" | awk -F . '{print $1}'
fi

###
### Retorna o uso Total menos o DRPOOL
if [ "$1" == "stg_total" ]; then
	DSMC "select sum(occ.logical_mb)*1048576 as usage_bytes from occupancy occ inner join stgpools stg   on occ.STGPOOL_NAME = stg.STGPOOL_NAME inner join devclasses dev on stg.DEVCLASS     = dev.DEVCLASS_NAME where occ.STGPOOL_NAME <> 'DRPOOL'" | awk -F . '{print $1}'
fi



###
### Conta o numero de dispositivos carregados
if [ "$1" == "dev_count" ] ; then
	case $2 in
		drive)
			disp="/proc/scsi/IBMtape"
		;;
		library)
			disp="/proc/scsi/IBMchanger"
		;;
		*)
			echo "Error"
			exit 1
		;;
	esac
	if [ -e "$disp" ] ; then
		egrep "^[0-9]" -c $disp
	else
		echo "0"
	fi
		
fi
	

###
### Contador de eventos dia anterior
if [ "$1" == "drm_fitas" ]; then
	# VAULT
	case $2 in
		total)
			where=""
		;;
		dbbackup)
			where=" voltype = 'DBBackup'"
		;;
		*)
			where=" state = '$2'"
		;;
	esac
	DSMC "SELECT count(*) FROM drmedia WHERE $where"
	exit 0
fi

###
###
if [ "$1" == "volh_dbb" ]; then
	#DSMC "select volume_name,date_time from volhistory where type='BACKUPFULL' "
	case $2 in
		tape)	
			DSMC "select volume_name,date_time from volhistory where type='BACKUPFULL' order by date_time desc  fetch first 1 rows only"
		;;
		date)
			DSMC "select CAST (DAYS(date_time) - DAYS('1970-01-01') AS INTEGER) * 86400 + (MIDNIGHT_SECONDS(TIMESTAMP(date_time) - CURRENT TIMEZONE)) from volhistory where type='BACKUPFULL' order by date_time desc  fetch first 1 rows only"
		;;
	esac
fi

exit 0
##### Status Existentes
#  Started
#  Completed
#  In Progress
#  Failed
#  Missed
#  Severed   ????



SELECT TO_CHAR(CHAR(scheduled_start),'YYYY-MM-DD HH24:MI:SS') as SCHEDULED_START, TRANSLATE('a bc:de:fg', DIGITS(completed - actual_start), '_______abcdefgh_____',' ') as \"ELAPTIME (D HHMMSS)\", schedule_name, node_name, status FROM events WHERE scheduled_start> '2016-10-25 00:00:00' and scheduled_start< '2016-10-26 00:00:00'

DSMC "SELECT TO_CHAR(CHAR(scheduled_start),'YYYY-MM-DD HH24:MI:SS') as SCHEDULED_START, TRANSLATE('a bc:de:fg', DIGITS(completed - actual_start), '_______abcdefgh_____',' ') as \"ELAPTIME (D HHMMSS)\", schedule_name, node_name, status FROM events WHERE scheduled_start> '2016-10-25 00:00:00' and scheduled_start< '2016-10-26 00:00:00' and node_name <> ''"


DSMC "SELECT TO_CHAR(CHAR(scheduled_start),'YYYY-MM-DD HH24:MI:SS') as SCHEDULED_START, TRANSLATE('a bc:de:fg', DIGITS(completed - actual_start), '_______abcdefgh_____',' ') as \"ELAPTIME (D HHMMSS)\", schedule_name, node_name, status FROM events WHERE scheduled_start> '2016-10-25 00:00:00' and scheduled_start< '2016-10-26 00:00:00' and node_name <> '' and status not in  ('Completed','Started')"



# Fitas access
select * from devclasses dev inner join volumes vol on vol.DEVCLASS_NAME=dev.DEVCLASS_NAME  where LIBRARY_NAME='TS3100' and ACCESS='READWRITE'

select * from devclasses dev inner join volumes vol on vol.DEVCLASS_NAME=dev.DEVCLASS_NAME  where LIBRARY_NAME='TS3100' and ACCESS='UNAVAILABLE'

