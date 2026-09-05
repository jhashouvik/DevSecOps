"""
Wezva Technologies - MLOps Platform Engineering Framework
Component: Data Engineering ETL & Shift-Left PII Redaction Engine
Author: Adam, Head of Platform
"""

import os
import hashlib
import pandas as pd
import numpy as np

# 1. ESTABLISH SECURITY ANCHORS (Enterprise Salt & Pepper Pattern)
# In production, pull this from AWS Secrets Manager instead of hardcoding.
SECRET_PEPPER = os.getenv("CORPORATE_PII_PEPPER", "WezvaTechFinTechSecret2026_SaltKey")

def tokenize_pii_field(raw_value):
    """
    Applies an irreversible, deterministic cryptographic hash to sensitive fields.
    This masks PII while preserving data patterns for ML model training.
    """
    if pd.isna(raw_value):
        return "MASKED_NULL"
    
    # Combine raw data with corporate pepper string to block hash-reversal/rainbow-table attacks
    salted_string = f"{str(raw_value)}{SECRET_PEPPER}"
    return hashlib.sha256(salted_string.encode('utf-8')).hexdigest()

def mask_financial_instrument(card_number):
    """
    Enforces PCI-DSS compliance by completely redacting structural card segments,
    preserving only the final 4 auditing digits.
    """
    if pd.isna(card_number) or len(str(card_number)) < 4:
        return "UNAVAILABLE"
    
    clean_card = str(card_number).replace(" ", "").replace("-", "")
    return f"************{clean_card[-4:]}"

def main():
    print("🚀 Ingesting raw financial records from internal VPC staging database...")
    np.random.seed(42)
    n_samples = 5000

    # SIMULATING RAW INCOMING TRANSACTION RECORDS (CONTAINS COMPLIANCE VULNERABILITIES)
    raw_incoming_data = {
        # High Risk Direct PII (Must be completely removed or cryptographically hashed)
        'raw_customer_id': np.random.randint(5000000, 9999999, n_samples),
        'customer_name': np.random.choice(['Adam M', 'Arjun P', 'Krish E', 'Yuvraj D'], size=n_samples),
        'raw_pan_card': [f"ABCDE{np.random.randint(1000, 9999)}M" for _ in range(n_samples)],
        'raw_credit_card': [f"4532-{np.random.randint(1000, 9999)}-{np.random.randint(1000, 9999)}-{np.random.randint(1000, 9999)}" for _ in range(n_samples)],
        
        # Behavioral Features (Safe for Model Training)
        'transaction_id': range(100000, 100000 + n_samples),
        'amount': np.random.exponential(scale=50, size=n_samples) + np.random.uniform(1, 10, n_samples),
        'is_international': np.random.choice([0, 1], size=n_samples, p=[0.92, 0.08]),
        'failed_login_attempts': np.random.choice([0, 1, 2, 3, 5], size=n_samples, p=[0.85, 0.10, 0.03, 0.01, 0.01]),
        'velocity_1h': np.random.randint(1, 5, n_samples),  
        'card_present': np.random.choice([0, 1], size=n_samples, p=[0.30, 0.70]),
    }

    # Generate synthetic fraud labels based on mathematical risk metrics
    fraud_prob = (
        (raw_incoming_data['amount'] / 500) * 0.3 + 
        (raw_incoming_data['is_international'] * 0.3) + 
        (raw_incoming_data['failed_login_attempts'] / 5) * 0.2 +
        (raw_incoming_data['velocity_1h'] / 5) * 0.2
    )
    fraud_prob = np.clip(fraud_prob, 0, 1)
    raw_incoming_data['is_fraud'] = (np.random.random(n_samples) < fraud_prob).astype(int)

    # Convert to processing DataFrame
    raw_df = pd.DataFrame(raw_incoming_data)

    print("🛡️ Shift-Left Security Activated: Initializing PII Redaction Pipeline...")

    # =========================================================================
    # THE REDACTION LAYER: Transform data BEFORE outputting to workspace
    # =========================================================================
    clean_df = pd.DataFrame()
    
    # 1. Drop high-risk direct text identifiers entirely (Absolute Deletion)
    # By intentionally omitting 'customer_name' from assignment, it is deleted.
    print("   [1/4] Dropping direct customer names from dataset matrix...")

    # 2. Tokenize identifying fields (Anonymization via Salted Hashing)
    print("   [2/4] Executing SHA-256 tokenization on corporate Customer IDs and PAN Cards...")
    clean_df['customer_token'] = raw_df['raw_customer_id'].apply(tokenize_pii_field)
    clean_df['pan_token'] = raw_df['raw_pan_card'].apply(tokenize_pii_field)

    # 3. Mask financial accounts (PCI-DSS compliance)
    print("   [3/4] Enforcing structural masking on transaction card account numbers...")
    clean_df['masked_card'] = raw_df['raw_credit_card'].apply(mask_financial_instrument)

    # 4. Migrate safe behavioral components
    print("   [4/4] Migrating mathematical behavioral patterns to clean dataset...")
    clean_df['transaction_id'] = raw_df['transaction_id']
    clean_df['amount'] = raw_df['amount']
    clean_df['is_international'] = raw_df['is_international']
    clean_df['failed_login_attempts'] = raw_df['failed_login_attempts']
    clean_df['velocity_1h'] = raw_df['velocity_1h']
    clean_df['card_present'] = raw_df['card_present']
    clean_df['is_fraud'] = raw_df['is_fraud']

    # Ensure output directory exists locally inside the runner
    os.makedirs('data', exist_ok=True)
    
    # Save the finalized, fully scrubbed file
    output_path = 'data/fraud_data.csv'
    clean_df.to_csv(output_path, index=False)

    print("\n✅ Compliance Pipeline Execution Complete:")
    print(f"   -> Anonymized File Written: {output_path}")
    print(f"   -> Data Matrix Shape: {clean_df.shape}")
    print(f"   -> Verified Fraud Rate (Class Imbalance): {clean_df['is_fraud'].mean():.2%}")
    print("   -> Status: Clean dataset prepared for automated security audits & DVC version staging.\n")

if __name__ == "__main__":
    main()
