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

#Directorio de archivos a generar
LOG_PATH="/home/ceamsopy/pentaho/Log/"
ARCHIVOS_PATH="/home/ceamsopy/portal-sfp/client/dist/data/"
ARCHIVOS_PATH_PENTAHO="/home/ceamsopy/cambioETL/"

PENTAHO_JOB_CARGA_OEE="/home/ceamsopy/pentaho/Jobs/CARGAR_TABLA_OEE.kjb"

#Borra las OEE de la base de datos destino	
psql -U $USUARIO_BD_DESTINO -W -h $IP_BD_DESTINO -p $PUERTO_BD_DESTINO $NOMBRE_BD_DESTINO -w -c 'truncate table opendata.oee cascade'

LOG_NAME="crono_log_oee_$(date +%Y_%m_%d)"
LOG_FILE=`echo $LOG_PATH$LOG_NAME'.log'`


#Vamos al directorio del data integration
cd $KETTLE_HOME

#Carga las OEE
if [ -f "$PENTAHO_JOB_CARGA_OEE" ]; then
	sh kitchen.sh -file $PENTAHO_JOB_CARGA_OEE -param:nombreConexionOrigen=$NOMBRE_CONEXION_ORIGEN -param:ipBDOrigen=$IP_BD_ORIGEN -param:puertoBDOrigen=$PUERTO_BD_ORIGEN -param:nombreBDOrigen=$NOMBRE_BD_ORIGEN -param:usuarioBDOrigen=$USUARIO_BD_ORIGEN -param:passBDOrigen=$PASS_BD_ORIGEN -param:nombreConexionDestino=$NOMBRE_CONEXION_DESTINO -param:ipBDDestino=$IP_BD_DESTINO -param:puertoBDDestino=$PUERTO_BD_DESTINO -param:nombreBDDestino=$NOMBRE_BD_DESTINO -param:usuarioBDDestino=$USUARIO_BD_DESTINO -param:passBDDestino=$PASS_BD_DESTINO  level=Debug >> $LOG_FILE
else
		echo "No existe el directorio de archivos de Jobs Pentaho" >> logScriptPentaho.txt
fi
#Generacion de json de OEE
JSON_NAME="oee"
JSON_FILE=`echo $ARCHIVOS_PATH$JSON_NAME`
if [ -f $PENTAHO_JOB_JSON_OEE ]; then
	sh kitchen.sh -file $PENTAHO_JOB_JSON_OEE -param:nombreConexion=$NOMBRE_CONEXION_DESTINO -param:ipBD=$IP_BD_DESTINO -param:puertoBD=$PUERTO_BD_DESTINO -param:nombreBD=$NOMBRE_BD_DESTINO -param:usuarioBD=$USUARIO_BD_DESTINO -param:passBD=$PASS_BD_DESTINO -param:jsonFile=$JSON_FILE level=Debug >> $LOG_FILE
	error=`grep ETL_PORTAL_SFP $LOG_FILE`	
	if [[ $error == *ETL_PORTAL_SFP* ]]; then	
		exit 		
	fi
else
	echo "No existe el directorio de archivos de Jobs Pentaho" >> logScriptPentaho.txt
	exit
fi
	
#Generacion de csv de OEE
CSV_NAME="oee"
CSV_FILE=`echo $ARCHIVOS_PATH$CSV_NAME`
if [ -f "$PENTAHO_JOB_CSV_OEE" ]; then
	sh kitchen.sh -file $PENTAHO_JOB_CSV_OEE -param:nombreConexion=$NOMBRE_CONEXION_DESTINO -param:ipBD=$IP_BD_DESTINO -param:puertoBD=$PUERTO_BD_DESTINO -param:nombreBD=$NOMBRE_BD_DESTINO -param:usuarioBD=$USUARIO_BD_DESTINO -param:passBD=$PASS_BD_DESTINO -param:csvFile=$CSV_FILE level=Debug >> $LOG_FILE
	error=`grep ETL_PORTAL_SFP $LOG_FILE`	
	if [ $error == *ETL_PORTAL_SFP* ]; then	
		exit 		
	fi
else
	echo "No existe el directorio de archivos de Jobs Pentaho" >> logScriptPentaho.txt
	exit
fi	

