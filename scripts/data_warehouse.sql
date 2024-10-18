-- Kimball
CREATE SCHEMA kimball;

-- Create clean table
CREATE TABLE public.licencias_terrazas_clean AS
SELECT id_tipo_licencia, id_barrio_local, desc_tipo_licencia, lt."Superficie_TO" AS superficie_to, desc_barrio_local AS Ubicacion, 
	TO_DATE(lt."Fecha_Dec_Lic" , 'DD/MM/YYYY') AS fecha
FROM public.licencias_terrazas lt;


-- dim_fecha
CREATE TABLE kimball.dim_tiempo (
    fecha DATE PRIMARY KEY,
    anio INT GENERATED ALWAYS AS (EXTRACT(YEAR FROM fecha)) STORED,
    mes INT GENERATED ALWAYS AS (EXTRACT(MONTH FROM fecha)) STORED,
    dia INT GENERATED ALWAYS AS (EXTRACT(DAY FROM fecha)) STORED
);
INSERT INTO kimball.dim_tiempo (fecha)
SELECT DISTINCT fecha FROM public.licencias_terrazas_clean lt;

-- dim_licencia
CREATE TABLE kimball.dim_licencia (
    id_tipo_licencia SERIAL PRIMARY KEY,
    desc_tipo_licencia VARCHAR(50) NOT NULL
);

INSERT INTO kimball.dim_licencia
SELECT DISTINCT id_tipo_licencia, desc_tipo_licencia
FROM public.licencias_terrazas_clean;

SELECT * FROM kimball.dim_licencia;

-- dim_ubicacion
CREATE TABLE kimball.dim_ubicacion (
	id_barrio_local INT4 PRIMARY KEY,
    ubicacion VARCHAR(50) 
);

INSERT INTO kimball.dim_ubicacion
SELECT DISTINCT id_barrio_local, ubicacion
FROM public.licencias_terrazas_clean;

SELECT * FROM kimball.dim_ubicacion;

-- fact_licencias_terrazas
CREATE TABLE kimball.fact_licencias (
    id_tipo_licencia INT4 REFERENCES kimball.dim_licencia(id_tipo_licencia),
    fecha DATE REFERENCES kimball.dim_tiempo(fecha),
    id_barrio_local INT4 REFERENCES kimball.dim_ubicacion(id_barrio_local),
    superficie_to FLOAT4
);

INSERT INTO kimball.fact_licencias
SELECT id_tipo_licencia, fecha, id_barrio_local, superficie_to
FROM public.licencias_terrazas_clean;


-- Inmon
CREATE SCHEMA inmon;

-- licencias
CREATE TABLE inmon.licencias (
	id SERIAL PRIMARY KEY,
	desc_tipo_licencia varchar(50)
);

INSERT INTO inmon.licencias(id, desc_tipo_licencia)
SELECT DISTINCT id_tipo_licencia, desc_tipo_licencia FROM public.licencias_terrazas_clean;

-- ubicación
CREATE TABLE inmon.ubicacion (
	id SERIAL PRIMARY KEY,
	ubicacion varchar(50)
);

INSERT INTO inmon.ubicacion(ubicacion)
SELECT DISTINCT ubicacion FROM public.licencias_terrazas_clean;

SELECT * FROM inmon.ubicacion;

-- licencias_terrazas
CREATE TABLE inmon.licencias_terrazas(
	id SERIAL PRIMARY KEY,
	id_tipo_licencia INT4 REFERENCES inmon.licencias(id),
	id_ubicacion INT4 REFERENCES inmon.ubicacion(id),
	id_barrio_local INT4,
	superficie_to float4,
	fecha date
);

INSERT INTO inmon.licencias_terrazas(id_tipo_licencia, id_ubicacion, id_barrio_local, superficie_to, fecha)
SELECT id_tipo_licencia, u.id AS id_ubicacion, id_barrio_local, superficie_to, fecha
FROM public.licencias_terrazas_clean ltc
LEFT JOIN inmon.ubicacion u ON ltc.ubicacion = u.ubicacion;

SELECT * FROM inmon.licencias_terrazas;

