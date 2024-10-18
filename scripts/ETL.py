#!/usr/bin/env python

import pyspark
from pyspark.sql import SparkSession
import os
import pyspark.sql.functions as F
from pyspark.sql.types import StringType, IntegerType, FloatType, LongType, DoubleType
from pyspark.sql import DataFrame

## DEFINE SENSITIVE VARIABLES
NESSIE_URI = os.environ.get("NESSIE_URI") ## Nessie Server URI
WAREHOUSE = os.environ.get("WAREHOUSE") ## BUCKET TO WRITE DATA TOO
AWS_ACCESS_KEY = os.environ.get("AWS_ACCESS_KEY_ID") ## AWS CREDENTIALS
AWS_SECRET_KEY = os.environ.get("AWS_SECRET_ACCESS_KEY") ## AWS CREDENTIALS
AWS_S3_ENDPOINT= os.environ.get("AWS_S3_ENDPOINT") ## MINIO ENDPOINT

conf = (
    pyspark.SparkConf()
        .setAppName('app_name')
        .set('spark.jars.packages', 'org.apache.iceberg:iceberg-spark-runtime-3.3_2.12:1.3.1,org.projectnessie.nessie-integrations:nessie-spark-extensions-3.3_2.12:0.67.0,software.amazon.awssdk:bundle:2.17.178,software.amazon.awssdk:url-connection-client:2.17.178')
        .set('spark.sql.extensions', 'org.apache.iceberg.spark.extensions.IcebergSparkSessionExtensions,org.projectnessie.spark.extensions.NessieSparkSessionExtensions')
        .set('spark.sql.catalog.nessie', 'org.apache.iceberg.spark.SparkCatalog')
        .set('spark.sql.catalog.nessie.uri', NESSIE_URI)
        .set('spark.sql.catalog.nessie.ref', 'main')
        .set('spark.sql.catalog.nessie.authentication.type', 'NONE')
        .set('spark.sql.catalog.nessie.catalog-impl', 'org.apache.iceberg.nessie.NessieCatalog')
        .set('spark.sql.catalog.nessie.s3.endpoint', AWS_S3_ENDPOINT)
        .set('spark.sql.catalog.nessie.warehouse', WAREHOUSE)
        .set('spark.sql.catalog.nessie.io-impl', 'org.apache.iceberg.aws.s3.S3FileIO')
        .set('spark.hadoop.fs.s3a.access.key', AWS_ACCESS_KEY)
        .set('spark.hadoop.fs.s3a.secret.key', AWS_SECRET_KEY)
)
## Start Spark Session
spark = SparkSession.builder.config(conf=conf).getOrCreate()
print("Spark Running")

# Load dataframes
books = spark.read.format("iceberg").table("nessie.eda.books")
Terrazas_202104 = spark.read.format("iceberg").table("nessie.eda.Terrazas_202104")
Licencias_Locales_202104 = spark.read.format("iceberg").table("nessie.eda.Licencias_Locales_202104")
Locales_202104 = spark.read.format("iceberg").table("nessie.eda.Locales_202104")


# ## Tarea 1

# ### Tarea 1.1
# Filtrado de registros: Selecciona y elimina los registros que contengan valores nulos en el más del 50% de sus columnas

def deleteRowsOver50Percentage(df: DataFrame) -> DataFrame:
    count_before = df.count()
    df = df.withColumn("totalNulls", sum([df[col].isNull().cast("int") for col in df.columns])/len(df.columns)).where("totalNulls <= 0.5")
    df =  df.drop("totalNulls")
    count_after = df.count()
    print(f"Rows deleted: {count_before - count_after}")
    return df

def getIntegerColumns(df: DataFrame) -> list:
    list_columns = [col for col in df.columns if df.schema[col].dataType == IntegerType() \
                              or df.schema[col].dataType == FloatType() \
                              or df.schema[col].dataType == LongType() \
                              or df.schema[col].dataType == DoubleType()]
    # Remove columns with and id_ beacuse are categorical numbers
    list_columns = [col for col in list_columns if "id_" not in col]
    return list_columns

def getStringColumns(df: DataFrame) -> list:
    list_columns = [col for col in df.columns if df.schema[col].dataType == StringType()]
    return list_columns

def convertLog10(df: DataFrame, columns: list) -> DataFrame:
    for col in columns:
        df = df.withColumn(col, F.log10(df[col]))
    return df

def cleanStringColumns(df: DataFrame) -> DataFrame:
    for col in getStringColumns(df):
        # Try to delete spaces with trim and convert to lower otherwises create null
        df = df.withColumn(col, F.when(F.trim(F.col(col)) != "", F.lower(F.trim(F.col(col)))))
    return df

# Books
books = deleteRowsOver50Percentage(books)
Terrazas_202104 = deleteRowsOver50Percentage(Terrazas_202104)
Licencias_Locales_202104 = deleteRowsOver50Percentage(Licencias_Locales_202104)
Locales_202104 = deleteRowsOver50Percentage(Locales_202104)


# ### Tarea 1.2
# 
# Normalización de datos; Estandariza los valores de las columnas numéricas a una escala logarítmica

# Obtener las columnas numéricas
integer_list_books = getIntegerColumns(books)
integer_Terrazas_202104 = getIntegerColumns(Terrazas_202104)
integer_Licencias_Locales_202104 = getIntegerColumns(Licencias_Locales_202104)
integer_Locales_202104 = getIntegerColumns(Locales_202104)

# Normalización de columnas integer con logaritmo base 10
books = convertLog10(books, integer_list_books)
Terrazas_202104 = convertLog10(Terrazas_202104,integer_Terrazas_202104)
Licencias_Locales_202104 = convertLog10(Licencias_Locales_202104,integer_Licencias_Locales_202104)
Locales_202104 = convertLog10(Locales_202104,integer_Locales_202104)


# ### Tarea 1.3
# 
# Al dataset Terrazas_202104 crear la columna ration que divida "Superficie_TO" (Superficie_ES * 2) entre id_terraza.

Terrazas_202104 = Terrazas_202104.withColumn("Superficie_TO", (F.col("Superficie_ES") * 2)/F.col("id_terraza"))
Terrazas_202104.write.format("iceberg").save("nessie.etl.Terrazas_Normalizadas")


# ## Tarea 2

# ### Tarea 2.1
# 
# Eliminación de duplicados en Licencias_Locales_202104 usando "id_local" y "ref_licencia". Guardar el resultado en 

Licencias_Locales_202104 = Licencias_Locales_202104.dropDuplicates(subset=["id_local", "ref_licencia"])
Licencias_Locales_202104.write.format("iceberg").save("nessie.etl.Licencias_SinDuplicados")


# ### Tarea 2.2
# 
# Aplicar Strip, lower en el dataset Books y guardarlo en "Books_Limpio"

books = cleanStringColumns(books)

# Save the DataFrame
books.write.format("iceberg").save("nessie.etl.Books_Limpio")


# ## Tarea 3

# ### Tarea 3.1
# 
# Join entre las tablas "Terrazas_Normalizadas" y "Licencias_SinDuplicados" usando la columna "id_local". Guardar el resultado en "Licencias_Terrazas_Integradas"

# Cargar los dataframes
Terrazas_Normalizadas = spark.read.format("iceberg").load("nessie.etl.Terrazas_Normalizadas")
Licencias_SinDuplicados = spark.read.format("iceberg").load("nessie.etl.Licencias_SinDuplicados")

# Aplicar limpieza sobre las columnas de string
Terrazas_Normalizadas = cleanStringColumns(Terrazas_Normalizadas)
Licencias_SinDuplicados = cleanStringColumns(Licencias_SinDuplicados)


# Join de los dataframes
duplicated_columns = ['rotulo','clase_vial_edificio', 'coordenada_x_agrupacion', 'coordenada_x_local','coordenada_y_agrupacion','coordenada_y_local','desc_barrio_local','desc_distrito_local','desc_situacion_local','desc_situacion_terraza','desc_tipo_acceso_local','desc_vial_edificio','id_barrio_local','id_clase_ndp_edificio','id_distrito_local','id_local_agrupado','id_ndp_edificio','id_planta_agrupado','id_situacion_local','id_tipo_acceso_local','id_vial_edificio','nom_edificio','num_edificio','secuencial_local_PC']
Licencias_Terrazas_Integradas = Terrazas_Normalizadas.join(Licencias_SinDuplicados.drop(*duplicated_columns), on="id_local", how="inner")
Licencias_Terrazas_Integradas.write.format("iceberg").save("nessie.etl.Licencias_Terrazas_Integradas")


# ### Tarea 3.2
# 
# Agrupación de datos geográficos por barrio o distritio en el dataset "Terrazas_202104", sumar área de las superficies. Guardar el resultado en "Superficie_Agregadas"

Terrazas_202104 = cleanStringColumns(Terrazas_202104)

Superficies_Agregadas = Terrazas_202104.groupBy("id_distrito_local").agg(
    F.sum("Superficie_ES").alias("Superficie_ES_agregado"), \
    F.sum("Superficie_RA").alias("Superficie_RA_agregado")
)
Superficies_Agregadas.write.format("iceberg").save("nessie.etl.Superficies_Agregadas")
