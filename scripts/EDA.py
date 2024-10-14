# Import libraries
import pandas as pd
import sweetviz as sv
import matplotlib.pyplot as plt
from seaborn import heatmap
from typing import List, Optional

def strip_columns(df: pd.DataFrame, columns: List[str]) -> pd.DataFrame:
    # Apply strip
    for col in columns:
        df[col] = df[col].str.strip()
    return df

def create_corr_graph(df: pd.DataFrame, title: str, path: str):

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
    df_report = sv.analyze(df)
    df_report.show_html(f"{path}/reports/{title}_EDA.html")

def generate_parquet(df: pd.DataFrame, title: str, path: str):
    df.to_parquet(f"{path}/dataframes/{title}.parquet", index=False)

def generate_eda(df: pd.DataFrame, title: str, path: str, exclude_colums_eda: Optional[List[str]] = None):

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
terrazas = pd.read_csv(f"{raw_data_dir}/Terrazas_202104.csv", sep=";", encoding="latin-1")

## Locales
locales = pd.read_csv(f"{raw_data_dir}/Locales_202104.csv", sep=";", encoding="latin-1").dropna(axis=1, how="all")

## Terrazas
licencias = pd.read_csv(f"{raw_data_dir}/Licencias_Locales_202104.csv", sep=";", encoding="latin-1")

# Generate EDA
generate_eda(locales, "Locales_202104", eda_report_dir)
generate_eda(terrazas, "Terrazas_202104", eda_report_dir)
generate_eda(licencias, "Licencias_Locales_202104", eda_report_dir)
generate_eda(books, "books", eda_report_dir, exclude_colums_eda=["authors" , "categories"])
