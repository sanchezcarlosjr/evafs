from langchain.evaluation import load_evaluator
from langchain_community.embeddings import HuggingFaceEmbeddings

embeddings = HuggingFaceEmbeddings(model_name="Salesforce/SFR-Embedding-Mistral")

hf_evaluator = load_evaluator("pairwise_embedding_distance", embeddings=embeddings)
print(hf_evaluator.evaluate_string_pairs(prediction="Eighteen", prediction_b="18"))
