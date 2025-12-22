import os
import pandas as pd

INPUT_CSV  = r"data_processed/movies_enriched.csv"  
OUTPUT_CSV = r"data_processed/balanced_multilabel.csv"

TARGET_PER_GENRE = 127       
GENRE_COL = "genres_norm"      
INCLUDE_NO_GENRE_LABEL = False 

def parse_genres(s):
    if pd.isna(s) or str(s).strip() == "":
        return []
    return [g.strip() for g in str(s).split("|") if g.strip()]


def main():
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

    out.to_csv(OUTPUT_CSV, index=False)

    print(f"✅ Saved: {OUTPUT_CSV}")
    print(f"Rows selected: {len(out)}")
    print("\nGenre counts (selected set):")
    for g in all_genres:
        print(f"  {g:15s} -> {counts[g]} (target={TARGET_PER_GENRE})")


if __name__ == "__main__":
    main()
