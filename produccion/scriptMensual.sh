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
NOMBRE_BD_DESTINO="pentaho2"
USUARIO_BD_DESTINO="postgres"
PASS_BD_DESTINO="Op3nd4t4"

#Datos del correo electronico
SMTP_SERVER="mail.konecta.com.py"
CORREO_DESTINATARIO="diana.jara@konecta.com.py"
CORREO_EMISOR="diana.jara@konecta.com.py"
PUERTO_SERVER="25"
NOMBRE_DESTINATARIO="PENTAHO"

#Archivos Pentaho

PENTAHO_JOB_CARGA_FUN="/home/ceamsopy/pentaho/Jobs/CARGAR_DETALLES_FUNCIONARIOS.kjb"
PENTAHO_JOB_CARGA_OFUS="/home/ceamsopy/pentaho/Jobs/CARGAR_DETALLES_FUNCIONARIOS_OFUSCADOS.kjb"

#Directorio de archivos a generar
LOG_PATH="/home/ceamsopy/cambioETL/pruebas/"
#ARCHIVOS_PATH="/home/ceamsopy/portal-sfp/client/dist/data/"

#Vamos al directorio del data integration
cd $KETTLE_HOME

LOG_NAME="crono_log_comun_$(date +%Y_%m_%d)"
LOG_FILE=`echo $LOG_PATH$LOG_NAME'.log'`

MES=7
ANHO=2015

LOG_NAME="crono_log_$(date +%Y_%m_%d)"
LOG_FILE=`echo $LOG_PATH$LOG_NAME'_'$ANHO'-'$MES'.log'`

#Borra el mes de la base de datos destino	
psql -U $USUARIO_BD_DESTINO -W -h $IP_BD_DESTINO -p $PUERTO_BD_DESTINO $NOMBRE_BD_DESTINO -w -c 'drop table if exists opendata.detalles_funcionarios_'$ANHO'_'$MES' cascade'

#Borra el mes de la base de datos destino	
psql -U $USUARIO_BD_DESTINO -W -h $IP_BD_DESTINO -p $PUERTO_BD_DESTINO $NOMBRE_BD_DESTINO -w -c 'drop table if exists opendata.funcionarios_'$ANHO'_'$MES' cascade'

if [ -f "$PENTAHO_JOB_CARGA_FUN" ]; then
	#Carga el detalle de funcionarios del mes
	sh kitchen.sh -file $PENTAHO_JOB_CARGA_FUN -param:anho=$ANHO -param:mes=$MES -param:nombreConexionOrigen=$NOMBRE_CONEXION_ORIGEN -param:ipBDOrigen=$IP_BD_ORIGEN -param:puertoBDOrigen=$PUERTO_BD_ORIGEN -param:nombreBDOrigen=$NOMBRE_BD_ORIGEN -param:usuarioBDOrigen=$USUARIO_BD_ORIGEN -param:passBDOrigen=$PASS_BD_ORIGEN -param:nombreConexionDestino=$NOMBRE_CONEXION_DESTINO -param:ipBDDestino=$IP_BD_DESTINO -param:puertoBDDestino=$PUERTO_BD_DESTINO -param:nombreBDDestino=$NOMBRE_BD_DESTINO -param:usuarioBDDestino=$USUARIO_BD_DESTINO -param:passBDDestino=$PASS_BD_DESTINO -param:correoDestinatario=$CORREO_DESTINATARIO -param:correoEmisor=$CORREO_EMISOR -param:nombreDestinatario=$NOMBRE_DESTINATARIO -param:puertoMail=$PUERTO_SERVER -param:smtpServer=$SMTP_SERVER level=Debug >> $LOG_FILE
else
	echo "No existe el directorio de archivos de Jobs Pentaho" >> logScriptPentaho.txt
	break	
fi

#Generacion de csv de funcionarios del mes y anho 
#	CSV_NAME="funcionarios_"$ANHO"_"$MES
#	CSV=`echo $ARCHIVOS_PATH$CSV_NAME`
#	CSV_FILE=`echo $CSV'.csv'`

#	if [ -f $CSV_FILE ]; then
#		rm $CSV_FILE:	
#	fi

#	if [ -f $PENTAHO_JOB_CSV_FUN ]; then
#		sh kitchen.sh -file $PENTAHO_JOB_CSV_FUN -param:anho=$ANHO -param:mes=$MES -param:nombreConexion=$NOMBRE_CONEXION_DESTINO -param:ipBD=$IP_BD_DESTINO -param:puertoBD=$PUERTO_BD_DESTINO -param:nombreBD=$NOMBRE_BD_DESTINO -param:usuarioBD=$USUARIO_BD_DESTINO -param:passBD=$PASS_BD_DESTINO -param:csvFile=$CSV -param:correoDestinatario=$CORREO_DESTINATARIO -param:correoEmisor=$CORREO_EMISOR -param:nombreDestinatario=$NOMBRE_DESTINATARIO -param:puertoMail=$PUERTO_SERVER -param:smtpServer=$SMTP_SERVER level=Debug >> $LOG_FILE
#		error=`grep ETL_PORTAL_SFP $LOG_FILE`	
#		if [ $error == *ETL_PORTAL_SFP* ]; then	
#			exit 		
#		fi
#	else
#		echo "No existe el directorio de archivos de Jobs Pentaho" >> logScriptPentaho.txt
#		break
#	fi
	
#	#Generacion de json de funcionarios del mes y anho 
#	JSON_NAME="funcionarios_"$ANHO"_"$MES
#	JSON=`echo $ARCHIVOS_PATH$JSON_NAME`
#	JSON_FILE=`echo $JSON'.json'`
	
#	if [ -f $CSV_FILE ]; then
#		if [ -f $JSON_FILE ]; then
#			rm $JSON_FILE
#		fi
#		csv2json $CSV_FILE >> $JSON_FILE
#		zip -j `echo $ARCHIVOS_PATH$CSV_FILE'.zip'` $CSV_FILE
 #       	zip -j `echo $ARCHIVOS_PATH$JSON_FILE'.zip'` $JSON_FILE
#		rm $JSON_FILE
#		rm $CSV_FILE
#	fi


#Zipea el log
zip `echo $LOG_PATH$LOG_NAME'_'$ANHO'-'$MES'.zip'` $LOG_FILE

#Borra el logfile ya zipeado
#rm $LOG_FILE:




