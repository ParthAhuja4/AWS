#!/bin/bash
set -e

# ---------------- 72 — DATA LIFECYCLE MANAGEMENT ----------------
# A lifecycle configuration = rules S3 runs for you automatically, based
# on the AGE of an object. Two kinds of action:
#   Transition -> move the object to a cheaper storage class
#   Expiration -> delete the object
#
# Typical log-file story: hot for a month, rarely read after, legally
# kept for a year, then useless:
#   day 0    STANDARD
#   day 30   -> STANDARD_IA
#   day 90   -> GLACIER
#   day 365  -> deleted
#
# Rule fields:
#   ID      -> just a label
#   Status  -> Enabled / Disabled (lets you switch a rule off without deleting it)
#   Filter  -> which objects: a Prefix ("logs/"), tags, or {} for the
#              whole bucket
#   NoncurrentVersion* -> same actions but for OLD versions on a
#              versioned bucket (see 3_versioning.sh). This is how you
#              stop old versions piling up and costing money.
#   AbortIncompleteMultipartUpload -> cleans up half-finished big
#              uploads, which are invisible in `ls` but still billed.
#
# Constraints: transitions only go "downwards" (Standard -> IA ->
# Glacier -> Deep Archive, never back), and an object must be at least
# 30 days old before moving to STANDARD_IA / ONEZONE_IA.
cat > /tmp/s3-demo/lifecycle.json <<'EOF'
{
  "Rules": [
    {
      "ID": "archive-then-delete-logs",
      "Status": "Enabled",
      "Filter": { "Prefix": "logs/" },
      "Transitions": [
        { "Days": 30, "StorageClass": "STANDARD_IA" },
        { "Days": 90, "StorageClass": "GLACIER" }
      ],
      "Expiration": { "Days": 365 }
    },
    {
      "ID": "cleanup-old-versions",
      "Status": "Enabled",
      "Filter": {},
      "NoncurrentVersionExpiration": { "NoncurrentDays": 30 },
      "AbortIncompleteMultipartUpload": { "DaysAfterInitiation": 7 }
    }
  ]
}
EOF

# This call REPLACES the bucket's whole lifecycle configuration — it
# does not append. To add one rule you must send all the existing rules
# again plus the new one.
awslocal s3api put-bucket-lifecycle-configuration \
  --bucket my-local-bucket \
  --lifecycle-configuration file:///tmp/s3-demo/lifecycle.json

awslocal s3api get-bucket-lifecycle-configuration --bucket my-local-bucket

# REAL AWS: rules are evaluated about once a day (midnight UTC), so
# nothing happens the moment you save this, and the transition can lag
# a day or two behind. LocalStack stores and returns the configuration
# but never actually moves or deletes anything.
#
# To remove every rule:
#   awslocal s3api delete-bucket-lifecycle --bucket my-local-bucket
