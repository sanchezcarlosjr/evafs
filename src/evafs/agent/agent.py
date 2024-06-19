"""
   Hierarchical task network planning.
   Online CSP algorithm.
   Primitive tasks.
   Compound tasks.
   Goal tasks.
   Knowledge graph.
   LLM (LLama3-Instruct).
   Similarity search with syntax and semantics methods.
   DuckDB+SQL Macros.
   Python.
   Dask.

   SQL schema.


Template engine. The below tables are used in the template engine.
They don't save the actual schema, but a template.

CREATE TABLE tasks(
    id INTEGER PRIMARY KEY,
    schema JSON,
    goal_task boolean,
    cost numeric,
    probability numeric,
    progress numeric
)

CREATE TABLE entities (
    id INTEGER PRIMARY KEY,
    entity TEXT,
    resources JSON,
    embedding vector
)

Start State:
SELECT id, parse(id, schema, depends_on) FROM tasks WHERE progress = 0;
TaskGraph :-
(action, depends_on, schema)
(action, depends_on, schema)
...

get(TaskGraph, id)

An example is
 x = f() -> f -> (f, schema)
 y = g(x) -> g x -> (g, [1], schema)

get({'1': ('f', schema), '2': ('g', [1], schema)}, [1,2])


Do and increase the KB.


Invariants:
A reachable task is one that entails from the KB.
An unreachable task is one that contradicts from the KB.

In each hop, answer the below question,
we do the reachable undone tasks and then increase the KB and add new tasks if any.

Have we got a path to the goal tasks?
1. No. Contradiction. Impossible.
2. Maybe. Contingency. Soundness and completeness. Inference.
3. Yes. Entailment.


task(1)
task(2)
task(3)





Goal State:
SELECT count(1)=0 FROM tasks WHERE progress = 0 AND goal_task = true;


...Ad hoc tables and environment variables

"""

import json
import uuid
from typing import Union
from urllib.parse import urlparse

import duckdb
import pandas as pd
from kink import di, inject

from evafs.io.EntityFinder import RegexFinder
from evafs.io.store import SQLTemplate, read


def parse_schema(schema):
    schema = schema if isinstance(schema, dict) else {"url": schema}
    return json.dumps(schema)


class Actions:
    def __init__(self):
        self.actions = []

    def parse(self, schema):
        url = urlparse(schema.get("url", ""))
        for action in self.actions:
            f, matcher = action
            if args := matcher(url, schema):
                return f, args

    def command(self, matcher):
        def decorate(f):
            f = inject(f)

            self.actions.append((f, matcher))

            return f

        return decorate


actions = Actions()


@actions.command(lambda url, _: url.scheme == "http" and str(url))
def call_http_service(http_url: str):
    return http_url


@actions.command(lambda url, _: url.scheme == "file" and url.path)
def read_files_from(*paths: list[str]):
    return read(paths, RegexFinder())


@actions.command(lambda url, scheme: url.scheme == "insert+duckdb")
def save_entities(entities_frame: pd.DataFrame, db: duckdb.DuckDBPyConnection):
    db.sql("CREATE TABLE IF NOT EXISTS dataset AS SELECT * FROM entities_frame")
    db.sql(
        """
       INSERT INTO entities(entity, resource)
       SELECT column_name as entity, ('\"duckdb:SELECT ' || column_name ||  ' from dataset\"')::json as resource FROM information_schema.columns WHERE table_name = 'dataset'
     """
    )
    return entities_frame


class Agent:
    def __init__(
        self,
        tasks_frame: Union[pd.DataFrame | str],
        entities_frame: pd.DataFrame,
        knowledge_base_sql="",
        database=":memory:",
    ):
        self.database = duckdb.connect(database)
        if isinstance(tasks_frame, pd.DataFrame):
            tasks_frame = tasks_frame.assign(
                schema=tasks_frame["schema"].apply(parse_schema)
            )
            tasks_insertion_sentence = "INSERT INTO tasks (schema, goal_task, cost, probability, progress) SELECT * FROM tasks_frame;"
        else:
            tasks_insertion_sentence = tasks_frame

        self.template = SQLTemplate(
            f"""
        CREATE SEQUENCE sequence_task_id START 1;

        CREATE TABLE IF NOT EXISTS tasks(
            id integer PRIMARY KEY DEFAULT nextval('sequence_task_id'),
            schema JSON,
            goal_task boolean default FALSE,
            cost numeric DEFAULT 0,
            probability numeric DEFAULT 1,
            progress numeric DEFAULT 0
        );


        CREATE TABLE IF NOT EXISTS entities (
            id TEXT PRIMARY KEY DEFAULT uuid(),
            entity TEXT,
            resource JSON,
            price numeric DEFAULT 0,
            permissions TEXT DEFAULT null,
            segmentation TEXT DEFAULT null,
            entity_es TEXT DEFAULT null
        );

        {tasks_insertion_sentence}

        INSERT INTO entities (entity, price, permissions, segmentation, resource, entity_es)
        SELECT * FROM entities_frame;

        CREATE VIEW tasks_dependencies as select * from tasks;

                """
        )
        self.database.sql(self.template.render())
        di["db"] = self.database

    def plan(self):
        while True:
            goals = self.database.sql(
                "SELECT COUNT(1) FROM tasks WHERE goal_task = true and progress != 1"
            ).fetchone()[0]
            if goals == 0:
                return {}
            tasks = self.database.sql("SELECT * FROM tasks WHERE progress == 0").df()
            tasks = tasks.assign(
                schema=tasks["schema"].apply(json.loads).apply(actions.parse)
            )
            anchors = [str(uuid.uuid4())]
            planning = {anchors[0]: tasks}
            breakpoint()
            yield planning, anchors

    def act(self, actions):
        breakpoint()
        return 1

    def knowledge_base(self):
        return self.database

    def control(self):
        for actions in self.plan():
            yield self.act(actions)
