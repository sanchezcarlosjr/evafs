from evafs import __version__

__author__ = "sanchezcarlosjr"
__copyright__ = "sanchezcarlosjr"
__license__ = "MIT"

from typing import Optional

import ray
import typer
from rich import print
from typing_extensions import Annotated

from evafs import _logger, setup_logging
from evafs.auth_provider import auth
from evafs.supabase_client import supabase_client
from evafs.webservice import WebService, serve

# ---- CLI ----
# The functions defined in this section are wrappers around the main Python
# API allowing them to be called directly from the terminal as a CLI
# executable/script.


app = typer.Typer()


@app.command()
def version():
    print(f"evafs {__version__}")


@app.command()
def login(
    provider: Annotated[str, typer.Argument(help="Auth provider. GitHUb, Google.")] = ""
):
    auth.login(provider)


@app.command()
def logout():
    auth.logout()


@app.command()
def read(table):
    result = supabase_client.postgrest.table(table).select("*").execute()
    print(result.data)


@app.command()
def run_webapp(
    share: Annotated[bool, typer.Option(help="Share with Gradio servers.")] = False
):
    _logger.info("Starting webapp..")
    from evafs.webapp import webapp

    webapp.launch(share=share)


@app.command()
def run_webservice():
    """
    The command initiates the webservice and maintains it in the background.
    Additionally, this command is used to update the service.
    """
    _logger.info("Starting webservice...")
    ray.init()
    serve.run(WebService.bind(), route_prefix="/hello")


def main(
    verbose: Optional[int] = typer.Option(
        0,
        "--verbose",
        "-v",
        count=True,
        help="Increase verbosity by augmenting the count of 'v's, and enhance "
        "the total number of messages.",
    )
):
    setup_logging(verbose * 10)
    app()


def run():
    app()


if __name__ == "__main__":
    typer.run(app)
