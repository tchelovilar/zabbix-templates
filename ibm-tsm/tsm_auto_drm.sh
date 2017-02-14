#!/bin/bash
. /opt/Scripts/etc/general.conf

DATABASE="/opt/Scripts/var/tsm_autodrm.db"

arqLog=/opt/Scripts/var/tsm_autodrm.log
arqInfo=/tmp/_info_scrtsm.log

info_lastbkp=/opt/Scripts/var/tsm_autodrm_last.info
info_status=/opt/Scripts/var/tsm_autodrm_status.info

#
PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/root/bin:/bin"

#
par_show=${1:-n}


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
	if [ -n "$2" ] ; then
		echo -n "$2" > $info_status
	fi
	if [ $par_show == "s" ] ; then
		echo "${dataNow} - $1"
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


###
if [ ! -f $DATABASE ] ; then
	SQLITE "CREATE TABLE fitas_vaultr(volume TEXT PRIMARY KEY ASC, data integer, status TEXT);"
	if [ $ret -lt 0 ] ; then
		echo "Falha ao criar o banco."
		exit 1
	fi
fi 	


echo "" > $arqInfo

###
### Adiciona o status de inicio do Script
LOG "Iniciando script de retirada de fitas" 100

###
### Verifica se tem processos em execução
count=0
n=0
while [ $n -eq 0 ]  ; do
	ret_proc=$(DSMC "q proc")
	if [ $? -eq 0 ] ; then
		echo "$ret_proc" | awk '{print $2}' | egrep -q "Migration|Backup|Database"
		if [ $? -eq 0 ] ; then
			LOG "Processos em execucao" 103
			#
			sleep 600
		else
			n=1
		fi
	else
		n=1
	fi
	if [ $count -ge 18 ]; then
		LOG "ERRO: Expirou o tempo limite para iniciar o script." 201
		exit 1
	fi
	let count++
done

###
### Verifica se existe um backup do banco recente
#select volume_name,date_time from volhistory where type='BACKUPFULL' and date_time > current timestamp - 10 hours
tapeDBB=$(DSMC "select volume_name from volhistory where type='BACKUPFULL' and date_time \> current timestamp - 10 hours fetch first 1 rows only")
status=$?
if [ $status -eq 0 ] ; then
	fitas=$(echo "$tapeDBB" | awk '{print $1}' | tr "\n" " ")
	LOG "Fitas DBBackup: $fitas" 104
elif [ $status -eq 11 ] ; then
	LOG "ERRO: Nao foi encontrado uma fita de backup do bando do TSM recente." 202
	exit 1
else
	LOG "ERRO: Ocorreu uma falha desconhecida na verificacao de fita DBBackup" 202
	exit 1
fi

### Info Pre start
DSMC_PURO "q libv" >> $arqInfo
DSMC_PURO "q drm" >> $arqInfo

###
### Listar Fitas Mountable
tapeMount=$(DSMC "select VOLUME_NAME, VOLTYPE from drmedia where state='MOUNTABLE'")
status=$?
if [ $status -eq 0 ] ; then
	fitas=$(echo "$tapeMount" | awk '{print $1}' | tr "\n" " ")
	LOG "Fitas mountable: $fitas" 105
elif [ $status -eq 11 ] ; then
	LOG "Sem fitas mountable para efetuar a retirada." 203
	exit 0
else
	LOG "ERRO: Falha na listagem das fitas do DRM" 203
	exit 1
fi


###
### Mover as fitas para o Cofre
ret_move=$(DSMC "move drmedia * wherestate=mountable tostate=vault source=dbbackup remove=no wait=no")
if [ $? -eq 0 ] ; then
	echo "$ret_move" >> $arqInfo
	proc_move=$(grep "Process number" <<< "$ret_move" | awk '{print $4}')
	LOG "Iniciado o processo para retirar fitas para o cofre. (Processo: ${proc_move})" 107
else 
	LOG "Falha na execucao do move drmedia para vault" 204
fi


###
### Monitorar a execucao do move drmedia
n=0
while [ $n -eq 0 ] ; do
	ret_mmove=$(DSMC "q proc ${proc_move}")
	status=$?
	if [ $status -eq 11 ]; then
		LOG "Termino da execucao do move drmedia." 109
		n=1
	elif [ $status -eq 0 ]; then
		sleep 10
	else
		LOG "Falha na checagem do processo do move drmedia. ${proc_move}" 207
		exit 1
	fi
done

### Info Meio start
DSMC_PURO "q drm" >> $arqInfo

###
### Conferir se as fitas mudaram o status para Vault
erro_count=0
run_retrieve=0
while read LINHA ; do
	tape=($LINHA) 
	status=$(DSMC "select state from drmedia where VOLUME_NAME='${tape[0]}'")
	if [ "$status" == "MOUNTABLE" ] ; then
		let erro_count++
		LOG "Erro: Fita ${tape[0]} continua com status mountable."
	elif [ "$status" == "VAULTRETRIEVE" ] ; then
		run_retrieve=1
		tapeRetrieve="${tape[0]} $tapeRetrieve"
	elif [ "$status" == "VAULT" ] ; then
		tapeVault="${tape[0]} $tapeVault"
	else
		let erro_count++
		LOG "Erro: Fita ${tape[0]} com status $status."
	fi 
done <<< "$tapeMount"

if [ $erro_count -gt 0 ]; then
	LOG "Falha no script do DRM." 209
	exit 1
else
	LOG "Fitas Vault: $tapeVault"
fi

###
### Retornar fitas Vault Retrieve
if [ $run_retrieve -eq 1 ] ; then
	LOG "Fitas Vaultretrieve: $tapeRetrieve" 111
	for fita in $tapeRetrieve ; do
		ret_retorno=$(DSMC "move drmedia $fita wherestate=vaultr tostate=onsiter wait=no")
		sleep 5
	done
	ret_checkin=$(DSMC "checkin libv ${LIBR_DRM} search=yes status=scratch waitt=0")
	proc_checkin=$(grep "Process number" <<< "$ret_checkin" | awk '{print $4}')
	LOG "Iniciado checkin de fitas. Processo: ${proc_checkin}"
	n=0
	while [ $n -eq 0 ] ; do
		ret_mon=$(DSMC "q proc ${proc_checkin}")
		status=$?
		if [ $status -eq 11 ]; then
			LOG "Termino da execucao do checkin libv." 113
			n=1
		elif [ $status -eq 0 ]; then
			sleep 10
		else
			LOG "Falha no checkin. ${proc_checkin}" 211
			exit 1
		fi
	done
else
	LOG "Nenhuma fita mountable esta como vault retrieve." 115
fi


###
### Verificar lista de fitas para retornar para a library
tapeVaultret=$(DSMC "select VOLUME_NAME, VOLTYPE from drmedia where state='VAULTRETRIEVE'")
status=$?
if [ $status -eq 0 ] ; then
	fitasVaultret=$(echo "$tapeVaultret" | awk '{print $1}' | tr "\n" " ")
	LOG "Fitas vaultretrieve: $fitasVaultret" 117
	infoVaultret="Fitas para retornar para a Library: $fitasVaultret"
	# Registra no banco as fitas para retornar
	while read fitas_info ; do
		info=($fitas_info)
		sql="insert or ignore into fitas_vaultr values ('${info[0]}','','')"
		SQLITE "$sql"
		sql="update fitas_vaultr set status='VAULTRETRIEVE', data=datetime('now') where volume = '${info[0]}'"
		SQLITE "$sql"
	done <<< "$tapeVaultret"
elif [ $status -eq 11 ] ; then
	LOG "Sem fitas para retornar do cofre."
	infoVaultret="Sem fitas para retornar para a Library."
else
	LOG "ERRO: Falha na listagem das fitas vaultretrieve" 213
	exit 1
fi


### Info Pos start
DSMC_PURO "q drm" >> $arqInfo


### Registra horario de termino do backup automativo e efetua o log da informacao
LOG "Execucao do script de retirada de fitas realizado com sucesso." 0
date +"%s" > $info_lastbkp


###
### Envio de e-mail para o suporte


emailSuporte="Olá,

Seguem as fitas para retirar e retornar para a Library:

Fitas para retirar para o Cofre: $tapeVault

$infoVaultret


Abaixo seguem os logs da execução da retirada.


Atenciosamente,
Bot

### 
### Log Script
`tail -n 20 $arqLog | grep "$(date +"%d/%m/%Y")"`

### 
### Info TSM
`cat $arqInfo`
"




###
### Enviar email de notificacao para o suporte
if [ -n "$TSM_DRM_NOTIFY" ]; then
	/opt/Scripts/emailpy/envia_email.py marcelo@tradetechnology.com.br "Retirada de fitas DRM ${EMPRESA}" "$emailSuporte"
fi

#if [ $par_show == "s" ] ; then
#	echo "$emailSuporte"
#fi

exit 0







### Verificar se está em execução algum processo que interfira na retirada de fitas. validar se foi feito o backup do banco do dia.


### Verificar fitas mountable
DSMC "select VOLUME_NAME, VOLTYPE from drmedia where state='MOUNTABLE'"



### Executar o comando para alterar o status das fitas para vault
move drmedia * wherestate=mountable tostate=vault source=dbbackup remove=no wait=no


### monitorar o processo

#ANR2110I RECLAIM STGPOOL started as process 451.
#ANR4931I Reclamation process 451 started for copy storage pool DRPOOL manually, threshold=90, offsiteRclmLimit=No Limit, duration=None.
#ANS8003I Process number 451 started.


### Apos o termino, conferir o status das fitas, caso alguma tenha ficado Valtr, fazer checkin

### 


### Enviar e-mail com as fitas para retornar e retirar para o cofre





