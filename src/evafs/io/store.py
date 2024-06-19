import glob
import json
import mimetypes
import os
import random
import re
from pathlib import Path

import duckdb
import magic
import pandas as pd
from duckdb.typing import VARCHAR
from sqlmesh.core.dialect import parse
from sqlmesh.core.macros import MacroEvaluator, macro


def guess_type(path):
    mime = magic.Magic(mime=True)
    file_type = mime.from_file(path)
    if re.match("text", file_type):
        return mimetypes.guess_type(path)[0]
    return file_type


def read_from(path):
    file_type = guess_type(path)
    path_str = str(path)
    try:
        if "text/csv" in file_type:
            return pd.read_csv(path_str)
        elif "application/json" in file_type:
            return pd.read_json(path_str)
        elif (
            "application/vnd.ms-excel" in file_type
            or "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet"
            in file_type
        ):
            return pd.read_excel(path_str)
        elif "application/octet-stream" in file_type:
            if path_str.endswith(".parquet"):
                return pd.read_parquet(path_str)
            elif path_str.endswith(".feather"):
                return pd.read_feather(path_str)
        elif "text/html" in file_type:
            return pd.read_html(path_str)
        elif "application/x-hdf" in file_type or "application/x-hdf5" in file_type:
            return pd.read_hdf(path_str)
        elif "application/python-pickle" in file_type or path_str.endswith(".pkl"):
            return pd.read_pickle(path_str)
        elif "inode/x-empty" in file_type:
            return pd.DataFrame()
        else:
            return pd.DataFrame()
    except Exception as e:
        print(e)
        return pd.DataFrame()


def read(paths, model) -> pd.DataFrame:
    df_list = []
    for file in sum([glob.glob(str(path), recursive=True) for path in paths], []):
        df = (
            read_from(file)
            .replace(r"(^\s+|\s+$)", "", regex=True)
            .dispose_first_row_as_headers()
            .find_entities(model)
            .assign_unique_uuid()
        )
        df["source"] = file
        df_list.append(df)
    if len(df_list) == 0:
        return pd.DataFrame()
    return pd.concat(df_list).drop(columns=["index"])


def load_file_into_json(path):
    with open(path) as f:
        return json.load(f)


def register_pandas_plugins():
    pd.read_from = read_from
    pd.read = read
    json.load_file = load_file_into_json


def post(x):
    if random.choice([True, False]):
        raise Exception("error")
    return json.dumps({"x": "y"})


@macro()
def schema(evaluator: MacroEvaluator, url: str) -> str:
    return f"""'{{"url": "{url}"}}'"""


class SQLTemplate:
    def __init__(self, template: str, dialect: str = "duckdb"):
        self.template = template
        self.dialect = dialect
        self.evaluator = MacroEvaluator(dialect=dialect)

    def render(self, **kwargs) -> str:
        expressions = parse(self.template)
        x = "; ".join(
            map(
                lambda expression: self.evaluator.transform(expression).sql(),
                expressions,
            )
        )
        return x


def patch_duckdb(connection=duckdb.connect()):
    connection.sql(
        """
       INSTALL excel;
       LOAD excel;
       INSTALL spatial;
       LOAD spatial;
    """
    )
    connection.create_function(
        "post",
        post,
        [VARCHAR],
        VARCHAR,
        side_effects=True,
        exception_handling="return_null",
    )
    return connection


APP_PATH = str(Path(__file__).parent.resolve())
ROOT_PATH = os.environ.get("ROOT_PATH", APP_PATH)
