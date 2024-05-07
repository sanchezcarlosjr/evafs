from sentence_transformers import SentenceTransformer

model = SentenceTransformer(
    "Alibaba-NLP/gte-Qwen1.5-7B-instruct", trust_remote_code=True
)
