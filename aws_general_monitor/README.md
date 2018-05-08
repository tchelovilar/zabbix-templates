

## Host usado para realizar as consultas

- Salvar os script mon_aws.py em /opt/scripts/mon_aws.py

- Definir a opção `Timeout` no arquivo de configuração do Zabbix Server e do Agent
  que vai realizar a consulta para 15 segundos.

- Atachar uma Role na instância do Zabbix com as permissões:
  * Leitura de instancias reservadas
  * Leitura de instancias e security groups

- Configuração do UserParameter no arquivo de configuracao do Zabbix Agent
```
UserParameter=monitor.aws[*],/opt/scripts/mon_aws.py $1 $2 $3 $4 $5 $6
```
