#!/bin/bash

echo "Injecting continuous traffic... Press Ctrl+C to stop."

while true; do
  curl -s -o /dev/null -w "%{http_code}\n" \
    http://localhost/v2/models/fraud-predictor-stable/infer \
    -H "Host: fraud-predictor-stable.default.svc.cluster.local" \
    -H "Content-Type: application/json" \
    -d '{
      "inputs": [
        {"name": "amount", "shape": [1], "datatype": "FP32", "data": [350.0]},
        {"name": "is_international", "shape": [1], "datatype": "INT64", "data": [1]},
        {"name": "failed_login_attempts", "shape": [1], "datatype": "INT64", "data": [2]},
        {"name": "velocity_1h", "shape": [1], "datatype": "INT64", "data": [4]},
        {"name": "card_present", "shape": [1], "datatype": "INT64", "data": [0]}
      ]
    }' &
  sleep 0.1
done
