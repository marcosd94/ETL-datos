#!/bin/bash
#variables

export KETTLE_HOME="/home/ceamsopy/data-integration"

#Datos de la conexion de bd origen
NOMBRE_CONEXION_ORIGEN="SFP"
IP_BD_ORIGEN="10.2.29.182"
PUERTO_BD_ORIGEN="5432"
NOMBRE_BD_ORIGEN="sicca"
USUARIO_BD_ORIGEN="opendata"
PASS_BD_ORIGEN="Op3nd4t4"

#Datos de la conexion de bd destino
NOMBRE_CONEXION_DESTINO="CEAMSO"
IP_BD_DESTINO="195.154.173.81"
PUERTO_BD_DESTINO="5434"
NOMBRE_BD_DESTINO="sfp"
USUARIO_BD_DESTINO="postgres"
PASS_BD_DESTINO="postgres"

#Datos del correo electronico
SMTP_SERVER="mail.konecta.com.py"
CORREO_DESTINATARIO="diana.jara@konecta.com.py"
CORREO_EMISOR="diana.jara@konecta.com.py"
PUERTO_SERVER="25"
NOMBRE_DESTINATARIO="PENTAHO"

#Archivos Pentaho
PENTAHO_JOB_VENCIMIENTO="/home/ceamsopy/pentaho/Jobs/CARGAR_TABLA_PROCESAMIENTO.kjb"
PENTAHO_JOB_PROCESAMIENTO="/home/ceamsopy/pentaho/Jobs/CARGAR_TABLA_VENCIMIENTO.kjb"

#Directorio de archivos a generar
LOG_PATH="/home/ceamsopy/pentaho/Log/"
ARCHIVOS_PATH="/home/ceamsopy/portal-sfp/client/dist/data/"

#Backup de la bd destino
BACKUP_PATH="/home/ceamsopy/pentaho/Backup/"
BACKUP_NAME="backup_proc_venc_$(date +%Y_%m_%d)"
BACKUP_FILE=`echo $BACKUP_PATH$BACKUP_NAME'.bak'`

#pg_dump -Fc -i -h $IP_BD_DESTINO -p $PUERTO_BD_DESTINO -U $USUARIO_BD_DESTINO -t opendata.procesamiento -t opendata.vencimientos -b -w -v -f $BACKUP_FILE $NOMBRE_BD_DESTINO

#Vamos al directorio del data integration
cd $KETTLE_HOME

LOG_NAME="crono_log_proc_venc_$(date +%Y_%m_%d)"
LOG_FILE=`echo $LOG_PATH$LOG_NAME'.log'`

#Borra la tabla de procesamiento de la base de datos destino	
psql -U $USUARIO_BD_DESTINO -W -h $IP_BD_DESTINO -p $PUERTO_BD_DESTINO $NOMBRE_BD_DESTINO -w -c 'truncate table opendata.procesamiento cascade'
psql -U $USUARIO_BD_DESTINO -W -h $IP_BD_DESTINO -p $PUERTO_BD_DESTINO $NOMBRE_BD_DESTINO -w -c 'truncate table opendata.vencimientos cascade'

#Carga la tabla de procesamiento
if [ -f $PENTAHO_JOB_PROCESAMIENTO ]; then	
	sh kitchen.sh -file $PENTAHO_JOB_PROCESAMIENTO -param:nombreConexionOrigen=$NOMBRE_CONEXION_ORIGEN -param:ipBDOrigen=$IP_BD_ORIGEN -param:puertoBDOrigen=$PUERTO_BD_ORIGEN -param:nombreBDOrigen=$NOMBRE_BD_ORIGEN -param:usuarioBDOrigen=$USUARIO_BD_ORIGEN -param:passBDOrigen=$PASS_BD_ORIGEN -param:nombreConexionDestino=$NOMBRE_CONEXION_DESTINO -param:ipBDDestino=$IP_BD_DESTINO -param:puertoBDDestino=$PUERTO_BD_DESTINO -param:nombreBDDestino=$NOMBRE_BD_DESTINO -param:usuarioBDDestino=$USUARIO_BD_DESTINO -param:passBDDestino=$PASS_BD_DESTINO  level=Debug >> $LOG_FILE
	error=`grep ETL_PORTAL_SFP $LOG_FILE`	
	if [[ $error == *ETL_PORTAL_SFP* ]]; then	
		exit 		
	fi
else
	echo "No existe el directorio de archivos de Jobs Pentaho" >> logScriptPentaho.txt
	exit	
fi	

#Carga la tabla de vencimiento	
if [ -f $PENTAHO_JOB_VENCIMIENTO ]; then	
	sh kitchen.sh -file $PENTAHO_JOB_VENCIMIENTO -param:nombreConexionOrigen=$NOMBRE_CONEXION_ORIGEN -param:ipBDOrigen=$IP_BD_ORIGEN -param:puertoBDOrigen=$PUERTO_BD_ORIGEN -param:nombreBDOrigen=$NOMBRE_BD_ORIGEN -param:usuarioBDOrigen=$USUARIO_BD_ORIGEN -param:passBDOrigen=$PASS_BD_ORIGEN -param:nombreConexionDestino=$NOMBRE_CONEXION_DESTINO -param:ipBDDestino=$IP_BD_DESTINO -param:puertoBDDestino=$PUERTO_BD_DESTINO -param:nombreBDDestino=$NOMBRE_BD_DESTINO -param:usuarioBDDestino=$USUARIO_BD_DESTINO -param:passBDDestino=$PASS_BD_DESTINO  level=Debug >> $LOG_FILE
	error=`grep ETL_PORTAL_SFP $LOG_FILE`	
	if [[ $error == *ETL_PORTAL_SFP* ]]; then	
		exit 		
	fi
else
	echo "No existe el directorio de archivos de Jobs Pentaho" >> logScriptPentaho.txt
	exit	
fi	

#Zipea el log
zip `echo $LOG_PATH$LOG_NAME'.zip'` $LOG_FILE

#Borra el logfile ya zipeado
#rm $LOG_FILE:



