import gradio as gr
from evafs import pipeline

predict = pipeline()

with gr.Blocks(title="evafs") as webapp:
    gr.Markdown("# Greetings from evafs!")
    inp = gr.Textbox(placeholder="What is your name?")
    out = gr.Textbox()

    inp.change(fn=predict,
               inputs=inp,
               outputs=out)