import pandas as pd

df = pd.read_csv("data_processed/balanced_multilabel.csv")

row = df[df["y_Action"] == 1].iloc[0]

print("genres_norm :", row["genres_norm"])
print("y_Action    :", row["y_Action"])
print("labels_list :", row["labels_list"])
