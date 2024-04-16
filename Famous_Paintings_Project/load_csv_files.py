import pandas as pd
from sqlalchemy import create_engine
import maskpass

# for postgreSQL database credentials can be written as
user = input("Username: ")
password = maskpass.askpass()
host = "localhost"
port = "5432"
database = "paintings"
# for creating connection string
connection_str = f"postgresql://{user}:{password}@{host}:{port}/{database}"
# SQLAlchemy engine
engine = create_engine(connection_str)
# you can test if the connection is made or not
try:
    with engine.connect() as connection_str:
        print("Successfully connected to the PostgreSQL database")
except Exception as ex:
    print(f"Sorry failed to connect: {ex}")

conn = engine.connect()

files = [
    "artist",
    "canvas_size",
    "image_link",
    "museum_hours",
    "museum",
    "product_size",
    "subject",
    "work",
]

for file in files:

    df = pd.read_csv(f"Datasets/{file}.csv")
    df.to_sql(file, con=conn, if_exists="replace", index=False)
