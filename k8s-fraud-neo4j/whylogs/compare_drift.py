import argparse
import sys
import pandas as pd
from scipy.stats import ks_2samp, chisquare

def parse_args():
    parser = argparse.ArgumentParser(
        description="Compare baseline data against production batch for data drift."
    )
    parser.add_argument("-b", "--baseline", required=True, help="Baseline CSV path")
    parser.add_argument("-p", "--production", required=True, help="Production CSV path")
    return parser.parse_args()

def run_drift_analysis():
    args = parse_args()

    try:
        baseline_df = pd.read_csv(args.baseline)
        production_df = pd.read_csv(args.production)
    except Exception as e:
        print(f"❌ Failed to load CSV files: {e}")
        sys.exit(1)

    results = []
    # Test common columns
    common_cols = list(set(baseline_df.columns) & set(production_df.columns))

    for col in common_cols:
        base_s = baseline_df[col].dropna()
        prod_s = production_df[col].dropna()

        # Continuous / Numeric features
        if pd.api.types.is_numeric_dtype(base_s):
            stat, p_val = ks_2samp(base_s, prod_s)
            algo = "KS-Test"
        # Categorical features
        else:
            # Align categories
            base_counts = base_s.value_counts(normalize=True)
            prod_counts = prod_s.value_counts(normalize=True)
            aligned = pd.DataFrame({"base": base_counts, "prod": prod_counts}).fillna(0)
            stat, p_val = chisquare(aligned["prod"] + 1e-5, aligned["base"] + 1e-5)
            algo = "Chi-Square"

        status = "DRIFT" if p_val < 0.05 else "NO_DRIFT"

        results.append({
            "Feature": col,
            "Algorithm": algo,
            "P-Value": round(p_val, 4),
            "Statistic": round(stat, 4),
            "Status": status,
        })

    summary_df = pd.DataFrame(results)

    print("==========================================================================")
    print("                    DATA DRIFT SUMMARY REPORT                             ")
    print("==========================================================================")
    print(summary_df.to_string(index=False))
    print("==========================================================================\n")

    drifted = summary_df[summary_df["Status"] == "DRIFT"]
    if not drifted.empty:
        print(f"⚠️  DRIFT DETECTED in {len(drifted)} feature(s): {drifted['Feature'].tolist()}")
    else:
        print("✅ No significant data drift detected across features.")

if __name__ == "__main__":
    run_drift_analysis()
