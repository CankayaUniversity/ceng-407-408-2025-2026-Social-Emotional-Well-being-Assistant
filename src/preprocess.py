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

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--movies", default=r"data_raw/movies.csv", help="Path to movies.csv")
    ap.add_argument("--ratings", default=r"data_raw/ratings.csv", help="Path to ratings.csv")
    ap.add_argument("--out", default=r"data_processed/movies_enriched.csv", help="Output CSV path")
    ap.add_argument("--chunksize", type=int, default=1_000_000, help="ratings.csv read chunksize")
    args = ap.parse_args()

    os.makedirs(os.path.dirname(args.out), exist_ok=True)

    out.to_csv(args.out, index=False)
    print(f"Saved: {args.out} | rows={len(out)}")

if __name__ == "__main__":
    main()