import mimetypes
import os
import re
from pathlib import Path

import magic
import pandas as pd


def raw(*subpath):
    return Path(os.path.join(os.environ["RAW_DATA_DIR"], *subpath))


def processed(*subpath):
    return Path(os.path.join(os.environ["PROCESSED_DATA_DIR"], *subpath))


def external(*subpath):
    return Path(os.path.join(os.environ["EXTERNAL_DATA_DIR"], *subpath))


def data(*subpath):
    return Path(os.path.join(os.environ["DATA_DIR"], *subpath))


def model(*subpath):
    return Path(os.path.join(os.environ["MODELS_DIR"], *subpath))


def guess_type(path):
    """
    Guesses the type of a file based on its path.

    Args:
        path (str): The path to the file.

    Returns:
        str: The guessed MIME type of the file. If the file type is text, the MIME type is guessed using the `mimetypes.guess_type()` function. Otherwise, the file type is returned as is.
    """
    mime = magic.Magic(mime=True)
    file_type = mime.from_file(path)
    if re.match("text", file_type):
        return mimetypes.guess_type(path)[0]
    return file_type


class IOManager:
    def __init__(self, path: [Path, str] = ""):
        self.path = path

    def save_inputs(self, path):
        return {result.name: self.read_input(result) for result in self.path.glob(path)}

    def read_input(self, path: [Path, str]):
        pass


class PandasIOManager(IOManager):

    def read_input(self, path):
        file_type = guess_type(path)
        if "text/csv" in file_type:
            return pd.read_csv(path, engine="pyarrow")
        elif "application/json" in file_type:
            return pd.read_json(path, dtype_backend="pyarrow")
        elif (
            "application/vnd.ms-excel" in file_type
            or "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet"
            in file_type
        ):
            return pd.read_excel(path, dtype_backend="pyarrow")
        elif "inode/x-empty" in file_type:
            pass
        else:
            raise ValueError("Unsupported file format")
