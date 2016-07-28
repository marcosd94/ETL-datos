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
PASS_BD_DESTINO="Op3nd4t4"

#Datos del correo electronico
SMTP_SERVER="mail.konecta.com.py"
CORREO_DESTINATARIO="diana.jara@konecta.com.py"
CORREO_EMISOR="diana.jara@konecta.com.py"
PUERTO_SERVER="25"
NOMBRE_DESTINATARIO="PENTAHO"

#Archivos Pentaho
PENTAHO_JOB_CONCURSOS="/home/ceamsopy/pentaho/Jobs/CARGAR_TABLA_CONCURSOS.kjb"
PENTAHO_JOB_JSON_CONCURSOS="/home/ceamsopy/cambioETL/GENERAR_JSON_CONCURSOS.kjb"
PENTAHO_JOB_CSV_CONCURSOS="/home/ceamsopy/cambioETL/GENERAR_CSV_CONCURSOS.kjb"

#Directorio de archivos a generar
LOG_PATH="/home/ceamsopy/cambioETL/Log/"
ARCHIVOS_PATH="/home/ceamsopy/portal-sfp/client/dist/data/"

#Backup de la bd destino
BACKUP_PATH="/home/ceamsopy/cambioETL/Backup/"
BACKUP_NAME="backup_concursos_$(date +%Y_%m_%d)"
BACKUP_FILE=`echo $BACKUP_PATH$BACKUP_NAME'.bak'`

pg_dump -Fc -i -h $IP_BD_DESTINO -p $PUERTO_BD_DESTINO -U $USUARIO_BD_DESTINO -t opendata.concursos -t opendata.postulacion -t opendata.evaluacion -t opendata.adjudicacion -b -w -v -f $BACKUP_FILE $NOMBRE_BD_DESTINO

#Vamos al directorio del data integration
cd $KETTLE_HOME

LOG_NAME="crono_log_concursos_$(date +%Y_%m_%d)"
LOG_FILE=`echo $LOG_PATH$LOG_NAME'.log'`

#Borra la tabla de procesamiento de la base de datos destino	
psql -U $USUARIO_BD_DESTINO -W -h $IP_BD_DESTINO -p $PUERTO_BD_DESTINO $NOMBRE_BD_DESTINO -w -c 'truncate table opendata.concursos cascade'
psql -U $USUARIO_BD_DESTINO -W -h $IP_BD_DESTINO -p $PUERTO_BD_DESTINO $NOMBRE_BD_DESTINO -w -c 'truncate table opendata.postulacion cascade'
psql -U $USUARIO_BD_DESTINO -W -h $IP_BD_DESTINO -p $PUERTO_BD_DESTINO $NOMBRE_BD_DESTINO -w -c 'truncate table opendata.evaluacion cascade'
psql -U $USUARIO_BD_DESTINO -W -h $IP_BD_DESTINO -p $PUERTO_BD_DESTINO $NOMBRE_BD_DESTINO -w -c 'truncate table opendata.adjudicacion cascade'

#Carga la tabla de concursos
if [ -f $PENTAHO_JOB_CARGA_CONCURSOS ]; then	
	sh kitchen.sh -file $PENTAHO_JOB_CONCURSOS -param:nombreConexionOrigen=$NOMBRE_CONEXION_ORIGEN -param:ipBDOrigen=$IP_BD_ORIGEN -param:puertoBDOrigen=$PUERTO_BD_ORIGEN -param:nombreBDOrigen=$NOMBRE_BD_ORIGEN -param:usuarioBDOrigen=$USUARIO_BD_ORIGEN -param:passBDOrigen=$PASS_BD_ORIGEN -param:nombreConexionDestino=$NOMBRE_CONEXION_DESTINO -param:ipBDDestino=$IP_BD_DESTINO -param:puertoBDDestino=$PUERTO_BD_DESTINO -param:nombreBDDestino=$NOMBRE_BD_DESTINO -param:usuarioBDDestino=$USUARIO_BD_DESTINO -param:passBDDestino=$PASS_BD_DESTINO  level=Debug >> $LOG_FILE
	error=`grep ETL_PORTAL_SFP $LOG_FILE`	
	if [[ $error == *ETL_PORTAL_SFP* ]]; then	
		exit 		
	fi
else
	echo "No existe el directorio de archivos de Jobs Pentaho" >> logScriptPentaho.txt
	exit	
fi	

	#Generacion de json de concursos
        JSON_NAME="concursos"
        JSON_FILE=`echo $ARCHIVOS_PATH$JSON_NAME`
        JSON_FILE_JSON=`echo $ARCHIVOS_PATH$JSON_NAME'.json'`
        JSON_FILE_OLD=`echo $ARCHIVOS_PATH$JSON_NAME'.json.old'`

        if [ -f $JSON_FILE_JSON ]; then
                mv $JSON_FILE_JSON $JSON_FILE_OLD
        fi

	if [ -f $PENTAHO_JOB_JSON_CONCURSOS ]; then
		sh kitchen.sh -file $PENTAHO_JOB_JSON_CONCURSOS -param:nombreConexion=$NOMBRE_CONEXION_DESTINO -param:ipBD=$IP_BD_DESTINO -param:puertoBD=$PUERTO_BD_DESTINO -param:nombreBD=$NOMBRE_BD_DESTINO -param:usuarioBD=$USUARIO_BD_DESTINO -param:passBD=$PASS_BD_DESTINO -param:jsonFile=$JSON_FILE level=Debug >> $LOG_FILE
	       error=`grep ETL_PORTAL_SFP $LOG_FILE`
                if [[ $error == *ETL_PORTAL_SFP* ]]; then
                        cd $ARCHIVOS_PATH
                        for FILE in *.old ; do NEWFILE=`echo $FILE | sed 's/.old//g'` ; mv "$FILE" $NEWFILE ; done
                        exit
                fi
        else
            	echo "No existe el directorio de archivos de Jobs Pentaho" >> logScriptPentaho.txt
                exit
        fi

	#Generacion de csv de concursos
        CSV_NAME="concursos"
        CSV_FILE=`echo $ARCHIVOS_PATH$CSV_NAME`
        CSV_FILE_CSV=`echo $ARCHIVOS_PATH$CSV_NAME'.csv'`
        CSV_FILE_OLD=`echo $ARCHIVOS_PATH$CSV_NAME'.csv.old'`
        if [ -f $CSV_FILE_CSV ]; then
                mv $CSV_FILE_CSV $CSV_FILE_OLD
        fi

	if [ -f "$PENTAHO_JOB_CSV_CONCURSOS" ]; then
                sh kitchen.sh -file $PENTAHO_JOB_CSV_CONCURSOS -param:nombreConexion=$NOMBRE_CONEXION_DESTINO -param:ipBD=$IP_BD_DESTINO -param:puer$
                error=`grep ETL_PORTAL_SFP $LOG_FILE`
                if [[ $error == *ETL_PORTAL_SFP* ]]; then
                        cd $ARCHIVOS_PATH
                        for FILE in *.old ; do NEWFILE=`echo $FILE | sed 's/.old//g'` ; mv "$FILE" $NEWFILE ; done
                        exit
                fi
        else
            	echo "No existe el directorio de archivos de Jobs Pentaho" >> logScriptPentaho.txt
                exit
        fi
	zip -j `echo $CSV_FILE_CSV'.zip'` $CSV_FILE_CSV
        zip -j `echo $JSON_FILE_JSON'.zip'` $JSON_FILE_JSON



	

#Zipea el log
zip `echo $LOG_PATH$LOG_NAME'.zip'` $LOG_FILE

#Borra el logfile ya zipeado
#rm $LOG_FILE:



