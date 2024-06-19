import os
import uuid

from sqlalchemy import create_engine

# Ensure the DATABASE_URL is set in your environment variables
engine = create_engine(os.environ.get("DATABASE_URL"), echo=False)


def write(name, df):
    """
    Write a DataFrame to SQL with a UUID as the primary key.

    Parameters:
    name (str): Name of the SQL table to create/replace.
    df (DataFrame): pandas DataFrame to write to SQL.
    """
    df["id"] = [uuid.uuid4() for _ in range(len(df))]
    df = df.set_index("id")
    try:
        df.to_sql(name=name, con=engine, index=False, if_exists="replace")
        return df
    except Exception as e:
        print(f"An error occurred: {e}")


# Usage example:
# write('table_name', pd.DataFrame({'data': [1, 2, 3]}))
