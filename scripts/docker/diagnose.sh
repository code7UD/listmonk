#!/bin/bash

# Script de diagnostic pour Listmonk Géographique

echo "🔍 DIAGNOSTIC LISTMONK GÉOGRAPHIQUE"
echo "==================================="

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

echo ""
log_info "1. Vérification de l'environnement"
echo "=================================="

# Docker
if command -v docker &> /dev/null; then
    log_success "Docker installé: $(docker --version)"
    if docker info &> /dev/null; then
        log_success "Docker fonctionne"
    else
        log_error "Docker ne répond pas"
    fi
else
    log_error "Docker non installé"
fi

# Docker Compose
if command -v docker-compose &> /dev/null; then
    log_success "Docker Compose installé: $(docker-compose --version)"
else
    log_error "Docker Compose non installé"
fi

# Git
if command -v git &> /dev/null; then
    BRANCH=$(git branch --show-current 2>/dev/null || echo "unknown")
    log_info "Branche Git: $BRANCH"
    if [ "$BRANCH" = "feature/french-geographic-segmentation" ]; then
        log_success "Bonne branche Git"
    else
        log_warning "Branche Git incorrecte (attendu: feature/french-geographic-segmentation)"
    fi
else
    log_warning "Git non disponible"
fi

echo ""
log_info "2. Vérification des fichiers"
echo "============================"

REQUIRED_FILES=(
    "install-listmonk-geo.sh"
    "docker-compose.simple.yml"
    "Dockerfile.geo.simple"
    "docker/entrypoint.sh"
    "demo_geo_data.csv"
    "demo_geographic_queries.sql"
    "test_geo_data.csv"
    ".env.example"
)

for file in "${REQUIRED_FILES[@]}"; do
    if [ -f "$file" ]; then
        log_success "$file"
    else
        log_error "$file manquant"
    fi
done

echo ""
log_info "3. Vérification des ports"
echo "========================="

PORTS=(5432 8080 9000)
for port in "${PORTS[@]}"; do
    if netstat -tuln 2>/dev/null | grep -q ":$port " || ss -tuln 2>/dev/null | grep -q ":$port "; then
        log_warning "Port $port occupé"
    else
        log_success "Port $port libre"
    fi
done

echo ""
log_info "4. Vérification de l'espace disque"
echo "=================================="

AVAILABLE_SPACE=$(df . | awk 'NR==2 {print $4}')
AVAILABLE_GB=$((AVAILABLE_SPACE / 1024 / 1024))

if [ "$AVAILABLE_SPACE" -gt 2097152 ]; then
    log_success "Espace disque suffisant: ${AVAILABLE_GB}GB"
else
    log_warning "Espace disque faible: ${AVAILABLE_GB}GB (minimum 2GB recommandé)"
fi

echo ""
log_info "5. État des containers Docker"
echo "============================="

if docker ps -a --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}" | grep -E "(listmonk|postgres)" &> /dev/null; then
    echo "Containers Listmonk trouvés:"
    docker ps -a --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}" | grep -E "(listmonk|postgres)"
    
    # Vérifier les containers en erreur
    if docker ps -a --format "{{.Names}}\t{{.Status}}" | grep -E "(listmonk|postgres)" | grep -q "Exited\|unhealthy"; then
        log_warning "Containers en erreur détectés"
        
        # Vérifier spécifiquement l'erreur PostgreSQL
        if docker logs listmonk-postgres-geo 2>/dev/null | grep -q "database files are incompatible"; then
            log_error "Problème de version PostgreSQL détecté!"
            log_info "Solution: ./scripts/docker/fix-postgres-version.sh"
        fi
    fi
else
    log_info "Aucun container Listmonk trouvé"
fi

echo ""
log_info "6. Images Docker"
echo "================"

if docker images | grep -E "(listmonk|postgres)" &> /dev/null; then
    echo "Images Listmonk trouvées:"
    docker images | grep -E "(listmonk|postgres)"
else
    log_info "Aucune image Listmonk trouvée"
fi

echo ""
log_info "7. Logs récents (si containers actifs)"
echo "======================================"

COMPOSE_FILES=("docker-compose.simple.yml" "docker-compose.custom.yml" "docker-compose.geo.yml")

for compose_file in "${COMPOSE_FILES[@]}"; do
    if [ -f "$compose_file" ]; then
        log_info "Vérification avec $compose_file"
        if docker-compose -f "$compose_file" ps | grep -q "Up"; then
            echo "--- Logs récents ---"
            docker-compose -f "$compose_file" logs --tail=10
            break
        fi
    fi
done

echo ""
log_info "8. Recommandations"
echo "=================="

echo "🔧 Actions suggérées:"
echo ""

# Vérifier les problèmes courants
if ! command -v docker &> /dev/null; then
    echo "• Installer Docker: https://docs.docker.com/get-docker/"
fi

if ! command -v docker-compose &> /dev/null; then
    echo "• Installer Docker Compose: https://docs.docker.com/compose/install/"
fi

if [ "$BRANCH" != "feature/french-geographic-segmentation" ]; then
    echo "• Basculer sur la bonne branche: git checkout feature/french-geographic-segmentation"
fi

if [ "$AVAILABLE_SPACE" -lt 2097152 ]; then
    echo "• Libérer de l'espace disque (minimum 2GB)"
fi

# Vérifier si des ports sont occupés
PORTS_OCCUPIED=false
for port in 5432 8080 9000; do
    if netstat -tuln 2>/dev/null | grep -q ":$port " || ss -tuln 2>/dev/null | grep -q ":$port "; then
        PORTS_OCCUPIED=true
        break
    fi
done

if [ "$PORTS_OCCUPIED" = true ]; then
    echo "• Le script install-listmonk-geo.sh gère automatiquement les conflits de ports"
fi

echo ""
echo "🚀 Pour installer/réinstaller:"
echo "   ./install-listmonk-geo.sh --clean && ./install-listmonk-geo.sh"
echo ""
echo "📋 Pour voir ce diagnostic à nouveau:"
echo "   ./scripts/docker/diagnose.sh"