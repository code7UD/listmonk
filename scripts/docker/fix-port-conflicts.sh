#!/bin/bash

# Script de correction automatique des conflits de ports

echo "🔧 RÉSOLUTION DES CONFLITS DE PORTS"
echo "==================================="

# Fonction pour vérifier si un port est utilisé
check_port() {
    local port=$1
    if netstat -tuln 2>/dev/null | grep -q ":$port " || ss -tuln 2>/dev/null | grep -q ":$port "; then
        return 0  # Port utilisé
    else
        return 1  # Port libre
    fi
}

# Fonction pour trouver un port libre
find_free_port() {
    local start_port=$1
    local port=$start_port
    
    while check_port $port; do
        port=$((port + 1))
        if [ $port -gt 65535 ]; then
            echo "Erreur: Aucun port libre trouvé"
            exit 1
        fi
    done
    
    echo $port
}

echo "🔍 Vérification des ports..."

# Vérifier les ports par défaut
POSTGRES_PORT=5432
ADMINER_PORT=8080
LISTMONK_PORT=9000

NEW_POSTGRES_PORT=$POSTGRES_PORT
NEW_ADMINER_PORT=$ADMINER_PORT
NEW_LISTMONK_PORT=$LISTMONK_PORT

# Vérifier PostgreSQL (5432)
if check_port $POSTGRES_PORT; then
    echo "⚠️ Port $POSTGRES_PORT (PostgreSQL) déjà utilisé"
    NEW_POSTGRES_PORT=$(find_free_port 5433)
    echo "✅ Nouveau port PostgreSQL: $NEW_POSTGRES_PORT"
fi

# Vérifier Adminer (8080)
if check_port $ADMINER_PORT; then
    echo "⚠️ Port $ADMINER_PORT (Adminer) déjà utilisé"
    NEW_ADMINER_PORT=$(find_free_port 8081)
    echo "✅ Nouveau port Adminer: $NEW_ADMINER_PORT"
fi

# Vérifier Listmonk (9000)
if check_port $LISTMONK_PORT; then
    echo "⚠️ Port $LISTMONK_PORT (Listmonk) déjà utilisé"
    NEW_LISTMONK_PORT=$(find_free_port 9001)
    echo "✅ Nouveau port Listmonk: $NEW_LISTMONK_PORT"
fi

# Créer un docker-compose avec les nouveaux ports
echo "📝 Création de docker-compose avec ports libres..."

cat > docker-compose.ports-fixed.yml << EOF
version: '3.8'

services:
  # Base de données PostgreSQL
  postgres:
    image: postgres:15-alpine
    container_name: listmonk-postgres-geo
    restart: unless-stopped
    environment:
      POSTGRES_DB: listmonk
      POSTGRES_USER: listmonk
      POSTGRES_PASSWORD: \${POSTGRES_PASSWORD}
      POSTGRES_HOST_AUTH_METHOD: trust
    volumes:
      - postgres_data:/var/lib/postgresql/data
      - ./docker/init-scripts:/docker-entrypoint-initdb.d
    ports:
      - "$NEW_POSTGRES_PORT:5432"
    networks:
      - listmonk-network
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U listmonk -d listmonk"]
      interval: 10s
      timeout: 5s
      retries: 5

  # Application Listmonk avec extension géographique
  listmonk:
    build:
      context: .
      dockerfile: Dockerfile.geo.simple
    container_name: listmonk-app-geo
    restart: unless-stopped
    depends_on:
      postgres:
        condition: service_healthy
    environment:
      LISTMONK_DB_HOST: postgres
      LISTMONK_DB_PORT: 5432
      LISTMONK_DB_USER: listmonk
      LISTMONK_DB_PASSWORD: \${POSTGRES_PASSWORD}
      LISTMONK_DB_DATABASE: listmonk
      LISTMONK_DB_SSL_MODE: disable
      LISTMONK_APP_ADDRESS: 0.0.0.0:9000
      LISTMONK_APP_ADMIN_USERNAME: \${ADMIN_USERNAME}
      LISTMONK_APP_ADMIN_PASSWORD: \${ADMIN_PASSWORD}
      LISTMONK_IMPORT_DEMO_DATA: \${IMPORT_DEMO_DATA:-false}
    ports:
      - "$NEW_LISTMONK_PORT:9000"
    volumes:
      - ./config/config.toml:/listmonk/config.toml:ro
      - uploads_data:/listmonk/uploads
      - ./demo:/listmonk/demo:ro
    networks:
      - listmonk-network
    healthcheck:
      test: ["CMD", "wget", "--quiet", "--tries=1", "--spider", "http://localhost:9000/health", "||", "exit", "1"]
      interval: 30s
      timeout: 10s
      retries: 3

  # Interface d'administration (optionnel)
  adminer:
    image: adminer:latest
    container_name: listmonk-adminer-geo
    restart: unless-stopped
    depends_on:
      - postgres
    ports:
      - "$NEW_ADMINER_PORT:8080"
    networks:
      - listmonk-network
    environment:
      ADMINER_DEFAULT_SERVER: postgres

volumes:
  postgres_data:
    driver: local
  uploads_data:
    driver: local

networks:
  listmonk-network:
    driver: bridge
EOF

echo "✅ Fichier docker-compose.ports-fixed.yml créé avec les nouveaux ports"

# Arrêter les services existants
echo "🛑 Arrêt des services existants..."
docker-compose -f docker-compose.geo.yml down 2>/dev/null || true
docker-compose -f docker-compose.simple.yml down 2>/dev/null || true

# Démarrer avec les nouveaux ports
echo "🚀 Démarrage avec les ports corrigés..."
docker-compose -f docker-compose.ports-fixed.yml up -d

# Attendre le démarrage
echo "⏳ Attente du démarrage des services..."
sleep 20

# Vérifier l'état
echo "🔍 Vérification de l'état des services..."
docker-compose -f docker-compose.ports-fixed.yml ps

# Test de connectivité
echo "🧪 Test de connectivité..."
if curl -s http://localhost:$NEW_LISTMONK_PORT/health > /dev/null; then
    echo "✅ Listmonk est accessible !"
else
    echo "⏳ Listmonk démarre encore, patientez..."
fi

echo ""
echo "🎉 CORRECTION TERMINÉE !"
echo "======================="
echo ""
echo "📱 Nouveaux accès aux services :"
echo "  • Listmonk : http://localhost:$NEW_LISTMONK_PORT"
echo "  • Adminer  : http://localhost:$NEW_ADMINER_PORT"
echo "  • PostgreSQL : localhost:$NEW_POSTGRES_PORT"
echo ""
echo "🔑 Identifiants :"
echo "  • Utilisateur : admin"
echo "  • Mot de passe : admin123!"
echo ""
echo "🔧 Commandes pour ce déploiement :"
echo "  • Logs : docker-compose -f docker-compose.ports-fixed.yml logs -f"
echo "  • Arrêt : docker-compose -f docker-compose.ports-fixed.yml down"
echo "  • Redémarrage : docker-compose -f docker-compose.ports-fixed.yml restart"
echo ""
echo "💾 Le fichier docker-compose.ports-fixed.yml a été sauvegardé pour usage futur"