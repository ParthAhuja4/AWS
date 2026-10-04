# AWS Lambda & How It Auto Scales — ELI5 Notes

**Big picture:** Lambda = a kitchen that hires a new cook the instant a new order arrives, and sends them home when there are no orders. You only pay for the seconds the cooks are actually cooking.

---

## What is Lambda?

**ELI5:** You hand AWS a recipe (your code). Whenever an order (event) comes in, AWS finds a cook, gives them the recipe, they cook, done. You never see or manage the kitchen (servers).

- **Serverless compute** — no EC2, no OS patching, no capacity planning.
- Runs code **in response to events**; you pay **per request + per GB-second** (billed per **1 ms**).
- **Free tier:** 1 million requests + 400,000 GB-seconds per month.
- Runtimes: Python, Node.js, Java, .NET, Ruby, or any language via **custom runtime** / **container image** (up to 10 GB).

### Key limits

| Setting              | Value                                                   |
| -------------------- | ------------------------------------------------------- |
| Max timeout          | **15 minutes**                                          |
| Memory               | **128 MB – 10,240 MB** (CPU scales with memory; ~1,769 MB = 1 vCPU) |
| `/tmp` storage       | 512 MB – 10 GB                                          |
| Sync payload         | **6 MB** request/response                               |
| Deployment package   | 50 MB zipped (direct upload), 250 MB unzipped, 10 GB container image |
| Env variables        | 4 KB total                                              |
| Concurrency (default)| **1,000 per region per account** (soft limit, can raise) |

> More memory = more CPU = often **faster and not more expensive** (shorter duration). Tune it.

### How Lambda gets invoked

| Type             | Who calls it                                   | On error / throttle                          |
| ---------------- | ---------------------------------------------- | -------------------------------------------- |
| **Synchronous**  | API Gateway, ALB, SDK `invoke`, Cognito         | Caller gets the error / `429` and must retry |
| **Asynchronous** | S3 events, SNS, EventBridge                     | Lambda queues it, **retries 2 times**, then → DLQ / on-failure destination |
| **Event source mapping (poll)** | SQS, Kinesis, DynamoDB Streams, Kafka, MQ | Lambda's **pollers** read batches and invoke your function |

```
S3 upload ─┐
SQS msg  ──┼──► Lambda function ──► DynamoDB / S3 / another service
API call ──┘
```

---

## Execution environment, cold & warm starts

**ELI5:** A **cold start** is hiring a new cook — they need to put on the apron and read the recipe first (slow). A **warm start** is a cook already standing at the stove — just hand them the next order (fast).

- Each **execution environment** = a tiny isolated micro-VM (Firecracker) with your code loaded.
- **One environment handles ONE request at a time.**
- Lifecycle: **Init** (download code, start runtime, run code outside the handler) → **Invoke** (run handler) → stays **frozen/warm** for reuse → eventually **shut down**.
- **Cold start** = Init phase happens → adds latency (ms to a few seconds; worst with Java, big packages, VPC in the old days).
- **Warm start** = reused environment → only the handler runs.
- Tip: create DB connections / SDK clients **outside the handler** → reused across warm invocations.

---

## How AWS auto scales Lambda

**ELI5:** Every new order that arrives while all cooks are busy → AWS hires **another cook**. Orders slow down → idle cooks are sent home. You set nothing; it just happens.

### 1. Scaling unit = concurrency

- **Concurrency** = number of requests running **at the same moment** = number of busy execution environments.
- Formula:

```
concurrency = requests per second × average duration (seconds)

e.g. 100 req/s × 0.5 s = 50 concurrent environments
     100 req/s × 2 s   = 200 concurrent environments
```

- Faster code → fewer environments needed for the same traffic.

### 2. Scaling flow

```
Request arrives
     │
     ▼
Is there a free warm environment? ── yes ──► reuse it (warm start)
     │ no
     ▼
Under concurrency limit? ── no ──► THROTTLE (429 / retry / stays in queue)
     │ yes
     ▼
Create new environment (cold start) ──► run handler
     │
Idle for a while ──► AWS shuts it down (scale to zero)
```

### 3. Scaling rate (how fast it adds cooks)

- Each function can scale up by **1,000 concurrent executions every 10 seconds** (per function, independently).
- Keeps going until it hits the **account concurrency limit** (default **1,000 per region**, shared by all functions in that region) or the function's **reserved concurrency**.
- Scales **down to zero** automatically → no traffic = no cost.

### 4. Scaling differs per event source

| Source                          | How it scales                                                                 |
| ------------------------------- | ----------------------------------------------------------------------------- |
| API Gateway / ALB / SDK (sync)  | One environment per in-flight request, up to concurrency limit                |
| S3 / SNS / EventBridge (async)  | Events go into Lambda's internal queue; scales like above; throttled events retried for up to **6 h** |
| **SQS**                         | Pollers scale up as the queue grows (adds up to ~300 concurrent invokes/minute); cap it with **maximum concurrency** on the event source mapping |
| **Kinesis / DynamoDB Streams**  | **1 invocation per shard** by default; up to **10 per shard** with *parallelization factor* (order kept per partition key) |

### 5. Throttling — what happens when the limit is hit

- **Sync** → caller gets **`429 TooManyRequestsException`** (API Gateway returns 429/5xx to the client).
- **Async** → Lambda retries automatically for up to 6 hours, then sends to **DLQ / on-failure destination**.
- **SQS** → messages stay in the queue and are retried after the visibility timeout.

---

## Controlling the scaling

**ELI5:** You can **reserve** some cooks only for one dish, and you can **pre-hire** cooks who stand ready with aprons on so nobody waits.

### Reserved concurrency (free)

- **Guarantees** a function N concurrency out of the account pool **and caps it at N**.
- Use to: protect a critical function from being starved, **or** protect a downstream DB from being flooded (e.g. cap at 50 so RDS isn't overwhelmed).
- Set it to **0** → function is fully throttled (emergency "off switch").

### Provisioned concurrency (paid)

- Keeps N environments **pre-initialised and warm** → **no cold starts** for those N.
- You pay for it even when idle.
- Can itself **auto scale** with **Application Auto Scaling**:
  - **Scheduled** — e.g. 500 warm environments 9 AM–6 PM, 50 at night.
  - **Target tracking** — on `ProvisionedConcurrencyUtilization` (e.g. keep at 70%).
- Traffic beyond the provisioned amount still scales normally (with cold starts) up to the limits.
- Works on a **version or alias**, not `$LATEST`.

### SnapStart

- Snapshots the initialised environment and restores from it → much faster cold starts (Java, Python, .NET). Free for Java.

|                      | Reserved concurrency       | Provisioned concurrency            |
| -------------------- | -------------------------- | ---------------------------------- |
| Purpose              | Guarantee + **cap**        | **Remove cold starts**             |
| Cost                 | Free                       | Paid (per hour, even idle)         |
| Pre-warmed?          | ❌                         | ✅                                 |
| Auto scaling         | N/A                        | ✅ via Application Auto Scaling    |

---

## Lambda scaling vs EC2 Auto Scaling

|                     | Lambda                                  | EC2 + ASG                                     |
| ------------------- | --------------------------------------- | --------------------------------------------- |
| Who scales          | AWS, automatically, per request         | You configure ASG policies                    |
| Scaling speed       | Seconds (1,000 envs / 10 s per function)| Minutes (boot instance + health check)        |
| Scale to zero       | ✅                                      | ❌ (min capacity usually ≥ 1)                 |
| Unit                | 1 environment = 1 concurrent request    | 1 instance = many concurrent requests         |
| Max run time        | 15 min                                  | Unlimited                                     |
| Cost model          | Per request + GB-second                 | Per instance-second, even when idle           |
| Best for            | Spiky, event-driven, short tasks        | Steady, long-running, stateful workloads      |

---

## Quick Recall

- Concurrency formula → **req/s × avg duration**
- One execution environment handles → **one request at a time**
- Default account concurrency → **1,000 per region** (soft limit)
- Scaling rate per function → **+1,000 concurrency every 10 s**
- Sync throttle error → **429 TooManyRequestsException**
- Async failed events → retried **2×**, then **DLQ / destination**
- Kill switch for a function → **reserved concurrency = 0**
- No cold starts → **provisioned concurrency** (or SnapStart)
- Protect a downstream DB → **reserved concurrency cap** / SQS **maximum concurrency**
- Max timeout → **15 min**; max memory → **10,240 MB**
