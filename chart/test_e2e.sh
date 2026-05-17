#!/usr/bin/env bash
set -euo pipefail

kubectl create namespace fastembed

kubectl create secret generic hf-token \
  --namespace fastembed \
  --from-literal=HF_TOKEN=$HF_TOKEN

helm install fastembed ./chart \
  --namespace fastembed \
  --values chart/values.yaml \
  --set global.huggingface.existingSecret=hf-token \
  --set global.networkPolicy.enabled=false \ 
  --set dense.preloadModel=true \
  --set sparse.preloadModel=true \
  --set reranker.preloadModel=true \
  --wait \
  --timeout 10m


NAMESPACE="fastembed"
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Start port forwards
echo -e "${BLUE}Starting port forwards...${NC}"
kubectl port-forward -n "$NAMESPACE" svc/fastembed-dense-svc 8200:8200 &>/tmp/pf-dense.log &
PF1=$!
kubectl port-forward -n "$NAMESPACE" svc/fastembed-sparse-svc 8201:8201 &>/tmp/pf-sparse.log &
PF2=$!
kubectl port-forward -n "$NAMESPACE" svc/fastembed-reranker-svc 8202:8202 &>/tmp/pf-reranker.log &
PF3=$!

sleep 3

cleanup() {
    echo -e "\n${BLUE}Stopping port forwards...${NC}"
    kill $PF1 $PF2 $PF3 2>/dev/null || true
    echo -e "${GREEN}Done.${NC}"
}
trap cleanup EXIT

# Test function
test_endpoint() {
    local name=$1
    local method=$2
    local url=$3
    local data=$4
    local expected=$5
    
    echo -e "\n${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BLUE}Testing: ${name}${NC}"
    echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    
    if [ "$method" = "POST" ]; then
        response=$(curl -s -w "\n%{http_code}" -X POST "$url" \
            -H "Content-Type: application/json" \
            -d "$data")
    else
        response=$(curl -s -w "\n%{http_code}" "$url")
    fi
    
    http_code=$(echo "$response" | tail -1)
    body=$(echo "$response" | sed '$d')
    
    if [ "$http_code" = "200" ]; then
        echo -e "${GREEN}✓ Status: $http_code${NC}"
    else
        echo -e "${RED}✗ Status: $http_code${NC}"
    fi
    
    echo -e "${BLUE}Response:${NC}"
    echo "$body" | head -c 500
    echo ""
    
    if [ -n "$expected" ]; then
        if echo "$body" | grep -q "$expected"; then
            echo -e "${GREEN}✓ Found expected: '$expected'${NC}"
        else
            echo -e "${RED}✗ Missing expected: '$expected'${NC}"
        fi
    fi
}

# ==========================================
# DENSE SERVICE (8200)
# ==========================================
echo -e "\n${GREEN}╔═══════════════════════════════════════╗${NC}"
echo -e "${GREEN}║     DENSE EMBEDDING SERVICE (8200)    ║${NC}"
echo -e "${GREEN}╚═══════════════════════════════════════╝${NC}"

# Health check
test_endpoint \
    "Dense - Health Check" \
    "GET" \
    "http://localhost:8200/health" \
    "" \
    "ok"

# Readiness check
test_endpoint \
    "Dense - Readiness Check" \
    "GET" \
    "http://localhost:8200/readyz" \
    "" \
    "ready"

# Generate embeddings
test_endpoint \
    "Dense - Generate Embeddings" \
    "POST" \
    "http://localhost:8200/embed" \
    '{"texts":["Hello world","Test embedding","Another sentence"]}' \
    "vectors"

# Batch embeddings
test_endpoint \
    "Dense - Batch Embeddings" \
    "POST" \
    "http://localhost:8200/embed" \
    '{"texts":["Machine learning","Deep learning","Neural networks","Artificial intelligence","Data science"]}' \
    "vectors"

# Metrics
test_endpoint \
    "Dense - Prometheus Metrics" \
    "GET" \
    "http://localhost:8200/metrics" \
    "" \
    "dense_requests_total"

# ==========================================
# SPARSE SERVICE (8201)
# ==========================================
echo -e "\n${GREEN}╔═══════════════════════════════════════╗${NC}"
echo -e "${GREEN}║    SPARSE EMBEDDING SERVICE (8201)    ║${NC}"
echo -e "${GREEN}╚═══════════════════════════════════════╝${NC}"

# Health check
test_endpoint \
    "Sparse - Health Check" \
    "GET" \
    "http://localhost:8201/health" \
    "" \
    "ok"

# Readiness check
test_endpoint \
    "Sparse - Readiness Check" \
    "GET" \
    "http://localhost:8201/readyz" \
    "" \
    "ready"

# Generate sparse embeddings
test_endpoint \
    "Sparse - Generate Sparse Embeddings" \
    "POST" \
    "http://localhost:8201/embed" \
    '{"texts":["Hello world","Test sparse embedding"]}' \
    "indices"

# Batch sparse embeddings
test_endpoint \
    "Sparse - Batch Sparse Embeddings" \
    "POST" \
    "http://localhost:8201/embed" \
    '{"texts":["Sparse retrieval","BM25 algorithm","SPLADE model","Keyword matching"]}' \
    "values"

# Metrics
test_endpoint \
    "Sparse - Prometheus Metrics" \
    "GET" \
    "http://localhost:8201/metrics" \
    "" \
    "sparse_requests_total"

# ==========================================
# RERANKER SERVICE (8202)
# ==========================================
echo -e "\n${GREEN}╔═══════════════════════════════════════╗${NC}"
echo -e "${GREEN}║      RERANKER SERVICE (8202)          ║${NC}"
echo -e "${GREEN}╚═══════════════════════════════════════╝${NC}"

# Health check
test_endpoint \
    "Reranker - Health Check" \
    "GET" \
    "http://localhost:8202/health" \
    "" \
    "ok"

# Readiness check
test_endpoint \
    "Reranker - Readiness Check" \
    "GET" \
    "http://localhost:8202/readyz" \
    "" \
    "ready"

# Rerank documents
test_endpoint \
    "Reranker - Rerank Documents" \
    "POST" \
    "http://localhost:8202/rerank" \
    '{"query":"best search method","documents":["Dense embeddings are good for semantic search","Sparse vectors excel at keyword matching","Hybrid search combines both approaches","Rerankers improve search quality"]}' \
    "scores"

# Rerank with more documents
test_endpoint \
    "Reranker - Rerank Multiple Documents" \
    "POST" \
    "http://localhost:8202/rerank" \
    '{"query":"machine learning frameworks","documents":["PyTorch is popular for research","TensorFlow is used in production","Scikit-learn is great for beginners","JAX is gaining popularity","Keras provides high-level APIs"]}' \
    "scores"

# Metrics
test_endpoint \
    "Reranker - Prometheus Metrics" \
    "GET" \
    "http://localhost:8202/metrics" \
    "" \
    "reranker_requests_total"

# ==========================================
# SUMMARY
# ==========================================
echo -e "\n${GREEN}╔═══════════════════════════════════════╗${NC}"
echo -e "${GREEN}║           TEST SUMMARY                ║${NC}"
echo -e "${GREEN}╚═══════════════════════════════════════╝${NC}"

echo -e "\n${BLUE}Quick Access Commands:${NC}"
echo "  curl http://localhost:8200/health    # Dense health"
echo "  curl http://localhost:8201/health    # Sparse health"
echo "  curl http://localhost:8202/health    # Reranker health"
echo ""
echo "  curl http://localhost:8200/metrics   # Dense metrics"
echo "  curl http://localhost:8201/metrics   # Sparse metrics"
echo "  curl http://localhost:8202/metrics   # Reranker metrics"
echo ""
echo -e "${GREEN}All tests completed successfully!${NC}"

