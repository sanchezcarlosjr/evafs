import json
import logging
import os
import sys

import dotenv
import pandas as pd
import seaborn as sns

# import statsmodels.api as sm
# from statsmodels.formula.api import ols

dotenv.load_dotenv()

sns.set_context("poster")
sns.set(rc={"figure.figsize": (16, 9.0)})
sns.set_style("whitegrid")

pd.set_option("display.max_rows", 120)
pd.set_option("display.max_columns", 120)

logging.basicConfig(level=logging.INFO, stream=sys.stdout)

ROOT_DIR = os.environ["APP"]


def tweet_baseline(file):
    return os.path.join(ROOT_DIR, "data", "raw", "evaluation", "baselines", file)


def tweet_golds(file):
    return os.path.join(ROOT_DIR, "data", "raw", "evaluation", "golds", file)


def tweet_dev():
    f = open(
        os.path.join(
            ROOT_DIR,
            "data",
            "raw",
            "EXIST 2024 Tweets Dataset",
            "dev",
            "EXIST2024_dev.json",
        )
    )
    return json.load(f)


def tweet_test():
    f = open(
        os.path.join(
            ROOT_DIR,
            "data",
            "raw",
            "EXIST 2024 Tweets Dataset",
            "test",
            "EXIST2023_test_clean.json",
        )
    )
    return json.load(f)


def tweet_training():
    f = open(
        os.path.join(
            ROOT_DIR,
            "data",
            "raw",
            "EXIST 2024 Tweets Dataset",
            "training",
            "EXIST2024_training.json",
        )
    )
    return json.load(f)


def apply_predict_to(dataset, predict):
    return list(map(predict, dataset.values()))


def meme_baseline(file):
    return os.path.join(ROOT_DIR, "data", "raw", "evaluation", "baselines", file)


def meme_golds(file):
    return os.path.join(ROOT_DIR, "data", "raw", "evaluation", "golds", file)


def meme_dev():
    f = open(
        os.path.join(
            ROOT_DIR,
            "data",
            "raw",
            "EXIST 2024 Memes Dataset",
            "dev",
            "EXIST2024_dev.json",
        )
    )
    return json.load(f)


def meme_test():
    f = open(
        os.path.join(
            ROOT_DIR,
            "data",
            "raw",
            "EXIST 2024 Memes Dataset",
            "dev",
            "EXIST2023_test_clean.json",
        )
    )
    return json.load(f)


def meme_training():
    f = open(
        os.path.join(
            ROOT_DIR,
            "data",
            "raw",
            "EXIST 2024 Memes Dataset",
            "training",
            "EXIST2024_training.json",
        )
    )
    return json.load(f)


def meme_training_image(image):
    return os.path.join(
        ROOT_DIR, "data", "raw", "EXIST 2024 Memes Dataset", "training", "memes", image
    )


def meme_test_image(image):
    return os.path.join(
        ROOT_DIR, "data", "raw", "EXIST 2024 Memes Dataset", "test", "memes", image
    )
