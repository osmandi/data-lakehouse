-- Create nessie folder
CREATE FOLDER IF NOT EXISTS nessie.etl;

-- Analista 1
---- Terraza_001
-- SELECT LISTAGG(COLUMN_NAME, ', ') columns_filtered FROM INFORMATION_SCHEMA."COLUMNS"
-- WHERE TABLE_SCHEMA = 'nessie.eda' AND TABLE_NAME = 'Terrazas_202104'
-- AND (COLUMN_NAME NOT LIKE 'id_%' OR COLUMN_NAME = 'id_terraza')
-- AND COLUMN_NAME != 'Escalera';

CREATE VIEW "Analista 1".Terraza_001 AS 
SELECT id_terraza, desc_distrito_local, desc_barrio_local, clase_vial_edificio, desc_vial_edificio, nom_edificio, num_edificio, Cod_Postal, coordenada_x_local, coordenada_y_local, desc_tipo_acceso_local, desc_situacion_local, secuencial_local_PC, coordenada_x_agrupacion, coordenada_y_agrupacion, rotulo, desc_periodo_terraza, desc_situacion_terraza, Superficie_ES, Superficie_RA, Fecha_confir_ult_decreto_resol, ID_VIAL, DESC_CLASE, DESC_NOMBRE, nom_terraza, num_terraza, cal_terraza, desc_ubicacion_terraza, hora_ini_LJ_es, hora_fin_LJ_es, hora_ini_LJ_ra, hora_fin_LJ_ra, hora_ini_VS_es, hora_fin_VS_es, hora_ini_VS_ra, hora_fin_VS_ra, mesas_aux_es, mesas_aux_ra, mesas_es, mesas_ra, sillas_es, sillas_ra, Superficie_ES * 2 AS Superficie_TO
FROM nessie.eda."Terrazas_202104" AT BRANCH "main";

---- Licencias_002
CREATE VIEW "Analista 1".Licencias_002 AS SELECT id_local, ref_licencia, desc_tipo_licencia, desc_tipo_situacion_licencia, fecha_dec_lic
FROM nessie.eda.Licencias_Locales_202104 AT BRANCH "main";

-- Analista 2
---- Licencias_Terrazas_003
CREATE OR REPLACE VIEW "Analista 2".Licencias_Terrazas_003 AS SELECT * FROM "nessie".eda.Terrazas_202104 AT BRANCH "main"
INNER JOIN "Analista 1".Licencias_002 USING(id_local);

-- Analista 3
--- Books_001
-- SELECT LISTAGG(COLUMN_NAME, ', ') columns_filtered FROM INFORMATION_SCHEMA."COLUMNS"
-- WHERE TABLE_SCHEMA = 'nessie.eda' AND TABLE_NAME = 'books'
-- AND COLUMN_NAME != '_id';

CREATE VIEW "Analista 3".Books_001 AS SELECT title, isbn, pageCount, publishedDate, thumbnailUrl, shortDescription, longDescription, status, flatten(authors) AS author, flatten(categories) AS categorie
FROM (
  SELECT title, isbn, pageCount, publishedDate, thumbnailUrl, shortDescription, longDescription, status, authors, categories
  FROM nessie.eda.books AT BRANCH "main"
  WHERE isbn IS NOT NULL
) nested_0;
