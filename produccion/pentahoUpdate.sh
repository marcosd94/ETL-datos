#!/bin/bash
#variables

export KETTLE_HOME="/home/marcosd94/ETL-portal/data-integration"

#Datos de la conexion de bd origen
NOMBRE_CONEXION_ORIGEN="SFP"
IP_BD_ORIGEN="10.2.29.182"
PUERTO_BD_ORIGEN="5432"
NOMBRE_BD_ORIGEN="sicca"
USUARIO_BD_ORIGEN="opendata"
PASS_BD_ORIGEN="Op3nd4t4"

#Datos de la conexion de bd destino
NOMBRE_CONEXION_DESTINO="PRUEBA"
IP_BD_DESTINO="localhost"
PUERTO_BD_DESTINO="5434"
NOMBRE_BD_DESTINO="sfp"
USUARIO_BD_DESTINO="postgres"
PASS_BD_DESTINO="Op3nd4t4"

#Datos del correo electronico
SMTP_SERVER="mail.konecta.com.py"
CORREO_DESTINATARIO="mperalta@sfp.gov.py"
CORREO_EMISOR="diana.jara@konecta.com.py"
PUERTO_SERVER="25"
NOMBRE_DESTINATARIO="PENTAHO"

#Datos de la conexion para rename
NOMBRE_BD_PENTAHO="pentaho"
NOMBRE_BD="postgres"
NOMBRE_BD_TEMPORAL="pentaho_"

#Directorio de archivos a generar
LOG_PATH="/home/marcosd94/ETL-portal/cambioETL/Log/"
ARCHIVOS_PATH="/home/marcosd94/portal-sfp/client/dist/data/"
ARCHIVOS_PATH_PENTAHO="/home/marcosd94/ETL-portal/cambioETL/"

#Directorio de Archivos Pentaho
PENTAHO_JOB_CONCURSOS=`echo $ARCHIVOS_PATH_PENTAHO'CARGAR_TABLA_CONCURSOS.kjb'`
PENTAHO_JOB_JSON_CONCURSOS=`echo $ARCHIVOS_PATH_PENTAHO'GENERAR_JSON_CONCURSOS.kjb'`
PENTAHO_JOB_CSV_CONCURSOS=`echo $ARCHIVOS_PATH_PENTAHO'GENERAR_CSV_CONCURSOS.kjb'`

PENTAHO_JOB_CARGA_VENCIMIENTO=`echo $ARCHIVOS_PATH_PENTAHO'CARGAR_TABLA_VENCIMIENTO.kjb'`
PENTAHO_JOB_CARGA_PROCESAMIENTO=`echo $ARCHIVOS_PATH_PENTAHO'CARGAR_TABLA_PROCESAMIENTO.kjb'`

PENTAHO_JOB_CARGA_FUN=`echo $ARCHIVOS_PATH_PENTAHO'PROCESAR_NUEVOS_REGISTROS.kjb'`
PENTAHO_JOB_CSV_FUN=`echo $ARCHIVOS_PATH_PENTAHO'GENERAR_CSV_FUNCIONARIOS.kjb'`

PENTAHO_JOB_CARGA_OEE=`echo $ARCHIVOS_PATH_PENTAHO'CARGAR_TABLA_OEE.kjb'`
PENTAHO_JOB_JSON_OEE=`echo $ARCHIVOS_PATH_PENTAHO'GENERAR_JSON_OEE.kjb'`
PENTAHO_JOB_CSV_OEE=`echo $ARCHIVOS_PATH_PENTAHO'GENERAR_CSV_OEE.kjb'`

PENTAHO_JOB_UPDATE_FALLIDA=`echo $ARCHIVOS_PATH_PENTAHO'ENVIAR_MAIL_FALLIDO.kjb'`


#Directorio del backup
BACKUP_PATH="/home/marcosd94/ETL-portal/cambioETL/Backup/"
BACKUP_NAME="backup_$(date +%Y_%m_%d)"
BACKUP_FILE=`echo $BACKUP_PATH$BACKUP_NAME'.bak'`
BACKUP_INDEX_FILE=`echo $BACKUP_PATH$BACKUP_NAME'.sql'`

estado=$(psql -qtA -U $USUARIO_BD_DESTINO -W -h $IP_BD_DESTINO -p $PUERTO_BD_DESTINO $NOMBRE_BD_DESTINO -w -c 'select estado from opendata.etl_procesamiento where fecha_inicio =( select max(fecha_inicio) from opendata.etl_procesamiento)')

if [ $estado != procesando ]; then

	fecha_ultimo_etl=$(psql -qtA -U $USUARIO_BD_DESTINO -W -h $IP_BD_DESTINO -p $PUERTO_BD_DESTINO $NOMBRE_BD_DESTINO -w -c 'select max(fecha_inicio) from opendata.etl_procesamiento where script='"'funcionarios'"' and estado='"'finalizado'")

	psql -U $USUARIO_BD_DESTINO -h $IP_BD_DESTINO -p $PUERTO_BD_DESTINO $NOMBRE_BD_DESTINO -w -c 'insert into opendata.etl_procesamiento values ('"'funcionarios'"','"'procesando'"', current_timestamp, null)'

	#Backup de la BD
	pg_dump -h $IP_BD_DESTINO -p $PUERTO_BD_DESTINO -U $USUARIO_BD_DESTINO -w -d $NOMBRE_BD_DESTINO -f $BACKUP_FILE

	#Se verifica si existen usuarios conectados a la BD PENTAHO
	usuarios_linea_drop=$(psql -qtA -U $USUARIO_BD_DESTINO -W -h $IP_BD_DESTINO -p $PUERTO_BD_DESTINO $NOMBRE_BD -w -c 'SELECT COUNT(*) AS users_online FROM pg_stat_activity WHERE datname='"'"$NOMBRE_BD_PENTAHO"'")
	if [ $usuarios_linea_drop -ne 0 ]; then
		#Si existen usuarios conectados los termina
		psql -U $USUARIO_BD_DESTINO -W -h $IP_BD_DESTINO -p $PUERTO_BD_DESTINO $NOMBRE_BD -w -c 'SELECT pg_terminate_backend(pid) FROM pg_stat_activity WHERE datname='"'"$NOMBRE_BD_PENTAHO"'"'AND pid<>pg_backend_pid()'
	fi
	psql -U $USUARIO_BD_DESTINO -h $IP_BD_DESTINO -p $PUERTO_BD_DESTINO -w -c 'DROP DATABASE IF EXISTS '$NOMBRE_BD_PENTAHO
	psql -U $USUARIO_BD_DESTINO -h $IP_BD_DESTINO -p $PUERTO_BD_DESTINO -w -c 'CREATE DATABASE '$NOMBRE_BD_PENTAHO
	psql -U $USUARIO_BD_DESTINO -h $IP_BD_DESTINO -p $PUERTO_BD_DESTINO -d $NOMBRE_BD_PENTAHO -w -c 'CREATE EXTENSION unaccent SCHEMA pg_catalog;ALTER FUNCTION unaccent(text) IMMUTABLE;'
	psql -h $IP_BD_DESTINO -p $PUERTO_BD_DESTINO -U $USUARIO_BD_DESTINO -d $NOMBRE_BD_PENTAHO -w -f $BACKUP_FILE

	#Vamos al directorio del data integration
	cd $KETTLE_HOME

	LOG_NAME="crono_log_comun_$(date +%Y_%m_%d)"
	LOG_FILE=`echo $LOG_PATH$LOG_NAME'.log'`

	#Borra la tabla de procesamiento de la base de datos destino
	psql -U $USUARIO_BD_DESTINO -W -h $IP_BD_DESTINO -p $PUERTO_BD_DESTINO $NOMBRE_BD_PENTAHO -w -c 'truncate table opendata.procesamiento cascade'

	#Carga la tabla de procesamiento
	if [ -f "$PENTAHO_JOB_CARGA_PROCESAMIENTO" ]; then
		sh kitchen.sh -file $PENTAHO_JOB_CARGA_PROCESAMIENTO -param:ipBDOrigen=$IP_BD_ORIGEN -param:puertoBDOrigen=$PUERTO_BD_ORIGEN -param:nombreBDOrigen=$NOMBRE_BD_ORIGEN -param:usuarioBDOrigen=$USUARIO_BD_ORIGEN -param:passBDOrigen=$PASS_BD_ORIGEN -param:ipBDDestino=$IP_BD_DESTINO -param:puertoBDDestino=$PUERTO_BD_DESTINO -param:nombreBDDestino=$NOMBRE_BD_PENTAHO -param:nombreBDFallida=$NOMBRE_BD_DESTINO -param:usuarioBDDestino=$USUARIO_BD_DESTINO -param:passBDDestino=$PASS_BD_DESTINO -param:correoDestinatario=$CORREO_DESTINATARIO -param:correoEmisor=$CORREO_EMISOR -param:nombreDestinatario=$NOMBRE_DESTINATARIO -param:puertoMail=$PUERTO_SERVER -param:smtpServer=$SMTP_SERVER level=Debug >> $LOG_FILE
		error=`grep ETL_PORTAL_SFP $LOG_FILE`
		if [[ $error == *ETL_PORTAL_SFP* ]]; then
			 exit
		fi

	else
		echo "No existe el directorio de archivos de Jobs Pentaho" >> logScriptPentaho.txt
	fi

	#Borra la tabla de vencimiento de la base de datos destino
	psql -U $USUARIO_BD_DESTINO -W -h $IP_BD_DESTINO -p $PUERTO_BD_DESTINO $NOMBRE_BD_PENTAHO -w -c 'truncate table opendata.vencimientos cascade'

	#Carga la tabla de vencimiento
	if [ -f "$PENTAHO_JOB_CARGA_VENCIMIENTO" ]; then
		sh kitchen.sh -file $PENTAHO_JOB_CARGA_VENCIMIENTO -param:ipBDOrigen=$IP_BD_ORIGEN -param:puertoBDOrigen=$PUERTO_BD_ORIGEN -param:nombreBDOrigen=$NOMBRE_BD_ORIGEN -param:usuarioBDOrigen=$USUARIO_BD_ORIGEN -param:passBDOrigen=$PASS_BD_ORIGEN -param:ipBDDestino=$IP_BD_DESTINO -param:puertoBDDestino=$PUERTO_BD_DESTINO -param:nombreBDDestino=$NOMBRE_BD_PENTAHO -param:nombreBDFallida=$NOMBRE_BD_DESTINO -param:usuarioBDDestino=$USUARIO_BD_DESTINO -param:passBDDestino=$PASS_BD_DESTINO -param:correoDestinatario=$CORREO_DESTINATARIO -param:correoEmisor=$CORREO_EMISOR -param:nombreDestinatario=$NOMBRE_DESTINATARIO -param:puertoMail=$PUERTO_SERVER -param:smtpServer=$SMTP_SERVER level=Debug >> $LOG_FILE
		error=`grep ETL_PORTAL_SFP $LOG_FILE`
		if [[ $error == *ETL_PORTAL_SFP* ]]; then
			 exit
		fi
	else
		echo "No existe el directorio de archivos de Jobs Pentaho" >> logScriptPentaho.txt
	fi

	#Zipea el log
	zip -j `echo $LOG_PATH$LOG_NAME'.zip'` $LOG_FILE
	#Borra el logfile ya zipeado
	#rm $LOG_FILE:

	LOG_NAME="crono_log_oee_$(date +%Y_%m_%d)"
	LOG_FILE=`echo $LOG_PATH$LOG_NAME'.log'`

	#Borra las OEE de la base de datos destino
	psql -U $USUARIO_BD_DESTINO -W -h $IP_BD_DESTINO -p $PUERTO_BD_DESTINO $NOMBRE_BD_PENTAHO -w -c 'truncate table opendata.oee cascade'

	#Carga las OEE
	if [ -f "$PENTAHO_JOB_CARGA_OEE" ]; then
		sh kitchen.sh -file $PENTAHO_JOB_CARGA_OEE -param:ipBDOrigen=$IP_BD_ORIGEN -param:puertoBDOrigen=$PUERTO_BD_ORIGEN -param:nombreBDOrigen=$NOMBRE_BD_ORIGEN -param:usuarioBDOrigen=$USUARIO_BD_ORIGEN -param:passBDOrigen=$PASS_BD_ORIGEN -param:ipBDDestino=$IP_BD_DESTINO -param:puertoBDDestino=$PUERTO_BD_DESTINO -param:nombreBDDestino=$NOMBRE_BD_PENTAHO -param:nombreBDFallida=$NOMBRE_BD_DESTINO -param:usuarioBDDestino=$USUARIO_BD_DESTINO -param:passBDDestino=$PASS_BD_DESTINO -param:correoDestinatario=$CORREO_DESTINATARIO -param:correoEmisor=$CORREO_EMISOR -param:nombreDestinatario=$NOMBRE_DESTINATARIO -param:puertoMail=$PUERTO_SERVER -param:smtpServer=$SMTP_SERVER  level=Debug >> $LOG_FILE
		error=`grep ETL_PORTAL_SFP $LOG_FILE`
		if [[ $error == *ETL_PORTAL_SFP* ]]; then
			 exit
		fi

	else
			echo "No existe el directorio de archivos de Jobs Pentaho" >> logScriptPentaho.txt
	fi

	#Generacion de json de OEE
	JSON_NAME="oee"
	JSON_FILE=`echo $ARCHIVOS_PATH$JSON_NAME`
        JSON_FILE_OEE=`echo $ARCHIVOS_PATH$JSON_NAME'.json'`
        JSON_FILE_OLD=`echo $ARCHIVOS_PATH$JSON_NAME'.json.old'`
	JSON_FILE_NUEVO=`echo $ARCHIVOS_PATH$JSON_NAME'.json.nuevo'`

        if [ -f $JSON_FILE_OEE ]; then
                mv $JSON_FILE_OEE $JSON_FILE_OLD
        fi

	if [ -f "$PENTAHO_JOB_JSON_OEE" ]; then
		sh kitchen.sh -file $PENTAHO_JOB_JSON_OEE -param:nombreConexion=$NOMBRE_CONEXION_DESTINO -param:ipBD=$IP_BD_DESTINO -param:puertoBD=$PUERTO_BD_DESTINO -param:nombreBD=$NOMBRE_BD_PENTAHO -param:nombreBDFallida=$NOMBRE_BD_DESTINO -param:usuarioBD=$USUARIO_BD_DESTINO -param:passBD=$PASS_BD_DESTINO -param:jsonFile=$JSON_FILE -param:correoDestinatario=$CORREO_DESTINATARIO -param:correoEmisor=$CORREO_EMISOR -param:nombreDestinatario=$NOMBRE_DESTINATARIO -param:puertoMail=$PUERTO_SERVER -param:smtpServer=$SMTP_SERVER level=Debug >> $LOG_FILE
		mv $JSON_FILE_OEE $JSON_FILE_NUEVO
		error=`grep ETL_PORTAL_SFP $LOG_FILE`
		if [[ $error == *ETL_PORTAL_SFP* ]]; then
			cd $ARCHIVOS_PATH
			rm *.nuevo
                        for FILE in *.old ; do NEWFILE=`echo $FILE | sed 's/.old//g'` ; mv "$FILE" $NEWFILE ; done
			exit
		fi
	else
		echo "No existe el directorio de archivos de Jobs Pentaho" >> logScriptPentaho.txt
	fi
	#Generacion de csv de OEE
	CSV_NAME="oee"
	CSV_FILE=`echo $ARCHIVOS_PATH$CSV_NAME`
	CSV_FILE_OEE=`echo $ARCHIVOS_PATH$CSV_NAME'.csv'`
        CSV_FILE_OLD=`echo $ARCHIVOS_PATH$CSV_NAME'.csv.old'`
	CSV_FILE_NUEVO=`echo $ARCHIVOS_PATH$CSV_NAME'.csv.nuevo'`

	if [ -f $CSV_FILE_OEE ]; then
                mv $CSV_FILE_OEE $CSV_FILE_OLD
        fi

	if [ -f "$PENTAHO_JOB_CSV_OEE" ]; then
		sh kitchen.sh -file $PENTAHO_JOB_CSV_OEE -param:nombreConexion=$NOMBRE_CONEXION_DESTINO -param:ipBD=$IP_BD_DESTINO -param:puertoBD=$PUERTO_BD_DESTINO -param:nombreBD=$NOMBRE_BD_PENTAHO -param:nombreBDFallida=$NOMBRE_BD_DESTINO -param:usuarioBD=$USUARIO_BD_DESTINO -param:passBD=$PASS_BD_DESTINO -param:csvFile=$CSV_FILE -param:correoDestinatario=$CORREO_DESTINATARIO -param:correoEmisor=$CORREO_EMISOR -param:nombreDestinatario=$NOMBRE_DESTINATARIO -param:puertoMail=$PUERTO_SERVER -param:smtpServer=$SMTP_SERVER level=Debug >> $LOG_FILE
		mv $CSV_FILE_OEE $CSV_FILE_NUEVO
		error=`grep ETL_PORTAL_SFP $LOG_FILE`
		if [[ $error == *ETL_PORTAL_SFP* ]]; then
			cd $ARCHIVOS_PATH
			rm *.nuevo
                        for FILE in *.old ; do NEWFILE=`echo $FILE | sed 's/.old//g'` ; mv "$FILE" $NEWFILE ; done
			exit
		fi
	else
		echo "No existe el directorio de archivos de Jobs Pentaho" >> logScriptPentaho.txt
	fi

	#Zipea el log
	zip -j `echo $LOG_PATH$LOG_NAME'.zip'` $LOG_FILE

	#Borra el logfile ya zipeado
	rm $LOG_FILE:

	#Directorio de archivos a generar
	LOG_NAME="crono_log_$(date +%Y_%m_%d)"
	LOG_FILE=`echo $LOG_PATH$LOG_NAME'.log'`

	if [ -f "$PENTAHO_JOB_CARGA_FUN" ]; then
		#Carga el detalle de funcionarios del mes
		sh kitchen.sh -file $PENTAHO_JOB_CARGA_FUN -param:fecha_ultimo_etl=$fecha_ultimo_etl -param:ipBDOrigen=$IP_BD_ORIGEN -param:puertoBDOrigen=$PUERTO_BD_ORIGEN -param:nombreBDOrigen=$NOMBRE_BD_ORIGEN -param:nombreBDFallida=$NOMBRE_BD_DESTINO -param:usuarioBDOrigen=$USUARIO_BD_ORIGEN -param:passBDOrigen=$PASS_BD_ORIGEN -param:ipBDDestino=$IP_BD_DESTINO -param:puertoBDDestino=$PUERTO_BD_DESTINO -param:nombreBDDestino=$NOMBRE_BD_PENTAHO -param:usuarioBDDestino=$USUARIO_BD_DESTINO -param:passBDDestino=$PASS_BD_DESTINO -param:correoDestinatario=$CORREO_DESTINATARIO -param:correoEmisor=$CORREO_EMISOR -param:nombreDestinatario=$NOMBRE_DESTINATARIO -param:puertoMail=$PUERTO_SERVER -param:smtpServer=$SMTP_SERVER level=Debug >> $LOG_FILE
		error=`grep ETL_PORTAL_SFP $LOG_FILE`
		if [[ $error == *ETL_PORTAL_SFP* ]]; then
			cd $ARCHIVOS_PATH
			rm *.nuevo
                        for FILE in *.old ; do NEWFILE=`echo $FILE | sed 's/.old//g'` ; mv "$FILE" $NEWFILE ; done
			exit
		fi
	else
			echo "No existe el directorio de archivos de Jobs Pentaho"
			exit
	fi

	#Obtiene el periodo anho/mes que tuvieron cambios para volver a generar el JSON/CSV
	IFS=\|
	psql -U $USUARIO_BD_ORIGEN -h $IP_BD_ORIGEN -p $PUERTO_BD_ORIGEN $NOMBRE_BD_ORIGEN --quiet --no-align  -t -c 'SELECT distinct tmp1.anho,tmp1.mes FROM remuneracion.remuneraciones_tmp tmp1 where tmp1.fecha_alta >'"'"$fecha_ultimo_etl"'"' UNION SELECT distinct tmp1.anho,tmp1.mes FROM remuneracion.historico_remuneraciones_tmp tmp1 where tmp1.fecha_alta >'"'"$fecha_ultimo_etl"'"'union SELECT DISTINCT anho,mes FROM remuneracion.audit_inactivos where fecha_mod >'"'"$fecha_ultimo_etl"'"|
	while read COL1 COL2; do
		#Generacion de csv de funcionarios del mes y anho
		NAME="funcionarios_"$COL1"_"$COL2
		CSV=`echo $ARCHIVOS_PATH$NAME`
		CSV_FILE=`echo $CSV'.csv'`
		CSV_FILE_ZIP=`echo $CSV'.csv.zip'`
	        CSV_FILE_OLD=`echo $CSV'.csv.zip.old'`
		CSV_FILE_NUEVO=`echo $CSV'.csv.zip.nuevo'`

		if [ -f $CSV_FILE_ZIP ]; then
			mv $CSV_FILE_ZIP $CSV_FILE_OLD
		fi

		if [ -f $PENTAHO_JOB_CSV_FUN ]; then
			sh kitchen.sh -file $PENTAHO_JOB_CSV_FUN -param:anho=$COL1 -param:mes=$COL2 -param:nombreConexion=$NOMBRE_CONEXION_DESTINO -param:ipBD=$IP_BD_DESTINO -param:puertoBD=$PUERTO_BD_DESTINO -param:nombreBD=$NOMBRE_BD_PENTAHO -param:nombreBDFallida=$NOMBRE_BD_DESTINO -param:usuarioBD=$USUARIO_BD_DESTINO -param:passBD=$PASS_BD_DESTINO -param:csvFile=$CSV -param:correoDestinatario=$CORREO_DESTINATARIO -param:correoEmisor=$CORREO_EMISOR -param:nombreDestinatario=$NOMBRE_DESTINATARIO -param:puertoMail=$PUERTO_SERVER -param:smtpServer=$SMTP_SERVER level=Debug >> $LOG_FILE
			zip -j $CSV_FILE_ZIP $CSV_FILE
			mv $CSV_FILE_ZIP $CSV_FILE_NUEVO
			error=`grep ETL_PORTAL_SFP $LOG_FILE`
			if [[ $error == *ETL_PORTAL_SFP* ]]; then
			       cd $ARCHIVOS_PATH
				rm *.nuevo
		                for FILE in *.old ; do NEWFILE=`echo $FILE | sed 's/.old//g'` ; mv "$FILE" $NEWFILE ; done
				exit
			fi
		else
			echo "No existe el directorio de archivos de Jobs Pentaho" >> logScriptPentaho.txt
			break
		fi

		#Generacion de json de funcionarios del mes y anho
		JSON_FILE=`echo $ARCHIVOS_PATH$NAME'.json'`
		JSON_FILE_ZIP=`echo $JSON_FILE'.zip'`
	        JSON_FILE_OLD=`echo $JSON_FILE_ZIP'.old'`

		if [ -f $CSV_FILE ]; then
			if [ -f $JSON_FILE_ZIP ]; then
			        mv $JSON_FILE_ZIP $JSON_FILE_OLD
			fi
			csv2json $CSV_FILE >> $JSON_FILE
			zip -j `echo $JSON_FILE_ZIP` $JSON_FILE
			JSON_FILE_NUEVO=`echo $JSON_FILE_ZIP'.nuevo'`
			mv $JSON_FILE_ZIP $JSON_FILE_NUEVO
			rm $JSON_FILE
			rm $CSV_FILE
		fi
	done

	LOG_NAME="crono_log_concursos_$(date +%Y_%m_%d)"
	LOG_FILE=`echo $LOG_PATH$LOG_NAME'.log'`

	#Borra la tabla de concursos, postulacion, evaluacion y adjudicacion de la base de datos destino
	psql -U $USUARIO_BD_DESTINO -W -h $IP_BD_DESTINO -p $PUERTO_BD_DESTINO $NOMBRE_BD_PENTAHO -w -c 'truncate table opendata.concursos cascade'
	psql -U $USUARIO_BD_DESTINO -W -h $IP_BD_DESTINO -p $PUERTO_BD_DESTINO $NOMBRE_BD_PENTAHO -w -c 'truncate table opendata.postulacion cascade'
	psql -U $USUARIO_BD_DESTINO -W -h $IP_BD_DESTINO -p $PUERTO_BD_DESTINO $NOMBRE_BD_PENTAHO -w -c 'truncate table opendata.evaluacion cascade'
	psql -U $USUARIO_BD_DESTINO -W -h $IP_BD_DESTINO -p $PUERTO_BD_DESTINO $NOMBRE_BD_PENTAHO -w -c 'truncate table opendata.adjudicacion cascade'

	#Carga la tabla de concursos
	if [ -f $PENTAHO_JOB_CARGA_CONCURSOS ]; then
		sh kitchen.sh -file $PENTAHO_JOB_CONCURSOS -param:nombreConexionOrigen=$NOMBRE_CONEXION_ORIGEN -param:ipBDOrigen=$IP_BD_ORIGEN -param:puertoBDOrigen=$PUERTO_BD_ORIGEN -param:nombreBDOrigen=$NOMBRE_BD_ORIGEN -param:usuarioBDOrigen=$USUARIO_BD_ORIGEN -param:nombreBDFallida=$NOMBRE_BD_DESTINO -param:passBDOrigen=$PASS_BD_ORIGEN -param:nombreConexionDestino=$NOMBRE_CONEXION_DESTINO -param:ipBDDestino=$IP_BD_DESTINO -param:puertoBDDestino=$PUERTO_BD_DESTINO -param:nombreBDDestino=$NOMBRE_BD_PENTAHO -param:usuarioBDDestino=$USUARIO_BD_DESTINO -param:passBDDestino=$PASS_BD_DESTINO  -param:correoDestinatario=$CORREO_DESTINATARIO -param:correoEmisor=$CORREO_EMISOR -param:nombreDestinatario=$NOMBRE_DESTINATARIO -param:puertoMail=$PUERTO_SERVER -param:smtpServer=$SMTP_SERVER level=Debug >> $LOG_FILE
		error=`grep ETL_PORTAL_SFP $LOG_FILE`
		if [[ $error == *ETL_PORTAL_SFP* ]]; then
			cd $ARCHIVOS_PATH
			rm *.nuevo
	                for FILE in *.old ; do NEWFILE=`echo $FILE | sed 's/.old//g'` ; mv "$FILE" $NEWFILE ; done
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
	JSON_FILE_ZIP=`echo $JSON_FILE_JSON'.zip'`
        JSON_FILE_OLD=`echo $JSON_FILE_ZIP'.old'`
	JSON_FILE_NUEVO=`echo $JSON_FILE_ZIP'.nuevo'`

        if [ -f $JSON_FILE_JSON ]; then
                mv $JSON_FILE_ZIP $JSON_FILE_OLD
        fi

	if [ -f $PENTAHO_JOB_JSON_CONCURSOS ]; then
		sh kitchen.sh -file $PENTAHO_JOB_JSON_CONCURSOS -param:nombreConexion=$NOMBRE_CONEXION_DESTINO -param:ipBD=$IP_BD_DESTINO -param:puertoBD=$PUERTO_BD_DESTINO -param:nombreBD=$NOMBRE_BD_PENTAHO -param:nombreBDFallida=$NOMBRE_BD_DESTINO -param:usuarioBD=$USUARIO_BD_DESTINO -param:passBD=$PASS_BD_DESTINO -param:jsonFile=$JSON_FILE  -param:correoDestinatario=$CORREO_DESTINATARIO -param:correoEmisor=$CORREO_EMISOR -param:nombreDestinatario=$NOMBRE_DESTINATARIO -param:puertoMail=$PUERTO_SERVER -param:smtpServer=$SMTP_SERVER level=Debug >> $LOG_FILE
		zip -j $JSON_FILE_ZIP $JSON_FILE_JSON
		mv $JSON_FILE_ZIP $JSON_FILE_NUEVO
		rm $JSON_FILE_JSON
	       error=`grep ETL_PORTAL_SFP $LOG_FILE`
                if [[ $error == *ETL_PORTAL_SFP* ]]; then
			cd $ARCHIVOS_PATH
			rm *.nuevo
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
	CSV_FILE_ZIP=`echo $CSV_FILE_CSV'.zip'`
        CSV_FILE_OLD=`echo $CSV_FILE_ZIP'.old'`
        CSV_FILE_NUEVO=`echo $CSV_FILE_ZIP'.nuevo'`
        if [ -f $CSV_FILE_CSV ]; then
                mv $CSV_FILE_ZIP $CSV_FILE_OLD
        fi

	if [ -f "$PENTAHO_JOB_CSV_CONCURSOS" ]; then
                sh kitchen.sh -file $PENTAHO_JOB_CSV_CONCURSOS -param:nombreConexion=$NOMBRE_CONEXION_DESTINO -param:nombreBDFallida=$NOMBRE_BD_DESTINO -param:ipBD=$IP_BD_DESTINO -param:puertoBD=$PUERTO_BD_DESTINO -param:nombreBD=$NOMBRE_BD_PENTAHO -param:usuarioBD=$USUARIO_BD_DESTINO -param:passBD=$PASS_BD_DESTINO -param:csvFile=$CSV_FILE  -param:correoDestinatario=$CORREO_DESTINATARIO -param:correoEmisor=$CORREO_EMISOR -param:nombreDestinatario=$NOMBRE_DESTINATARIO -param:puertoMail=$PUERTO_SERVER -param:smtpServer=$SMTP_SERVER level=Debug >> $LOG_FILE
		zip -j $CSV_FILE_ZIP $CSV_FILE_CSV
		rm $CSV_FILE_CSV
                mv $CSV_FILE_ZIP $CSV_FILE_NUEVO
		error=`grep ETL_PORTAL_SFP $LOG_FILE`
                if [[ $error == *ETL_PORTAL_SFP* ]]; then
                        cd $ARCHIVOS_PATH
			rm *.nuevo
                        for FILE in *.old ; do NEWFILE=`echo $FILE | sed 's/.old//g'` ; mv "$FILE" $NEWFILE ; done
                        exit
                fi
        else
            	echo "No existe el directorio de archivos de Jobs Pentaho" >> logScriptPentaho.txt
                exit
        fi
	#Zipea el log
	zip `echo $LOG_PATH$LOG_NAME'.zip'` $LOG_FILE

	cd $ARCHIVOS_PATH
	for FILE in *.nuevo ; do NEWFILE=`echo $FILE | sed 's/.nuevo//g'` ; mv "$FILE" $NEWFILE ; done
	rm *.old
	psql -U $USUARIO_BD_DESTINO -W -h $IP_BD_DESTINO -p $PUERTO_BD_DESTINO $NOMBRE_BD_PENTAHO -w -c 'update opendata.etl_procesamiento set estado='"'finalizado'"', fecha_fin=current_timestamp where fecha_inicio=(select max(fecha_inicio) from opendata.etl_procesamiento) and estado='"'procesando'"''

	#Renombra la BD PENTAHO
	#Se verifica si existen usuarios conectados a la BD PRODUCCION
	usuarios_linea=$(psql -qtA -U $USUARIO_BD_DESTINO -W -h $IP_BD_DESTINO -p $PUERTO_BD_DESTINO $NOMBRE_BD -w -c 'SELECT COUNT(*) AS users_online FROM pg_stat_activity WHERE datname='"'"$NOMBRE_BD_DESTINO"'")
	if [ $usuarios_linea -ne 0 ]; then
		#Si existen usuarios conectados los termina
		psql -U $USUARIO_BD_DESTINO -W -h $IP_BD_DESTINO -p $PUERTO_BD_DESTINO $NOMBRE_BD -w -c 'SELECT pg_terminate_backend(pid) FROM pg_stat_activity WHERE datname='"'"$NOMBRE_BD_DESTINO"'"' AND pid<>pg_backend_pid()'
	fi

	#Se verifica si existen usuarios conectados a la BD PENTAHO
	usuarios_linea_=$(psql -qtA -U $USUARIO_BD_DESTINO -W -h $IP_BD_DESTINO -p $PUERTO_BD_DESTINO $NOMBRE_BD -w -c 'SELECT COUNT(*) AS users_online FROM pg_stat_activity WHERE datname='"'"$NOMBRE_BD_PENTAHO"'")
	if [ $usuarios_linea_ -ne 0 ]; then
		#Si existen usuarios conectados los termina
		psql -U $USUARIO_BD_DESTINO -W -h $IP_BD_DESTINO -p $PUERTO_BD_DESTINO $NOMBRE_BD -w -c 'SELECT pg_terminate_backend(pid) FROM pg_stat_activity WHERE datname='"'"$NOMBRE_BD_PENTAHO"'"' AND pid<>pg_backend_pid()'
	fi

	#Renombra la BD PRODUCCION a una BD TEMPORAL
	psql -U $USUARIO_BD_DESTINO -W -h $IP_BD_DESTINO -p $PUERTO_BD_DESTINO $NOMBRE_BD -w -c 'ALTER DATABASE '$NOMBRE_BD_DESTINO' RENAME TO '$NOMBRE_BD_TEMPORAL

	#Renombra la BD PENTAHO a la BD PRODUCCION
	psql -U $USUARIO_BD_DESTINO -W -h $IP_BD_DESTINO -p $PUERTO_BD_DESTINO $NOMBRE_BD -w -c 'ALTER DATABASE '$NOMBRE_BD_PENTAHO' RENAME TO '$NOMBRE_BD_DESTINO

	#Borra la BD temporal
	psql -U $USUARIO_BD_DESTINO -W -h $IP_BD_DESTINO -p $PUERTO_BD_DESTINO -w -c 'DROP DATABASE IF EXISTS '$NOMBRE_BD_TEMPORAL
else
	cd $KETTLE_HOME
	sh kitchen.sh -file $PENTAHO_JOB_UPDATE_FALLIDA -param:nombreConexionDestino=$NOMBRE_CONEXION_DESTINO -param:ipBDDestino=$IP_BD_DESTINO -param:puertoBDDestino=$PUERTO_BD_DESTINO -param:nombreBDFallida=$NOMBRE_BD_DESTINO -param:usuarioBDDestino=$USUARIO_BD_DESTINO -param:passBDDestino=$PASS_BD_DESTINO -param:correoDestinatario=$CORREO_DESTINATARIO -param:correoEmisor=$CORREO_EMISOR -param:nombreDestinatario=$NOMBRE_DESTINATARIO -param:puertoMail=$PUERTO_SERVER -param:smtpServer=$SMTP_SERVER
fi
