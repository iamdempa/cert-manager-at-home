# cert-manager-at-home
Learning cert-manager TLS certificate setup


# 1. Generate the CA Key and Certificate 

```bash
openssl genrsa -out ca.key 4096
```

```bash
openssl req -new -x509 -sha256 -days 10950 -key ca.key -out ca.crt
```

# 2. Create `cert-manager` ClusterIssuer/Issuer object

```
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: ca-issuer
  namespace: cert-manager
spec:
  ca:
    secretName: ca-key-pair
```