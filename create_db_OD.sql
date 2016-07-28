-- Schema: opendata

-- DROP SCHEMA opendata;

CREATE SCHEMA opendata
  AUTHORIZATION postgres;

GRANT ALL ON SCHEMA opendata TO postgres;
GRANT USAGE ON SCHEMA opendata TO opendata;

ALTER DEFAULT PRIVILEGES IN SCHEMA opendata
    GRANT SELECT ON TABLES
    TO opendata;
--------------------------------------------
-- Function: opendata.insert_detalles_funcionarios_function()

-- DROP FUNCTION opendata.insert_detalles_funcionarios_function();

CREATE OR REPLACE FUNCTION opendata.insert_detalles_funcionarios_function()
  RETURNS trigger AS
$BODY$
DECLARE
_tablename text;
_tablenamedet text;
_ci text;
_count integer;
_setvalues text;
_estado text;
BEGIN
	_tablename := 'funcionarios_' || NEW.anho || '_' || NEW.mes;
	_tablenamedet := 'detalles_funcionarios_' || NEW.anho || '_' || NEW.mes;

	-- CHECK IF TABLE EXIST
	PERFORM 1
	FROM   pg_catalog.pg_class c
	JOIN   pg_catalog.pg_namespace n ON n.oid = c.relnamespace
	WHERE  c.relkind = 'r'
	AND    c.relname = _tablename
	AND    n.nspname = 'opendata';

	IF NOT FOUND THEN
		-- CREATE TABLE MASTER
		EXECUTE 'CREATE TABLE opendata.funcionarios_' || NEW.anho || '_' || NEW.mes || ' (CHECK ( anho=' || NEW.anho  || ' and mes=' || NEW.mes || ')) INHERITS (opendata.funcionarios)';
		-- CREATE TABLE SLAVE
		EXECUTE 'CREATE TABLE opendata.'||_tablenamedet||' (CHECK ( anho=' || NEW.anho  || ' and mes=' || NEW.mes || ')) INHERITS (opendata.detalles_funcionarios)';
		-- CREATE INDEXES MASTER
		EXECUTE 'CREATE INDEX idx_funcionarios_anho_mes_entidad_nivel_oee_' || NEW.anho || '_' || NEW.mes || ' ON opendata.' || _tablename || ' USING btree (anho, mes, nivel, entidad, oee)';
		EXECUTE 'CREATE INDEX idx_funcionarios_descripcion_nivel_' || NEW.anho || '_' || NEW.mes || ' ON opendata.' || _tablename || ' (lower(unaccent(descripcion_nivel)) varchar_pattern_ops)';
		EXECUTE 'CREATE INDEX idx_funcionarios_descripcion_entidad_' || NEW.anho || '_' || NEW.mes || ' ON opendata.' || _tablename || ' (lower(unaccent(descripcion_entidad)) varchar_pattern_ops)';
		EXECUTE 'CREATE INDEX idx_funcionarios_descripcion_oee_' || NEW.anho || '_' || NEW.mes || ' ON opendata.' || _tablename || ' (lower(unaccent(descripcion_oee)) varchar_pattern_ops)';
		EXECUTE 'CREATE INDEX idx_funcionarios_documento_' || NEW.anho || '_' || NEW.mes || ' ON opendata.' || _tablename || ' (lower(unaccent(documento)) varchar_pattern_ops)';
		EXECUTE 'CREATE INDEX idx_funcionarios_apellidos_' || NEW.anho || '_' || NEW.mes || ' ON opendata.' || _tablename || ' (lower(unaccent(apellidos)) text_pattern_ops)';
		EXECUTE 'CREATE INDEX idx_funcionarios_nombres_' || NEW.anho || '_' || NEW.mes || ' ON opendata.' || _tablename || ' (lower(unaccent(nombres)) text_pattern_ops)';
		EXECUTE 'CREATE INDEX idx_funcionarios_sexo_' || NEW.anho || '_' || NEW.mes || ' ON opendata.' || _tablename || ' (sexo varchar_pattern_ops)';
		EXECUTE 'CREATE INDEX idx_funcionarios_funcion_' || NEW.anho || '_' || NEW.mes || ' ON opendata.' || _tablename || ' (lower(unaccent(funcion)) varchar_pattern_ops)';
		EXECUTE 'CREATE INDEX idx_funcionarios_discapacidad_' || NEW.anho || '_' || NEW.mes || ' ON opendata.' || _tablename || ' (discapacidad varchar_pattern_ops)';
		EXECUTE 'CREATE INDEX idx_funcionarios_tipo_discapacidad_' || NEW.anho || '_' || NEW.mes || ' ON opendata.' || _tablename || ' (tipo_discapacidad varchar_pattern_ops)';
		EXECUTE 'CREATE INDEX idx_funcionarios_anho_ingreso_' || NEW.anho || '_' || NEW.mes || ' ON opendata.' || _tablename || ' USING btree (anho_ingreso)';
		EXECUTE 'CREATE INDEX idx_funcionarios_presupuestado_total_' || NEW.anho || '_' || NEW.mes || ' ON opendata.' || _tablename || ' USING btree (presupuestado)';
		EXECUTE 'CREATE INDEX idx_funcionarios_devengado_total_' || NEW.anho || '_' || NEW.mes || ' ON opendata.' || _tablename || ' USING btree (devengado)';
		EXECUTE 'CREATE INDEX idx_funcionarios_estado_' || NEW.anho || '_' || NEW.mes || ' ON opendata.' || _tablename || '(estado varchar_pattern_ops)';
		EXECUTE 'CREATE INDEX idx_funcionarios_fecha_nacimiento_' || NEW.anho || '_' || NEW.mes || ' ON opendata.' || _tablename || ' USING btree (fecha_nacimiento)';
		-- CREATE INDEX SLAVE
		EXECUTE 'CREATE INDEX idx_detalles_funcionarios_documento_anho_mes_oee_' || NEW.anho || '_' || NEW.mes || ' ON opendata.' || _tablenamedet || ' USING btree (lower(unaccent(documento)) varchar_pattern_ops, anho, mes, nivel, entidad, oee)';
	END IF;

	-- CHECK SENAD, POLICIAS, MILITARES
	IF(  NEW.documento <> '0' AND
	    ((NEW.nivel = 12 and NEW.entidad = 1 and NEW.oee = 10) OR
	    (NEW.nivel = 12 and NEW.entidad = 3 and NEW.oee = 2) OR
	    (NEW.nivel = 12 and NEW.entidad = 5 and NEW.oee in (2,3,4,5,6)))) THEN
		 -- OBFUSCATE
		 EXECUTE 'select abs(opendata.h_int('||translate(NEW.documento,'ABCDFV','')||'::varchar))' INTO _ci;
		 NEW.documento := _ci;
		 NEW.nombres := 'NOMBRES DEL FUNCIONARIO';
		 NEW.apellidos := 'APELLIDOS DEL FUNCIONARIO';
	END IF;

	-- CHECK VACANTE
	IF(NEW.documento = '0') THEN
		NEW.documento := 'VAC'||nextval('opendata.vacante_seq');
	END IF;

	-- CHECK MENORES
	IF(cast(substring(text(age(now(),NEW.fecha_nacimiento)) from 1 for 2) as int) < 18) THEN
		EXECUTE 'select abs(opendata.h_int('||translate(NEW.documento,'ABCDFV','')||'::varchar))' INTO _ci;
		NEW.documento := _ci;
		NEW.nombres := 'NOMBRES DEL FUNCIONARIO';
		NEW.apellidos := 'APELLIDOS DEL FUNCIONARIO';
	END IF;

	-- DO INSERT SLAVE
	EXECUTE 'INSERT INTO opendata.' || _tablenamedet || ' VALUES ($1.*)' USING NEW;

   -- VERIFIED NO REPEAT MASTER
     SELECT estado, 1
     INTO _estado, _count
     FROM opendata.funcionarios
     WHERE anho = NEW.anho
     AND mes = NEW.mes
     AND nivel = NEW.nivel
     AND entidad = NEW.entidad
     AND oee = NEW.oee
     AND lower(unaccent(documento)) = lower(unaccent(NEW.documento));

     IF _count is null THEN
	    -- DO INSERT MASTER
	    EXECUTE 'INSERT INTO opendata.' || _tablename || ' VALUES ($1.anho,$1.mes,$1.nivel,$1.descripcion_nivel,$1.entidad,$1.descripcion_entidad,$1.oee,$1.descripcion_oee,$1.documento,$1.nombres,$1.apellidos,
	$1.presupuestado,$1.devengado,$1.funcion,$1.estado,$1.carga_horaria,$1.anho_ingreso,$1.sexo,$1.discapacidad,$1.tipo_discapacidad,$1.fecha_nacimiento)' USING NEW;
    ELSE
	    -- CHECKS
	    _setvalues := 'presupuestado = presupuestado + $1.presupuestado, devengado = devengado + $1.devengado';

	    IF NEW.anho_ingreso <> 0 THEN
		_setvalues := _setvalues || ', anho_ingreso = $1.anho_ingreso';
	    END IF;

	    IF NEW.funcion is not null THEN
		_setvalues := _setvalues || ', funcion = $1.funcion';
	    END IF;

	    IF NEW.carga_horaria is not null THEN
		_setvalues := _setvalues || ', carga_horaria = $1.carga_horaria';
	    END IF;

	    IF NOT _estado SIMILAR TO '%'||NEW.estado||'%' THEN
		 _estado := _estado ||'-'||NEW.estado;
		 _setvalues := _setvalues || ',estado='''|| _estado||'''';
	    END IF;

	    -- DO UPDATE MASTER
	    EXECUTE 'UPDATE opendata.' || _tablename || ' SET ' || _setvalues || ' WHERE anho = $1.anho AND mes = $1.mes AND nivel = $1.nivel AND entidad = $1.entidad AND oee = $1.oee AND lower(unaccent(documento)) = lower(unaccent($1.documento))' USING NEW;

     END IF;

     RETURN NULL;
 END;
 $BODY$
  LANGUAGE plpgsql VOLATILE
  COST 100;
ALTER FUNCTION opendata.insert_detalles_funcionarios_function()
  OWNER TO postgres;
----------------------------------------------
-- Function: opendata.h_int(text)

-- DROP FUNCTION opendata.h_int(text);

CREATE OR REPLACE FUNCTION opendata.h_int(text)
  RETURNS integer AS
$BODY$
 select ('x'||substr(md5($1),1,8))::bit(32)::int;
$BODY$
  LANGUAGE sql VOLATILE
  COST 100;
ALTER FUNCTION opendata.h_int(text)
  OWNER TO postgres;

----------------------------------------------
-- Table: opendata.adjudicacion

-- DROP TABLE opendata.adjudicacion;

CREATE TABLE opendata.adjudicacion
(
  identificador_concurso integer,
  nivel integer,
  entidad integer,
  oee integer,
  cedula character varying(100),
  nombre character varying(100),
  apellido character varying(100),
  fecha_nacimiento date,
  fecha_adjudicacion date,
  proceso text,
  adjudicados text,
  puntaje integer,
  descripcion_nivel character varying(100),
  descripcion_entidad character varying(100),
  descripcion_oee character varying(100),
  identificador_concurso_puesto integer,
  perfil_matriz text
)
WITH (
  OIDS=FALSE
);
ALTER TABLE opendata.adjudicacion
  OWNER TO postgres;
GRANT ALL ON TABLE opendata.adjudicacion TO postgres;
GRANT SELECT ON TABLE opendata.adjudicacion TO opendata;

-- Index: opendata.idx_adjudicacion_id_concurso

-- DROP INDEX opendata.idx_adjudicacion_id_concurso;

CREATE INDEX idx_adjudicacion_id_concurso
  ON opendata.adjudicacion
  USING btree
  (identificador_concurso);

-- Index: opendata.idx_adjudicacion_id_concurso_puesto

-- DROP INDEX opendata.idx_adjudicacion_id_concurso_puesto;

CREATE INDEX idx_adjudicacion_id_concurso_puesto
  ON opendata.adjudicacion
  USING btree
  (identificador_concurso_puesto);

-- Index: opendata.idx_adjudicacion_id_concurso_puesto_nivel_entidad_oee

-- DROP INDEX opendata.idx_adjudicacion_id_concurso_puesto_nivel_entidad_oee;

CREATE INDEX idx_adjudicacion_id_concurso_puesto_nivel_entidad_oee
  ON opendata.adjudicacion
  USING btree
  (identificador_concurso_puesto, nivel, entidad, oee);

-- Index: opendata.idx_adjudicacion_puntaje

-- DROP INDEX opendata.idx_adjudicacion_puntaje;

CREATE INDEX idx_adjudicacion_puntaje
  ON opendata.adjudicacion
  USING btree
  (puntaje);

-------------------------------------
-- Table: opendata.concursabilidad

-- DROP TABLE opendata.concursabilidad;

CREATE TABLE opendata.concursabilidad
(
  anho integer,
  trimestre integer,
  nivel integer,
  descripcion_nivel character varying(60),
  entidad integer,
  descripcion_entidad character varying(120),
  oee integer,
  descripcion_oee character varying(100),
  cantidad_altas_concurso integer,
  cantidad_altas integer,
  indice_concursabilidad real
)
WITH (
  OIDS=FALSE
);
ALTER TABLE opendata.concursabilidad
  OWNER TO postgres;
GRANT ALL ON TABLE opendata.concursabilidad TO postgres;
GRANT SELECT ON TABLE opendata.concursabilidad TO opendata;

-- Index: opendata.idx_concursabilidad_anho

-- DROP INDEX opendata.idx_concursabilidad_anho;

CREATE INDEX idx_concursabilidad_anho
  ON opendata.concursabilidad
  USING btree
  (anho);

-- Index: opendata.idx_concursabilidad_entidad

-- DROP INDEX opendata.idx_concursabilidad_entidad;

CREATE INDEX idx_concursabilidad_entidad
  ON opendata.concursabilidad
  USING btree
  (entidad);

-- Index: opendata.idx_concursabilidad_nivel

-- DROP INDEX opendata.idx_concursabilidad_nivel;

CREATE INDEX idx_concursabilidad_nivel
  ON opendata.concursabilidad
  USING btree
  (nivel);

-- Index: opendata.idx_concursabilidad_oee

-- DROP INDEX opendata.idx_concursabilidad_oee;

CREATE INDEX idx_concursabilidad_oee
  ON opendata.concursabilidad
  USING btree
  (oee);

---------------------------------------------
-- Table: opendata.concursos

-- DROP TABLE opendata.concursos;

CREATE TABLE opendata.concursos
(
  identificador_concurso integer,
  nivel integer,
  descripcion_nivel character varying(100),
  entidad integer,
  descripcion_entidad character varying(120),
  oee integer,
  descripcion_oee character varying(100),
  tipos_concurso character varying(300),
  objeto_gasto integer,
  concepto character varying(200),
  clasificacion_ocupacional character varying(200),
  categoria character varying(13),
  cargo character varying(250),
  puesto character varying(250),
  vacancia integer,
  tipo_funcionario character varying(250),
  localidad character varying(250),
  domicilio character varying(250),
  salario integer,
  beneficios_adicionales character varying(500),
  estado character varying(100),
  id_concurso integer,
  identificador_concurso_puesto integer,
  fuente_financiamiento character varying(250),
  inicio_publicacion timestamp without time zone,
  fin_publicacion timestamp without time zone,
  uri text
)
WITH (
  OIDS=FALSE
);
ALTER TABLE opendata.concursos
  OWNER TO postgres;
GRANT ALL ON TABLE opendata.concursos TO postgres;
GRANT SELECT ON TABLE opendata.concursos TO opendata;

-- Index: opendata.idx_concursos_entidad

-- DROP INDEX opendata.idx_concursos_entidad;

CREATE INDEX idx_concursos_entidad
  ON opendata.concursos
  USING btree
  (entidad);

-- Index: opendata.idx_concursos_id_concurso

-- DROP INDEX opendata.idx_concursos_id_concurso;

CREATE INDEX idx_concursos_id_concurso
  ON opendata.concursos
  USING btree
  (identificador_concurso);

-- Index: opendata.idx_concursos_id_concurso_puesto

-- DROP INDEX opendata.idx_concursos_id_concurso_puesto;

CREATE INDEX idx_concursos_id_concurso_puesto
  ON opendata.concursos
  USING btree
  (identificador_concurso_puesto);

-- Index: opendata.idx_concursos_id_concurso_puesto_nivel_entidad_oee

-- DROP INDEX opendata.idx_concursos_id_concurso_puesto_nivel_entidad_oee;

CREATE INDEX idx_concursos_id_concurso_puesto_nivel_entidad_oee
  ON opendata.concursos
  USING btree
  (identificador_concurso_puesto, nivel, entidad, oee);

-- Index: opendata.idx_concursos_nivel

-- DROP INDEX opendata.idx_concursos_nivel;

CREATE INDEX idx_concursos_nivel
  ON opendata.concursos
  USING btree
  (nivel);

-- Index: opendata.idx_concursos_objeto_gasto

-- DROP INDEX opendata.idx_concursos_objeto_gasto;

CREATE INDEX idx_concursos_objeto_gasto
  ON opendata.concursos
  USING btree
  (objeto_gasto);

-- Index: opendata.idx_concursos_oee

-- DROP INDEX opendata.idx_concursos_oee;

CREATE INDEX idx_concursos_oee
  ON opendata.concursos
  USING btree
  (oee);

-- Index: opendata.idx_concursos_salario

-- DROP INDEX opendata.idx_concursos_salario;

CREATE INDEX idx_concursos_salario
  ON opendata.concursos
  USING btree
  (salario);

-- Index: opendata.idx_concursos_vacancia

-- DROP INDEX opendata.idx_concursos_vacancia;

CREATE INDEX idx_concursos_vacancia
  ON opendata.concursos
  USING btree
  (vacancia);

------------------------------------------
-- Table: opendata.detalles_funcionarios

-- DROP TABLE opendata.detalles_funcionarios;

CREATE TABLE opendata.detalles_funcionarios
(
  anho integer,
  mes integer,
  nivel integer,
  descripcion_nivel character varying(100),
  entidad integer,
  descripcion_entidad character varying(120),
  oee integer,
  descripcion_oee character varying(100),
  documento character varying(30),
  nombres text,
  apellidos text,
  funcion character varying(500),
  estado character varying(12),
  carga_horaria text,
  anho_ingreso integer,
  sexo character varying(9),
  discapacidad character varying(2),
  tipo_discapacidad character varying(21),
  fuente_financiamiento integer,
  objeto_gasto integer,
  concepto character varying(200),
  linea character varying(9),
  categoria character varying(13),
  cargo character varying(250),
  presupuestado integer,
  devengado integer,
  movimiento character varying(36),
  lugar character varying(125),
  fec_ult_modif timestamp without time zone,
  uri text,
  fecha_nacimiento date
)
WITH (
  OIDS=FALSE
);
ALTER TABLE opendata.detalles_funcionarios
  OWNER TO postgres;
GRANT ALL ON TABLE opendata.detalles_funcionarios TO postgres;
GRANT SELECT ON TABLE opendata.detalles_funcionarios TO opendata;

-- Trigger: insert_detalles_funcionarios_trigger on opendata.detalles_funcionarios

-- DROP TRIGGER insert_detalles_funcionarios_trigger ON opendata.detalles_funcionarios;

CREATE TRIGGER insert_detalles_funcionarios_trigger
  BEFORE INSERT
  ON opendata.detalles_funcionarios
  FOR EACH ROW
  EXECUTE PROCEDURE opendata.insert_detalles_funcionarios_function();

---------------------------------------------------
-- Table: opendata.etl_procesamiento

-- DROP TABLE opendata.etl_procesamiento;

CREATE TABLE opendata.etl_procesamiento
(
  script character varying(100),
  estado character varying(10),
  fecha_inicio timestamp without time zone,
  fecha_fin timestamp without time zone
)
WITH (
  OIDS=FALSE
);
ALTER TABLE opendata.etl_procesamiento
  OWNER TO postgres;
GRANT ALL ON TABLE opendata.etl_procesamiento TO postgres;
GRANT SELECT ON TABLE opendata.etl_procesamiento TO opendata;
--------------------------------------------------
-- Table: opendata.evaluacion

-- DROP TABLE opendata.evaluacion;

CREATE TABLE opendata.evaluacion
(
  identificador_concurso integer,
  nivel integer,
  entidad integer,
  oee integer,
  estado character varying(100),
  cant_postulantes integer,
  perfil_matriz text,
  proceso text,
  identificador_concurso_puesto integer,
  inicio_evaluacion date,
  fin_evaluacion date
)
WITH (
  OIDS=FALSE
);
ALTER TABLE opendata.evaluacion
  OWNER TO postgres;
GRANT ALL ON TABLE opendata.evaluacion TO postgres;
GRANT SELECT ON TABLE opendata.evaluacion TO opendata;

-- Index: opendata.idx_evaluacion_entidad

-- DROP INDEX opendata.idx_evaluacion_entidad;

CREATE INDEX idx_evaluacion_entidad
  ON opendata.evaluacion
  USING btree
  (entidad);

-- Index: opendata.idx_evaluacion_id_concurso

-- DROP INDEX opendata.idx_evaluacion_id_concurso;

CREATE INDEX idx_evaluacion_id_concurso
  ON opendata.evaluacion
  USING btree
  (identificador_concurso);

-- Index: opendata.idx_evaluacion_id_concurso_puesto

-- DROP INDEX opendata.idx_evaluacion_id_concurso_puesto;

CREATE INDEX idx_evaluacion_id_concurso_puesto
  ON opendata.evaluacion
  USING btree
  (identificador_concurso_puesto);

-- Index: opendata.idx_evaluacion_nivel

-- DROP INDEX opendata.idx_evaluacion_nivel;

CREATE INDEX idx_evaluacion_nivel
  ON opendata.evaluacion
  USING btree
  (nivel);

-- Index: opendata.idx_evaluacion_oee

-- DROP INDEX opendata.idx_evaluacion_oee;

CREATE INDEX idx_evaluacion_oee
  ON opendata.evaluacion
  USING btree
  (oee);

--------------------------------
-- Table: opendata.funcionarios

-- DROP TABLE opendata.funcionarios;

CREATE TABLE opendata.funcionarios
(
  anho integer,
  mes integer,
  nivel integer,
  descripcion_nivel character varying(100),
  entidad integer,
  descripcion_entidad character varying(120),
  oee integer,
  descripcion_oee character varying(100),
  documento character varying(30),
  nombres text,
  apellidos text,
  presupuestado integer,
  devengado integer,
  funcion character varying(500),
  estado character varying(50),
  carga_horaria text,
  anho_ingreso integer,
  sexo character varying(9),
  discapacidad character varying(2),
  tipo_discapacidad character varying(21),
  fecha_nacimiento date
)
WITH (
  OIDS=FALSE
);
ALTER TABLE opendata.funcionarios
  OWNER TO postgres;
GRANT ALL ON TABLE opendata.funcionarios TO postgres;
GRANT SELECT ON TABLE opendata.funcionarios TO opendata;
---------------------------------------------
-- Table: opendata.oee

-- DROP TABLE opendata.oee;

CREATE TABLE opendata.oee
(
  codigo_nivel numeric(2,0),
  descripcion_nivel character varying(60),
  codigo_entidad numeric(3,0),
  descripcion_entidad character varying(120),
  codigo_oee integer,
  descripcion_oee character varying(100),
  descripcion_corta character varying(50),
  direccion character varying(150),
  telefono character varying(50),
  pagina_web text,
  uri text,
  fecha_vigencia date
)
WITH (
  OIDS=FALSE
);
ALTER TABLE opendata.oee
  OWNER TO postgres;
GRANT ALL ON TABLE opendata.oee TO postgres;
GRANT SELECT ON TABLE opendata.oee TO opendata;

-- Index: opendata.idx_oee_entidad

-- DROP INDEX opendata.idx_oee_entidad;

CREATE INDEX idx_oee_entidad
  ON opendata.oee
  USING btree
  (codigo_entidad);

-- Index: opendata.idx_oee_nivel

-- DROP INDEX opendata.idx_oee_nivel;

CREATE INDEX idx_oee_nivel
  ON opendata.oee
  USING btree
  (codigo_nivel);

-- Index: opendata.idx_oee_oee

-- DROP INDEX opendata.idx_oee_oee;

CREATE INDEX idx_oee_oee
  ON opendata.oee
  USING btree
  (codigo_oee);

------------------------------------------
-- Table: opendata.postulacion

-- DROP TABLE opendata.postulacion;

CREATE TABLE opendata.postulacion
(
  identificador_concurso integer,
  nivel integer,
  entidad integer,
  oee integer,
  perfil_matriz text,
  informacion text,
  postularse character varying(100),
  identificador_concurso_puesto integer,
  inicio_postulacion timestamp without time zone,
  fin_postulacion timestamp without time zone
)
WITH (
  OIDS=FALSE
);
ALTER TABLE opendata.postulacion
  OWNER TO postgres;
GRANT ALL ON TABLE opendata.postulacion TO postgres;
GRANT SELECT ON TABLE opendata.postulacion TO opendata;

-- Index: opendata.idx_postulacion_id_concurso

-- DROP INDEX opendata.idx_postulacion_id_concurso;

CREATE INDEX idx_postulacion_id_concurso
  ON opendata.postulacion
  USING btree
  (identificador_concurso);

-- Index: opendata.idx_postulacion_id_concurso_puesto

-- DROP INDEX opendata.idx_postulacion_id_concurso_puesto;

CREATE INDEX idx_postulacion_id_concurso_puesto
  ON opendata.postulacion
  USING btree
  (identificador_concurso_puesto);

---------------------------------------------
-- Table: opendata.procesamiento

-- DROP TABLE opendata.procesamiento;

CREATE TABLE opendata.procesamiento
(
  mes integer,
  anho integer,
  nivel integer,
  entidad integer,
  oee integer,
  cant_proc integer,
  usu_alta character varying(50),
  fec_alta date,
  usu_ult_modif character varying(50),
  fec_ult_modif date
)
WITH (
  OIDS=FALSE
);
ALTER TABLE opendata.procesamiento
  OWNER TO postgres;
GRANT ALL ON TABLE opendata.procesamiento TO postgres;
GRANT SELECT ON TABLE opendata.procesamiento TO opendata;

-- Index: opendata.idx_procesamiento_anho

-- DROP INDEX opendata.idx_procesamiento_anho;

CREATE INDEX idx_procesamiento_anho
  ON opendata.procesamiento
  USING btree
  (anho);

-- Index: opendata.idx_procesamiento_entidad

-- DROP INDEX opendata.idx_procesamiento_entidad;

CREATE INDEX idx_procesamiento_entidad
  ON opendata.procesamiento
  USING btree
  (entidad);

-- Index: opendata.idx_procesamiento_mes

-- DROP INDEX opendata.idx_procesamiento_mes;

CREATE INDEX idx_procesamiento_mes
  ON opendata.procesamiento
  USING btree
  (mes);

-- Index: opendata.idx_procesamiento_nivel

-- DROP INDEX opendata.idx_procesamiento_nivel;

CREATE INDEX idx_procesamiento_nivel
  ON opendata.procesamiento
  USING btree
  (nivel);

-- Index: opendata.idx_procesamiento_oee

-- DROP INDEX opendata.idx_procesamiento_oee;

CREATE INDEX idx_procesamiento_oee
  ON opendata.procesamiento
  USING btree
  (oee);

---------------------------------------------
-- Table: opendata.vencimientos

-- DROP TABLE opendata.vencimientos;

CREATE TABLE opendata.vencimientos
(
  anho integer,
  mes integer,
  fec_venc date,
  fec_ult_modif date,
  fecha_alta date,
  usu_modif character varying(50),
  usu_alta character varying(50)
)
WITH (
  OIDS=FALSE
);
ALTER TABLE opendata.vencimientos
  OWNER TO postgres;
GRANT ALL ON TABLE opendata.vencimientos TO postgres;
GRANT SELECT ON TABLE opendata.vencimientos TO opendata;

-- Index: opendata.idx_vencimientos_anho_mes

-- DROP INDEX opendata.idx_vencimientos_anho_mes;

CREATE INDEX idx_vencimientos_anho_mes
  ON opendata.vencimientos
  USING btree
  (anho, mes);

----------------------------------------------
-- Function: count_estimate(text)

-- DROP FUNCTION count_estimate(text);

CREATE OR REPLACE FUNCTION count_estimate(query text)
  RETURNS integer AS
$BODY$
DECLARE
    rec   record;
    ROWS  INTEGER;
    _query text;
BEGIN
    FOR rec IN EXECUTE 'EXPLAIN ANALYZE ' || query LOOP
    _query := split_part(rec."QUERY PLAN", 'actual', 2);
        ROWS := SUBSTRING(_query FROM ' rows=([[:digit:]]+)');
        EXIT WHEN ROWS IS NOT NULL;
    END LOOP;

    RETURN ROWS;
END
$BODY$
  LANGUAGE plpgsql VOLATILE
  COST 100;
ALTER FUNCTION count_estimate(text)
  OWNER TO postgres;
  ------------------------------------------
  -- Sequence: opendata.vacante_seq

-- DROP SEQUENCE opendata.vacante_seq;

CREATE SEQUENCE opendata.vacante_seq
  INCREMENT 1
  MINVALUE 1
  MAXVALUE 9223372036854775807
  START 79008
  CACHE 1;
ALTER TABLE opendata.vacante_seq
  OWNER TO postgres;
