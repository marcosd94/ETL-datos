#!/bin/bash
#variables

#Datos de la conexion de bd destino
NOMBRE_CONEXION_DESTINO="CEAMSO"
IP_BD_DESTINO="195.154.173.81"
PUERTO_BD_DESTINO="5434"
NOMBRE_BD_DESTINO="sfp"
USUARIO_BD_DESTINO="postgres"
PASS_BD_DESTINO="postgres"

#Datos de la conexion para rename
NOMBRE_BD_PENTAHO="pentaho"
NOMBRE_BD="postgres"
NOMBRE_BD_TEMPORAL="pentaho2"

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
