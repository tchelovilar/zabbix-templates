#!/bin/bash

source /opt/Scripts/etc/general.conf
source /opt/Scripts/lib/lib_tsm.sh

lista=$(DSMC "select (home_element-4095) as local from libvolumes order by local")

#echo -e "Lista Usados: \n$lista"

for i in `seq 1 22`; do
	#echo $i
	egrep -q "^$i$" <<< "$lista"
	if [ $? -eq 0 ]; then
		#echo $i: Usado
		l[$i]="Usado"
	else
		l[$i]="Livre"
	fi
done  


library="Seguem os slots que estao em uso pelo TSM. 
 
 
Left Magazine (Esquerda)
-------------------------------------------------
| 08- ${l[8]} | 09- ${l[9]} | 10- ${l[10]} | 11- ${l[11]} |
|-----------|-----------|-----------|-----------|
| 04- ${l[4]} | 05- ${l[5]} | 06- ${l[6]} | 07- ${l[7]} |
|-----------|-----------|-----------|-----------|
| IOStation | 01- ${l[1]} | 02- ${l[2]} | 03- ${l[3]} |
-------------------------------------------------


Right Magazine (Direita)
-------------------------------------------------
| 23- CLEAN | 22- ${l[22]} | 21- ${l[21]} | 20- ${l[20]} |
|-----------|-----------|-----------|-----------|
| 19- ${l[19]} | 18- ${l[18]} | 17- ${l[17]} | 16- ${l[16]} |
|-----------|-----------|-----------|-----------|
| 15- ${l[15]} | 14- ${l[14]} | 13- ${l[13]} | 12- ${l[12]} |
-------------------------------------------------
"


/opt/Scripts/emailpy/envia_email.py $email_cliente "TS3100 Status dos Slots" "$library"


