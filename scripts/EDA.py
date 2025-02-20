# Import libraries
import pandas as pd
import sweetviz as sv
import matplotlib.pyplot as plt
from seaborn import heatmap
from typing import List, Optional

def strip_columns(df: pd.DataFrame, columns: List[str]) -> pd.DataFrame:
    """
    Elimina espacios en blanco al inicio y al final de los valores de las columnas especificadas en un DataFrame.
    
    Parámetros:
    - df (pd.DataFrame): El DataFrame sobre el cual se aplicará la limpieza de columnas.
    - columns (List[str]): Lista de nombres de las columnas a las que se les debe aplicar el método `strip`.
    
    Retorno:
    - pd.DataFrame: El DataFrame original con los espacios en blanco eliminados de las columnas especificadas.
    """
    for col in columns:
        df[col] = df[col].str.strip()
    return df

def create_corr_graph(df: pd.DataFrame, title: str, path: str):
    """
    Genera un gráfico de calor de la matriz de correlación para las variables numéricas del DataFrame
    y lo guarda en un archivo PNG.
    
    Parámetros:
    - df (pd.DataFrame): El DataFrame del cual se extraerá la matriz de correlación.
    - title (str): Título que se usará para el gráfico y el nombre del archivo guardado.
    - path (str): Ruta donde se guardará la imagen del gráfico.
    
    Retorno:
    - None: Esta función no retorna ningún valor, pero guarda el gráfico de correlación en la ubicación especificada.
    """

    # Create correlation matrix for numeric only
    ## and filter only for the higest correlation values
    df_corr = df.corr(method="pearson", numeric_only=True)
    df_corr = df_corr[((df_corr >= 0.5) | (df_corr <= -0.5)) & (df_corr != 1.0)]

    # Configure image
    plt.figure(figsize=(16,9))
    plt.title(title)

    # Create image
    heatmap(df_corr, annot=True, fmt=".1f")
    plt.tight_layout() # Fit the image

    # Save file
    plt.savefig(f"{path}/reports/{title}_correlation.png")

def generate_sweetviz_report(df: pd.DataFrame, title: str, path: str):
    """
    Genera un informe de análisis exploratorio de datos (EDA) utilizando la biblioteca Sweetviz 
    y lo guarda en formato HTML.
    
    Parámetros:
    - df (pd.DataFrame): El DataFrame que se analizará.
    - title (str): Título que se usará para el informe generado.
    - path (str): Ruta donde se guardará el informe en HTML.
    
    Retorno:
    - None: Esta función no retorna ningún valor, pero guarda el informe en la ubicación especificada.
    """
    df_report = sv.analyze(df)
    df_report.show_html(f"{path}/reports/{title}_EDA.html")

def generate_parquet(df: pd.DataFrame, title: str, path: str):
    """
    Guarda un DataFrame en un archivo en formato Parquet, que es un formato de almacenamiento columnar eficiente.
    
    Parámetros:
    - df (pd.DataFrame): El DataFrame que se quiere guardar.
    - title (str): Nombre del archivo que se generará.
    - path (str): Ruta donde se guardará el archivo Parquet.
    
    Retorno:
    - None: Esta función no retorna ningún valor, pero guarda el DataFrame en un archivo Parquet en la ubicación especificada.
    """
    df.to_parquet(f"{path}/dataframes/{title}.parquet", index=False)

def generate_eda(df: pd.DataFrame, title: str, path: str, exclude_colums_eda: Optional[List[str]] = None):
    """
    Genera un análisis exploratorio de datos (EDA) guardando un archivo Parquet, creando un gráfico de
    correlación y generando un informe de Sweetviz. Permite excluir columnas específicas del análisis.
    
    Parámetros:
    - df (pd.DataFrame): El DataFrame que se analizará.
    - title (str): Título que se usará para los archivos generados.
    - path (str): Ruta donde se guardarán los archivos generados.
    - exclude_colums_eda (Optional[List[str]]): Lista de nombres de columnas que se deben excluir del análisis. 
      Por defecto es `None`.
    
    Retorno:
    - None: Esta función no retorna ningún valor, pero realiza varias acciones que incluyen guardar archivos y generar informes.
    """
    # Export csv cleaned
    generate_parquet(df, title, path)

    # Correlation
    create_corr_graph(df, title, path)

    if exclude_colums_eda is not None:
        df = df.drop(exclude_colums_eda, axis = 1)

    # EDA report with Sweetviz
    generate_sweetviz_report(df, title, path)

# Folder paths
raw_data_dir = "/home/raw_data"
eda_report_dir = "/home/eda"

# Load dataframes
## Books
books = pd.read_json(f"{raw_data_dir}/books.json", lines=True)
books["_id"] = books["_id"].apply(lambda x: x["$oid"] if type(x) == dict else str(x))
books["publishedDate"] = pd.json_normalize(books["publishedDate"])
books["publishedDate"] = pd.to_datetime(books["publishedDate"])

##  Terrazas
terrazas = pd.read_csv(f"{raw_data_dir}/Terrazas_202104.csv", sep=";", encoding="latin-1", decimal=",", thousands=".")

## Locales
locales = pd.read_csv(f"{raw_data_dir}/Locales_202104.csv", sep=";", encoding="latin-1", decimal=",", thousands=".")#.dropna(axis=1, how="all")

## Terrazas
licencias = pd.read_csv(f"{raw_data_dir}/Licencias_Locales_202104.csv", sep=";", encoding="latin-1", decimal=",", thousands=".")

# Generate EDA
generate_eda(locales, "Locales_202104", eda_report_dir)
generate_eda(terrazas, "Terrazas_202104", eda_report_dir)
generate_eda(licencias, "Licencias_Locales_202104", eda_report_dir)
generate_eda(books, "books", eda_report_dir, exclude_colums_eda=["authors" , "categories"])
