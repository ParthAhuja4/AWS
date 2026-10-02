#!/bin/bash
set -e

# ---------------- 70 — STORAGE CLASSES: STANDARD / INFREQUENT / GLACIER ----------------
# Storage class is set PER OBJECT, not per bucket — one bucket can hold
# objects of every class. The trade is always the same:
#   cheaper to STORE  <->  more expensive / slower to READ
#
#   STANDARD             default. Frequent access, ms retrieval, no
#                        retrieval fee, no minimum duration.
#   STANDARD_IA          Infrequent Access. ~half the storage price, but
#                        a per-GB RETRIEVAL fee. Min 30 days, min 128KB
#                        billed per object. Backups, DR copies.
#   ONEZONE_IA           same as IA but stored in ONE AZ only (cheaper,
#                        lost if that AZ is destroyed). Re-creatable data.
#   INTELLIGENT_TIERING  S3 watches access and moves the object between
#                        tiers for you. Small monitoring fee, no
#                        retrieval fee. Use when the pattern is unknown.
#   GLACIER_IR           Glacier Instant Retrieval. Archive, still ms
#                        retrieval. Min 90 days.
#   GLACIER              Glacier Flexible Retrieval. Object must be
#                        RESTORED before reading: minutes to 12 hours.
#                        Min 90 days.
#   DEEP_ARCHIVE         cheapest of all. Restore takes 12-48 hours.
#                        Min 180 days. Compliance data kept for years.
#
# "Min N days" = delete it earlier and you are still billed for N days.
# All classes have the same 11 nines durability (One Zone: within its AZ).

echo "some data" > /tmp/s3-demo/data.txt

# --storage-class picks the class at upload time. Omit it = STANDARD.
awslocal s3 cp /tmp/s3-demo/data.txt s3://my-local-bucket/classes/standard.txt
awslocal s3 cp /tmp/s3-demo/data.txt s3://my-local-bucket/classes/ia.txt \
  --storage-class STANDARD_IA
awslocal s3 cp /tmp/s3-demo/data.txt s3://my-local-bucket/classes/glacier.txt \
  --storage-class GLACIER

# StorageClass shows up in the listing (list-objects-v2 is the s3api
# version of `s3 ls`).
awslocal s3api list-objects-v2 \
  --bucket my-local-bucket \
  --prefix classes/ \
  --query 'Contents[].{Key:Key,Class:StorageClass,Size:Size}' \
  --output table

# Change the class of an EXISTING object = copy it onto itself with a
# new class. (Objects are immutable, so "changing" always means a copy.)
awslocal s3 cp s3://my-local-bucket/classes/standard.txt \
  s3://my-local-bucket/classes/standard.txt \
  --storage-class ONEZONE_IA

# A GLACIER object can't be downloaded directly — a GET returns
# InvalidObjectState. You first ask for a temporary restored copy:
#   Days = how long the restored copy stays readable
#   Tier = Expedited (1-5 min, priciest) | Standard (3-5 h) | Bulk (5-12 h, cheapest)
# REAL AWS: you then wait hours and poll head-object until the Restore
# field says ongoing-request="false". LocalStack restores instantly.
awslocal s3api restore-object \
  --bucket my-local-bucket \
  --key classes/glacier.txt \
  --restore-request '{"Days":1,"GlacierJobParameters":{"Tier":"Standard"}}'

awslocal s3api head-object \
  --bucket my-local-bucket \
  --key classes/glacier.txt \
  --query '{Class:StorageClass,Restore:Restore}'

# Doing these moves by hand doesn't scale — automating it is the next
# script (6_lifecycle.sh).
