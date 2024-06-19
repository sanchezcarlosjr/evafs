import time

import gradio as gr
import uvicorn
from fastapi import FastAPI, Request
from starlette.middleware.cors import CORSMiddleware

from evafs.io.assets import PandasIOManager
from evafs.io.vectorstore import Vectorstore
from evafs.knowledge_graph.entities import patch_pandas

io = PandasIOManager()
vectorstore = Vectorstore()

patch_pandas()


def get_user(request: Request):
    return request.headers.get("Authorization")


app = FastAPI()

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

theme = gr.themes.Base(
    font=["DM Sans", "ui-sans-serif", "system-ui", "-apple-system"],
).set(
    body_background_fill_dark="transparent",
    border_color_primary_dark="transparent",
    button_primary_background_fill_dark="rgb(31, 41, 55)",
    button_primary_text_color_dark="rgb(156, 163, 175)",
    button_primary_border_color_dark="rgb(31, 41, 55)",
)


def upload_file(filepath, options, progress=gr.Progress()):
    progress(0, desc="Starting...")
    for i in progress.tqdm(range(10), desc="Uploading"):
        time.sleep(0.1)
    df = io.read_input(filepath).find_entities(vectorstore)
    df_element = gr.Dataframe(df, visible=True, interactive=True)
    return [gr.UploadButton(visible=False), gr.Dropdown(visible=False), df_element]


with gr.Blocks(
    theme=theme,
    css="""
.gradio-container {
  border: none !important;
}
""",
) as demo:
    with gr.Row():
        files = gr.File(file_count="single")
    with gr.Row():
        options = gr.Dropdown(["RFC", "CURP", "NSS"], multiselect=True, label="Datos")
    with gr.Row():
        dataframe = gr.Dataframe(visible=False)
        dataframe.input(lambda x: x, gr.Dataframe(visible=True, interactive=True))

    files.upload(upload_file, [files, options], [files, options, dataframe])
    demo.queue()

app = gr.mount_gradio_app(app, demo, path="/", auth_dependency=get_user)

if __name__ == "__main__":
    uvicorn.run(app)
