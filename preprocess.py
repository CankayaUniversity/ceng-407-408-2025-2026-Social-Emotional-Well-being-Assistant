import os
import re
import argparse
import pandas as pd

YEAR_RE = re.compile(r"\((\d{4})\)\s*$")

def extract_year(title: str):
    if pd.isna(title):
        return None
    m = YEAR_RE.search(str(title))
    return int(m.group(1)) if m else None

def normalize_genres(genres: str):
    """
    'Adventure|Animation|Children|Comedy' -> 'Adventure|Animation|Family|Comedy'
    """
    if pd.isna(genres) or str(genres).strip() == "":
        return ""
    parts = [g.strip() for g in str(genres).split("|") if g.strip()]
    parts = [("Family" if g == "Children" else g) for g in parts]
    return "|".join(parts)

def aggregate_ratings(ratings_csv: str, chunksize: int = 1_000_000):
    """
    Streaming aggregation (memory friendly):
      rating_count = number of ratings per movieId
      rating_mean  = average rating per movieId
    """
    count_acc = pd.Series(dtype="int64")
    sum_acc = pd.Series(dtype="float64")

    reader = pd.read_csv(
        ratings_csv,
        usecols=["movieId", "rating"],
        chunksize=chunksize,
    )

    for chunk in reader:
        g = chunk.groupby("movieId")["rating"].agg(["count", "sum"])
        count_acc = count_acc.add(g["count"], fill_value=0).astype("int64")
        sum_acc = sum_acc.add(g["sum"], fill_value=0.0)

    mean = sum_acc / count_acc
    out = pd.DataFrame({
        "movieId": count_acc.index.astype(int),
        "rating_count": count_acc.values.astype("int64"),
        "rating_mean": mean.values.astype("float64"),
    })
    return out

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--movies", default=r"Dataset/movies.csv", help="Path to movies.csv")
    ap.add_argument("--ratings", default=r"Dataset/ratings.csv", help="Path to ratings.csv")
    ap.add_argument("--out", default=r"Dataset/movies_enriched.csv", help="Output CSV path")
    ap.add_argument("--chunksize", type=int, default=1_000_000, help="ratings.csv read chunksize")
    args = ap.parse_args()

    os.makedirs(os.path.dirname(args.out), exist_ok=True)

    movies = pd.read_csv(args.movies)
    movies["year"] = movies["title"].apply(extract_year)
    movies["genres"] = movies["genres"].apply(normalize_genres)

    ratings_agg = aggregate_ratings(args.ratings, chunksize=args.chunksize)

    out = movies.merge(ratings_agg, on="movieId", how="left")
    out["rating_count"] = out["rating_count"].fillna(0).astype("int64")

    out = out[["movieId", "title", "year", "genres", "rating_count", "rating_mean"]]

    out.to_csv(args.out, index=False)
    print(f"Saved: {args.out} | rows={len(out)}")

if __name__ == "__main__":
    main()