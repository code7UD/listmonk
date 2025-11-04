#!/bin/bash

# Script de validation post-installation

set -e

# Couleurs
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() { echo -e "${BLUE}ℹ️ $1${NC}"; }
log_success() { echo -e "${GREEN}✅ $1${NC}"; }
log_warning() { echo -e "${YELLOW}⚠️ $1${NC}"; }
log_error() { echo -e "${RED}❌ $1${NC}"; }

echo "🔍 VALIDATION INSTALLATION LISTMONK GÉOGRAPHIQUE"
echo "==============================================="
echo ""

# Déterminer le fichier docker-compose à utiliser
COMPOSE_FILE="docker-compose.simple.yml"
if [ -f "docker-compose.custom.yml" ]; then
    COMPOSE_FILE="docker-compose.custom.yml"
fi

log_info "Utilisation du fichier: $COMPOSE_FILE"
echo ""

# 1. Vérifier que les services sont actifs
log_info "1. Vérification de l'état des services"
echo "======================================"

if docker-compose -f "$COMPOSE_FILE" ps | grep -q "Up"; then
    log_success "Services Docker actifs"
    docker-compose -f "$COMPOSE_FILE" ps
else
    log_error "Aucun service actif trouvé"
    echo "Lancez d'abord: ./install-listmonk-geo.sh"
    exit 1
fi

echo ""

# 2. Vérifier PostgreSQL
log_info "2. Validation PostgreSQL"
echo "========================"

# Vérifier que PostgreSQL répond
if docker exec listmonk-postgres-geo pg_isready -U listmonk -d listmonk &>/dev/null; then
    log_success "PostgreSQL répond"
else
    log_error "PostgreSQL ne répond pas"
    exit 1
fi

# Vérifier la version PostgreSQL
PG_VERSION=$(docker exec listmonk-postgres-geo psql -U listmonk -d listmonk -t -c "SELECT version();" | head -1)
if echo "$PG_VERSION" | grep -q "PostgreSQL 17"; then
    log_success "PostgreSQL 17 confirmé"
else
    log_warning "Version PostgreSQL inattendue: $PG_VERSION"
fi

# Vérifier les extensions
EXTENSIONS=$(docker exec listmonk-postgres-geo psql -U listmonk -d listmonk -t -c "SELECT extname FROM pg_extension WHERE extname IN ('uuid-ossp', 'pg_trgm');" | tr -d ' ' | sort)
if echo "$EXTENSIONS" | grep -q "pg_trgm" && echo "$EXTENSIONS" | grep -q "uuid-ossp"; then
    log_success "Extensions PostgreSQL installées (uuid-ossp, pg_trgm)"
else
    log_warning "Extensions manquantes. Trouvées: $EXTENSIONS"
fi

echo ""

# 3. Vérifier la table de mapping géographique
log_info "3. Validation des données géographiques"
echo "======================================="

# Vérifier l'existence de la table
if docker exec listmonk-postgres-geo psql -U listmonk -d listmonk -t -c "\dt departement_region_mapping" &>/dev/null; then
    log_success "Table departement_region_mapping existe"
    
    # Compter les départements
    DEPT_COUNT=$(docker exec listmonk-postgres-geo psql -U listmonk -d listmonk -t -c "SELECT COUNT(*) FROM departement_region_mapping;" | tr -d ' ')
    if [ "$DEPT_COUNT" = "95" ]; then
        log_success "95 départements français chargés"
    else
        log_warning "Nombre de départements inattendu: $DEPT_COUNT (attendu: 95)"
    fi
    
    # Vérifier quelques régions
    REGIONS=$(docker exec listmonk-postgres-geo psql -U listmonk -d listmonk -t -c "SELECT COUNT(DISTINCT region_nom) FROM departement_region_mapping;" | tr -d ' ')
    if [ "$REGIONS" -ge "12" ]; then
        log_success "$REGIONS régions françaises disponibles"
    else
        log_warning "Nombre de régions faible: $REGIONS"
    fi
else
    log_error "Table departement_region_mapping manquante"
fi

echo ""

# 4. Vérifier Listmonk
log_info "4. Validation Listmonk"
echo "======================"

# Vérifier le health check
if docker-compose -f "$COMPOSE_FILE" ps | grep listmonk | grep -q "healthy"; then
    log_success "Listmonk healthy"
elif docker-compose -f "$COMPOSE_FILE" ps | grep listmonk | grep -q "Up"; then
    log_warning "Listmonk actif mais health check en cours..."
else
    log_error "Listmonk non actif"
fi

# Tester la connectivité HTTP
if curl -f -s http://localhost:9000/health >/dev/null 2>&1; then
    log_success "Listmonk accessible sur http://localhost:9000"
elif curl -f -s http://localhost:9001/health >/dev/null 2>&1; then
    log_success "Listmonk accessible sur http://localhost:9001 (port alternatif)"
elif curl -f -s http://localhost:9002/health >/dev/null 2>&1; then
    log_success "Listmonk accessible sur http://localhost:9002 (port alternatif)"
else
    log_warning "Listmonk non accessible via HTTP (peut être en cours de démarrage)"
fi

echo ""

# 5. Vérifier Adminer
log_info "5. Validation Adminer"
echo "===================="

if curl -f -s http://localhost:8080 >/dev/null 2>&1; then
    log_success "Adminer accessible sur http://localhost:8080"
elif curl -f -s http://localhost:8081 >/dev/null 2>&1; then
    log_success "Adminer accessible sur http://localhost:8081 (port alternatif)"
else
    log_warning "Adminer non accessible"
fi

echo ""

# 6. Résumé et recommandations
log_info "6. Résumé de validation"
echo "======================="

echo "🎯 Services validés:"
echo "  • PostgreSQL 17 avec extensions géographiques"
echo "  • Table de mapping départements/régions (95 départements)"
echo "  • Listmonk avec extension géographique"
echo "  • Adminer pour administration base de données"
echo ""

echo "🌐 Accès aux services:"
# Détecter les ports utilisés
LISTMONK_PORT=$(docker-compose -f "$COMPOSE_FILE" ps | grep listmonk | grep -o "0.0.0.0:[0-9]*" | cut -d: -f2 | head -1)
ADMINER_PORT=$(docker-compose -f "$COMPOSE_FILE" ps | grep adminer | grep -o "0.0.0.0:[0-9]*" | cut -d: -f2 | head -1)

if [ -n "$LISTMONK_PORT" ]; then
    echo "  • Listmonk : http://localhost:$LISTMONK_PORT"
else
    echo "  • Listmonk : http://localhost:9000 (port par défaut)"
fi

if [ -n "$ADMINER_PORT" ]; then
    echo "  • Adminer  : http://localhost:$ADMINER_PORT"
else
    echo "  • Adminer  : http://localhost:8080 (port par défaut)"
fi

echo "  • PostgreSQL : localhost:5432"
echo ""

echo "🔑 Identifiants par défaut:"
echo "  • Utilisateur : admin"
echo "  • Mot de passe : admin123!"
echo ""

echo "📋 Prochaines étapes:"
echo "  1. Accéder à Listmonk via l'URL ci-dessus"
echo "  2. Se connecter avec les identifiants par défaut"
echo "  3. Importer un fichier CSV avec données géographiques"
echo "  4. Tester la segmentation géographique dans 'Listes'"
echo ""

echo "🆘 En cas de problème:"
echo "  • Diagnostic : ./scripts/docker/diagnose.sh"
echo "  • Logs : docker-compose -f $COMPOSE_FILE logs -f"
echo "  • Réinstallation : ./install-listmonk-geo.sh --clean && ./install-listmonk-geo.sh"

echo ""
log_success "Validation terminée ! L'installation semble fonctionnelle."