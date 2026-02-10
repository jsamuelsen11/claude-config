---
name: deployment-patterns
description:
  This skill should be used when implementing CD pipelines, configuring deployment environments,
  setting up OIDC authentication, or designing rollback strategies.
version: 0.1.0
---

# Deployment Patterns for GitHub Actions

This skill provides comprehensive guidance for implementing continuous deployment pipelines using
GitHub Actions. These patterns ensure safe, reliable, and auditable deployments across multiple
environments and cloud providers.

## Existing Repository Compatibility

When implementing deployment patterns in existing repositories, thorough analysis is critical:

**Discovery and Assessment**:

1. Document existing deployment workflows and their triggers
2. Review current environment configuration (staging, production, etc.)
3. Identify authentication methods currently in use (keys, OIDC, etc.)
4. Map deployment permissions and approval processes
5. Understand rollback procedures and incident history
6. Check for existing deployment monitoring and alerting
7. Review deployment frequency and success rates
8. Identify dependencies between services and deployment order

**Safety Considerations**:

- Never modify production deployment workflows without thorough testing
- Test new deployment patterns in staging environment first
- Maintain existing deployment approval gates during migration
- Keep existing authentication mechanisms during OIDC transition
- Preserve deployment audit logs and history
- Document all changes to deployment processes
- Coordinate with on-call teams before changing production workflows
- Have rollback plans for workflow changes themselves

**Migration Strategies**:

- Run new deployment workflows in parallel with old ones initially
- Use feature flags or branch conditions to test new deployment logic
- Migrate non-production environments first
- Gradually transition authentication from credentials to OIDC
- Maintain backward compatibility during transition periods
- Update runbooks and documentation before changing workflows
- Schedule deployment workflow changes during low-traffic periods
- Monitor metrics closely after workflow changes

**Team Coordination**:

- Communicate deployment workflow changes to all stakeholders
- Update on-call runbooks and incident response procedures
- Train team members on new deployment processes
- Establish clear ownership of deployment workflows
- Define escalation paths for deployment failures
- Document emergency rollback procedures
- Create testing environments for deployment workflow development

## GitHub Environments

Environments provide deployment protection rules, secrets, and audit trails:

**CORRECT - Environment Configuration**:

```yaml
name: Deploy to Production

on:
  push:
    branches: [main]
  workflow_dispatch:

jobs:
  deploy-staging:
    runs-on: ubuntu-latest
    environment:
      name: staging
      url: https://staging.example.com

    steps:
      - name: Checkout code
        uses: actions/checkout@v4

      - name: Deploy to staging
        run: |
          echo "Deploying to staging environment"
          ./deploy.sh staging

      - name: Run smoke tests
        run: ./smoke-tests.sh https://staging.example.com

  deploy-production:
    needs: deploy-staging
    runs-on: ubuntu-latest
    environment:
      name: production
      url: https://example.com

    steps:
      - name: Checkout code
        uses: actions/checkout@v4

      - name: Deploy to production
        run: |
          echo "Deploying to production environment"
          ./deploy.sh production

      - name: Verify deployment
        run: ./health-check.sh https://example.com
```

**CORRECT - Multiple Environments with Conditionals**:

```yaml
name: Multi-Environment Deployment

on:
  workflow_dispatch:
    inputs:
      environment:
        description: 'Environment to deploy to'
        required: true
        type: choice
        options:
          - development
          - staging
          - production

jobs:
  deploy:
    runs-on: ubuntu-latest
    environment:
      name: ${{ inputs.environment }}
      url: ${{ steps.deploy.outputs.url }}

    steps:
      - name: Checkout code
        uses: actions/checkout@v4

      - name: Deploy application
        id: deploy
        env:
          ENVIRONMENT: ${{ inputs.environment }}
        run: |
          URL=$(./deploy.sh ${ENVIRONMENT})
          echo "url=${URL}" >> $GITHUB_OUTPUT
          echo "Deployed to ${URL}"

      - name: Post-deployment verification
        run: |
          ./verify.sh ${{ steps.deploy.outputs.url }}
```

**CORRECT - Environment-Specific Secrets**:

```yaml
jobs:
  deploy:
    runs-on: ubuntu-latest
    environment: production

    steps:
      - name: Deploy with environment secrets
        env:
          # These secrets are defined in the 'production' environment
          # and override any repository-level secrets with the same name
          DATABASE_URL: ${{ secrets.DATABASE_URL }}
          API_KEY: ${{ secrets.API_KEY }}
          DEPLOY_TOKEN: ${{ secrets.DEPLOY_TOKEN }}
        run: |
          ./deploy.sh production
```

**Environment Protection Rules**:

Configure these in GitHub repository settings under Environments:

1. **Required Reviewers**: Specify users/teams who must approve deployments

   ```yaml
   # No workflow configuration needed - set in GitHub UI
   # Protection rule: Require 2 reviewers from the 'platform-team'
   ```

2. **Wait Timer**: Delay deployment by specified minutes

   ```yaml
   # Set in GitHub UI: Wait 15 minutes before allowing deployment
   # Useful for scheduled maintenance windows
   ```

3. **Deployment Branches**: Restrict which branches can deploy

   ```yaml
   # Set in GitHub UI: Only 'main' and 'release/*' can deploy to production
   ```

4. **Custom Deployment Protection Rules**: Use GitHub Apps for advanced checks

   ```yaml
   # Example: Require security scan pass, no active incidents, etc.
   ```

**WRONG - No Environment Configuration**:

```yaml
jobs:
  deploy:
    runs-on: ubuntu-latest
    # Missing environment configuration
    # No protection rules, audit trail, or environment-specific secrets
    steps:
      - run: ./deploy.sh production
```

**WRONG - Hardcoded Secrets Instead of Environment Secrets**:

```yaml
jobs:
  deploy:
    runs-on: ubuntu-latest
    environment: production
    steps:
      - name: Deploy
        env:
          # WRONG: Using repository secrets instead of environment secrets
          DATABASE_URL: ${{ secrets.PROD_DATABASE_URL }}
          # Better: Use DATABASE_URL defined in production environment
        run: ./deploy.sh
```

**Environment Best Practices**:

| Environment | Protection Rules        | Deployment Branches | Use Case                  |
| ----------- | ----------------------- | ------------------- | ------------------------- |
| Development | None                    | Any branch          | Rapid iteration, testing  |
| Staging     | Wait timer (5 min)      | main, develop       | Pre-production validation |
| Production  | Required reviewers (2+) | main only           | Live customer-facing      |
| Canary      | Required reviewer (1)   | main only           | Progressive rollout       |

## OIDC Authentication

OpenID Connect eliminates long-lived credentials for cloud provider authentication:

**CORRECT - AWS OIDC Configuration**:

```yaml
name: Deploy to AWS

on:
  push:
    branches: [main]

permissions:
  contents: read
  id-token: write # Required for OIDC

jobs:
  deploy:
    runs-on: ubuntu-latest
    environment: production

    steps:
      - name: Checkout code
        uses: actions/checkout@v4

      - name: Configure AWS credentials
        uses: aws-actions/configure-aws-credentials@v4
        with:
          role-to-assume: arn:aws:iam::123456789012:role/GitHubActionsDeploymentRole
          aws-region: us-east-1
          role-session-name: GitHubActions-${{ github.run_id }}

      - name: Deploy to S3
        run: |
          aws s3 sync ./dist s3://my-production-bucket --delete

      - name: Invalidate CloudFront
        run: |
          aws cloudfront create-invalidation \
            --distribution-id E1234567890ABC \
            --paths "/*"
```

**AWS IAM Role Trust Policy**:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Federated": "arn:aws:iam::123456789012:oidc-provider/token.actions.githubusercontent.com"
      },
      "Action": "sts:AssumeRoleWithWebIdentity",
      "Condition": {
        "StringEquals": {
          "token.actions.githubusercontent.com:aud": "sts.amazonaws.com",
          "token.actions.githubusercontent.com:sub": "repo:myorg/myrepo:ref:refs/heads/main"
        }
      }
    }
  ]
}
```

**CORRECT - Azure OIDC Configuration**:

```yaml
name: Deploy to Azure

on:
  push:
    branches: [main]

permissions:
  contents: read
  id-token: write

jobs:
  deploy:
    runs-on: ubuntu-latest
    environment: production

    steps:
      - name: Checkout code
        uses: actions/checkout@v4

      - name: Azure login with OIDC
        uses: azure/login@v2
        with:
          client-id: ${{ secrets.AZURE_CLIENT_ID }}
          tenant-id: ${{ secrets.AZURE_TENANT_ID }}
          subscription-id: ${{ secrets.AZURE_SUBSCRIPTION_ID }}

      - name: Deploy to Azure Web App
        uses: azure/webapps-deploy@v3
        with:
          app-name: my-production-app
          package: ./dist

      - name: Azure logout
        if: always()
        run: az logout
```

**CORRECT - Google Cloud OIDC Configuration**:

```yaml
name: Deploy to GCP

on:
  push:
    branches: [main]

permissions:
  contents: read
  id-token: write

jobs:
  deploy:
    runs-on: ubuntu-latest
    environment: production

    steps:
      - name: Checkout code
        uses: actions/checkout@v4

      - name: Authenticate to Google Cloud
        uses: google-github-actions/auth@v2
        with:
          workload_identity_provider: projects/123456789/locations/global/workloadIdentityPools/github-pool/providers/github-provider
          service_account: github-actions@my-project.iam.gserviceaccount.com

      - name: Set up Cloud SDK
        uses: google-github-actions/setup-gcloud@v2

      - name: Deploy to Cloud Run
        run: |
          gcloud run deploy my-service \
            --image gcr.io/my-project/my-app:${{ github.sha }} \
            --region us-central1 \
            --platform managed
```

**CORRECT - Multi-Cloud OIDC**:

```yaml
jobs:
  deploy-aws:
    runs-on: ubuntu-latest
    permissions:
      id-token: write
      contents: read
    steps:
      - uses: actions/checkout@v4

      - name: Configure AWS
        uses: aws-actions/configure-aws-credentials@v4
        with:
          role-to-assume: arn:aws:iam::123456789012:role/DeploymentRole
          aws-region: us-east-1

      - name: Deploy to AWS
        run: ./deploy-aws.sh

  deploy-azure:
    runs-on: ubuntu-latest
    permissions:
      id-token: write
      contents: read
    steps:
      - uses: actions/checkout@v4

      - name: Configure Azure
        uses: azure/login@v2
        with:
          client-id: ${{ secrets.AZURE_CLIENT_ID }}
          tenant-id: ${{ secrets.AZURE_TENANT_ID }}
          subscription-id: ${{ secrets.AZURE_SUBSCRIPTION_ID }}

      - name: Deploy to Azure
        run: ./deploy-azure.sh
```

**WRONG - Using Long-Lived Credentials**:

```yaml
jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - name: Configure AWS
        env:
          # WRONG: Long-lived credentials are a security risk
          AWS_ACCESS_KEY_ID: ${{ secrets.AWS_ACCESS_KEY_ID }}
          AWS_SECRET_ACCESS_KEY: ${{ secrets.AWS_SECRET_ACCESS_KEY }}
        run: aws s3 sync ./dist s3://bucket
```

**WRONG - Missing id-token Permission**:

```yaml
permissions:
  contents: read
  # Missing id-token: write

jobs:
  deploy:
    steps:
      - uses: aws-actions/configure-aws-credentials@v4
        with:
          role-to-assume: arn:aws:iam::123:role/Role
          # This will fail without id-token permission
```

**OIDC Benefits**:

| Aspect          | OIDC                      | Long-Lived Credentials    |
| --------------- | ------------------------- | ------------------------- |
| Security        | Short-lived tokens        | Permanent secrets         |
| Rotation        | Automatic                 | Manual process            |
| Scope           | Fine-grained per workflow | Broad access              |
| Audit           | Detailed attribution      | Generic service account   |
| Revocation      | Immediate                 | Requires rotation         |
| Compromise Risk | Minimal (expires quickly) | High (valid indefinitely) |

## Deployment Strategies

Choose deployment strategies based on risk tolerance and infrastructure:

**CORRECT - Blue-Green Deployment**:

```yaml
name: Blue-Green Deployment

on:
  push:
    branches: [main]

permissions:
  contents: read
  id-token: write

jobs:
  deploy:
    runs-on: ubuntu-latest
    environment: production

    steps:
      - name: Checkout code
        uses: actions/checkout@v4

      - name: Configure AWS credentials
        uses: aws-actions/configure-aws-credentials@v4
        with:
          role-to-assume: ${{ secrets.AWS_DEPLOY_ROLE }}
          aws-region: us-east-1

      - name: Determine active environment
        id: active
        run: |
          ACTIVE=$(aws elbv2 describe-target-groups \
            --names production-tg \
            --query 'TargetGroups[0].Tags[?Key==`Environment`].Value' \
            --output text)

          if [ "${ACTIVE}" = "blue" ]; then
            echo "active=blue" >> $GITHUB_OUTPUT
            echo "inactive=green" >> $GITHUB_OUTPUT
          else
            echo "active=green" >> $GITHUB_OUTPUT
            echo "inactive=blue" >> $GITHUB_OUTPUT
          fi

      - name: Deploy to inactive environment
        env:
          TARGET_ENV: ${{ steps.active.outputs.inactive }}
        run: |
          echo "Deploying to ${TARGET_ENV} environment"
          ./deploy.sh ${TARGET_ENV}

      - name: Run health checks on inactive environment
        run: |
          ./health-check.sh ${{ steps.active.outputs.inactive }}

      - name: Switch traffic to new environment
        run: |
          aws elbv2 modify-target-group \
            --target-group-arn ${{ secrets.TARGET_GROUP_ARN }} \
            --tags Key=Environment,Value=${{ steps.active.outputs.inactive }}

          echo "Traffic switched to ${{ steps.active.outputs.inactive }}"

      - name: Monitor new environment
        run: |
          sleep 60
          ./monitor.sh ${{ steps.active.outputs.inactive }}

      - name: Rollback on failure
        if: failure()
        run: |
          echo "Deployment failed, rolling back"
          aws elbv2 modify-target-group \
            --target-group-arn ${{ secrets.TARGET_GROUP_ARN }} \
            --tags Key=Environment,Value=${{ steps.active.outputs.active }}
```

**CORRECT - Canary Deployment**:

```yaml
name: Canary Deployment

on:
  push:
    branches: [main]

jobs:
  deploy-canary:
    runs-on: ubuntu-latest
    environment: production

    steps:
      - name: Checkout code
        uses: actions/checkout@v4

      - name: Deploy canary (10% traffic)
        run: |
          ./deploy.sh canary
          ./set-traffic.sh canary 10

      - name: Monitor canary for 10 minutes
        run: |
          ./monitor-canary.sh 600

      - name: Check error rates
        id: canary-health
        run: |
          ERROR_RATE=$(./get-error-rate.sh canary)
          BASELINE=$(./get-error-rate.sh production)

          if (( $(echo "${ERROR_RATE} > ${BASELINE} * 1.5" | bc -l) )); then
            echo "healthy=false" >> $GITHUB_OUTPUT
            echo "Canary error rate too high: ${ERROR_RATE} vs baseline ${BASELINE}"
            exit 1
          else
            echo "healthy=true" >> $GITHUB_OUTPUT
          fi

  increase-canary:
    needs: deploy-canary
    runs-on: ubuntu-latest
    environment: production

    steps:
      - name: Increase canary to 50%
        run: ./set-traffic.sh canary 50

      - name: Monitor for 5 minutes
        run: ./monitor-canary.sh 300

      - name: Check health
        run: ./health-check.sh canary

  full-deployment:
    needs: increase-canary
    runs-on: ubuntu-latest
    environment: production

    steps:
      - name: Deploy to all instances
        run: |
          ./deploy.sh production
          ./set-traffic.sh production 100

      - name: Remove canary deployment
        run: ./cleanup-canary.sh
```

**CORRECT - Rolling Deployment**:

```yaml
name: Rolling Deployment

on:
  push:
    branches: [main]

jobs:
  deploy:
    runs-on: ubuntu-latest
    environment: production

    strategy:
      matrix:
        instance: [1, 2, 3, 4, 5, 6]
      max-parallel: 2 # Deploy to 2 instances at a time

    steps:
      - name: Checkout code
        uses: actions/checkout@v4

      - name: Remove instance from load balancer
        run: |
          ./lb-remove.sh instance-${{ matrix.instance }}

      - name: Deploy to instance
        run: |
          ./deploy.sh instance-${{ matrix.instance }}

      - name: Health check
        run: |
          ./health-check.sh instance-${{ matrix.instance }}

      - name: Add instance back to load balancer
        run: |
          ./lb-add.sh instance-${{ matrix.instance }}

      - name: Wait for stabilization
        run: sleep 30

      - name: Verify instance health
        run: |
          ./verify-lb-health.sh instance-${{ matrix.instance }}
```

**Deployment Strategy Comparison**:

| Strategy   | Risk   | Rollback Speed | Infrastructure Cost | Best For             |
| ---------- | ------ | -------------- | ------------------- | -------------------- |
| Blue-Green | Low    | Instant        | High (2x resources) | Critical systems     |
| Canary     | Low    | Fast           | Medium              | High-traffic apps    |
| Rolling    | Medium | Slow           | Low                 | Standard deployments |
| Recreate   | High   | Manual         | Low                 | Dev/staging          |

## Reusable Deployment Workflows

Create reusable workflows for consistent deployment logic:

**CORRECT - Reusable Deployment Workflow**:

```yaml
# .github/workflows/reusable-deploy.yml
name: Reusable Deployment Workflow

on:
  workflow_call:
    inputs:
      environment:
        description: 'Target environment'
        required: true
        type: string
      version:
        description: 'Version to deploy'
        required: true
        type: string
      region:
        description: 'AWS region'
        required: false
        type: string
        default: 'us-east-1'
      strategy:
        description: 'Deployment strategy'
        required: false
        type: string
        default: 'rolling'
      health-check-url:
        description: 'URL for health checks'
        required: true
        type: string

    secrets:
      aws-role:
        description: 'AWS IAM role ARN'
        required: true
      slack-webhook:
        description: 'Slack webhook for notifications'
        required: false

    outputs:
      deployment-url:
        description: 'URL of deployed application'
        value: ${{ jobs.deploy.outputs.url }}
      deployment-id:
        description: 'Unique deployment identifier'
        value: ${{ jobs.deploy.outputs.deployment-id }}

jobs:
  pre-deployment:
    runs-on: ubuntu-latest
    steps:
      - name: Notify deployment start
        if: secrets.slack-webhook != ''
        run: |
          curl -X POST -H 'Content-type: application/json' \
            --data '{"text":"Starting deployment of ${{ inputs.version }} to ${{ inputs.environment }}"}' \
            ${{ secrets.slack-webhook }}

      - name: Check environment health
        run: |
          curl -f ${{ inputs.health-check-url }}/health || echo "Warning: Pre-deployment health check failed"

  deploy:
    needs: pre-deployment
    runs-on: ubuntu-latest
    environment: ${{ inputs.environment }}

    permissions:
      contents: read
      id-token: write

    outputs:
      url: ${{ steps.deploy.outputs.url }}
      deployment-id: ${{ steps.deploy.outputs.deployment-id }}

    steps:
      - name: Checkout code
        uses: actions/checkout@v4
        with:
          ref: ${{ inputs.version }}

      - name: Configure AWS credentials
        uses: aws-actions/configure-aws-credentials@v4
        with:
          role-to-assume: ${{ secrets.aws-role }}
          aws-region: ${{ inputs.region }}

      - name: Deploy application
        id: deploy
        env:
          ENVIRONMENT: ${{ inputs.environment }}
          VERSION: ${{ inputs.version }}
          STRATEGY: ${{ inputs.strategy }}
        run: |
          DEPLOYMENT_ID=$(date +%s)
          echo "deployment-id=${DEPLOYMENT_ID}" >> $GITHUB_OUTPUT

          ./deploy.sh ${ENVIRONMENT} ${VERSION} ${STRATEGY}

          URL="https://${ENVIRONMENT}.example.com"
          echo "url=${URL}" >> $GITHUB_OUTPUT

      - name: Wait for deployment to stabilize
        run: sleep 30

      - name: Run health checks
        run: |
          MAX_ATTEMPTS=10
          ATTEMPT=0

          while [ $ATTEMPT -lt $MAX_ATTEMPTS ]; do
            if curl -f ${{ inputs.health-check-url }}/health; then
              echo "Health check passed"
              exit 0
            fi

            ATTEMPT=$((ATTEMPT + 1))
            echo "Health check failed (attempt $ATTEMPT/$MAX_ATTEMPTS)"
            sleep 10
          done

          echo "Health checks failed after $MAX_ATTEMPTS attempts"
          exit 1

      - name: Run smoke tests
        run: |
          ./smoke-tests.sh ${{ inputs.health-check-url }}

  post-deployment:
    needs: deploy
    runs-on: ubuntu-latest
    if: always()

    steps:
      - name: Notify deployment result
        if: secrets.slack-webhook != ''
        run: |
          if [ "${{ needs.deploy.result }}" = "success" ]; then
            MESSAGE="Deployment of ${{ inputs.version }} to ${{ inputs.environment }} succeeded: ${{ needs.deploy.outputs.url }}"
          else
            MESSAGE="Deployment of ${{ inputs.version }} to ${{ inputs.environment }} failed"
          fi

          curl -X POST -H 'Content-type: application/json' \
            --data "{\"text\":\"${MESSAGE}\"}" \
            ${{ secrets.slack-webhook }}

      - name: Create deployment record
        run: |
          echo "Deployment ID: ${{ needs.deploy.outputs.deployment-id }}"
          echo "Version: ${{ inputs.version }}"
          echo "Environment: ${{ inputs.environment }}"
          echo "URL: ${{ needs.deploy.outputs.url }}"
```

**Calling the Reusable Workflow - Staging**:

```yaml
# .github/workflows/deploy-staging.yml
name: Deploy to Staging

on:
  push:
    branches: [develop]
  workflow_dispatch:

jobs:
  deploy:
    uses: ./.github/workflows/reusable-deploy.yml
    with:
      environment: staging
      version: ${{ github.sha }}
      region: us-west-2
      strategy: rolling
      health-check-url: https://staging.example.com
    secrets:
      aws-role: ${{ secrets.STAGING_AWS_ROLE }}
      slack-webhook: ${{ secrets.SLACK_WEBHOOK }}
```

**Calling the Reusable Workflow - Production**:

```yaml
# .github/workflows/deploy-production.yml
name: Deploy to Production

on:
  push:
    tags: ['v*.*.*']
  workflow_dispatch:
    inputs:
      version:
        description: 'Version to deploy (tag or SHA)'
        required: true
        type: string

jobs:
  deploy:
    uses: ./.github/workflows/reusable-deploy.yml
    with:
      environment: production
      version: ${{ inputs.version || github.ref_name }}
      region: us-east-1
      strategy: blue-green
      health-check-url: https://example.com
    secrets:
      aws-role: ${{ secrets.PRODUCTION_AWS_ROLE }}
      slack-webhook: ${{ secrets.SLACK_WEBHOOK }}
```

## Rollback Strategies

Design robust rollback mechanisms for rapid recovery:

**CORRECT - Manual Rollback Workflow**:

```yaml
name: Rollback Deployment

on:
  workflow_dispatch:
    inputs:
      environment:
        description: 'Environment to rollback'
        required: true
        type: choice
        options:
          - staging
          - production
      version:
        description: 'Version to rollback to (tag or SHA)'
        required: true
        type: string
      reason:
        description: 'Reason for rollback'
        required: true
        type: string

jobs:
  validate-rollback:
    runs-on: ubuntu-latest
    steps:
      - name: Checkout code
        uses: actions/checkout@v4
        with:
          fetch-depth: 0 # Full history for version verification

      - name: Validate version exists
        run: |
          if ! git rev-parse ${{ inputs.version }} >/dev/null 2>&1; then
            echo "Error: Version ${{ inputs.version }} not found"
            exit 1
          fi

          echo "Version ${{ inputs.version }} verified"

      - name: Log rollback request
        run: |
          echo "Rollback requested for ${{ inputs.environment }}"
          echo "Target version: ${{ inputs.version }}"
          echo "Reason: ${{ inputs.reason }}"
          echo "Requested by: ${{ github.actor }}"

  rollback:
    needs: validate-rollback
    runs-on: ubuntu-latest
    environment: ${{ inputs.environment }}

    permissions:
      contents: read
      id-token: write

    steps:
      - name: Checkout target version
        uses: actions/checkout@v4
        with:
          ref: ${{ inputs.version }}

      - name: Configure AWS credentials
        uses: aws-actions/configure-aws-credentials@v4
        with:
          role-to-assume: ${{ secrets.AWS_DEPLOY_ROLE }}
          aws-region: us-east-1

      - name: Create rollback backup
        run: |
          CURRENT_VERSION=$(aws ecs describe-services \
            --cluster production \
            --services my-service \
            --query 'services[0].taskDefinition' \
            --output text)

          echo "Current version: ${CURRENT_VERSION}"
          echo "ROLLBACK_FROM=${CURRENT_VERSION}" >> $GITHUB_ENV

      - name: Execute rollback
        run: |
          ./deploy.sh ${{ inputs.environment }} ${{ inputs.version }}

      - name: Verify rollback
        run: |
          sleep 30
          ./health-check.sh https://${{ inputs.environment }}.example.com

      - name: Notify team
        if: always()
        run: |
          STATUS="${{ job.status }}"
          MESSAGE="Rollback to ${{ inputs.version }} on ${{ inputs.environment }}: ${STATUS}"
          MESSAGE="${MESSAGE}\nReason: ${{ inputs.reason }}"
          MESSAGE="${MESSAGE}\nPerformed by: ${{ github.actor }}"

          curl -X POST -H 'Content-type: application/json' \
            --data "{\"text\":\"${MESSAGE}\"}" \
            ${{ secrets.SLACK_WEBHOOK }}

  post-rollback:
    needs: rollback
    if: failure()
    runs-on: ubuntu-latest
    steps:
      - name: Alert on rollback failure
        run: |
          echo "CRITICAL: Rollback failed for ${{ inputs.environment }}"
          echo "Manual intervention required immediately"

          curl -X POST -H 'Content-type: application/json' \
            --data '{"text":"@channel CRITICAL: Rollback failed on ${{ inputs.environment }}. Manual intervention needed."}' \
            ${{ secrets.SLACK_WEBHOOK }}
```

**CORRECT - Automated Rollback on Health Check Failure**:

```yaml
name: Deploy with Auto-Rollback

on:
  push:
    branches: [main]

jobs:
  deploy:
    runs-on: ubuntu-latest
    environment: production

    steps:
      - name: Checkout code
        uses: actions/checkout@v4

      - name: Get current deployment version
        id: current
        run: |
          CURRENT=$(aws ecs describe-services \
            --cluster production \
            --services my-service \
            --query 'services[0].taskDefinition' \
            --output text)
          echo "version=${CURRENT}" >> $GITHUB_OUTPUT
          echo "Current version: ${CURRENT}"

      - name: Deploy new version
        id: deploy
        run: |
          ./deploy.sh production ${{ github.sha }}
          echo "deployed=true" >> $GITHUB_OUTPUT

      - name: Health check with retries
        id: health
        run: |
          MAX_ATTEMPTS=12
          ATTEMPT=0

          while [ $ATTEMPT -lt $MAX_ATTEMPTS ]; do
            if curl -f https://example.com/health; then
              echo "Health check passed"
              exit 0
            fi

            ATTEMPT=$((ATTEMPT + 1))
            echo "Health check failed (attempt $ATTEMPT/$MAX_ATTEMPTS)"
            sleep 10
          done

          echo "Health checks failed after $MAX_ATTEMPTS attempts"
          exit 1

      - name: Automated rollback on failure
        if: failure() && steps.deploy.outputs.deployed == 'true'
        run: |
          echo "Initiating automated rollback to ${{ steps.current.outputs.version }}"
          ./deploy.sh production ${{ steps.current.outputs.version }}

          # Verify rollback
          sleep 30
          curl -f https://example.com/health

          echo "Rollback completed successfully"

      - name: Notify on rollback
        if: failure() && steps.deploy.outputs.deployed == 'true'
        run: |
          curl -X POST -H 'Content-type: application/json' \
            --data '{"text":"Automated rollback triggered for production deployment. Previous version restored."}' \
            ${{ secrets.SLACK_WEBHOOK }}
```

**CORRECT - Artifact-Based Rollback**:

```yaml
name: Artifact Retention for Rollback

on:
  push:
    branches: [main]

jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - name: Checkout code
        uses: actions/checkout@v4

      - name: Build application
        run: npm run build

      - name: Create deployment package
        run: |
          tar -czf deployment-${{ github.sha }}.tar.gz dist/

      - name: Upload deployment artifact
        uses: actions/upload-artifact@v4
        with:
          name: deployment-${{ github.sha }}
          path: deployment-${{ github.sha }}.tar.gz
          retention-days: 90 # Keep for 3 months

      - name: Upload to S3 for long-term storage
        run: |
          aws s3 cp deployment-${{ github.sha }}.tar.gz \
            s3://my-deployment-artifacts/deployments/

  deploy:
    needs: build
    runs-on: ubuntu-latest
    environment: production
    steps:
      - name: Download deployment artifact
        uses: actions/download-artifact@v4
        with:
          name: deployment-${{ github.sha }}

      - name: Deploy artifact
        run: |
          tar -xzf deployment-${{ github.sha }}.tar.gz
          ./deploy.sh production dist/
```

**Rollback from Artifact**:

```yaml
name: Rollback from Artifact

on:
  workflow_dispatch:
    inputs:
      version:
        description: 'Git SHA of version to rollback to'
        required: true
        type: string

jobs:
  rollback:
    runs-on: ubuntu-latest
    environment: production
    steps:
      - name: Download artifact from S3
        run: |
          aws s3 cp s3://my-deployment-artifacts/deployments/deployment-${{ inputs.version }}.tar.gz .

      - name: Extract and deploy
        run: |
          tar -xzf deployment-${{ inputs.version }}.tar.gz
          ./deploy.sh production dist/

      - name: Verify deployment
        run: |
          sleep 30
          ./health-check.sh https://example.com
```

**Rollback Best Practices**:

| Practice               | Implementation                           | Benefit                          |
| ---------------------- | ---------------------------------------- | -------------------------------- |
| Keep N artifacts       | Retain last 10 production releases       | Fast rollback without rebuild    |
| Document rollback      | Require reason in workflow_dispatch      | Audit trail and learning         |
| Test rollback          | Regular rollback drills in staging       | Confidence in recovery process   |
| Automate health checks | Fail deployment on unhealthy             | Catch issues before full rollout |
| Notify team            | Slack/email on rollback                  | Immediate awareness              |
| Preserve data          | Database migrations compatible both ways | Safe rollback without data loss  |

These deployment patterns enable safe, reliable, and auditable deployments at scale. Apply them
thoughtfully based on your application's requirements, team size, and risk tolerance.
