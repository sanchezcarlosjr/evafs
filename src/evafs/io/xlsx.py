import pandas as pd


def read(file):
    df = pd.read_excel(file).dropna(how="all").reset_index(drop=True)
    if (df.columns.str.match("Unnamed")).all():
        df.columns = df.loc[0]
        df = df.drop([0])
    return df.reset_index()
