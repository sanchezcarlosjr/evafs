import json
import uuid

import inflection
import jq
import pandas as pd
from dask.optimization import cull
from dask.threaded import get
from pandas.core.base import PandasObject

from evafs.io import api
from evafs.io.api import ServiceError
from evafs.io.EntityFinder import RegexFinder
from evafs.supabase_client import supabase_client
from evafs.template_engine import parse


def to_title_case(s):
    # Handle snake case
    if "_" in s:
        s = inflection.humanize(s)
    else:
        # Handle PascalCase
        s = inflection.titleize(inflection.underscore(s))

    s = " ".join([word.capitalize() for word in s.split()])
    return s


def find_entities(df, model):
    df.columns = list(map(lambda column: model(column), df.columns))
    return df


def resolve_entities(df: pd.DataFrame, model):
    def define_entity(row):
        entity = model(row["entity"])
        row["entity"] = entity
        row["resource"]["queries"] = {
            key: model(value) for key, value in row["resource"]["queries"].items()
        }
        row["entity_es"] = to_title_case(entity)
        return row

    return df.apply(define_entity, axis=1)


def dispose_first_row_as_headers(df):
    df = df.dropna(how="all").reset_index(drop=True)
    if (df.columns.str.match("Unnamed")).all():
        df.columns = df.loc[0]
        df = df.drop([0])
    df = df.reset_index()
    return df.drop(df.columns[df.columns.str.contains("unnamed", case=False)], axis=1)


def assign_unique_uuid(df: pd.DataFrame):
    return df.assign(uuid=[str(uuid.uuid4()) for _ in range(len(df))])


def clean_dataset(df, model):
    states = df.estado_de_nacimiento.apply(
        lambda row: model.close_doc(row).metadata["code"]
    )
    return df.assign(estado_de_nacimiento=states)


class Message(str):
    def __init__(self, message):
        str.__init__(message)
        self.error = None

    def build(text, error):
        message = Message(text)
        message.error = error
        return message


def call_api(depends_on, cmetadata, getter):
    if isinstance(depends_on[0], Message):
        return {"message": depends_on[0].error}
    try:
        response, headers = api.post(
            **{
                "url": parse(
                    template=cmetadata["url_template"],
                    data={"data": json.dumps(depends_on)},
                ),
                "headers": parse(
                    template=cmetadata["headers"],
                    data={"token": cmetadata["api_token"]},
                ),
            }
        )
    except ServiceError as e:
        errors = (
            jq.compile('[.data.errors | values[] | join(",")]  | join(",")')
            .input_value(e.message)
            .first()
        )
        return {"message": errors}
    return response


def retrieve_from_json(depends_on, cmetdata, getter):
    response = depends_on[0]
    try:
        result = jq.compile(getter).input_value(response).first()
    except Exception as e:
        print(e)
        return Message.build(response["message"], "")
    if result is None:
        return Message.build(response["message"], "")
    return result


def find_openapi_entities():
    body, headers = api.get("https://apimarket.mx/openapi.json")
    df = pd.DataFrame(
        jq.compile(
            """
[
  .servers as $servers |
  .paths |
  to_entries[] |
  . as $o |
  .value.post["x-price"] as $price |
  .value.post["x-permissions"] as $permissions |
  .value.post.responses |
  select(. != null) |
  to_entries[] |
  (.value["content"]["application/json"]["example"]?.data // .value["content"]["application/json"]["examples"]?["example-0"]?.value?.data) |
  select(type != "array" and . != null) |
  [paths(scalars) as $path | ([$path[] | (if type == "number" then "[]" else "." + tostring end)] | join(""))] as $path |
  keys[]  |
  . as $key |
  {
    "entity": .,
    "price": $price,
    "permissions": [$permissions[] | .name],
    "segmentation": ".data\($path | map(select(. | contains("."+$key) or contains("[]"+$key)))[0])",
    "resource": {
      "url": "\($servers[0].url)\($o.key)",
      "headers": {
          "Accept": "application/json"
      },
      "rate_limit": "",
      "queries": (reduce ($o.value.post.parameters[] | select(.in == "query") | {(.name): .name}) as $i ({}; . + $i)),
    }
  }
]
    """
        )
        .input_value(body)
        .first()
    ).define_entity_space(RegexFinder())
    return df


def classify(task):
    if "url_template" in task["cmetadata"]:
        return (call_api, task["depends_on"], task["cmetadata"], " " + task["getter"])
    if None in task["depends_on"]:
        return (
            None,
            task["depends_on"],
            task["cmetadata"],
            " " + task["getter"],
        )
    return (
        retrieve_from_json,
        task["depends_on"],
        task["cmetadata"],
        " " + task["getter"],
    )


def plan(anchor, tasks, row, outputs):
    dsk = {task["task"]: classify(task) for task in tasks}
    dsk[anchor.page_content] = row
    dsk1, dependencies = cull(dsk, outputs)
    results = get(dsk1, outputs)
    return dict(zip(outputs, results))


def execute_plan(df, anchor, tasks, outputs):
    issues = []
    for index, row in df.loc[issues].iterrows():
        try:
            answer = plan(anchor, tasks, row, outputs)
            df.loc[index] = answer
            supabase_client.table(anchor.metadata["table"]).update(answer).eq(
                "id", row.id
            ).execute()
        except Exception as e:
            issues.append(index)
            print(f"Something has failed with i={index} id={row.id} {e}")
    return issues


def patch_pandas():
    PandasObject.find_entities = find_entities
    PandasObject.dispose_first_row_as_headers = dispose_first_row_as_headers
    PandasObject.assign_unique_uuid = assign_unique_uuid
    PandasObject.define_entity_space = resolve_entities
