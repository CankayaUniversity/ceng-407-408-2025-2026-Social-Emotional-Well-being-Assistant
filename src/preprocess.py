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
<<<<<<< HEAD
    os.makedirs(os.path.dirname(OUTPUT_CSV), exist_ok=True)
    df = pd.read_csv(INPUT_CSV)

    # 1) Tüm genre setini çıkar
    all_genres = set()
    for x in df[GENRE_COL].fillna(""):
        for g in parse_genres(x):
            if g == "(no genres listed)" and not INCLUDE_NO_GENRE_LABEL:
                continue
            all_genres.add(g)

    all_genres = sorted(all_genres)
    counts={g:0 for g in all_genres}
    selected_idx=[]

    for idx,row in df.iterrows():
        gs=parse_genres(row[GENRE_COL])
        if not INCLUDE_NO_GENRE_LABEL:
            gs=[g for g in gs if g!="(no genres listed)"]
        if not gs:
            continue
        if any(counts.get(g,0)<TARGET_PER_GENRE for g in gs):
            selected_idx.append(idx)
            for g in gs:
                if g in counts:
                    counts[g]+=1
        if all(counts[g]>=TARGET_PER_GENRE for g in counts):
            break

    out=df.loc[selected_idx].copy().reset_index(drop=True)

    for g in all_genres:
        out[f"y_{g}"]=0

    for i,row in out.iterrows():
        gs=parse_genres(row[GENRE_COL])
        if not INCLUDE_NO_GENRE_LABEL:
            gs=[g for g in gs if g!="(no genres listed)"]
        for g in gs:
            col=f"y_{g}"
            if col in out.columns:
                out.at[i,col]=1

    out["labels_list"]=out[GENRE_COL].fillna("").apply(parse_genres)
    if not INCLUDE_NO_GENRE_LABEL:
        out["labels_list"]=out["labels_list"].apply(lambda xs:[g for g in xs if g!="(no genres listed)"])
    out.to_csv(OUTPUT_CSV, index=False)

    print(f"✅ Saved: {OUTPUT_CSV}")
    print(f"Rows selected: {len(out)}")
    print("\nGenre counts (selected set):")
    for g in all_genres:
        print(f"  {g:15s} -> {counts[g]} (target={TARGET_PER_GENRE})")
=======
    ap = argparse.ArgumentParser()
    ap.add_argument("--movies", default=r"data_raw/movies.csv", help="Path to movies.csv")
    ap.add_argument("--ratings", default=r"data_raw/ratings.csv", help="Path to ratings.csv")
    ap.add_argument("--out", default=r"data_processed/movies_enriched.csv", help="Output CSV path")
    ap.add_argument("--chunksize", type=int, default=1_000_000, help="ratings.csv read chunksize")
    args = ap.parse_args()
>>>>>>> 4d41b87 (Update preprocess script)

    out.to_csv(args.out, index=False)
    print(f"Saved: {args.out} | rows={len(out)}")

if __name__ == "__main__":
    main()