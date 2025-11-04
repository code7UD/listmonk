#!/bin/bash

# Script d'installation corrigé pour Listmonk avec extension géographique française
# Version corrigée qui résout les problèmes de build Docker

set -e

echo "🗺️ INSTALLATION LISTMONK AVEC EXTENSION GÉOGRAPHIQUE FRANÇAISE (VERSION CORRIGÉE)"
echo "=================================================================================="

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
        exit 1
    fi
    
    # Vérifier Docker Compose
    if ! command -v docker &> /dev/null || ! docker compose version &> /dev/null; then
        print_error "Docker Compose n'est pas installé ou accessible"
        exit 1
    fi
    
    # Vérifier les permissions Docker
    if ! docker ps &> /dev/null; then
        print_error "Permissions Docker insuffisantes. Ajoutez votre utilisateur au groupe docker ou utilisez sudo"
        exit 1
    fi
    
    print_success "Prérequis validés"
}

# Fonction de nettoyage
cleanup_previous() {
    print_status "Nettoyage des installations précédentes..."
    
    # Arrêter les conteneurs existants
    docker compose -f docker-compose.fixed.yml down -v 2>/dev/null || true
    docker compose -f docker-compose.simple.yml down -v 2>/dev/null || true
    docker compose -f docker-compose.custom.yml down -v 2>/dev/null || true
    
    # Nettoyer les volumes PostgreSQL incompatibles
    print_status "Nettoyage des volumes PostgreSQL incompatibles..."
    docker volume rm listmonk_postgres_data 2>/dev/null || true
    
    # Nettoyer le cache Docker
    docker builder prune -f
    
    print_success "Nettoyage terminé"
}

# Fonction de création du fichier .env
create_env_file() {
    print_status "Création du fichier .env..."
    
    if [[ ! -f ".env" ]]; then
        cat > .env << 'EOF'
# =============================================================================
# Configuration Listmonk avec extensions géographiques (VERSION CORRIGÉE)
# =============================================================================

# Application
LISTMONK_APP_ADMIN_USERNAME=admin
LISTMONK_APP_ADMIN_PASSWORD=admin123
LISTMONK_PORT=9000

# Base de données PostgreSQL 17
LISTMONK_DB_USER=listmonk
LISTMONK_DB_PASSWORD=listmonk_secure_password
LISTMONK_DB_DATABASE=listmonk

# Adminer (interface base de données)
ADMINER_PORT=8083

# Extensions géographiques
LISTMONK_GEO_ENABLED=true
LISTMONK_GEO_AUTO_INDEX=true
LISTMONK_GEO_CACHE_TTL=3600

# Import CSV
LISTMONK_CSV_BATCH_SIZE=1000
LISTMONK_CSV_VALIDATE_INSEE=true
EOF
        print_success "Fichier .env créé"
    else
        print_warning "Fichier .env existant conservé"
    fi
}

# Fonction de préparation des fichiers
prepare_files() {
    print_status "Création des répertoires..."
    mkdir -p uploads static/uploads demo
    
    print_status "Préparation des fichiers de démonstration..."
    
    # Créer un fichier de configuration par défaut si nécessaire
    if [[ ! -f "config.toml" ]]; then
        cp config.toml.sample config.toml 2>/dev/null || true
    fi
    
    print_status "Configuration des permissions..."
    chmod -R 755 uploads static demo 2>/dev/null || true
}

# Fonction de vérification des ports
check_ports() {
    print_status "Vérification des ports..."
    
    # Vérifier le port 9000 (Listmonk)
    if netstat -tuln 2>/dev/null | grep -q ":9000 " || ss -tuln 2>/dev/null | grep -q ":9000 "; then
        print_warning "Port 9000 occupé, Listmonk sera accessible via Docker"
    fi
    
    # Vérifier le port 8083 (Adminer)
    if netstat -tuln 2>/dev/null | grep -q ":8083 " || ss -tuln 2>/dev/null | grep -q ":8083 "; then
        print_warning "Port 8083 occupé, Adminer pourrait ne pas être accessible"
    fi
}

# Fonction de construction et démarrage
build_and_start() {
    print_status "Construction et démarrage des services..."
    print_status "Utilisation du fichier: docker-compose.fixed.yml"
    
    print_status "Vérification des fichiers requis..."
    required_files=(
        "Dockerfile.geo.fixed"
        "docker-compose.fixed.yml"
        "docker/init-scripts/01-init-geo.sql"
        "frontend/package.json"
        "go.mod"
    )
    
    for file in "${required_files[@]}"; do
        if [[ ! -f "$file" ]]; then
            print_error "Fichier requis manquant : $file"
            exit 1
        fi
    done
    print_success "Tous les fichiers requis sont présents"
    
    print_status "Construction de l'image Docker..."
    if docker compose -f docker-compose.fixed.yml build; then
        print_success "Construction réussie"
    else
        print_error "Échec de la construction Docker"
        print_status "Tentative de nettoyage et reconstruction..."
        docker builder prune -f
        if docker compose -f docker-compose.fixed.yml build --no-cache; then
            print_success "Reconstruction réussie"
        else
            print_error "Échec définitif de la construction"
            print_status "Vérifiez les logs ci-dessus pour plus de détails"
            exit 1
        fi
    fi
    
    print_status "Démarrage des services..."
    if docker compose -f docker-compose.fixed.yml up -d; then
        print_success "Services démarrés"
    else
        print_error "Échec du démarrage des services"
        exit 1
    fi
}

# Fonction d'attente de la base de données
wait_for_database() {
    print_status "Attente de la disponibilité de PostgreSQL..."
    
    max_attempts=30
    attempt=0
    
    while [ $attempt -lt $max_attempts ]; do
        if docker compose -f docker-compose.fixed.yml exec -T postgres pg_isready -U listmonk -d listmonk &>/dev/null; then
            print_success "PostgreSQL est prêt"
            return 0
        fi
        
        attempt=$((attempt + 1))
        echo -n "."
        sleep 2
    done
    
    print_error "Timeout: PostgreSQL n'est pas disponible après $((max_attempts * 2)) secondes"
    return 1
}

# Fonction d'initialisation de Listmonk
initialize_listmonk() {
    print_status "Initialisation de Listmonk..."
    
    # Attendre que Listmonk soit prêt
    sleep 10
    
    # Vérifier si Listmonk est déjà initialisé
    if docker compose -f docker-compose.fixed.yml exec -T listmonk ./listmonk --version &>/dev/null; then
        print_status "Tentative d'initialisation de la base de données..."
        
        # Essayer d'initialiser (ne fait rien si déjà fait)
        if docker compose -f docker-compose.fixed.yml exec -T listmonk ./listmonk --install --yes &>/dev/null; then
            print_success "Base de données initialisée"
        else
            print_warning "Base de données déjà initialisée ou erreur d'initialisation"
        fi
    else
        print_warning "Listmonk n'est pas encore prêt, initialisation manuelle requise"
    fi
}

# Fonction de vérification finale
verify_installation() {
    print_status "Vérification de l'installation..."
    
    # Vérifier les conteneurs
    if docker compose -f docker-compose.fixed.yml ps | grep -q "Up"; then
        print_success "Conteneurs en cours d'exécution"
    else
        print_warning "Certains conteneurs ne sont pas démarrés"
    fi
    
    # Vérifier l'accès à Listmonk
    sleep 5
    if curl -f http://localhost:9000/health &>/dev/null || curl -f http://localhost:9000 &>/dev/null; then
        print_success "Listmonk est accessible"
    else
        print_warning "Listmonk n'est pas encore accessible (peut nécessiter quelques minutes)"
    fi
}

# Fonction d'affichage des informations finales
show_final_info() {
    echo ""
    echo "🎉 INSTALLATION TERMINÉE !"
    echo "=========================="
    echo ""
    print_success "Listmonk avec extension géographique française est installé"
    echo ""
    echo "📋 INFORMATIONS D'ACCÈS :"
    echo "-------------------------"
    echo "🌐 Interface Listmonk : http://localhost:9000"
    echo "👤 Nom d'utilisateur  : admin"
    echo "🔑 Mot de passe       : admin123"
    echo ""
    echo "🗄️ Interface Adminer (base de données) : http://localhost:8083"
    echo "   Serveur    : postgres"
    echo "   Utilisateur: listmonk"
    echo "   Mot de passe: listmonk_secure_password"
    echo "   Base       : listmonk"
    echo ""
    echo "📊 FONCTIONNALITÉS GÉOGRAPHIQUES :"
    echo "----------------------------------"
    echo "✅ Segmentation par région (13 régions françaises)"
    echo "✅ Segmentation par département (95 départements)"
    echo "✅ Recherche de communes avec autocomplete"
    echo "✅ Filtrage par population communale"
    echo "✅ Filtrage par CSP (Catégorie Socio-Professionnelle)"
    echo "✅ Import CSV avec données géographiques françaises"
    echo ""
    echo "🔧 COMMANDES UTILES :"
    echo "--------------------"
    echo "# Voir les logs"
    echo "docker compose -f docker-compose.fixed.yml logs -f"
    echo ""
    echo "# Redémarrer les services"
    echo "docker compose -f docker-compose.fixed.yml restart"
    echo ""
    echo "# Arrêter les services"
    echo "docker compose -f docker-compose.fixed.yml down"
    echo ""
    echo "# Initialiser manuellement (si nécessaire)"
    echo "docker compose -f docker-compose.fixed.yml exec listmonk ./listmonk --install --yes"
    echo ""
    echo "🎯 PROCHAINES ÉTAPES :"
    echo "---------------------"
    echo "1. Accédez à http://localhost:9000"
    echo "2. Connectez-vous avec admin/admin123"
    echo "3. Allez sur 'Listes' → 'Nouvelle liste'"
    echo "4. Utilisez l'onglet 'Géographie' pour la segmentation"
    echo "5. Importez vos données CSV avec structure française"
    echo ""
    echo "📖 DOCUMENTATION :"
    echo "-----------------"
    echo "• NOTICE_INSTALLATION_DOCKER_FINALE.md - Guide complet"
    echo "• DEMARRAGE_RAPIDE.md - Guide express"
    echo "• GEOGRAPHIC_FEATURES.md - Fonctionnalités géographiques"
    echo ""
    echo "🚀 Bon marketing géographique avec Listmonk !"
    echo ""
}

# Exécution du script principal
main() {
    check_prerequisites
    cleanup_previous
    create_env_file
    prepare_files
    check_ports
    build_and_start
    wait_for_database
    initialize_listmonk
    verify_installation
    show_final_info
}

# Gestion des erreurs
trap 'print_error "Erreur lors de l'\''installation. Vérifiez les logs ci-dessus."' ERR

# Lancer l'installation
main "$@"