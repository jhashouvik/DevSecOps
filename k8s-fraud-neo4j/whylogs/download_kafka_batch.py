import argparse
import json
import os
import sys
import pandas as pd
from kafka import KafkaConsumer
from aws_msk_iam_sasl_signer import MSKAuthTokenProvider

# ==============================================================================
# CLI ARGUMENT PARSER
# ==============================================================================
def parse_args():
    parser = argparse.ArgumentParser(
        description="Download batch messages from MSK Kafka topic into a CSV file."
    )
    parser.add_argument(
        "-b",
        "--broker",
        required=True,
        help="MSK Serverless Bootstrap Broker (e.g. boot-u2wcldmo.c2.kafka-serverless.ap-south-1.amazonaws.com:9098)",
    )
    parser.add_argument(
        "-t",
        "--topic",
        default="fraud-events",
        help="Kafka topic to consume from (default: fraud-events)",
    )
    parser.add_argument(
        "-o",
        "--output",
        default="production_batch.csv",
        help="Output CSV file path (default: production_batch.csv)",
    )
    parser.add_argument(
        "--timeout",
        type=int,
        default=5000,
        help="Consumer timeout in milliseconds before stopping (default: 5000 ms)",
    )
    return parser.parse_args()


# ==============================================================================
# MSK IAM TOKEN PROVIDER
# ==============================================================================
class MSKTokenProvider:
    """Generates short-lived OAuth bearer tokens signed by AWS IAM."""
    def token(self):
        region = os.getenv("AWS_REGION", "ap-south-1")
        token, _ = MSKAuthTokenProvider.generate_auth_token(region)
        return token


# ==============================================================================
# MAIN CONSUMER LOGIC
# ==============================================================================
def download_batch():
    args = parse_args()

    region = os.getenv("AWS_REGION", "ap-south-1")
    print(f"Connecting to MSK Broker : {args.broker}")
    print(f"AWS Region               : {region}")
    print(f"Target Topic             : {args.topic}")

    tp = MSKTokenProvider()

    try:
        consumer = KafkaConsumer(
            args.topic,
            bootstrap_servers=[args.broker],
            security_protocol="SASL_SSL",
            sasl_mechanism="OAUTHBEARER",
            sasl_oauth_token_provider=tp,
            auto_offset_reset="earliest",  # Read from beginning of topic
            enable_auto_commit=False,
            group_id=f"batch-downloader-group-{os.getpid()}",  # Unique group ID
            consumer_timeout_ms=args.timeout,  # Stop iteration when topic is idle
            api_version=(2, 8, 1),
            value_deserializer=lambda v: json.loads(v.decode("utf-8")),
        )
    except Exception as e:
        print(f"\n❌ Failed to connect to Kafka Consumer: {e}")
        sys.exit(1)

    print("\nFetching batch messages from Kafka...")
    records = []

    try:
        for message in consumer:
            records.append(message.value)
            print(f"Downloaded record #{len(records)}: {message.value}")

    except Exception as e:
        print(f"⚠️ Error while reading messages: {e}")
    finally:
        consumer.close()

    if not records:
        print("\n⚠️ No records found in the topic or consumer timed out.")
        sys.exit(0)

    # Convert records list of JSON objects to Pandas DataFrame and export to CSV
    df = pd.DataFrame(records)
    df.to_csv(args.output, index=False)

    print(f"\n✅ Successfully downloaded {len(records)} records!")
    print(f"📁 Batch dataset saved to: {args.output}")


if __name__ == "__main__":
    download_batch()
