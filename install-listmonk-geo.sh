#!/bin/bash

# Script principal d'installation de Listmonk avec extension géographique française
# Version nettoyée et consolidée

set -e

# Couleurs pour l'affichage
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Fonctions utilitaires
log_info() {
    echo -e "${BLUE}ℹ️ $1${NC}"
}

log_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

log_warning() {
    echo -e "${YELLOW}⚠️ $1${NC}"
}

log_error() {
    echo -e "${RED}❌ $1${NC}"
}

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
            log_error "Aucun port libre trouvé"
            exit 1
        fi
    done
    
    echo $port
}

# Fonction de nettoyage
cleanup_previous_installations() {
    log_info "Nettoyage des installations précédentes..."
    
    # Arrêter tous les containers listmonk existants
    docker-compose -f docker-compose.geo.yml down -v 2>/dev/null || true
    docker-compose -f docker-compose.simple.yml down -v 2>/dev/null || true
    docker-compose -f docker-compose.ports-fixed.yml down -v 2>/dev/null || true
    docker-compose -f docker-compose.custom.yml down -v 2>/dev/null || true
    
    # Supprimer spécifiquement les volumes PostgreSQL problématiques
    log_info "Nettoyage des volumes PostgreSQL incompatibles..."
    docker volume rm listmonk_postgres_data 2>/dev/null || true
    docker volume rm listmonk-geo_postgres_data 2>/dev/null || true
    docker volume rm $(docker volume ls -q | grep -E "(listmonk|postgres)") 2>/dev/null || true
    
    # Supprimer les containers arrêtés et images orphelines
    docker container prune -f 2>/dev/null || true
    docker system prune -f 2>/dev/null || true
    
    log_success "Nettoyage terminé"
}

# Fonction principale d'installation
main() {
    echo "🗺️ INSTALLATION LISTMONK AVEC EXTENSION GÉOGRAPHIQUE FRANÇAISE"
    echo "=============================================================="
    echo ""
    
    # Vérifications préliminaires
    log_info "Vérification des prérequis..."
    
    if ! command -v docker &> /dev/null; then
        log_error "Docker n'est pas installé. Veuillez installer Docker d'abord."
        exit 1
    fi
    
    if ! command -v docker-compose &> /dev/null; then
        log_error "Docker Compose n'est pas installé. Veuillez installer Docker Compose d'abord."
        exit 1
    fi
    
    # Vérifier que Docker fonctionne
    if ! docker info &> /dev/null; then
        log_error "Docker n'est pas démarré ou accessible. Vérifiez les permissions."
        log_info "Essayez: sudo systemctl start docker"
        exit 1
    fi
    
    # Vérifier l'espace disque (minimum 2GB)
    AVAILABLE_SPACE=$(df . | awk 'NR==2 {print $4}')
    if [ "$AVAILABLE_SPACE" -lt 2097152 ]; then  # 2GB en KB
        log_warning "Espace disque faible (< 2GB). L'installation pourrait échouer."
    fi
    
    # Vérifier les permissions d'écriture
    if [ ! -w "." ]; then
        log_error "Pas de permissions d'écriture dans le répertoire courant"
        exit 1
    fi
    
    log_success "Prérequis validés"
    
    # Vérifier la branche Git
    CURRENT_BRANCH=$(git branch --show-current 2>/dev/null || echo "unknown")
    if [ "$CURRENT_BRANCH" != "feature/french-geographic-segmentation" ]; then
        log_warning "Vous n'êtes pas sur la branche feature/french-geographic-segmentation"
        log_info "Basculement vers la bonne branche..."
        git checkout feature/french-geographic-segmentation
    fi
    
    # Nettoyage
    cleanup_previous_installations
    
    # Créer le fichier .env s'il n'existe pas
    if [ ! -f ".env" ]; then
        log_info "Création du fichier .env..."
        cp .env.example .env
        log_success "Fichier .env créé"
    fi
    
    # Créer les répertoires nécessaires
    log_info "Création des répertoires..."
    mkdir -p data/postgres data/uploads demo
    
    # Copier les fichiers de démonstration
    log_info "Préparation des fichiers de démonstration..."
    cp demo_geo_data.csv demo/ 2>/dev/null || log_warning "Fichier demo_geo_data.csv non trouvé"
    cp demo_geographic_queries.sql demo/ 2>/dev/null || log_warning "Fichier demo_geographic_queries.sql non trouvé"
    cp test_geo_data.csv demo/ 2>/dev/null || log_warning "Fichier test_geo_data.csv non trouvé"
    
    # Rendre les scripts exécutables
    log_info "Configuration des permissions..."
    chmod +x docker/entrypoint.sh
    chmod +x docker/scripts/*.sh 2>/dev/null || true
    chmod +x scripts/docker/*.sh 2>/dev/null || true
    
    # Vérification des ports
    log_info "Vérification des ports..."
    
    POSTGRES_PORT=5432
    ADMINER_PORT=8080
    LISTMONK_PORT=9000
    
    PORTS_CHANGED=false
    NEW_POSTGRES_PORT=$POSTGRES_PORT
    NEW_ADMINER_PORT=$ADMINER_PORT
    NEW_LISTMONK_PORT=$LISTMONK_PORT
    
    if check_port $POSTGRES_PORT; then
        NEW_POSTGRES_PORT=$(find_free_port 5433)
        log_warning "Port $POSTGRES_PORT occupé, utilisation du port $NEW_POSTGRES_PORT"
        PORTS_CHANGED=true
    fi
    
    if check_port $ADMINER_PORT; then
        NEW_ADMINER_PORT=$(find_free_port 8081)
        log_warning "Port $ADMINER_PORT occupé, utilisation du port $NEW_ADMINER_PORT"
        PORTS_CHANGED=true
    fi
    
    if check_port $LISTMONK_PORT; then
        NEW_LISTMONK_PORT=$(find_free_port 9001)
        log_warning "Port $LISTMONK_PORT occupé, utilisation du port $NEW_LISTMONK_PORT"
        PORTS_CHANGED=true
    fi
    
    # Choisir le fichier docker-compose approprié
    COMPOSE_FILE="docker-compose.simple.yml"
    
    if [ "$PORTS_CHANGED" = true ]; then
        log_info "Création d'une configuration Docker avec ports adaptés..."
        
        # Créer un docker-compose personnalisé
        sed "s/\"5432:5432\"/\"$NEW_POSTGRES_PORT:5432\"/g; s/\"8080:8080\"/\"$NEW_ADMINER_PORT:8080\"/g; s/\"9000:9000\"/\"$NEW_LISTMONK_PORT:9000\"/g" docker-compose.simple.yml > docker-compose.custom.yml
        
        COMPOSE_FILE="docker-compose.custom.yml"
    fi
    
    # Construction et démarrage
    log_info "Construction et démarrage des services..."
    log_info "Utilisation du fichier: $COMPOSE_FILE"
    
    # Vérifier que tous les fichiers nécessaires existent
    log_info "Vérification des fichiers requis..."
    
    REQUIRED_FILES=(
        "Dockerfile.geo.simple"
        "docker/entrypoint.sh"
        "demo_geo_data.csv"
        "demo_geographic_queries.sql"
        "test_geo_data.csv"
    )
    
    for file in "${REQUIRED_FILES[@]}"; do
        if [ ! -f "$file" ]; then
            log_error "Fichier requis manquant: $file"
            exit 1
        fi
    done
    
    log_success "Tous les fichiers requis sont présents"
    
    # Construction avec gestion d'erreur
    log_info "Construction de l'image Docker..."
    if ! docker-compose -f "$COMPOSE_FILE" build --no-cache; then
        log_error "Échec de la construction Docker"
        log_info "Tentative de nettoyage et reconstruction..."
        
        # Nettoyage approfondi
        docker system prune -af
        docker builder prune -af
        
        # Nouvelle tentative
        if ! docker-compose -f "$COMPOSE_FILE" build --no-cache; then
            log_error "Échec définitif de la construction"
            log_info "Vérifiez les logs ci-dessus pour plus de détails"
            exit 1
        fi
    fi
    
    log_success "Construction réussie"
    
    # Démarrage avec gestion d'erreur
    log_info "Démarrage des services..."
    if ! docker-compose -f "$COMPOSE_FILE" up -d; then
        log_error "Échec du démarrage des services"
        log_info "Affichage des logs pour diagnostic..."
        docker-compose -f "$COMPOSE_FILE" logs
        exit 1
    fi
    
    log_success "Services démarrés"
    
    # Attendre le démarrage
    log_info "Attente du démarrage des services (30 secondes)..."
    sleep 30
    
    # Vérification de l'état
    log_info "Vérification de l'état des services..."
    docker-compose -f "$COMPOSE_FILE" ps
    
    # Test de connectivité
    log_info "Test de connectivité..."
    RETRY_COUNT=0
    MAX_RETRIES=6
    
    while [ $RETRY_COUNT -lt $MAX_RETRIES ]; do
        if curl -s http://localhost:$NEW_LISTMONK_PORT/health > /dev/null; then
            log_success "Listmonk est accessible !"
            break
        else
            RETRY_COUNT=$((RETRY_COUNT + 1))
            log_info "Tentative $RETRY_COUNT/$MAX_RETRIES - Attente de Listmonk..."
            sleep 10
        fi
    done
    
    # Affichage des résultats
    echo ""
    echo "🎉 INSTALLATION TERMINÉE !"
    echo "========================="
    echo ""
    echo "📱 Accès aux services :"
    echo "  • Listmonk : http://localhost:$NEW_LISTMONK_PORT"
    echo "  • Adminer  : http://localhost:$NEW_ADMINER_PORT"
    echo "  • PostgreSQL : localhost:$NEW_POSTGRES_PORT"
    echo ""
    echo "🔑 Identifiants par défaut :"
    echo "  • Utilisateur : admin"
    echo "  • Mot de passe : admin123!"
    echo ""
    echo "📊 Fonctionnalités géographiques disponibles :"
    echo "  • Segmentation par région française"
    echo "  • Filtrage par département"
    echo "  • Recherche de communes"
    echo "  • Filtrage par population"
    echo "  • Segmentation par CSP"
    echo ""
    echo "🔧 Commandes utiles :"
    echo "  • Voir les logs : docker-compose -f $COMPOSE_FILE logs -f"
    echo "  • Arrêter : docker-compose -f $COMPOSE_FILE down"
    echo "  • Redémarrer : docker-compose -f $COMPOSE_FILE restart"
    echo ""
    
    if [ $RETRY_COUNT -eq $MAX_RETRIES ]; then
        log_warning "Listmonk ne répond pas encore. Vérifiez les logs avec:"
        echo "   docker-compose -f $COMPOSE_FILE logs -f listmonk"
    else
        log_success "Installation réussie ! Bon géomarketing avec Listmonk !"
    fi
}

# Gestion des arguments
case "${1:-}" in
    --help|-h)
        echo "Usage: $0 [options]"
        echo ""
        echo "Options:"
        echo "  --help, -h     Afficher cette aide"
        echo "  --clean        Nettoyer uniquement (sans installation)"
        echo ""
        echo "Ce script installe Listmonk avec l'extension géographique française."
        echo "Il gère automatiquement les conflits de ports et la configuration Docker."
        exit 0
        ;;
    --clean)
        cleanup_previous_installations
        log_success "Nettoyage terminé"
        exit 0
        ;;
    *)
        main
        ;;
esac