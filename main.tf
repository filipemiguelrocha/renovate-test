resource "helm_release" "atlantis" {
  name             = "atlantis"
  repository       = "https://runatlantis.github.io/helm-charts"
  chart            = "atlantis"
  version          = "4.0.7"
  namespace        = "atlantis"
  wait_for_jobs    = true
  create_namespace = false

  values = [
    <<YAML
  atlantisUrl: https://atlantis.${var.fqdn}
  orgAllowlist: ${var.org_whitelist}
  #logLevel: "debug"

  image:
    repository: ghcr.io/runatlantis/atlantis
    tag: v0.19.7

  # hidePrevPlanComments enables atlantis to hide previous plan comments
  hidePrevPlanComments: true

  ## defaultTFVersion set the default terraform version to be used in atlantis server
  defaultTFVersion: 1.2.0

  repoConfig: |
    ---
    repos:
    - id: /.*/
      apply_requirements: [approved, mergeable, undiverged]
      allowed_overrides: [workflow, apply_requirements, delete_source_branch_on_merge]
      allow_custom_workflows: false
    workflows:
      no_refresh:
        plan:
          steps:
          - init
          - plan:
              extra_args: ['-refresh=false']
      high_parallelism:
        plan:
          steps:
          - init
          - plan:
              extra_args: ['-parallelism=50']

    policies:
      owners:
        users:
          - paparuco
          - dgteixeira
          - calexandre
          - flippipe
      policy_sets:
        - name: prevent-atlantis-changes
          path: /mnt/policies
          source: local

  ## disabled because we'll use our own ingress with GCP managed certs
  ingress:
    enabled: false

  service:
    annotations:
      cloud.google.com/backend-config: '{"ports": {"80":"atlantis-security-policy"}}'
      cloud.google.com/neg: '{"ingress": true}'
    type: NodePort
    port: 80

  serviceAccount:
    annotations:
      iam.gke.io/gcp-service-account: ${data.google_service_account.this.email}

  environmentSecrets:
    - name: ATLANTIS_GH_WEBHOOK_SECRET
      secretKeyRef:
        name: github-app
        key: webhook-secret
    - name: ATLANTIS_GH_APP_ID
      secretKeyRef:
        name: github-app
        key: app-id
    - name: TF_VAR_app_id
      secretKeyRef:
        name: github-app
        key: app-id
    - name: TF_VAR_app_installation_id
      secretKeyRef:
        name: github-app
        key: app-installation-id
    - name: ARM_CLIENT_ID
      secretKeyRef:
        name: azure-tfrosie
        key: azure-tfrosie-client-id
    - name: ARM_CLIENT_SECRET
      secretKeyRef:
        name: azure-tfrosie
        key: azure-tfrosie-client-secret
    - name: MONGODB_ATLAS_PRIVATE_KEY
      secretKeyRef:
        name: mongodb-atlas
        key: mongodb-atlas-private-key
    - name: MONGODB_ATLAS_PUBLIC_KEY
      secretKeyRef:
        name: mongodb-atlas
        key: mongodb-atlas-public-key

  environmentRaw:
    - name: ATLANTIS_GH_ORG
      value: ${var.atlantis_gh_org}
    - name: ATLANTIS_GH_APP_KEY_FILE
      value: "/mnt/gcp-secrets/app-key.pem"
    - name: TF_VAR_app_pem_file_path
      value: "/mnt/gcp-secrets/app-key.pem"
    - name: ATLANTIS_WRITE_GIT_CREDS
      value: "true"
    - name: ATLANTIS_ENABLE_POLICY_CHECKS
      value: "true"
    - name: ATLANTIS_SILENCE_ALLOWLIST_ERRORS
      value: "true"

  extraVolumes:
    - name: gcp-secrets
      csi:
        driver: secrets-store.csi.k8s.io
        readOnly: true
        volumeAttributes:
          secretProviderClass: "gcp-secrets"
    - name: policies
      configMap:
        name: policies
        items:
        - key: prevent-atlantis-destroy.rego
          path: prevent-atlantis-destroy.rego
  extraVolumeMounts:
    ## each secret defined in the "gcp-secrets" csi secret store, will be mounted at this path
    - name: gcp-secrets
      mountPath: "/mnt/gcp-secrets"
      readOnly: true
    - name: policies
      mountPath: "/mnt/policies"
      readOnly: true

  extraManifests:
    - apiVersion: v1
      kind: ConfigMap
      metadata:
        name: policies
        namespace: atlantis
      data:
        prevent-atlantis-destroy.rego: ${yamlencode(file("${path.module}/policies/prevent-atlantis-destroy.rego"))}
  resources:
    limits:
      cpu: 3000m
      memory: 4Gi
    requests:
      cpu: 3000m
      memory: 4Gi

  nodeSelector:
    cloud.google.com/gke-nodepool: ${var.atlantis_node_pool_name}

  tolerations:
  - key: "dedicated"
    value: "atlantis"
    operator: "Equal"
    effect: "NoSchedule"

  YAML
  ]

  depends_on = [
    kubectl_manifest.atlantis
  ]
}
