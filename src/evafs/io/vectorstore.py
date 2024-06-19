import os

from langchain_community.embeddings import HuggingFaceEmbeddings
from langchain_postgres.vectorstores import PGVector


class Vectorstore:
    def __init__(
        self, collection_name="entities", connection=os.environ["DATABASE_URL_PSYCOPG"]
    ):
        self.embeddings = HuggingFaceEmbeddings(
            model_name="Alibaba-NLP/gte-large-en-v1.5",
            model_kwargs={"trust_remote_code": True},
        )

        self.vectorstore = PGVector(
            embeddings=self.embeddings,
            collection_name=collection_name,
            connection=connection,
            use_jsonb=True,
        )

    def save_docs(self, docs):
        self.vectorstore.add_documents(docs, ids=[doc.metadata["id"] for doc in docs])

    def close_doc(self, query):
        return self.vectorstore.similarity_search(query, k=1)[0]

    def __call__(self, query):
        return self.close_doc(query).page_content
