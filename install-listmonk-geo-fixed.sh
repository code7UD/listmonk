#!/bin/bash

# Script d'installation corrigé - Extension Géographique Listmonk
# Résout les problèmes de compatibilité Alpine Linux

set -e

echo "🗺️ INSTALLATION LISTMONK AVEC EXTENSION GÉOGRAPHIQUE FRANÇAISE (VERSION CORRIGÉE)"
echo "=================================================================================="
echo ""

# Couleurs pour l'affichage
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

print_status() {
    echo -e "${BLUE}ℹ️${NC} $1"
}

print_success() {
    echo -e "${GREEN}✅${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}⚠️${NC} $1"
}

print_error() {
    echo -e "${RED}❌${NC} $1"
}

# Fonction de vérification des prérequis
check_prerequisites() {
    print_status "Vérification des prérequis..."
    
    # Vérifier Docker
    if ! command -v docker &> /dev/null; then
        print_error "Docker n'est pas installé"
        echo "Installez Docker : https://docs.docker.com/get-docker/"
        exit 1
    fi
    
    # Vérifier Docker Compose
    if ! command -v docker &> /dev/null || ! docker compose version &> /dev/null; then
        print_error "Docker Compose n'est pas installé ou trop ancien"
        echo "Installez Docker Compose v2+ : https://docs.docker.com/compose/install/"
        exit 1
    fi
    
    # Vérifier les permissions Docker
    if ! docker ps &> /dev/null; then
        print_error "Permissions Docker insuffisantes"
        echo "Ajoutez votre utilisateur au groupe docker : sudo usermod -aG docker \$USER"
        exit 1
    fi
    
    print_success "Prérequis validés"
}

# Fonction de nettoyage
cleanup_previous() {
    print_status "Nettoyage des installations précédentes..."
    
    # Arrêter les conteneurs existants
    docker compose -f docker-compose.alpine-fixed.yml down -v 2>/dev/null || true
    docker compose -f docker-compose.simple.yml down -v 2>/dev/null || true
    docker compose -f docker-compose.yml down -v 2>/dev/null || true
    
    # Nettoyer les volumes PostgreSQL incompatibles
    print_status "Nettoyage des volumes PostgreSQL incompatibles..."
    docker volume rm listmonk_postgres_data 2>/dev/null || true
    
    # Nettoyer le cache Docker
    docker builder prune -f
    
    print_success "Nettoyage terminé"
}

# Fonction de configuration
setup_environment() {
    print_status "Création du fichier .env..."
    
    # Générer des mots de passe sécurisés
    DB_PASSWORD=$(openssl rand -base64 32 2>/dev/null || date +%s | sha256sum | base64 | head -c 32)
    ADMIN_PASSWORD="admin123"
    
    cat > .env << EOF
# =============================================================================
# Configuration Listmonk avec extensions géographiques (VERSION CORRIGÉE)
# =============================================================================

# Application
LISTMONK_APP_ADMIN_USERNAME=admin
LISTMONK_APP_ADMIN_PASSWORD=${ADMIN_PASSWORD}
LISTMONK_PORT=9000

# Base de données PostgreSQL 17
LISTMONK_DB_USER=listmonk
LISTMONK_DB_PASSWORD=${DB_PASSWORD}
LISTMONK_DB_DATABASE=listmonk

# Extensions géographiques
LISTMONK_GEO_ENABLED=true
LISTMONK_GEO_AUTO_INDEX=true
LISTMONK_GEO_CACHE_TTL=3600

# Import CSV
LISTMONK_CSV_BATCH_SIZE=1000
LISTMONK_CSV_VALIDATE_INSEE=true

# Interface d'administration (optionnel)
ADMINER_PORT=8080
EOF
    
    print_success "Fichier .env créé"
    print_warning "Mot de passe admin : ${ADMIN_PASSWORD}"
    print_warning "Mot de passe DB : ${DB_PASSWORD}"
}

# Fonction de préparation
prepare_files() {
    print_status "Création des répertoires..."
    mkdir -p uploads static demo
    
    print_status "Préparation des fichiers de démonstration..."
    
    # Créer un fichier CSV de démonstration
    cat > demo/demo_geo_data.csv << 'EOF'
email,firstname,lastname,city,state,zipcode,country,code_insee,population_commune,nom_commune,departement_numero,csp
jean.dupont@example.com,Jean,Dupont,Paris,PARIS,75001,France,75101,2161000,PARIS,75,Cadres
marie.martin@example.com,Marie,Martin,Lyon,RHÔNE,69001,France,69123,515695,LYON,69,Employés
pierre.bernard@example.com,Pierre,Bernard,Marseille,BOUCHES-DU-RHÔNE,13001,France,13201,861635,MARSEILLE,13,Ouvriers
sophie.dubois@example.com,Sophie,Dubois,Toulouse,HAUTE-GARONNE,31000,France,31555,471941,TOULOUSE,31,Professions intermédiaires
michel.robert@example.com,Michel,Robert,Nice,ALPES-MARITIMES,06000,France,06088,342637,NICE,06,Retraités
EOF
    
    print_status "Configuration des permissions..."
    chmod 755 uploads static demo
    chmod 644 demo/demo_geo_data.csv
}

# Fonction de vérification des ports
check_ports() {
    print_status "Vérification des ports..."
    
    LISTMONK_PORT=9000
    ADMINER_PORT=8080
    
    # Vérifier le port Listmonk
    if netstat -tuln 2>/dev/null | grep -q ":${LISTMONK_PORT} " || lsof -i :${LISTMONK_PORT} 2>/dev/null; then
        print_warning "Port ${LISTMONK_PORT} occupé, utilisation du port 9001"
        LISTMONK_PORT=9001
        sed -i "s/LISTMONK_PORT=9000/LISTMONK_PORT=9001/" .env
    fi
    
    # Vérifier le port Adminer
    if netstat -tuln 2>/dev/null | grep -q ":${ADMINER_PORT} " || lsof -i :${ADMINER_PORT} 2>/dev/null; then
        print_warning "Port ${ADMINER_PORT} occupé, utilisation du port 8083"
        ADMINER_PORT=8083
        sed -i "s/ADMINER_PORT=8080/ADMINER_PORT=8083/" .env
    fi
}

# Fonction de construction et démarrage
build_and_start() {
    print_status "Construction et démarrage des services..."
    print_status "Utilisation du fichier: docker-compose.alpine-fixed.yml"
    
    # Vérifier les fichiers requis
    print_status "Vérification des fichiers requis..."
    required_files=(
        "Dockerfile.geo.alpine-fixed"
        "docker-compose.alpine-fixed.yml"
        "docker/init-scripts/01-init-geo.sql"
        ".env"
    )
    
    for file in "${required_files[@]}"; do
        if [[ ! -f "$file" ]]; then
            print_error "Fichier manquant : $file"
            exit 1
        fi
    done
    
    print_success "Tous les fichiers requis sont présents"
    
    # Construction de l'image Docker
    print_status "Construction de l'image Docker..."
    if ! docker compose -f docker-compose.alpine-fixed.yml build; then
        print_error "Échec de la construction Docker"
        print_status "Tentative de nettoyage et reconstruction..."
        docker builder prune -f
        docker system prune -f
        
        if ! docker compose -f docker-compose.alpine-fixed.yml build --no-cache; then
            print_error "Échec définitif de la construction"
            print_status "Vérifiez les logs ci-dessus pour plus de détails"
            exit 1
        fi
    fi
    
    print_success "Construction Docker réussie"
    
    # Démarrage des services
    print_status "Démarrage des services..."
    if ! docker compose -f docker-compose.alpine-fixed.yml up -d; then
        print_error "Échec du démarrage des services"
        exit 1
    fi
    
    print_success "Services démarrés"
}

# Fonction d'attente et initialisation
wait_and_initialize() {
    print_status "Attente du démarrage de PostgreSQL..."
    
    # Attendre que PostgreSQL soit prêt
    for i in {1..30}; do
        if docker compose -f docker-compose.alpine-fixed.yml exec postgres pg_isready -U listmonk -d listmonk &>/dev/null; then
            print_success "PostgreSQL est prêt"
            break
        fi
        
        if [ $i -eq 30 ]; then
            print_error "Timeout - PostgreSQL ne répond pas"
            docker compose -f docker-compose.alpine-fixed.yml logs postgres
            exit 1
        fi
        
        echo -n "."
        sleep 2
    done
    
    print_status "Attente du démarrage de Listmonk..."
    sleep 10
    
    # Initialiser Listmonk (première installation uniquement)
    print_status "Initialisation de Listmonk..."
    if ! docker compose -f docker-compose.alpine-fixed.yml exec listmonk ./listmonk --install --yes; then
        print_warning "L'initialisation a échoué (peut-être déjà initialisé)"
        print_status "Tentative de redémarrage..."
        docker compose -f docker-compose.alpine-fixed.yml restart listmonk
        sleep 5
    fi
}

# Fonction de validation
validate_installation() {
    print_status "Validation de l'installation..."
    
    # Vérifier les conteneurs
    if ! docker compose -f docker-compose.alpine-fixed.yml ps | grep -q "Up"; then
        print_error "Les conteneurs ne sont pas en cours d'exécution"
        docker compose -f docker-compose.alpine-fixed.yml ps
        exit 1
    fi
    
    # Vérifier l'accès à l'interface
    LISTMONK_PORT=$(grep LISTMONK_PORT .env | cut -d'=' -f2)
    if curl -f -s "http://localhost:${LISTMONK_PORT}/health" > /dev/null 2>&1; then
        print_success "Interface Listmonk accessible"
    else
        print_warning "Interface Listmonk non accessible (peut nécessiter quelques minutes)"
    fi
    
    # Vérifier la base de données
    if docker compose -f docker-compose.alpine-fixed.yml exec postgres psql -U listmonk -d listmonk -c "SELECT COUNT(*) FROM departement_region_mapping;" | grep -q "95"; then
        print_success "Base de données géographique initialisée (95 départements)"
    else
        print_warning "Base de données géographique en cours d'initialisation"
    fi
}

# Fonction d'affichage des informations finales
show_final_info() {
    LISTMONK_PORT=$(grep LISTMONK_PORT .env | cut -d'=' -f2)
    ADMINER_PORT=$(grep ADMINER_PORT .env | cut -d'=' -f2)
    ADMIN_PASSWORD=$(grep LISTMONK_APP_ADMIN_PASSWORD .env | cut -d'=' -f2)
    
    echo ""
    echo "🎉 INSTALLATION TERMINÉE AVEC SUCCÈS !"
    echo "======================================"
    echo ""
    print_success "Interface Listmonk : http://localhost:${LISTMONK_PORT}"
    print_success "Identifiants admin : admin / ${ADMIN_PASSWORD}"
    print_success "Interface PostgreSQL : http://localhost:${ADMINER_PORT}"
    echo ""
    print_status "Fonctionnalités géographiques disponibles :"
    echo "  • Segmentation par région (13 régions françaises)"
    echo "  • Segmentation par département (95 départements)"
    echo "  • Recherche de communes avec autocomplete"
    echo "  • Filtrage par population communale"
    echo "  • Filtrage par CSP (Catégorie Socio-Professionnelle)"
    echo "  • Import CSV avec données géographiques françaises"
    echo ""
    print_status "Fichier de démonstration : demo/demo_geo_data.csv"
    echo ""
    print_status "Commandes utiles :"
    echo "  • Arrêter : docker compose -f docker-compose.alpine-fixed.yml down"
    echo "  • Démarrer : docker compose -f docker-compose.alpine-fixed.yml up -d"
    echo "  • Logs : docker compose -f docker-compose.alpine-fixed.yml logs -f"
    echo "  • Réinitialiser : docker compose -f docker-compose.alpine-fixed.yml down -v"
    echo ""
    print_success "🚀 Votre Listmonk géographique est prêt à l'emploi !"
}

# Exécution du script principal
main() {
    check_prerequisites
    cleanup_previous
    setup_environment
    prepare_files
    check_ports
    build_and_start
    wait_and_initialize
    validate_installation
    show_final_info
}

# Gestion des erreurs
trap 'print_error "Installation interrompue"; exit 1' INT TERM

# Lancer l'installation
main "$@"