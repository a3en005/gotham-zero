#!/bin/bash

###############################################################################
# GOTHAM-ZERO: One-Command Intelligence Platform Setup
# Run: chmod +x setup.sh && ./setup.sh
###############################################################################

set -e

echo "======================================"
echo "🎯 GOTHAM-ZERO DEPLOYMENT INITIATED"
echo "======================================"
echo ""

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Check if running as root
if [[ $EUID -eq 0 ]]; then
   echo -e "${RED}❌ Do not run this script as root${NC}" 
   exit 1
fi

echo -e "${YELLOW}📦 Checking dependencies...${NC}"

# Check for Docker
if ! command -v docker &> /dev/null; then
    echo -e "${RED}❌ Docker not found. Installing Docker...${NC}"
    curl -fsSL https://get.docker.com -o get-docker.sh
    sh get-docker.sh
    sudo usermod -aG docker $USER
    echo -e "${GREEN}✅ Docker installed. Please log out and back in, then run this script again.${NC}"
    exit 0
fi

# Check for Docker Compose
if ! command -v docker-compose &> /dev/null; then
    echo -e "${YELLOW}Installing Docker Compose...${NC}"
    sudo curl -L "https://github.com/docker/compose/releases/download/v2.23.0/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
    sudo chmod +x /usr/local/bin/docker-compose
fi

echo -e "${GREEN}✅ All dependencies satisfied${NC}"
echo ""

# Create directory structure
echo -e "${YELLOW}📂 Creating directory structure...${NC}"
mkdir -p data/{postgres,neo4j,minio,superset}
mkdir -p config/{superset,dagster,grafana}
mkdir -p logs
mkdir -p notebooks
mkdir -p scripts

# Create .env file
echo -e "${YELLOW}⚙️  Generating environment configuration...${NC}"
cat > .env << 'EOF'
# GOTHAM-ZERO Configuration
COMPOSE_PROJECT_NAME=gotham-zero

# Postgres
POSTGRES_USER=gotham
POSTGRES_PASSWORD=gotham_secure_password_change_me
POSTGRES_DB=gotham_core

# Neo4j (Graph Database)
NEO4J_AUTH=neo4j/gotham_neo4j_password_change_me

# Superset (Analytics)
SUPERSET_SECRET_KEY=YOUR_SUPERSET_SECRET_KEY_CHANGE_ME_TO_RANDOM_STRING

# MinIO (Object Storage)
MINIO_ROOT_USER=gotham_admin
MINIO_ROOT_PASSWORD=gotham_minio_password_change_me

# LLM Configuration (Local or API)
OLLAMA_HOST=http://ollama:11434
OPENAI_API_KEY=your_openai_key_if_using_openai

# Application Settings
GOTHAM_PORT=8080
NEO4J_BROWSER_PORT=7474
NEO4J_BOLT_PORT=7687
SUPERSET_PORT=8088
DAGSTER_PORT=3000
MINIO_CONSOLE_PORT=9001
JUPYTER_PORT=8888

# Timezone
TZ=UTC
EOF

echo -e "${GREEN}✅ Environment file created${NC}"

# Pull all Docker images in parallel
echo -e "${YELLOW}🐳 Pulling Docker images (this may take 5-10 minutes)...${NC}"
docker-compose pull

# Start the platform
echo -e "${YELLOW}🚀 Starting GOTHAM-ZERO platform...${NC}"
docker-compose up -d

# Wait for services to be healthy
echo -e "${YELLOW}⏳ Waiting for services to initialize...${NC}"
sleep 20

# Initialize Superset
echo -e "${YELLOW}📊 Initializing Superset (Analytics Dashboard)...${NC}"
docker-compose exec -T superset superset fab create-admin \
    --username admin \
    --firstname Admin \
    --lastname User \
    --email admin@gotham.local \
    --password admin || true

docker-compose exec -T superset superset db upgrade || true
docker-compose exec -T superset superset init || true

# Create Neo4j constraints
echo -e "${YELLOW}🕸️  Setting up Neo4j graph constraints...${NC}"
sleep 5
docker-compose exec -T neo4j cypher-shell -u neo4j -p gotham_neo4j_password_change_me \
    "CREATE CONSTRAINT entity_id IF NOT EXISTS FOR (n:Entity) REQUIRE n.id IS UNIQUE;" || true

echo ""
echo -e "${GREEN}======================================"
echo "✅ GOTHAM-ZERO DEPLOYMENT COMPLETE"
echo "======================================${NC}"
echo ""
echo "🌐 Access your intelligence platform:"
echo ""
echo -e "${GREEN}Main Dashboard:${NC}      http://localhost:8080"
echo -e "${GREEN}Superset Analytics:${NC}  http://localhost:8088 (admin/admin)"
echo -e "${GREEN}Neo4j Graph Browser:${NC} http://localhost:7474 (neo4j/gotham_neo4j_password_change_me)"
echo -e "${GREEN}Dagster Pipelines:${NC}   http://localhost:3000"
echo -e "${GREEN}MinIO Storage:${NC}       http://localhost:9001 (gotham_admin/gotham_minio_password_change_me)"
echo -e "${GREEN}Jupyter Notebooks:${NC}   http://localhost:8888"
echo ""
echo -e "${YELLOW}📝 Next steps:${NC}"
echo "1. Change all default passwords in .env file"
echo "2. Run: docker-compose restart"
echo "3. Access dashboards and start building your ontology"
echo ""
echo -e "${YELLOW}📚 Documentation:${NC} See README.md for full feature guide"
echo ""
echo -e "${RED}⚠️  SECURITY WARNING:${NC} This is running with default credentials."
echo "    Change all passwords before exposing to network!"
echo ""

# Show running containers
echo -e "${YELLOW}🐳 Active Services:${NC}"
docker-compose ps

echo ""
echo "Run: ${GREEN}docker-compose logs -f${NC} to view live logs"
echo "Run: ${GREEN}docker-compose down${NC} to stop all services"
echo ""
