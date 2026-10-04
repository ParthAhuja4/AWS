# AWS Load Balancers & API Gateway — ELI5 Notes

**Big picture:** A load balancer is a receptionist who spreads visitors across many counters so no single counter gets crushed. API Gateway is the security desk at the building entrance that checks IDs, counts visitors and decides which department they go to.

---

## What is Elastic Load Balancing (ELB)?

**ELI5:** One front door (DNS name), many workers behind it. If a worker falls sick, visitors stop being sent to them.

- Spreads incoming traffic across **targets** (EC2, IPs, containers, Lambda) in **multiple AZs**.
- **Health checks** → unhealthy targets get no traffic.
- **Target group** = the list of workers + health-check settings. A listener (port + protocol) forwards to target groups.
- Managed by AWS, scales automatically, highly available across AZs.
- Pairs with an **Auto Scaling Group (ASG)**: ASG adds/removes EC2s, the LB starts/stops sending them traffic.
- 4 types: **ALB, NLB, GWLB**, and legacy **CLB** (don't use it for new work).

```
                    ┌──► EC2 (AZ-a)
Client ──► LB ──────┼──► EC2 (AZ-b)
                    └──► EC2 (AZ-c)   ✗ unhealthy → skipped
```

---

## ALB — Application Load Balancer (Layer 7)

**ELI5:** A smart receptionist who **reads the letter** before deciding where it goes — "/orders" to the orders team, "/users" to the users team.

- Works on **HTTP / HTTPS / gRPC / WebSocket** (OSI Layer 7).
- **Content-based routing** with listener rules on:
  - **Path** → `/api/*`, `/images/*`
  - **Host** → `api.example.com` vs `shop.example.com`
  - **Headers, query strings, HTTP method, source IP**
- Targets: **EC2 instances, IP addresses, Lambda functions** (and ECS tasks via IP / instance).
- Can **redirect** (HTTP → HTTPS) and send **fixed responses** (e.g. 404 / maintenance page) without any backend.
- **SSL/TLS termination** with ACM certificates; SNI for many certs on one listener.
- Built-in auth with **Cognito / OIDC**; plugs into **AWS WAF**.
- Has a **Security Group**.
- **No static IP** — you get a DNS name (put an NLB in front if you need fixed IPs).
- Client IP reaches the backend in the **`X-Forwarded-For`** header (not the packet source).
- Best for: **microservices, containers (ECS/EKS), web apps**.

```
                  ┌─ /orders/* ──► Orders target group
Client ──► ALB ───┼─ /users/*  ──► Users target group
                  └─ host: admin.* ──► Admin target group
```

## NLB — Network Load Balancer (Layer 4)

**ELI5:** A super-fast traffic cop who **doesn't open the letter** — only looks at the address and port and waves it through. Handles millions of cars per second.

- Works on **TCP / UDP / TLS** (OSI Layer 4).
- **Millions of requests/sec**, **ultra-low latency** (lower than ALB, since it never parses HTTP).
- **Static IP per AZ**, and you can attach an **Elastic IP** → great when clients must whitelist IPs.
- **Preserves client source IP** at the packet level.
- Targets: **EC2 instances, IP addresses, ALB** (NLB → ALB combo = static IP + L7 routing).
- Supports Security Groups (must be chosen at creation time).
- Best for: **gaming, IoT, real-time streaming, non-HTTP protocols, fixed-IP needs, PrivateLink**.
- **API Gateway VPC Link** classically talks to a private **NLB**.

## GWLB — Gateway Load Balancer (Layer 3)

**ELI5:** A mandatory **security checkpoint on the highway**. Every car is diverted through scanners (firewalls) and then sent on to its original destination — the car doesn't even notice.

- Works at **Layer 3 (network / IP packets)**, uses the **GENEVE protocol on port 6081**.
- Used to deploy, scale and manage **third-party virtual appliances**: firewalls, IDS/IPS, deep packet inspection (Palo Alto, Fortinet, Check Point…).
- **Transparent**: inspects traffic then returns it to the original flow.
- Traffic is steered to it via **route tables** + **GWLB Endpoints** (`gwlbe-xxx`).
- Best for: **centralised network security / inspection VPC**.

```
Internet ──► IGW ──► GWLB Endpoint ──► GWLB ──► Firewall appliances
                                              │
                         App subnet ◄─────────┘ (traffic continues if allowed)
```

## CLB — Classic Load Balancer (legacy)

- Old generation, L4 + L7 basic. **No path/host routing.** AWS recommends migrating to ALB/NLB.

---

## ALB vs NLB vs GWLB — at a glance

|                    | ALB                            | NLB                                | GWLB                          |
| ------------------ | ------------------------------ | ---------------------------------- | ----------------------------- |
| OSI layer          | **7** (application)            | **4** (transport)                  | **3** (network)               |
| Protocols          | HTTP, HTTPS, gRPC, WebSocket   | TCP, UDP, TLS                      | IP packets via GENEVE (6081)  |
| Routing on         | Path, host, headers, query     | Port / protocol only               | Route tables → appliances     |
| Static IP          | ❌ (DNS only)                  | ✅ (+ Elastic IP)                  | ❌                            |
| Client IP          | `X-Forwarded-For` header       | Preserved                          | Preserved (transparent)       |
| Targets            | EC2, IP, **Lambda**            | EC2, IP, **ALB**                   | Virtual appliances (EC2, IP)  |
| Speed              | Fast                           | **Fastest**, millions req/s        | Depends on appliances         |
| Use case           | Web apps, microservices        | Gaming, IoT, fixed IP, PrivateLink | Firewalls, IDS/IPS            |

---

## API Gateway

**ELI5:** The **reception + security desk** of an office tower. It checks your badge (auth), limits how many times you can enter per minute (throttling), maybe hands you a cached answer, and then directs you to the right department (Lambda, ALB, NLB, any HTTP URL, other AWS services).

- **Fully managed, serverless** "front door" for APIs. No servers, pay per request.
- 3 flavours:

|              | REST API                                 | HTTP API                          | WebSocket API             |
| ------------ | ---------------------------------------- | --------------------------------- | ------------------------- |
| Features     | Most: API keys, usage plans, caching, request validation & transformation, WAF | Lean: JWT/OIDC auth, CORS, VPC Link | Two-way, persistent connections |
| Cost         | Higher (~$3.50 / million)                | **~70% cheaper** (~$1 / million)  | Per message + connection minutes |
| Use          | Public / partner APIs needing control    | Simple proxy to Lambda / HTTP     | Chat, live dashboards     |

- **Endpoint types:** Edge-optimized (via CloudFront), Regional, Private (only from your VPC).
- **Auth:** IAM (SigV4), **Cognito user pools**, **Lambda authorizer**, JWT (HTTP API), API keys (identification, not real security).
- **Throttling:** default **10,000 req/s** per account per region (burst 5,000); per-stage / per-method / per-client limits via **usage plans**.
- **Caching** (REST): cache responses for a TTL → fewer backend calls.
- **Stages** (`dev`, `prod`) + **stage variables** + **canary releases**.
- **Integrations:** Lambda, HTTP endpoint, AWS service (e.g. put straight into SQS / DynamoDB / Step Functions), Mock, **VPC Link** (private ALB/NLB).
- **Limits to remember:** integration timeout **29 s** by default, payload **10 MB**.
- Logging / tracing: CloudWatch Logs, CloudWatch metrics, X-Ray.

---

## ALB vs API Gateway — the real difference

**ELI5:** ALB is a **traffic distributor** — it only cares about spreading load evenly. API Gateway is an **API manager** — it cares about _who_ is calling, _how often_, and _what shape_ the request is in.

|                          | ALB                                           | API Gateway                                         |
| ------------------------ | --------------------------------------------- | --------------------------------------------------- |
| Main job                 | **Distribute traffic** across healthy targets | **Manage APIs** (auth, throttle, transform, version) |
| Layer                    | L7 load balancer                              | Managed API proxy (L7)                              |
| Load balancing           | ✅ core feature (round robin / least outstanding requests) | ❌ not a load balancer (forwards to one integration) |
| Rate limiting / quotas   | ❌                                            | ✅ throttling + usage plans + API keys              |
| Auth                     | Cognito / OIDC on listener                    | IAM, Cognito, Lambda authorizer, JWT, API keys      |
| Request validation / transformation | ❌                                 | ✅ (REST API: models, mapping templates)            |
| Caching                  | ❌                                            | ✅ (REST API)                                       |
| API versioning / stages  | ❌                                            | ✅ stages, canary deploys                           |
| Direct AWS service calls | ❌                                            | ✅ (SQS, DynamoDB, Step Functions… no code)         |
| Timeout                  | Idle timeout up to **4000 s**                 | **29 s** default                                    |
| Long-lived connections   | WebSocket ✅                                  | WebSocket API (separate type)                       |
| Pricing model            | **Per hour + LCU** (cheap at high, steady traffic) | **Per request** (cheap at low / spiky traffic)  |
| Lives in                 | **Your VPC** (subnets + SG)                   | AWS-managed, outside your VPC (reach in via VPC Link) |
| Typical backend          | EC2 / ECS / EKS fleets                        | Lambda, microservices, any HTTP backend             |

**Rule of thumb:**

- Steady, high traffic to containers/EC2, just need routing + spreading → **ALB**.
- Public API needing auth, quotas, API keys, transformations, serverless/Lambda backend, or low/spiky traffic → **API Gateway**.
- Need both? → **API Gateway in front, load balancer behind** (next section).

---

## Production pattern: API Gateway routes → Load Balancers spread

**ELI5:** API Gateway is the **building's front desk** (checks badges, counts visitors, tells you which floor). The load balancer is the **floor receptionist** who sends you to whichever free counter is open on that floor. The ASG hires/fires counter staff as the queue grows/shrinks.

```
                         ┌───────────────────── AWS-managed ─────────────────────┐
Client ─► Route 53 ─► CloudFront + WAF ─► API Gateway (auth, throttle, routing)
                                               │
                         /orders/*  ───────────┼──► VPC Link ─┐
                         /users/*   ───────────┼──► VPC Link ─┤
                         /reports   ───────────┴──► Lambda    │
                                                              │
        ┌──────────────────────────── Your VPC (private subnets) ──────────────────┐
        │                                                     ▼                     │
        │           Internal NLB / ALB  ──►  Target group (ASG / ECS tasks)         │
        │                                     EC2 AZ-a   EC2 AZ-b   EC2 AZ-c         │
        └───────────────────────────────────────────────────────────────────────────┘
```

**How a request flows:**

1. **Route 53** resolves `api.example.com` (custom domain on API Gateway).
2. **CloudFront + WAF** (optional) — edge caching, DDoS/bot protection.
3. **API Gateway** — validates the JWT / Cognito token, applies throttling and usage plans, picks the route (`/orders/*`, `/users/*`), maybe transforms the request.
4. **VPC Link** — private tunnel from API Gateway into your VPC (backend stays private, no public IPs).
   - **HTTP API** VPC Link → ALB, NLB or Cloud Map.
   - **REST API** VPC Link → traditionally a **private NLB** (often **NLB → ALB** when L7 rules are needed behind it).
5. **Internal ALB / NLB** — health checks + spreads load across instances/tasks in **multiple AZs**.
6. **Auto Scaling Group / ECS Service** — adds or removes targets based on CPU, request count per target, etc.

**Why this split is used in production:**

- **Separation of concerns:** API Gateway = API concerns (security, quotas, versioning). LB = availability and spreading load.
- **Backend stays private** — only API Gateway is public; the LB and servers sit in private subnets.
- **One API, many backends:** different routes can go to different LBs/services or straight to Lambda — easy microservices + gradual migration (strangler pattern: move one route at a time from monolith to new service).
- **Throttling protects the backend** — bad clients get `429` at the gateway before they ever hit your servers.
- **Independent scaling** — API Gateway scales automatically; the ASG behind the LB scales your compute.

**When teams skip API Gateway:** very high, steady traffic to containers where per-request pricing gets expensive, or responses taking longer than 29 s → **Route 53 → (CloudFront + WAF) → public ALB → ASG/ECS** directly.

---

## Quick Recall

- Path/host based routing → **ALB**
- Static IP / Elastic IP / millions of req/s / UDP → **NLB**
- Third-party firewall fleet → **GWLB** (GENEVE 6081)
- LB that can target Lambda → **ALB**
- Rate limiting + API keys + usage plans → **API Gateway**
- API Gateway default timeout → **29 s**
- Private backend behind API Gateway → **VPC Link → internal NLB/ALB**
- Client IP behind ALB → **`X-Forwarded-For`**
- Cheap at high steady traffic → **ALB**; cheap at low/spiky traffic → **API Gateway**
