from pathlib import Path

import duckdb
import gradio as gr

from evafs.io.assets import PandasIOManager
from evafs.io.vectorstore import Vectorstore
from evafs.knowledge_graph.entities import patch_pandas

io = PandasIOManager()
vectorstore = Vectorstore()

patch_pandas()


def upload_file(filepath, progress=gr.Progress()):
    progress(0, desc="Starting...")
    name = Path(filepath).name
    df = io.read_input(filepath).find_entities(vectorstore)
    df = duckdb.query("SELECT * FROM df").to_df()
    progress.update(10)
    return [
        gr.UploadButton(visible=False),
        gr.Dataframe(df, visible=True),
        gr.DownloadButton(label=f"Download {name}", value=filepath, visible=True),
    ]


def download_file():
    return [gr.UploadButton(visible=True), gr.DownloadButton(visible=False)]


def f(df):
    return df


demo = gr.Interface(f, gr.Dataframe(), gr.Dataframe())

if __name__ == "__main__":
    demo.queue()
    demo.launch()
