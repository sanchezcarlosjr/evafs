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
