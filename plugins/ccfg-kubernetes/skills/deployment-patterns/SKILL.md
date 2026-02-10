---
name: deployment-patterns
description:
  This skill should be used when implementing deployment strategies, configuring autoscaling,
  setting up probes, managing disruption budgets, or designing zero-downtime deployments.
version: 0.1.0
---

# Kubernetes Deployment Patterns

This skill provides comprehensive patterns for implementing production-grade deployments with
zero-downtime updates, intelligent autoscaling, health monitoring, and resilience against failures.
Apply these patterns when designing workload deployments, planning rollout strategies, or
troubleshooting deployment issues.

## Existing Repository Compatibility

Before applying deployment patterns, analyze existing deployment strategies:

1. **Rollout Configuration** - Review existing deployment strategies (RollingUpdate vs Recreate,
   maxSurge, maxUnavailable)
2. **Probe Configuration** - Identify established probe patterns (HTTP endpoints, timing values,
   failure thresholds)
3. **Autoscaling Setup** - Check existing HPA/VPA configurations and scaling metrics
4. **Disruption Budgets** - Review PDB policies and availability requirements
5. **Update History** - Examine past rollout issues and lessons learned
6. **Monitoring Integration** - Understand how deployments integrate with observability stack
7. **Graceful Shutdown** - Check existing preStop hooks and termination grace periods

When refactoring deployments, preserve patterns that work well in your environment. Validate changes
in staging before applying to production. Document the reasoning behind deviation from existing
patterns.

## Rollout Strategies

Choose the appropriate deployment strategy based on workload characteristics and downtime tolerance.

### RollingUpdate Strategy

Default strategy for zero-downtime deployments.

```yaml
# CORRECT: Zero-downtime rolling update
apiVersion: apps/v1
kind: Deployment
metadata:
  name: web-api
  namespace: production
spec:
  replicas: 10
  strategy:
    type: RollingUpdate
    rollingUpdate:
      maxSurge: 25% # Can have 12-13 pods during update (10 + 2.5)
      maxUnavailable: 0 # Never reduce below 10 healthy pods
  selector:
    matchLabels:
      app.kubernetes.io/name: web-api
  template:
    metadata:
      labels:
        app.kubernetes.io/name: web-api
        app.kubernetes.io/version: '2.1.0'
    spec:
      containers:
        - name: api
          image: web-api:2.1.0
          ports:
            - containerPort: 8080
          readinessProbe:
            httpGet:
              path: /health/ready
              port: 8080
            initialDelaySeconds: 10
            periodSeconds: 5
            failureThreshold: 3
```

```yaml
# CORRECT: Conservative rolling update for critical service
apiVersion: apps/v1
kind: Deployment
metadata:
  name: payment-service
spec:
  replicas: 20
  strategy:
    type: RollingUpdate
    rollingUpdate:
      maxSurge: 1 # Add only 1 pod at a time
      maxUnavailable: 0 # Keep all 20 pods available
  minReadySeconds: 30 # Wait 30s after ready before considering healthy
  progressDeadlineSeconds: 600 # Fail deployment after 10 minutes
```

```yaml
# WRONG: Aggressive settings risk downtime
spec:
  strategy:
    type: RollingUpdate
    rollingUpdate:
      maxSurge: 100%
      maxUnavailable: 50% # Half your pods can be down - risky!
```

### RollingUpdate Parameter Guide

| Parameter                        | Recommended          | Use Case         | Risk   |
| -------------------------------- | -------------------- | ---------------- | ------ |
| maxSurge: 25%, maxUnavailable: 0 | General use          | Most services    | Low    |
| maxSurge: 1, maxUnavailable: 0   | Critical services    | Payment, auth    | Lowest |
| maxSurge: 50%, maxUnavailable: 0 | Fast rollout         | Non-critical     | Medium |
| maxSurge: 0, maxUnavailable: 25% | Resource-constrained | Limited capacity | Medium |

### Recreate Strategy

Terminate all pods before creating new ones. Use only when required.

```yaml
# CORRECT: Recreate for exclusive resource access
apiVersion: apps/v1
kind: Deployment
metadata:
  name: database-migration
spec:
  replicas: 1
  strategy:
    type: Recreate # Ensures only one version runs at a time
  template:
    spec:
      containers:
        - name: migration
          image: db-migration:1.5.0
```

#### When to use Recreate

- Database migrations requiring exclusive access
- Stateful workloads without multi-version support
- Development environments where downtime is acceptable
- Applications that cannot run multiple versions simultaneously

#### Never use Recreate for

- Production stateless services
- High-availability requirements
- Customer-facing applications

### Rollout Management

```bash
# Monitor rollout progress
kubectl rollout status deployment/web-api -n production

# View rollout history
kubectl rollout history deployment/web-api -n production

# View specific revision
kubectl rollout history deployment/web-api -n production --revision=3

# Pause rollout (stop mid-deployment)
kubectl rollout pause deployment/web-api -n production

# Resume paused rollout
kubectl rollout resume deployment/web-api -n production

# Rollback to previous version
kubectl rollout undo deployment/web-api -n production

# Rollback to specific revision
kubectl rollout undo deployment/web-api -n production --to-revision=2

# Restart deployment (rolling restart)
kubectl rollout restart deployment/web-api -n production
```

## Health Probes

Configure probes to detect failures and manage traffic appropriately.

### Probe Types and Purposes

| Probe Type | Purpose                    | Failure Action      | Use When                          |
| ---------- | -------------------------- | ------------------- | --------------------------------- |
| Liveness   | Detect deadlocks/crashes   | Restart container   | App can hang                      |
| Readiness  | Detect startup/overload    | Remove from service | Slow startup or traffic sensitive |
| Startup    | Handle slow initialization | Delay other probes  | Very slow startup (>1 min)        |

### Liveness Probe

Detects containers that are running but unhealthy (deadlocked, crashed internal state).

```yaml
# CORRECT: HTTP liveness probe
apiVersion: v1
kind: Pod
metadata:
  name: web-api
spec:
  containers:
    - name: api
      image: web-api:1.0.0
      ports:
        - containerPort: 8080
      livenessProbe:
        httpGet:
          path: /health/live
          port: 8080
          httpHeaders:
            - name: X-Health-Check
              value: liveness
        initialDelaySeconds: 60 # Wait for app to start
        periodSeconds: 10 # Check every 10 seconds
        timeoutSeconds: 5 # 5 second timeout
        failureThreshold: 3 # Restart after 3 consecutive failures
        successThreshold: 1 # Back to healthy after 1 success
```

```yaml
# CORRECT: TCP liveness probe for non-HTTP services
apiVersion: v1
kind: Pod
metadata:
  name: redis
spec:
  containers:
    - name: redis
      image: redis:7
      ports:
        - containerPort: 6379
      livenessProbe:
        tcpSocket:
          port: 6379
        initialDelaySeconds: 30
        periodSeconds: 10
        timeoutSeconds: 5
        failureThreshold: 3
```

```yaml
# CORRECT: Exec liveness probe with custom script
apiVersion: v1
kind: Pod
metadata:
  name: custom-app
spec:
  containers:
    - name: app
      image: custom-app:1.0.0
      livenessProbe:
        exec:
          command:
            - /bin/sh
            - -c
            - /app/healthcheck.sh --liveness
        initialDelaySeconds: 45
        periodSeconds: 15
        timeoutSeconds: 10
        failureThreshold: 3
```

```yaml
# WRONG: Aggressive liveness probe causes restart loops
livenessProbe:
  httpGet:
    path: /health
    port: 8080
  initialDelaySeconds: 5 # Too short, app not ready
  periodSeconds: 5
  timeoutSeconds: 1 # Too short, false positives
  failureThreshold: 1 # Too aggressive, restarts on transient issues
```

### Readiness Probe

Determines when container can receive traffic. Failed readiness removes pod from service endpoints.

```yaml
# CORRECT: Readiness probe for gradual startup
apiVersion: v1
kind: Pod
metadata:
  name: web-api
spec:
  containers:
    - name: api
      image: web-api:1.0.0
      ports:
        - containerPort: 8080
      readinessProbe:
        httpGet:
          path: /health/ready
          port: 8080
        initialDelaySeconds: 10 # Start checking after 10s
        periodSeconds: 5 # Check frequently during startup
        timeoutSeconds: 3
        failureThreshold: 3
        successThreshold: 1
```

#### Readiness endpoint should check

- Application initialization complete
- Database connections established
- Required dependencies available
- Cache warmed up (if applicable)
- Not overloaded (can accept more traffic)

#### Readiness endpoint should NOT check

- External service availability (unless required for every request)
- Downstream service health (unless critical dependency)

```yaml
# CORRECT: Readiness during overload conditions
# Application code in /health/ready endpoint
# Returns 503 when queue depth > threshold
apiVersion: v1
kind: Pod
metadata:
  name: worker
spec:
  containers:
    - name: worker
      image: worker:1.0.0
      readinessProbe:
        httpGet:
          path: /health/ready # Returns 503 if queue > 1000
          port: 8080
        periodSeconds: 5
        failureThreshold: 2 # Fail quickly when overloaded
        successThreshold: 2 # Require stability before returning
```

### Startup Probe

Delays liveness/readiness checks for slow-starting containers.

```yaml
# CORRECT: Startup probe for slow initialization
apiVersion: v1
kind: Pod
metadata:
  name: java-app
spec:
  containers:
    - name: app
      image: java-app:1.0.0
      ports:
        - containerPort: 8080
      startupProbe:
        httpGet:
          path: /health/startup
          port: 8080
        initialDelaySeconds: 0
        periodSeconds: 10
        failureThreshold: 30 # 30 * 10s = 5 minutes max startup time
        successThreshold: 1
      livenessProbe:
        httpGet:
          path: /health/live
          port: 8080
        periodSeconds: 10
        failureThreshold: 3
      readinessProbe:
        httpGet:
          path: /health/ready
          port: 8080
        periodSeconds: 5
        failureThreshold: 3
```

#### Startup probe flow

1. Container starts
2. Startup probe runs (liveness/readiness disabled)
3. Once startup succeeds, liveness/readiness probes begin
4. If startup never succeeds, container restarts after failureThreshold

### Probe Timing Guidelines

| Application Type              | initialDelaySeconds | periodSeconds | timeoutSeconds | failureThreshold |
| ----------------------------- | ------------------- | ------------- | -------------- | ---------------- |
| Fast startup (Node.js, Go)    | 10-15               | 10            | 5              | 3                |
| Medium startup (Python, Ruby) | 30-45               | 10            | 5              | 3                |
| Slow startup (Java, .NET)     | Use startup probe   | 10            | 5              | 3                |
| Database                      | 30-60               | 10            | 5              | 3                |

### Common Probe Pitfalls

```yaml
# WRONG: Liveness and readiness check different endpoints
livenessProbe:
  httpGet:
    path: /health/live # Checks app liveness
readinessProbe:
  httpGet:
    path: /metrics # Wrong - checks Prometheus endpoint
```

```yaml
# WRONG: Readiness checks external dependencies
# GET /health/ready implementation
# if (!canConnectToPaymentGateway()) return 503
# This removes pod from rotation when external service is down
# Pod should stay ready and return errors to clients instead
```

```yaml
# WRONG: Too aggressive timing causes flapping
readinessProbe:
  httpGet:
    path: /health/ready
  periodSeconds: 1 # Too frequent, wastes CPU
  failureThreshold: 1 # Removes from service on first blip
  successThreshold: 1 # Returns immediately, causes flapping
```

## Autoscaling

Automatically adjust replica count based on resource utilization or custom metrics.

### Horizontal Pod Autoscaler (HPA)

Scale number of pods based on metrics.

```yaml
# CORRECT: HPA based on CPU and memory
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: web-api-hpa
  namespace: production
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: web-api
  minReplicas: 5
  maxReplicas: 50
  metrics:
    - type: Resource
      resource:
        name: cpu
        target:
          type: Utilization
          averageUtilization: 70 # Scale when average CPU > 70%
    - type: Resource
      resource:
        name: memory
        target:
          type: Utilization
          averageUtilization: 80 # Scale when average memory > 80%
  behavior:
    scaleDown:
      stabilizationWindowSeconds: 300 # Wait 5 minutes before scaling down
      policies:
        - type: Percent
          value: 50 # Scale down max 50% of pods
          periodSeconds: 60 # Every 60 seconds
        - type: Pods
          value: 2 # Or max 2 pods
          periodSeconds: 60 # Every 60 seconds
      selectPolicy: Min # Use most conservative policy
    scaleUp:
      stabilizationWindowSeconds: 0 # Scale up immediately
      policies:
        - type: Percent
          value: 100 # Scale up max 100% of pods (double)
          periodSeconds: 15 # Every 15 seconds
        - type: Pods
          value: 4 # Or max 4 pods
          periodSeconds: 15 # Every 15 seconds
      selectPolicy: Max # Use most aggressive policy
```

```yaml
# CORRECT: HPA based on custom metrics (requests per second)
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: web-api-hpa-custom
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: web-api
  minReplicas: 3
  maxReplicas: 30
  metrics:
    - type: Pods
      pods:
        metric:
          name: http_requests_per_second
        target:
          type: AverageValue
          averageValue: '1000' # Scale when RPS > 1000 per pod
```

```yaml
# CORRECT: HPA with external metrics (SQS queue depth)
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: worker-hpa
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: worker
  minReplicas: 2
  maxReplicas: 100
  metrics:
    - type: External
      external:
        metric:
          name: sqs_queue_depth
          selector:
            matchLabels:
              queue: processing
        target:
          type: AverageValue
          averageValue: '30' # 30 messages per pod
```

### HPA Best Practices

1. **Set Conservative Targets** - 70-80% utilization gives headroom for spikes
2. **Prevent Thrashing** - Use stabilizationWindowSeconds for scale-down
3. **Gradual Scaling** - Limit scale-up/down rates with behavior policies
4. **Resource Requests Required** - HPA needs accurate resource requests to calculate utilization
5. **Monitor HPA Decisions** - Check HPA events and metrics

```bash
# View HPA status
kubectl get hpa -n production

# Describe HPA to see events and decisions
kubectl describe hpa web-api-hpa -n production

# View HPA metrics
kubectl get hpa web-api-hpa -n production -o yaml

# Test HPA by generating load
kubectl run -i --tty load-generator --rm --image=busybox --restart=Never -- /bin/sh -c "while sleep 0.01; do wget -q -O- http://web-api; done"
```

### Vertical Pod Autoscaler (VPA)

Adjust resource requests/limits based on actual usage.

```yaml
# CORRECT: VPA in recommend-only mode
apiVersion: autoscaling.k8s.io/v1
kind: VerticalPodAutoscaler
metadata:
  name: web-api-vpa
  namespace: production
spec:
  targetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: web-api
  updateMode: 'Off' # Recommend only, don't auto-apply
  resourcePolicy:
    containerPolicies:
      - containerName: api
        minAllowed:
          cpu: 100m
          memory: 128Mi
        maxAllowed:
          cpu: 4000m
          memory: 8Gi
        controlledResources:
          - cpu
          - memory
```

```yaml
# CORRECT: VPA in auto mode for non-critical workload
apiVersion: autoscaling.k8s.io/v1
kind: VerticalPodAutoscaler
metadata:
  name: background-worker-vpa
spec:
  targetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: background-worker
  updateMode: 'Auto' # Automatically apply recommendations
  updatePolicy:
    updateMode: 'Auto'
```

#### VPA Update Modes

| Mode     | Behavior                  | Use Case                            |
| -------- | ------------------------- | ----------------------------------- |
| Off      | Recommend only            | Production (review before applying) |
| Initial  | Set on pod creation only  | New deployments                     |
| Recreate | Update by recreating pods | Non-critical workloads              |
| Auto     | Update by recreating pods | Development environments            |

#### Important VPA Limitations

- Do NOT use HPA and VPA on the same metric (CPU/memory)
- VPA requires pod restarts to apply changes
- Recommendations take 24-48 hours to stabilize

### KEDA (Event-Driven Autoscaling)

Scale based on event sources (queues, streams, schedules).

```yaml
# CORRECT: KEDA ScaledObject for RabbitMQ queue
apiVersion: keda.sh/v1alpha1
kind: ScaledObject
metadata:
  name: rabbitmq-consumer-scaler
  namespace: production
spec:
  scaleTargetRef:
    name: rabbitmq-consumer
  minReplicaCount: 2
  maxReplicaCount: 30
  pollingInterval: 30
  cooldownPeriod: 300
  triggers:
    - type: rabbitmq
      metadata:
        queueName: processing
        mode: QueueLength
        value: '20' # Maintain 20 messages per pod
        host: amqp://rabbitmq:5672
```

```yaml
# CORRECT: KEDA ScaledObject for scheduled scaling
apiVersion: keda.sh/v1alpha1
kind: ScaledObject
metadata:
  name: scheduled-scaler
spec:
  scaleTargetRef:
    name: web-api
  minReplicaCount: 5
  maxReplicaCount: 50
  triggers:
    - type: cron
      metadata:
        timezone: America/New_York
        start: 0 8 * * 1-5 # Scale up Mon-Fri at 8 AM
        end: 0 18 * * 1-5 # Scale down Mon-Fri at 6 PM
        desiredReplicas: '20'
```

## Pod Disruption Budgets

Protect availability during voluntary disruptions (node drains, cluster upgrades).

```yaml
# CORRECT: PDB ensuring minimum availability
apiVersion: policy/v1
kind: PodDisruptionBudget
metadata:
  name: web-api-pdb
  namespace: production
spec:
  minAvailable: 3 # Always keep at least 3 pods running
  selector:
    matchLabels:
      app.kubernetes.io/name: web-api
```

```yaml
# CORRECT: PDB with percentage
apiVersion: policy/v1
kind: PodDisruptionBudget
metadata:
  name: web-api-pdb
spec:
  minAvailable: 80% # Keep at least 80% of pods available
  selector:
    matchLabels:
      app.kubernetes.io/name: web-api
```

```yaml
# CORRECT: PDB with maxUnavailable
apiVersion: policy/v1
kind: PodDisruptionBudget
metadata:
  name: web-api-pdb
spec:
  maxUnavailable: 1 # Allow max 1 pod to be unavailable
  selector:
    matchLabels:
      app.kubernetes.io/name: web-api
```

### PDB Selection Guidelines

| Scenario                  | Recommendation           | Reasoning                                   |
| ------------------------- | ------------------------ | ------------------------------------------- |
| High-availability service | minAvailable: N-1 or 80% | Maintain capacity during disruptions        |
| Single replica            | Don't use PDB            | Would block all disruptions                 |
| 2-3 replicas              | maxUnavailable: 1        | Allow disruptions while maintaining service |
| Large deployment (10+)    | minAvailable: 75-80%     | Balance availability and disruption speed   |

```yaml
# WRONG: PDB blocks all disruptions
apiVersion: policy/v1
kind: PodDisruptionBudget
metadata:
  name: bad-pdb
spec:
  minAvailable: 3
  selector:
    matchLabels:
      app: myapp
# Deployment only has 3 replicas - PDB prevents any voluntary disruptions!
```

## Topology Spread Constraints

Distribute pods across zones and nodes for resilience.

```yaml
# CORRECT: Spread across availability zones
apiVersion: apps/v1
kind: Deployment
metadata:
  name: web-api
spec:
  replicas: 9
  template:
    spec:
      topologySpreadConstraints:
        - maxSkew: 1
          topologyKey: topology.kubernetes.io/zone
          whenUnsatisfiable: DoNotSchedule
          labelSelector:
            matchLabels:
              app.kubernetes.io/name: web-api
        - maxSkew: 2
          topologyKey: kubernetes.io/hostname
          whenUnsatisfiable: ScheduleAnyway
          labelSelector:
            matchLabels:
              app.kubernetes.io/name: web-api
```

### Topology Spread Parameters

- **maxSkew** - Maximum difference in pod count between topology domains
- **topologyKey** - Node label key defining domains (zone, hostname, etc.)
- **whenUnsatisfiable** - DoNotSchedule (hard) or ScheduleAnyway (soft)
- **labelSelector** - Which pods to consider for spreading

### Pod Anti-Affinity

Avoid scheduling pods on same node/zone.

```yaml
# CORRECT: Prefer different nodes, require different zones
apiVersion: apps/v1
kind: Deployment
metadata:
  name: web-api
spec:
  template:
    spec:
      affinity:
        podAntiAffinity:
          requiredDuringSchedulingIgnoredDuringExecution:
            - labelSelector:
                matchLabels:
                  app.kubernetes.io/name: web-api
              topologyKey: topology.kubernetes.io/zone
          preferredDuringSchedulingIgnoredDuringExecution:
            - weight: 100
              podAffinityTerm:
                labelSelector:
                  matchLabels:
                    app.kubernetes.io/name: web-api
                topologyKey: kubernetes.io/hostname
```

## Zero-Downtime Deployments

Achieve true zero-downtime with proper graceful shutdown and load balancer integration.

### Graceful Shutdown Pattern

```yaml
# CORRECT: Complete zero-downtime configuration
apiVersion: apps/v1
kind: Deployment
metadata:
  name: web-api
spec:
  replicas: 10
  strategy:
    type: RollingUpdate
    rollingUpdate:
      maxSurge: 25%
      maxUnavailable: 0
  template:
    spec:
      containers:
        - name: api
          image: web-api:2.0.0
          ports:
            - containerPort: 8080
              name: http
          lifecycle:
            preStop:
              exec:
                command:
                  - /bin/sh
                  - -c
                  - sleep 15 # Wait for load balancer to deregister
          readinessProbe:
            httpGet:
              path: /health/ready
              port: 8080
            initialDelaySeconds: 10
            periodSeconds: 5
            failureThreshold: 1 # Fail immediately on shutdown
          livenessProbe:
            httpGet:
              path: /health/live
              port: 8080
            initialDelaySeconds: 60
            periodSeconds: 10
      terminationGracePeriodSeconds: 60
```

### Zero-Downtime Deployment Flow

1. **New Pod Created** - Scheduler assigns to node
2. **Pod Starting** - Container starts, startup probe runs
3. **Pod Ready** - Readiness succeeds, added to service endpoints
4. **Load Balancer Updated** - Takes 5-15 seconds depending on provider
5. **Old Pod SIGTERM** - Kubernetes sends termination signal
6. **PreStop Hook** - Sleep to wait for LB deregistration
7. **Readiness Fails** - App stops accepting new requests, removed from endpoints
8. **Existing Requests Finish** - App completes in-flight requests
9. **SIGKILL** - After terminationGracePeriodSeconds if still running

### Application Code for Graceful Shutdown

```go
// CORRECT: Go application graceful shutdown
package main

import (
    "context"
    "net/http"
    "os"
    "os/signal"
    "syscall"
    "time"
)

func main() {
    srv := &http.Server{Addr: ":8080"}

    // Start server
    go func() {
        if err := srv.ListenAndServe(); err != http.ErrServerClosed {
            log.Fatal(err)
        }
    }()

    // Wait for SIGTERM
    quit := make(chan os.Signal, 1)
    signal.Notify(quit, syscall.SIGTERM, syscall.SIGINT)
    <-quit

    // Fail readiness immediately
    readinessProbe.Fail()

    // Graceful shutdown with 30s timeout
    ctx, cancel := context.WithTimeout(context.Background(), 30*time.Second)
    defer cancel()

    if err := srv.Shutdown(ctx); err != nil {
        log.Fatal(err)
    }
}
```

### Timing Configuration

| Setting                       | Value | Purpose                      |
| ----------------------------- | ----- | ---------------------------- |
| preStop sleep                 | 15s   | Wait for LB deregistration   |
| terminationGracePeriodSeconds | 60s   | Time to finish requests      |
| readiness failureThreshold    | 1     | Remove from service quickly  |
| Max request duration          | < 45s | Must complete before SIGKILL |

```yaml
# WRONG: Missing graceful shutdown
spec:
  terminationGracePeriodSeconds: 30
  containers:
    - name: api
      # No preStop hook - app receives traffic during shutdown
      # No readiness probe - stays in endpoints during shutdown
      # Requests are dropped mid-flight
```

## Progressive Delivery

Advanced deployment patterns for reduced risk.

### Blue-Green Deployment

```yaml
# Blue deployment (current production)
apiVersion: apps/v1
kind: Deployment
metadata:
  name: web-api-blue
  labels:
    version: blue
spec:
  replicas: 10
  selector:
    matchLabels:
      app: web-api
      version: blue
  template:
    metadata:
      labels:
        app: web-api
        version: blue
    spec:
      containers:
        - name: api
          image: web-api:1.0.0

---
# Green deployment (new version)
apiVersion: apps/v1
kind: Deployment
metadata:
  name: web-api-green
  labels:
    version: green
spec:
  replicas: 10
  selector:
    matchLabels:
      app: web-api
      version: green
  template:
    metadata:
      labels:
        app: web-api
        version: green
    spec:
      containers:
        - name: api
          image: web-api:2.0.0

---
# Service (switch by changing selector)
apiVersion: v1
kind: Service
metadata:
  name: web-api
spec:
  selector:
    app: web-api
    version: blue # Change to 'green' to switch versions
  ports:
    - port: 80
      targetPort: 8080
```

### Canary Deployment

Use service mesh or ingress weights for gradual rollout.

```yaml
# 90% traffic to stable, 10% to canary
apiVersion: v1
kind: Service
metadata:
  name: web-api-stable
spec:
  selector:
    app: web-api
    version: stable
  ports:
    - port: 80
      targetPort: 8080

---
apiVersion: v1
kind: Service
metadata:
  name: web-api-canary
spec:
  selector:
    app: web-api
    version: canary
  ports:
    - port: 80
      targetPort: 8080

---
# Nginx Ingress with traffic splitting
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: web-api
  annotations:
    nginx.ingress.kubernetes.io/canary: 'true'
    nginx.ingress.kubernetes.io/canary-weight: '10'
spec:
  rules:
    - host: api.example.com
      http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: web-api-canary
                port:
                  number: 80
```

## Deployment Checklist

Before deploying to production, verify:

- [ ] Strategy is RollingUpdate with maxUnavailable: 0
- [ ] Resources requests and limits defined
- [ ] Readiness probe configured correctly
- [ ] Liveness probe with conservative timing
- [ ] Startup probe for slow-starting apps
- [ ] preStop hook with LB drain delay
- [ ] terminationGracePeriodSeconds ≥ max request duration + 30s
- [ ] PodDisruptionBudget configured
- [ ] HPA configured for scalable workloads
- [ ] TopologySpreadConstraints or anti-affinity
- [ ] Deployment tested in staging environment
- [ ] Rollback plan documented
- [ ] Monitoring and alerts configured

Apply these patterns consistently to achieve reliable, zero-downtime deployments.
