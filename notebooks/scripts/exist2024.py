import os
from pathlib import Path

import dotenv
import myfm
import numpy as np
import pandas as pd
from langchain_experimental.open_clip import OpenCLIPEmbeddings
from pandas.core.base import PandasObject

import evafs.io.assets as assets

dotenv.load_dotenv()

baseline_path = assets.raw("evaluation", "baselines")
gold_path = assets.raw("evaluation", "gols")

categories = [
    "IDEOLOGICAL-INEQUALITY",
    "STEREOTYPING-DOMINANCE",
    "OBJECTIFICATION",
    "SEXUAL-VIOLENCE",
    "MISOGYNY-NON-SEXUAL-VIOLENCE",
    "-",
    "UNKNOWN",
]


def encode_bitset(category_bits):
    def categories_to_bitset(set_of_categories):
        bitset = 0
        for category in set_of_categories:
            if category in category_bits:
                bitset |= 1 << category_bits[category]
        return bitset

    return categories_to_bitset


def apply_encoding(series):
    category_bits = {category: index for index, category in enumerate(categories)}
    return series.apply(encode_bitset(category_bits))


def encode_tweets(df):
    return df.assign(
        score_task1=df["score_task1"].astype("category").cat.codes,
        score_task2=df["score_task2"].astype("category").cat.codes,
        score_task3=apply_encoding(df["score_task3"]),
    )[["annotator", "profile", "filename", "score_task1", "score_task2", "score_task3"]]


def encode_memes(df, *path):
    return df.assign(
        score_task4=df["score_task4"].astype("category").cat.codes,
        score_task5=df["score_task5"].astype("category").cat.codes,
        score_task6=apply_encoding(df["score_task6"]),
        path=os.path.join(os.environ["RAW_DATA_DIR"], *path) + os.sep + df["filename"],
    )[
        [
            "annotator",
            "profile",
            "item_id",
            "path",
            "score_task4",
            "score_task5",
            "score_task6",
        ]
    ]


def encode_test(df, *path):
    return df.assign(
        score_task4=None,
        score_task5=None,
        score_task6=None,
        path=os.path.join(os.environ["RAW_DATA_DIR"], *path) + os.sep + df["filename"],
    )[
        [
            "annotator",
            "profile",
            "item_id",
            "path",
            "score_task4",
            "score_task5",
            "score_task6",
        ]
    ]


def unique_pairs(df):
    return df["profile"].drop_duplicates(), df["path"].drop_duplicates()


def concat_attribute_and_embeddings(attribute, embeddings, name_attribute: str):
    return pd.concat([attribute.reset_index(), pd.Series(embeddings)], axis=1).rename(
        columns={0: name_attribute}
    )


def concat_embeddings(df):
    return df.assign(embeddings=df["profile_embeddings"] + df["item_embeddings"])


def find_embeddings(df):
    clip_embd = OpenCLIPEmbeddings(
        model_name="ViT-L-14", checkpoint="laion2b_s32b_b82k"
    )
    profiles, image_paths = df.unique_pairs()
    image_embeddings = clip_embd.embed_image(image_paths)
    profile_embeddings = clip_embd.embed_documents(profiles)
    profiles_with_embeddings = concat_attribute_and_embeddings(
        profiles, profile_embeddings, "profile_embeddings"
    )
    images_with_embeddings = concat_attribute_and_embeddings(
        image_paths, image_embeddings, "item_embeddings"
    )
    df_with_embeddings = df.merge(
        images_with_embeddings[["path", "item_embeddings"]]
    ).merge(profiles_with_embeddings[["profile", "profile_embeddings"]])
    return df.assign(
        embeddings=df_with_embeddings["profile_embeddings"]
        + df_with_embeddings["item_embeddings"]
    )


def predictor_variable(df):
    return np.array(df["embeddings"].tolist())


def variables_for_training(df, task_label: str):
    X = np.array(df["embeddings"].tolist())
    y = np.asarray(df[task_label])
    return X, y


def fit(df, task_label: str):
    X, y = variables_for_training(df, task_label)
    fm = myfm.MyFMRegressor(rank=4)
    fm.fit(X, y)
    return fm


def utility_matrix(df, values):
    matrix = df.pivot(index="annotator", columns="item_id", values=values)
    matrix.loc["Voting"] = matrix.mean()
    matrix.loc["Label"] = "NaN"
    return matrix


def utility_matrix_for_task4(df):
    matrix = df.pivot(index="annotator", columns="item_id", values="score_task4")
    matrix.loc["Voting"] = matrix.mean()
    matrix.loc["Soft"] = 0
    matrix.loc["Hard"] = 0
    return matrix


def utility_matrix_for_task5(df):
    matrix = df.pivot(index="annotator", columns="item_id", values="score_task5")
    matrix.loc["Voting"] = matrix.mean()
    matrix.loc["Soft"] = 0
    matrix.loc["Hard"] = 0
    return matrix


def utility_matrix_for_task6(df):
    matrix = df.pivot(index="annotator", columns="item_id", values="score_task6")
    matrix.loc["Voting"] = matrix.mean()
    matrix.loc["Soft"] = 0
    matrix.loc["Hard"] = 0
    return matrix


PandasObject.encode_tweets = encode_tweets
PandasObject.encode_memes = encode_memes
PandasObject.unique_pairs = unique_pairs
PandasObject.utility_matrix = utility_matrix
PandasObject.encode_test = encode_test
PandasObject.concat_embeddings = concat_embeddings
PandasObject.variables_for_training = variables_for_training
PandasObject.find_embeddings = find_embeddings
PandasObject.fit = fit
PandasObject.predictor_variable = predictor_variable
PandasObject.utility_matrix_for_task4 = utility_matrix_for_task4
PandasObject.utility_matrix_for_task5 = utility_matrix_for_task5
PandasObject.utility_matrix_for_task6 = utility_matrix_for_task6


def load_dataset(dataset):
    io = assets.PandasIOManager(assets.raw(dataset))
    return io.save_inputs("**/**/f_*_dataset.json")


def load_vectorstore():
    return pd.read_parquet(assets.processed("vectorstore.parquet"))


def glob_path_images(path):
    workdir = Path(assets.raw(path))
    return list(workdir.glob("**/*.jpg")) + list(workdir.glob("**/*.jpeg"))
