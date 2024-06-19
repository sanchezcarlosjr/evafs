import pandas as pd
from langchain_core.documents import Document

import evafs.knowledge_graph.entities as entities
from evafs.io.vectorstore import Vectorstore

entities.patch_pandas()


class MockVectorstore:
    def close_doc(self, query):
        return Document(
            page_content="Data", metadata={"id": "fb00f292-f7e6-4c40-885b-a6ec537e58a3"}
        )


def test_find_entities(mocker):
    mocker.patch.object(Vectorstore, "__new__", return_value=MockVectorstore())
    vectorstore = Vectorstore()

    df = pd.DataFrame({"data": [1, 2, 3]}).find_entities(vectorstore)

    assert (df.columns == ["Data"]).all()
