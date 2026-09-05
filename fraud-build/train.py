"""
Wezva Technologies - MLOps Platform Engineering Framework
Component: Enterprise Model Training & High-Speed Metadata Tracking
Author: Adam, Head of Platform
Optimized: Decoupled artifact handling, explicit network gates, and sandbox fallback.
"""

import os
import sys
import pandas as pd
import numpy as np
import pickle
import hashlib
import socket
from sklearn.model_selection import train_test_split
from sklearn.ensemble import RandomForestClassifier
from sklearn.metrics import accuracy_score, roc_auc_score, precision_score, recall_score, f1_score
import mlflow
import mlflow.sklearn
# ─── CRITICAL STEP 1: Import the native MLflow Model Signature inference engine ───
from mlflow.models import infer_signature

from requests.exceptions import ConnectionError, Timeout

# =====================================================================
# 🎯 CRITICAL NETWORK BLOCKERS: STOP INFINITE AWS / HTTP RETRIES
# =====================================================================
socket.setdefaulttimeout(30)
os.environ["AWS_METADATA_SERVICE_TIMEOUT"] = "5"
os.environ["AWS_METADATA_SERVICE_NUM_ATTEMPTS"] = "1"
os.environ["BOTO_CONFIG"] = "/dev/null"

try:
    import botocore
    import botocore.client  
    from botocore.config import Config
    
    strict_aws_config = Config(
        connect_timeout=15,
        read_timeout=15,
        retries={'max_attempts': 1}
    )
    botocore.client.Config = strict_aws_config
    print("🎯 Network Defenses Active: AWS/Botocore network loops throttled to 15s.")
except (ImportError, AttributeError) as e:
    print(f"⚠️ Botocore throttling bypassed: {str(e)}")

try:
    import urllib3
    urllib3.util.Timeout(connect=15.0, read=15.0)
except ImportError:
    pass
# =====================================================================

# 1. Establish central connection to your running MLflow Tracking Instance
tracking_uri = os.getenv("MLFLOW_TRACKING_URI", "http://localhost:31000")
print(f"Connecting to MLflow Tracking Server at: {tracking_uri}")

# 🎯 FIX: Hardcoded clean deployment standard to eliminate the automatic sandbox suffix
experiment_name = "Fraud-Detection-Pipeline"

try:
    mlflow.set_tracking_uri(tracking_uri)
    mlflow.set_experiment(experiment_name)
    active_experiment = mlflow.get_experiment_by_name(experiment_name)
    print(f"✅ Successfully established connection to remote MLflow: {experiment_name}")

except (ConnectionError, Timeout, Exception) as e:
    print("\n⚠️ WARNING: Remote MLflow server is unreachable or blocked by firewalls.")
    print("🛡️ Activating Sandbox Fallback: Redirecting all tracking logs to local SQLite DB...")

    mlflow.set_tracking_uri("sqlite:///mlflow.db")
    mlflow.set_experiment(experiment_name)
    active_experiment = mlflow.get_experiment_by_name(experiment_name)

# Start the automated training and tracking run session
with mlflow.start_run() as run:

    if os.getenv("GITHUB_SHA"):
        mlflow.set_tag("git_commit", os.getenv("GITHUB_SHA"))
        mlflow.set_tag("github_run_id", os.getenv("GITHUB_RUN_ID"))

    # Load dataset
    data_path = 'data/fraud_data.csv'
    df = pd.read_csv(data_path)

    # Core features
    features = ['amount', 'is_international', 'failed_login_attempts', 'velocity_1h', 'card_present']
    X = df[features]
    y = df['is_fraud']

    X_train, X_test, y_train, y_test = train_test_split(
        X, y, test_size=0.2, random_state=42, stratify=y
    )

    n_estimators = 100
    random_state = 42
    mlflow.log_param("n_estimators", n_estimators)
    mlflow.log_param("random_state", random_state)

    model = RandomForestClassifier(
        n_estimators=n_estimators,
        random_state=random_state,
        class_weight='balanced',
        n_jobs=-1
    )
    model.fit(X_train, y_train)

    y_pred = model.predict(X_test)
    y_proba = model.predict_proba(X_test)[:, 1]

    accuracy = accuracy_score(y_test, y_pred)
    auc = roc_auc_score(y_test, y_proba) if len(np.unique(y_test)) > 1 else 1.0
    precision = precision_score(y_test, y_pred, zero_division=0)
    recall = recall_score(y_test, y_pred, zero_division=0)
    f1 = f1_score(y_test, y_pred, zero_division=0)

    print(f"Model Training Complete.")
    print(f"Accuracy:  {accuracy:.4f} | AUC-ROC: {auc:.4f}")
    print(f"Precision: {precision:.4f} | Recall:  {recall:.4f} | F1-Score: {f1:.4f}")

    mlflow.log_metric("accuracy", accuracy)
    mlflow.log_metric("auc_roc", auc)
    mlflow.log_metric("precision", precision)
    mlflow.log_metric("recall", recall)
    mlflow.log_metric("f1_score", f1)

    # ─── CRITICAL STEP 2: OPTIMIZED DATA CONTRACT SIGNATURE EXTRACTOR ───
    input_sample = X_test.head(1)
    mock_output = np.array([0], dtype=np.int32)
    model_signature = infer_signature(input_sample, mock_output)

    # ─── NATIVE MLFLOW FLAVOR LOGGING ENGINE ───
    # This automatically compiles the required MLmodel file, requirements metadata, 
    # and serializes the model using high-performance pickle protocols.
    print("Compiling native MLflow model flavor package ecosystem...")
    mlflow.sklearn.log_model(
        sk_model=model,
        artifact_path="model_artifacts",
        signature=model_signature,
        serialization_format="pickle"
    )
    
    # Maintain local file emission block so your existing GitHub Actions proxy-upload logic remains unbroken
    os.makedirs('models', exist_ok=True)
    model_path = 'models/fraud_model.pkl'
    with open(model_path, 'wb') as f:
        pickle.dump(model, f, protocol=pickle.HIGHEST_PROTOCOL)

    print("Flashing model metrics and parameters locally cached successfully.")

    # Data Lineage Audit Fix: Log metadata hashes instead of heavy raw CSV data
    with open(data_path, "rb") as f:
        dataset_hash = hashlib.sha256(f.read()).hexdigest()

    mlflow.set_tag("dataset_sha256", dataset_hash)
    mlflow.set_tag("dataset_row_count", len(df))

    # ─── CRITICAL STEP 3: Export Run Metadata & Active Experiment ID for GitHub Actions ───
    active_run_id = run.info.run_id
    active_experiment_id = run.info.experiment_id

    with open("mlflow_run_id.txt", "w") as f:
        f.write(active_run_id)

    with open("mlflow_experiment_id.txt", "w") as f:
        f.write(active_experiment_id)

    print("Success: Model metrics stored and metadata generated!")
    print(f"🏃 Run Tracked At: {tracking_uri}/#/experiments/{active_experiment_id}/runs/{active_run_id}")
