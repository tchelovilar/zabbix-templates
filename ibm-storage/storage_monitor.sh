#!/bin/bash


#source /opt/Scripts/etc/general.conf

###
IP=$1
DATABASE="/opt/Scripts/var/stg_db_$1.sqlite3"
PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/root/bin:/bin"
LOG="/tmp/_stgmonitor.log"

###
if [ -z $1 ] ; then
	echo "ERRO: Informe o IP do storage."
	exit 1
fi

###
if [ ! -f $DATABASE ] ; then
	#echo "ERRO: Banco inexistente."
	#exit 1
	##
	sqlite3 $DATABASE "CREATE TABLE controle(info TEXT PRIMARY KEY ASC, time integer);"
	sqlite3 $DATABASE 'INSERT INTO controle VALUES ("systemstats","0")'
	sqlite3 $DATABASE 'INSERT INTO controle VALUES ("lssystem","0")'
	sqlite3 $DATABASE 'INSERT INTO controle VALUES ("enclosure","0")'
	sqlite3 $DATABASE 'INSERT INTO controle VALUES ("lshost","0")'

	##
	sqlite3 $DATABASE "CREATE TABLE host(hostname TEXT PRIMARY KEY ASC, v1 TEXT, v2 TEXT);"

	##
	sqlite3 $DATABASE "CREATE TABLE info(parametro TEXT PRIMARY KEY ASC, v1 TEXT, v2 TEXT);"
	sqlite3 $DATABASE 'INSERT INTO info VALUES ("total_mdisk_capacity","","")'
	sqlite3 $DATABASE 'INSERT INTO info VALUES ("total_used_capacity","","")'
	sqlite3 $DATABASE 'INSERT INTO info VALUES ("total_free_space","","")'
	sqlite3 $DATABASE 'INSERT INTO info VALUES ("code_level","","")'
	sqlite3 $DATABASE 'INSERT INTO info VALUES ("fonte_offline","","")'

	##
	sqlite3 $DATABASE "CREATE TABLE stat(parametro TEXT PRIMARY KEY ASC, v1 integer, v2 integer, v3 integer);"
	sqlite3 $DATABASE 'INSERT INTO stat VALUES ("power_w","","","")'
	sqlite3 $DATABASE 'INSERT INTO stat VALUES ("temp_c","","","")'
	sqlite3 $DATABASE 'INSERT INTO stat VALUES ("cpu_pc","","","")'
	sqlite3 $DATABASE 'INSERT INTO stat VALUES ("mdisk_r_mb","","","")'
	sqlite3 $DATABASE 'INSERT INTO stat VALUES ("mdisk_r_io","","","")'
	sqlite3 $DATABASE 'INSERT INTO stat VALUES ("mdisk_r_ms","","","")'
	sqlite3 $DATABASE 'INSERT INTO stat VALUES ("mdisk_w_mb","","","")'
	sqlite3 $DATABASE 'INSERT INTO stat VALUES ("mdisk_w_io","","","")'
	sqlite3 $DATABASE 'INSERT INTO stat VALUES ("mdisk_w_ms","","","")'
	sqlite3 $DATABASE 'INSERT INTO stat VALUES ("fc_mb","","","")'
	sqlite3 $DATABASE 'INSERT INTO stat VALUES ("fc_io","","","")'
	sqlite3 $DATABASE 'INSERT INTO stat VALUES ("sas_mb","","","")'
	sqlite3 $DATABASE 'INSERT INTO stat VALUES ("sas_io","","","")'
	sqlite3 $DATABASE 'INSERT INTO stat VALUES ("iscsi_mb","","","")'
	sqlite3 $DATABASE 'INSERT INTO stat VALUES ("iscsi_io","","","")'
	sqlite3 $DATABASE 'INSERT INTO stat VALUES ("write_cache_pc","","","")'
	sqlite3 $DATABASE 'INSERT INTO stat VALUES ("total_cache_pc","","","")' 
	chown zabbix $DATABASE
fi


###
###
function CMD() {
	if [ -n "$1" ] ; then
		ssh -i /home/zabbix/.ssh/id_rsa monitora@${IP} "$1"
		ret=$?
		if [ $ret -gt 0 ] ; then
			echo "ERRO: Falha na execucao do SSH."
			exit 1
		fi
	fi
}

function SQLITE() {
	n=1
	while [ $n -lt 8 ]; do
		query=$(sqlite3 $DATABASE "$1" 2>&1)
		ret=$?
		if [ $ret -eq 0 ] ; then
			echo -n "$query"
			n=1000
		elif [ $ret -eq 6 ] ; then
			#echo "ERRO: Tabela locked (SQL: $1) (Retorno: $ret) (Tentativas: $n) (Query: $query)." >> $LOG 
			let n++
			sleep 1
		else
			echo "ERRO: Falha na consulta SQL (SQL: $1) (Retorno: $ret) (Tentativas: $n) (Query: $query)." >> $LOG
			let n++
			sleep 1
		fi
	done
	if [ $n -ge 8 ] && [ $ret -gt 0 ]; then
		exit 1
	fi
}

#function SQLW() {
#	sqlite3 $DATABASE "$1"
#	ret=$?
#	if [ $ret -gt 0 ] ; then
#		echo "ERRO: Falha na consulta SQL ($1)." >> $LOG
#		exit 1
#	fi
#}


###
###
function sync_systemstats() {
	filtro="^(power_w|cpu_pc|temp_c|mdisk_r|mdisk_w|fc_|sas_|iscsi_|write_cache_pc|total_cache_pc)"
	intervalo=110
	now=$(date +"%s")
	last=$(SQLITE "select time from controle where info='systemstats'")
	if [ $(($now-$intervalo)) -gt $last ] ; then
		SQLITE "update controle set time='$now' where info='systemstats'"
		INFO=$(CMD lssystemstats | egrep "$filtro")
		while read linha ; do
			#vars=$(awk '{print $1 " " $2 " " $3}' <<< "$linha")
			vars=($linha)
			sql="update stat set v1='${vars[1]}', v2='${vars[2]}' where parametro='${vars[0]}'"
			SQLITE "$sql"
			#echo $linha
		done <<< "$INFO"
	fi
}


###
function systemstats() {
	sync_systemstats
	if [ -n $1 ]; then
		SQLITE "select v1 from stat where parametro='$1'"
	else
		echo "ERRO: Nao foi passado o parametro de consulta"
	fi
}

function sync_lssystem() {
	filtro="^(total_mdisk_capacity|total_used_capacity|total_free_space|code_level)"
	intervalo=1200
	now=$(date +"%s")
	last=$(SQLITE "select time from controle where info='lssystem'")
	if [ $(($now-$intervalo)) -gt $last ] ; then
		SQLITE "update controle set time='$now' where info='lssystem'"
		INFO=$(CMD lssystem | egrep "$filtro" | tr -d "TB")
		while read linha ; do
			#vars=$(awk '{print $1 " " $2 " " $3}' <<< "$linha")
			vars=($linha)
			sql="update info set v1='${vars[1]}' where parametro='${vars[0]}'"
			SQLITE "$sql"
			#echo $sql
			#echo $linha
		done <<< "$INFO"
	fi
}
# total_mdisk_capacity 21.2TB
# total_used_capacity 18.83TB
# total_free_space 2.3TB
# code_level 7.3.0.7 (build 97.5.1410080000)

###
function lssystem() {
	sync_lssystem
	sync_enclosure
	if [ -n $1 ]; then
		SQLITE "select v1 from info where parametro='$1'"
	else
		echo "ERRO: Nao foi passado o parametro de consulta"
	fi
}


###
### INFO ENCLOSURE
###
function sync_enclosure() {
	intervalo=1100
	now=$(date +"%s")
	last=$(SQLITE "select time from controle where info='enclosure'")
	if [ $(($now-$intervalo)) -gt $last ] ; then
		SQLITE "update controle set time='$now' where info='enclosure'"
		# Verifica se tem fontes de alimentacao offline
		c_psuoff=$(CMD lsenclosurepsu | egrep "^[0-9]{1,3}" | grep -v "online" | wc -l)
		sql="update info set v1='${c_psuoff}' where parametro='fonte_offline'"
		SQLITE "$sql"
	fi
}



###
### DISCOVER HOST
###
function disc_host(){
	#
	enc_list=$(CMD "lshost -nohdr")
	# JSON
	echo -e -n "{\n  \"data\":[ \n\t"
	#
	while read linha ; do
		info=($linha)
		echo -n -e "${SEP}{ \"{#HOST_ID}\":\"${info[0]}\" , \"{#HOST_NAME}\":\"${info[1]}\"   }"
		SEP=",\n\t"
		sql="insert or ignore into host values ('${info[1]}','','')"
		SQLITE "$sql"	
	done <<< "$enc_list"
	#
	echo -e "\n  ] \n}"
	#sync_host
}


function sync_host() {
	intervalo=580
	now=$(date +"%s")
	last=$(SQLITE "select time from controle where info='lshost'")
	if [ $(($now-$intervalo)) -gt $last ] ; then
		SQLITE "update controle set time='$now' where info='lshost'"
		INFO=$(CMD "lshost -nohdr")
		while read linha ; do
			#vars=$(awk '{print $1 " " $2 " " $3}' <<< "$linha")
			vars=($linha)
			sql="update host set v1='${vars[4]}', v2='${vars[2]}' where hostname='${vars[1]}'"
			SQLITE "$sql"
			#echo $sql
			#echo $linha
		done <<< "$INFO"
	fi
}

###
function lshost() {
	sync_host
	if [ -n $1 ]; then
		SQLITE "select v1 from host where hostname='$1'"
	else
		echo "ERRO: Nao foi passado o parametro de consulta"
	fi
}

###
### EVENTLOG
###
# alternativa finderr
function eventlog() {
	eventos=$(CMD "lseventlog -filtervalue 'error_code>0' -fixed=no -order=severity" | egrep "^[0-9]" | head -n 1)
	if [ -n "$eventos" ] ; then
		vars=($eventos)
		detalhes=$(CMD "lseventlog ${vars[0]}")
		while read linhaDet ; do
			info=($linhaDet)
			#echo "0: ${info[0]} 1: ${info[1]}"
			case ${info[0]} in
				error_code_text)
					error_text=${info[*]#${info[0]}}
				;;
				notification_type)
					error_type=${info[1]}
				;;
				error_code)
					error_code=${info[1]}
				;;
			esac
		done <<< "$detalhes"
		echo "${error_code}. $error_text"
	else
		echo ""
	fi
}

###
function alertcount() {
	if [ "$1" == "error" ]; then
		CMD "lseventlog -filtervalue 'error_code>0' -fixed=no -order=severity" | egrep "^[0-9]" | wc -l
	else
		CMD "lseventlog -filtervalue status=alert" | egrep "^[0-9]" | wc -l
	fi
}


###
### DRIVE
###
function lsdrive() {
	# failed
	CMD 'lsdrive -delim=":"' | awk -F":" '{print $4}' | grep $1 | wc -l
	#while read linha ; do
	#
	#done <<< "$lista"
}


###
###  PORT SAS
###
function lsportsas() {
	status=$1
	count=0
	if [ -z "$status" ] ; then exit ; fi 
	lista=$(CMD "lsportsas -delim=: -nohdr" | awk -F: '{printf("%s %s %s\n",$1,$7,$9)}')
	while read linha ; do
		vars=($linha)
		if [ ${vars[2]} != "none" ] ; then
			if [ "${vars[1]}" == "$status" ] ; then
				let count++
			fi
		fi
	done <<< "$lista"
	echo $count
}

###
###  PORT FC
###
function lsportfc() {
	status=$1
	count=0
	if [ -z "$status" ] ; then exit ; fi 
	lista=$(CMD "lsportfc -delim=: -nohdr" | awk -F: '{printf("%s %s %s\n",$1,$10,$11)}')
	while read linha ; do
		vars=($linha)
		if [ ${vars[2]} != "none" ] ; then
			if [ "${vars[1]}" == "$status" ] ; then
				let count++
			fi
		fi
	done <<< "$lista"
	echo $count
}



case $2 in
	systemstats)
		systemstats $3 $4
	;;
	lssystem)
		lssystem $3 $4
	;;
	disc_host)
		disc_host $3 $4
	;;
	lshost)
		lshost $3 $4
	;;
	eventlog)
		eventlog $3 $4
	;;
	alertcount)
		alertcount $3 $4
	;;
	lsdrive)
		lsdrive $3 $4
	;;
	lsportsas)
		lsportsas $3 $4
	;;
	lsportfc)
		lsportfc $3 $4
	;;
	*)
		exit 1
	;;
esac


###
### FIM DO SCRIPT
exit 0






lseventlog


IBM_Storwize:Cassul-v3700:monitora>lssystem         


total_mdisk_capacity 21.2TB
total_used_capacity 18.83TB
total_free_space 2.3TB
code_level 7.3.0.7 (build 97.5.1410080000)



space_in_mdisk_grps 21.2TB
space_allocated_to_vdisks 18.83TB
total_vdiskcopy_capacity 18.83TB

total_overallocation 88
total_vdisk_capacity 18.83TB
total_allocated_extent_capacity 18.83TB



    


#### 
# 
# Informacoes sobre a saida
# http://www.ibm.com/support/knowledgecenter/STLM5A_7.1.0/com.ibm.storwize.v3700.710.doc/svc_lssystemstats.html


#
# http://www.ibm.com/support/knowledgecenter/STLM5A_7.1.0/com.ibm.storwize.v3700.710.doc/easy_preparephysicalenv.html
