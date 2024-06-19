import json

import _jsonnet


def parse(template, data):
    return json.loads(_jsonnet.evaluate_snippet("snippet", template, ext_vars=data))
