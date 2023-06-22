# cert-manager-at-home
Learning cert-manager TLS certificate setup


# 1. Generate the CA Key and Certificate 

```bash
openssl genrsa -out ca.key 4096
```

```bash
openssl req -new -x509 -sha256 -days 10950 -key ca.key -out ca.crt
```

# 2. Create CA secret and `cert-manager` ClusterIssuer/Issuer object

```
apiVersion: v1
kind: Secret
metadata:
  name: ca
  namespace: cert-manager
data:
  tls.crt: <BASE64-ENCODED-VALUE>
  tls.key: <BASE64-ENCODED-VALUE>
---
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: ca-issuer
  namespace: cert-manager
spec:
  ca:
    secretName: ca
```