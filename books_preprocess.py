import os
import re
import argparse
import pandas as pd
from datetime import datetime

def extract_year(date_str: str):
    """
    Extract year from publishedDate string (e.g., '2023-01-15' -> 2023)
    """
    if pd.isna(date_str) or str(date_str).strip() == "":
        return None
    try:
        # Try parsing ISO format date
        year = int(str(date_str)[:4])
        return year if 1000 <= year <= datetime.now().year else None
    except (ValueError, TypeError):
        return None

def normalize_categories(categories: str):
    """
    Normalize book categories (pipe-separated)
    Maps similar categories to standard ones
    """
    if pd.isna(categories) or str(categories).strip() == "":
        return ""
    parts = [c.strip() for c in str(categories).split("|") if c.strip()]
    # Normalize common category variations
    normalized = []
    for cat in parts:
        cat = cat.strip()
        if cat:
            normalized.append(cat)
    return "|".join(normalized)

def aggregate_book_ratings(ratings_csv: str, chunksize: int = 1_000_000):
    """
    Streaming aggregation (memory friendly):
      rating_count = number of ratings per book (Title)
      rating_mean  = average rating per book (Title)
    """
    count_acc = pd.Series(dtype="int64")
    sum_acc = pd.Series(dtype="float64")

    reader = pd.read_csv(
        ratings_csv,
        usecols=["Title", "review/score"],
        chunksize=chunksize,
    )

    for chunk in reader:
        # Filter out NaN ratings
        chunk_clean = chunk.dropna(subset=["review/score"])
        if len(chunk_clean) == 0:
            continue
            
        g = chunk_clean.groupby("Title")["review/score"].agg(["count", "sum"])
        count_acc = count_acc.add(g["count"], fill_value=0).astype("int64")
        sum_acc = sum_acc.add(g["sum"], fill_value=0.0)

    mean = sum_acc / count_acc
    out = pd.DataFrame({
        "Title": count_acc.index,
        "rating_count": count_acc.values.astype("int64"),
        "rating_mean": mean.values.astype("float64"),
    })
    return out

def main():
    ap = argparse.ArgumentParser(description="Preprocess books dataset")
    ap.add_argument("--books", default=r"Dataset/books_data.csv", help="Path to books_data.csv")
    ap.add_argument("--ratings", default=r"Dataset/Books_rating.csv", help="Path to Books_rating.csv")
    ap.add_argument("--out", default=r"Dataset/books_enriched.csv", help="Output CSV path")
    ap.add_argument("--chunksize", type=int, default=1_000_000, help="Books_rating.csv read chunksize")
    args = ap.parse_args()

    os.makedirs(os.path.dirname(args.out) or ".", exist_ok=True)

    # Load and preprocess books data
    print(f"Loading books data from {args.books}...")
    books = pd.read_csv(args.books)
    
    books["year"] = books["publishedDate"].apply(extract_year)
    books["categories"] = books["categories"].apply(normalize_categories)

    # Aggregate ratings
    print(f"Aggregating ratings from {args.ratings}...")
    ratings_agg = aggregate_book_ratings(args.ratings, chunksize=args.chunksize)

    # Merge books with aggregated ratings
    print("Merging data...")
    out = books.merge(ratings_agg, on="Title", how="left")
    out["rating_count"] = out["rating_count"].fillna(0).astype("int64")
    out["rating_mean"] = out["rating_mean"].fillna(0).astype("float64")

    # Select relevant columns for enriched dataset
    out = out[[
        "Title", "year", "authors", "categories", 
        "publisher", "publishedDate", "description", 
        "rating_count", "rating_mean"
    ]]

    # Save enriched dataset
    print(f"Saving enriched dataset to {args.out}...")
    out.to_csv(args.out, index=False)
    print(f"✓ Saved: {args.out} | rows={len(out)}")

if __name__ == "__main__":
    main()
