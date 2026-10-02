#!/bin/bash
set -e

# ---------------- 59 — INTRODUCTION TO S3 ----------------
# S3 = Simple Storage Service = OBJECT storage. You don't get a disk or a
# filesystem (that's EBS) — you get a giant key -> value store over HTTP.
#
#   Bucket  = top-level container. Name must be GLOBALLY unique across
#             every AWS account in the world (it becomes part of a URL).
#   Object  = the file itself + its metadata. Max 5TB per object.
#   Key     = the object's full name inside the bucket, e.g.
#             "photos/2026/cat.png". There are NO real folders — the "/"
#             is just a character in the key that the console renders as
#             folders. "photos/2026/" is called a PREFIX.
#
# EBS vs S3 (since we just did EBS):
#   EBS = block storage, attached to ONE instance in ONE AZ, you mount it
#         and put a filesystem on it. Fixed size you pay for upfront.
#   S3  = object storage, reachable by anyone/anything with permission
#         over HTTP, unlimited size, pay only for what you store.
#         You can't "edit" an object in place — you re-upload the whole
#         thing.
#
# Durability vs availability (asked a lot):
#   Durability   = 99.999999999% (11 nines) — chance of LOSING the data.
#                  S3 copies every object across >= 3 AZs.
#   Availability = 99.99% for Standard — chance of the data being
#                  REACHABLE right now.
#
# Buckets live in a region, but the bucket NAMESPACE is global.

# `s3 ls` with no arguments lists every bucket in the account.
# REAL AWS: identical — S3 is one of the few services where the listing
# is account-wide, not per-region.
awslocal s3 ls

# Two different command families exist for S3, and we use both:
#   awslocal s3 ...     -> HIGH-level, file-manager-like (ls, cp, mv, rm,
#                          sync, mb, rb, presign). Friendly, does
#                          multipart uploads for you.
#   awslocal s3api ...  -> LOW-level, 1:1 with the raw S3 REST API
#                          (put-bucket-policy, put-bucket-versioning...).
#                          Needed for every bucket CONFIGURATION setting.
awslocal s3api list-buckets \
  --query 'Buckets[].{Name:Name,Created:CreationDate}' \
  --output table
