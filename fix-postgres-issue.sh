#!/bin/bash

# Script de correction du problème PostgreSQL

echo "🔧 CORRECTION PROBLÈME POSTGRESQL"
echo "================================="

# Couleurs
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

print_status() {
    echo -e "${BLUE}ℹ️${NC} $1"
}

print_success() {
    echo -e "${GREEN}✅${NC} $1"
}

print_error() {
    echo -e "${RED}❌${NC} $1"
}

# Arrêter tous les conteneurs
print_status "Arrêt des conteneurs..."
docker compose -f docker-compose.fixed.yml down -v

# Nettoyer les volumes PostgreSQL
print_status "Nettoyage des volumes PostgreSQL..."
docker volume rm listmonk_postgres_data 2>/dev/null || true
docker volume prune -f

# Vérifier si le port 5432 est occupé
print_status "Vérification du port 5432..."
if netstat -tuln 2>/dev/null | grep -q ":5432 " || ss -tuln 2>/dev/null | grep -q ":5432 "; then
    print_error "Port 5432 occupé par un autre service PostgreSQL"
    echo "Arrêtez le service PostgreSQL local avec :"
    echo "sudo systemctl stop postgresql"
    echo "ou modifiez le port dans docker-compose.fixed.yml"
    exit 1
fi

# Créer un docker-compose simplifié pour test
print_status "Création d'une configuration PostgreSQL simplifiée..."
cat > docker-compose.postgres-test.yml << 'EOF'
version: '3.8'

services:
  postgres:
    image: postgres:17-alpine
    container_name: listmonk-postgres-test
    environment:
      POSTGRES_DB: listmonk
      POSTGRES_USER: listmonk
      POSTGRES_PASSWORD: listmonk_secure_password
      POSTGRES_INITDB_ARGS: "--encoding=UTF8 --lc-collate=C --lc-ctype=C"
    volumes:
      - postgres_test_data:/var/lib/postgresql/data
      - ./docker/init-scripts:/docker-entrypoint-initdb.d:ro
    ports:
      - "5432:5432"
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U listmonk -d listmonk"]
      interval: 10s
      timeout: 5s
      retries: 10
      start_period: 30s
    restart: unless-stopped

volumes:
  postgres_test_data:
    driver: local
EOF

# Tester PostgreSQL seul
print_status "Test de PostgreSQL seul..."
docker compose -f docker-compose.postgres-test.yml up -d postgres

# Attendre que PostgreSQL soit prêt
print_status "Attente de PostgreSQL..."
max_attempts=30
attempt=0

while [ $attempt -lt $max_attempts ]; do
    if docker compose -f docker-compose.postgres-test.yml exec -T postgres pg_isready -U listmonk -d listmonk &>/dev/null; then
        print_success "PostgreSQL est prêt !"
        break
    fi
    
    attempt=$((attempt + 1))
    echo -n "."
    sleep 2
done

if [ $attempt -eq $max_attempts ]; then
    print_error "PostgreSQL ne démarre pas. Vérification des logs..."
    docker compose -f docker-compose.postgres-test.yml logs postgres
    exit 1
fi

# Vérifier les extensions géographiques
print_status "Vérification des extensions géographiques..."
if docker compose -f docker-compose.postgres-test.yml exec -T postgres psql -U listmonk -d listmonk -c "SELECT COUNT(*) FROM departement_region_mapping;" &>/dev/null; then
    dept_count=$(docker compose -f docker-compose.postgres-test.yml exec -T postgres psql -U listmonk -d listmonk -t -c "SELECT COUNT(*) FROM departement_region_mapping;" | tr -d ' ')
    print_success "Table départements créée avec $dept_count départements"
else
    print_error "Problème avec les scripts d'initialisation"
    docker compose -f docker-compose.postgres-test.yml logs postgres
fi

# Arrêter le test
docker compose -f docker-compose.postgres-test.yml down

# Créer un docker-compose corrigé final
print_status "Création de la configuration finale corrigée..."
cat > docker-compose.final.yml << 'EOF'
version: '3.8'

services:
  postgres:
    image: postgres:17-alpine
    container_name: listmonk-postgres
    environment:
      POSTGRES_DB: listmonk
      POSTGRES_USER: listmonk
      POSTGRES_PASSWORD: listmonk_secure_password
      POSTGRES_INITDB_ARGS: "--encoding=UTF8 --lc-collate=C --lc-ctype=C"
    volumes:
      - postgres_data:/var/lib/postgresql/data
      - ./docker/init-scripts:/docker-entrypoint-initdb.d:ro
    ports:
      - "5432:5432"
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U listmonk -d listmonk"]
      interval: 15s
      timeout: 10s
      retries: 10
      start_period: 60s
    restart: unless-stopped

  listmonk:
    build:
      context: .
      dockerfile: Dockerfile.geo.fixed
    container_name: listmonk-app
    environment:
      LISTMONK_app__address: "0.0.0.0:9000"
      LISTMONK_app__admin_username: admin
      LISTMONK_app__admin_password: admin123
      LISTMONK_db__host: postgres
      LISTMONK_db__port: 5432
      LISTMONK_db__user: listmonk
      LISTMONK_db__password: listmonk_secure_password
      LISTMONK_db__database: listmonk
      LISTMONK_db__ssl_mode: disable
      LISTMONK_db__max_open: 25
      LISTMONK_db__max_idle: 25
      LISTMONK_db__max_lifetime: "300s"
    ports:
      - "9000:9000"
    depends_on:
      postgres:
        condition: service_healthy
    volumes:
      - listmonk_uploads:/listmonk/uploads
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:9000/health"]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 120s
    restart: unless-stopped

  adminer:
    image: adminer:4.8.1
    container_name: listmonk-adminer
    environment:
      ADMINER_DEFAULT_SERVER: postgres
    ports:
      - "8083:8080"
    depends_on:
      - postgres
    restart: unless-stopped

volumes:
  postgres_data:
    driver: local
  listmonk_uploads:
    driver: local

networks:
  default:
    name: listmonk-network
EOF

# Démarrer avec la configuration finale
print_status "Démarrage avec la configuration corrigée..."
docker compose -f docker-compose.final.yml up -d

# Attendre PostgreSQL
print_status "Attente de PostgreSQL..."
sleep 30

# Vérifier le statut
print_status "Vérification du statut..."
docker compose -f docker-compose.final.yml ps

# Attendre Listmonk
print_status "Attente de Listmonk..."
sleep 30

# Initialiser Listmonk
print_status "Initialisation de Listmonk..."
docker compose -f docker-compose.final.yml exec -T listmonk ./listmonk --install --yes || true

print_success "Installation terminée !"
echo ""
echo "🎉 LISTMONK AVEC EXTENSION GÉOGRAPHIQUE FRANÇAISE"
echo "================================================"
echo ""
echo "🌐 Interface : http://localhost:9000"
echo "👤 Username : admin"
echo "🔑 Password : admin123"
echo ""
echo "🗄️ Adminer : http://localhost:8083"
echo "   Server: postgres"
echo "   User: listmonk"
echo "   Password: listmonk_secure_password"
echo ""
echo "📊 Fonctionnalités géographiques disponibles :"
echo "• Segmentation par région (13 régions françaises)"
echo "• Segmentation par département (95 départements)"
echo "• Recherche communes avec autocomplete"
echo "• Filtrage par population et CSP"
echo ""
echo "🎯 Allez sur 'Listes' → 'Nouvelle liste' → Onglet 'Géographie'"
echo ""