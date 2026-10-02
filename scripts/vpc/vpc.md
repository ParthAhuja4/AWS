# AWS VPC — ELI5 Notes (88 → 104)

**Big picture:** VPC = your gated colony in the AWS city. Subnets = lanes. Route table = signboards. IGW = main gate to the highway.

---

## 88 — Create First VPC

**ELI5:** Buy land in AWS and fence it. Decide how many house numbers (IPs) it gets.

- VPC = isolated private network in **one region**, spans all AZs.
- CIDR size: **/16 (biggest) to /28 (smallest)**. IPs = `2^(32 − prefix)` → `/16` = 65,536, `/24` = 256.
- Auto-created: main route table, default NACL, default SG. **Not** created: subnets, IGW.
- Plan CIDRs to never overlap (needed for peering later).

## 89 — Create First Subnet

**ELI5:** Mark lanes inside your land. Each lane sits in one neighbourhood (AZ).

- Subnet = slice of VPC CIDR, **exactly one AZ**.
- AWS reserves **5 IPs** per subnet → `/24` gives **251** usable.
- Auto-assign public IP is **off** by default.

## 90 — VPC + Subnet without IGW / Route Table

**ELI5:** House built, but no gate and no road out.

- Route table only has `10.0.0.0/16 → local` → instances talk internally only.
- Can't SSH in, can't reach the internet. **Custom VPC is private by default.**
- A public IP alone is **not** enough.

## 91 — Internet Gateway & Route Table

**ELI5:** Build the main gate and put up a signboard pointing to it.

- **1 VPC ↔ 1 IGW.** Create → **attach** to VPC.
- Internet needs all 3: **IGW attached + route `0.0.0.0/0 → IGW` + public IP** (and SG/NACL allow).
- Each subnet has one route table; most specific route wins.
- Best practice: keep the main route table private; make a separate public one.

## 92 — Public vs Private Subnet

**ELI5:** A lane is public only because its signboard points to the gate.

- **Public** = route to IGW. **Private** = no route to IGW. No checkbox.
- Public: load balancers, bastion, NAT GW. Private: app servers, DBs.

## 93 — Bastion Host

**ELI5:** Enter the guard room first, then walk to the private house.

- Bastion = small EC2 in **public** subnet; SSH to it, then hop to the private EC2.
- SG: bastion allows 22 from **My IP**; private EC2 allows 22 from **bastion's SG**.
- Hop without copying keys: `ssh-add key.pem` → `ssh -J ec2-user@<bastion> ec2-user@<private-ip>`
- No-bastion alternative: **SSM Session Manager**.

## 94 — NAT Instance

**ELI5:** A courier desk sends orders out for hidden houses; strangers can't come in.

- EC2 in **public** subnet doing NAT (outbound only).
- 🔴 **Disable source/destination check** (it forwards others' traffic).
- Private route table: `0.0.0.0/0 → NAT instance`.
- Cheap, but **single point of failure** and you manage it.

## 95 — NAT Gateway

**ELI5:** Same courier desk, but AWS runs it.

- Create in **public** subnet + **Elastic IP**; private route table `0.0.0.0/0 → NAT GW`.
- HA within one AZ → use **one per AZ** for full HA. Auto-scales.
- **No Security Group** on it. **Not free** — delete it after the lab, then release the EIP.

|            | NAT Instance | NAT Gateway     |
| ---------- | ------------ | --------------- |
| Managed by | You          | AWS             |
| HA         | ❌           | ✅ (per AZ)     |
| SG         | ✅           | ❌              |
| Cost       | Low          | Hourly + per GB |

## 96 — NACL vs Security Group

**ELI5:** SG = bouncer at your door who remembers you. NACL = lane checkpost with no memory, checks both ways.

|         | Security Group       | NACL                                          |
| ------- | -------------------- | --------------------------------------------- |
| Level   | Instance             | Subnet                                        |
| State   | **Stateful**         | **Stateless** (allow return ports 1024–65535) |
| Rules   | Allow only           | Allow **+ Deny**                              |
| Order   | All evaluated        | Lowest number first, first match wins         |
| Default | In: deny, Out: allow | Default NACL: allow all · Custom: deny all    |

- Block a specific IP → **NACL**.

## 99 — VPC Peering

**ELI5:** A private bridge between two colonies.

- Connects 2 VPCs (any account/region) privately.
- 🔴 **No overlapping CIDRs.** 🔴 **Not transitive** (A↔B, B↔C ≠ A↔C → use Transit Gateway).
- Steps: request → accept → **add routes in BOTH VPCs** (`other CIDR → pcx-xxx`) → update SGs.

## 104 — VPC Endpoint / Gateway Endpoint

**ELI5:** A private tunnel from your colony straight to the S3 warehouse — no highway, no courier.

|          | Gateway Endpoint                | Interface Endpoint  |
| -------- | ------------------------------- | ------------------- |
| Services | **S3, DynamoDB only**           | Most AWS services   |
| How      | Route in route table (`pl-xxx`) | ENI with private IP |
| Cost     | **Free**                        | Paid                |

- Private EC2 still needs an **IAM role** — endpoint = road, IAM = permission.
- Same region only. Saves NAT data charges.

---

## Quick Recall

- `/24` usable IPs → **251**
- Public subnet = **route to IGW**
- NAT GW lives in → **public subnet**
- Block an IP → **NACL**
- Peering transitive? → **No**
- Free endpoint for S3 → **Gateway Endpoint**
