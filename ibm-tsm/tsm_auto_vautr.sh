#!/bin/bash
. /opt/Scripts/etc/general.conf

DATABASE="/opt/Scripts/var/tsm_autodrm.db"

arqLog=/opt/Scripts/var/tsm_autovaultr.log

par_show=${1:-d}


# Criar Base
# sqlite3 /tmp/teste.db "CREATE TABLE fitas_vaultr(volume TEXT PRIMARY KEY ASC, data integer, status TEXT);"

function DSMC() {
	LANG=en_US dsmadmc -id=$TSM_USER -password=$TSM_PASS -out -dataonly=yes -displaymode=table -tab "${1}"
}


function DSMC_PURO() {
	LANG=en_US dsmadmc -id=$TSM_USER -password=$TSM_PASS -out "${1}"
}


function LOG() {
	dataNow=$(date +"%d/%m/%Y %H:%M:%S")
	# Registra informacao no log
	echo "${dataNow} - $1" >> $arqLog
	# Atualiza o status da execucao
	#if [ -n "$2" ] ; then
	#	echo -n "$2" > $info_status
	#fi
	if [ $par_show == "d" ] ; then
		echo "${dataNow} - $@"
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
			echo "ERRO: Falha na consulta SQL (SQL: $1) (Retorno: $ret) (Tentativas: $n) (Query: $query)." >> "/tmp/_erro"
			let n++
			sleep 1
		fi
	done
	if [ $n -ge 8 ] && [ $ret -gt 0 ]; then
		exit 1
	fi
}


function CHECKIN () {
	search=$1
	ret_checkin=$(DSMC "checkin libv ${LIBR_DRM} search=${search} status=scratch waitt=0")
	proc_checkin=$(grep "Process number" <<< "$ret_checkin" | awk '{print $4}')
	LOG "Iniciado checkin de fitas (${search}). Processo: ${proc_checkin}"
	n=0
	while [ $n -eq 0 ] ; do
		ret_mon=$(DSMC "q proc ${proc_checkin}")
		status=$?
		if [ $status -eq 11 ]; then
			LOG "Termino da execucao do checkin libv (${search})." 110
			n=1
		elif [ $status -eq 0 ]; then
			sleep 10
		else
			LOG "Falha no checkin (${search}). ${proc_checkin}" 205
			exit 1
		fi
	done
}


###
###
SQLITE "SELECT volume FROM fitas_vaultr WHERE status='VAULTRETRIEVE' and data < datetime('now','-12 hours')"



exit 0

# Executa o move DRMEDIA
for fita in $tapeRetrieve ; do
	ret_retorno=$(DSMC "move drmedia $fita wherestate=vaultr tostate=onsiter wait=no")
	status=$?
	if [ $status -eq 0 ]; then
		sleep 1
	else
		LOG "ERRO: Falha na execucao do move drmedia" 201
		exit 1
	fi
done

CHECKIN yes
CHECKIN bulk


# sqlite3 /tmp/teste.db "select * from controle where time < datetime('now','-19 hours')"
