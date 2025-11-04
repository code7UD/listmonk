#!/bin/bash

# Script d'installation final corrigé - Extension Géographique Listmonk
# Approche en deux étapes : PostgreSQL minimal + Listmonk + Extensions géographiques

set -e

echo "🗺️ INSTALLATION FINALE LISTMONK AVEC EXTENSION GÉOGRAPHIQUE FRANÇAISE"
echo "====================================================================="
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
    
    # Arrêter tous les conteneurs listmonk existants
    docker compose -f docker-compose.postgres-fixed.yml down -v 2>/dev/null || true
    docker compose -f docker-compose.alpine-fixed.yml down -v 2>/dev/null || true
    docker compose -f docker-compose.fixed.yml down -v 2>/dev/null || true
    docker compose -f docker-compose.final.yml down -v 2>/dev/null || true
    docker compose -f docker-compose.simple.yml down -v 2>/dev/null || true
    
    # Nettoyer les volumes
    docker volume rm listmonk_postgres_data 2>/dev/null || true
    
    print_success "Nettoyage terminé"
}

# Fonction de configuration
setup_environment() {
    print_status "Configuration de l'environnement..."
    
    # Générer des mots de passe sécurisés si .env n'existe pas
    if [[ ! -f .env ]]; then
        DB_PASSWORD=$(openssl rand -base64 32 2>/dev/null || date +%s | sha256sum | base64 | head -c 32)
        ADMIN_PASSWORD="admin123"
        
        cat > .env << EOF
# Configuration Listmonk avec extensions géographiques
LISTMONK_APP_ADMIN_USERNAME=admin
LISTMONK_APP_ADMIN_PASSWORD=${ADMIN_PASSWORD}
LISTMONK_PORT=9000
LISTMONK_DB_USER=listmonk
LISTMONK_DB_PASSWORD=${DB_PASSWORD}
LISTMONK_DB_DATABASE=listmonk
LISTMONK_GEO_ENABLED=true
LISTMONK_GEO_AUTO_INDEX=true
LISTMONK_GEO_CACHE_TTL=3600
LISTMONK_CSV_BATCH_SIZE=1000
LISTMONK_CSV_VALIDATE_INSEE=true
ADMINER_PORT=8080
EOF
        
        print_success "Fichier .env créé"
        print_warning "Mot de passe admin : ${ADMIN_PASSWORD}"
    else
        print_success "Fichier .env existant conservé"
    fi
}

# Fonction de vérification des fichiers
check_files() {
    print_status "Vérification des fichiers requis..."
    
    required_files=(
        "Dockerfile.geo.alpine-fixed"
        "docker-compose.postgres-fixed.yml"
        "docker/init-scripts/01-init-geo-minimal.sql"
        "add-geo-columns.sh"
        ".env"
    )
    
    for file in "${required_files[@]}"; do
        if [[ ! -f "$file" ]]; then
            print_error "Fichier manquant : $file"
            exit 1
        fi
    done
    
    print_success "Tous les fichiers requis sont présents"
}

# Étape 1: Démarrer PostgreSQL avec initialisation minimale
start_postgres() {
    print_status "Étape 1: Démarrage de PostgreSQL avec initialisation minimale..."
    
    # Construire et démarrer seulement PostgreSQL
    if ! docker compose -f docker-compose.postgres-fixed.yml up -d postgres; then
        print_error "Échec du démarrage de PostgreSQL"
        exit 1
    fi
    
    # Attendre que PostgreSQL soit prêt
    print_status "Attente de PostgreSQL..."
    for i in {1..30}; do
        if docker compose -f docker-compose.postgres-fixed.yml exec postgres pg_isready -U listmonk -d listmonk &>/dev/null; then
            print_success "PostgreSQL est prêt"
            break
        fi
        
        if [ $i -eq 30 ]; then
            print_error "Timeout - PostgreSQL ne répond pas"
            docker compose -f docker-compose.postgres-fixed.yml logs postgres
            exit 1
        fi
        
        echo -n "."
        sleep 2
    done
    
    # Vérifier que la table de mapping est créée
    dept_count=$(docker compose -f docker-compose.postgres-fixed.yml exec postgres psql -U listmonk -d listmonk -t -c "SELECT COUNT(*) FROM departement_region_mapping;" | tr -d ' ')
    
    if [[ $dept_count -eq 95 ]]; then
        print_success "95 départements français chargés"
    else
        print_warning "Seulement $dept_count départements trouvés"
    fi
}

# Étape 2: Construire et démarrer Listmonk
start_listmonk() {
    print_status "Étape 2: Construction et démarrage de Listmonk..."
    
    # Construire l'image Listmonk
    if ! docker compose -f docker-compose.postgres-fixed.yml build listmonk; then
        print_error "Échec de la construction de Listmonk"
        exit 1
    fi
    
    print_success "Construction de Listmonk réussie"
    
    # Démarrer Listmonk
    if ! docker compose -f docker-compose.postgres-fixed.yml up -d listmonk; then
        print_error "Échec du démarrage de Listmonk"
        exit 1
    fi
    
    print_status "Attente du démarrage de Listmonk..."
    sleep 10
    
    # Initialiser Listmonk
    print_status "Initialisation de Listmonk..."
    if docker compose -f docker-compose.postgres-fixed.yml exec listmonk ./listmonk --install --yes; then
        print_success "Listmonk initialisé avec succès"
    else
        print_warning "L'initialisation a échoué (peut-être déjà initialisé)"
    fi
    
    # Redémarrer Listmonk pour s'assurer qu'il fonctionne
    docker compose -f docker-compose.postgres-fixed.yml restart listmonk
    sleep 5
}

# Étape 3: Ajouter les extensions géographiques
add_geo_extensions() {
    print_status "Étape 3: Ajout des extensions géographiques..."
    
    # Exécuter le script d'ajout des colonnes géographiques
    if ./add-geo-columns.sh; then
        print_success "Extensions géographiques ajoutées avec succès"
    else
        print_error "Échec de l'ajout des extensions géographiques"
        exit 1
    fi
}

# Étape 4: Démarrer Adminer (optionnel)
start_adminer() {
    print_status "Étape 4: Démarrage d'Adminer (optionnel)..."
    
    if docker compose -f docker-compose.postgres-fixed.yml --profile admin up -d adminer; then
        print_success "Adminer démarré"
    else
        print_warning "Échec du démarrage d'Adminer (optionnel)"
    fi
}

# Fonction de validation finale
validate_installation() {
    print_status "Validation de l'installation..."
    
    # Vérifier les conteneurs
    if ! docker compose -f docker-compose.postgres-fixed.yml ps | grep -q "Up"; then
        print_error "Les conteneurs ne sont pas en cours d'exécution"
        docker compose -f docker-compose.postgres-fixed.yml ps
        exit 1
    fi
    
    # Vérifier l'accès à l'interface
    LISTMONK_PORT=$(grep LISTMONK_PORT .env | cut -d'=' -f2)
    if curl -f -s "http://localhost:${LISTMONK_PORT}/health" > /dev/null 2>&1; then
        print_success "Interface Listmonk accessible"
    else
        print_warning "Interface Listmonk non accessible (peut nécessiter quelques minutes)"
    fi
    
    # Vérifier les colonnes géographiques
    column_count=$(docker compose -f docker-compose.postgres-fixed.yml exec postgres psql -U listmonk -d listmonk -t -c "SELECT COUNT(*) FROM information_schema.columns WHERE table_name='subscribers' AND column_name IN ('code_insee', 'population_commune', 'nom_commune', 'departement_numero');" | tr -d ' ')
    
    if [[ $column_count -ge 4 ]]; then
        print_success "Extensions géographiques installées ($column_count colonnes)"
    else
        print_warning "Extensions géographiques partiellement installées ($column_count colonnes)"
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
    print_success "🌐 Interface Listmonk : http://localhost:${LISTMONK_PORT}"
    print_success "👤 Identifiants admin : admin / ${ADMIN_PASSWORD}"
    print_success "🗄️ Interface PostgreSQL : http://localhost:${ADMINER_PORT}"
    echo ""
    print_status "📊 Fonctionnalités géographiques disponibles :"
    echo "  • Segmentation par région (13 régions françaises)"
    echo "  • Segmentation par département (95 départements)"
    echo "  • Recherche de communes avec autocomplete"
    echo "  • Filtrage par population communale"
    echo "  • Filtrage par CSP (Catégorie Socio-Professionnelle)"
    echo "  • Import CSV avec données géographiques françaises"
    echo ""
    print_status "🎯 Allez sur 'Listes' → 'Nouvelle liste' → Onglet 'Géographie'"
    echo ""
    print_status "Commandes utiles :"
    echo "  • Arrêter : docker compose -f docker-compose.postgres-fixed.yml down"
    echo "  • Démarrer : docker compose -f docker-compose.postgres-fixed.yml up -d"
    echo "  • Logs : docker compose -f docker-compose.postgres-fixed.yml logs -f"
    echo "  • Réinitialiser : docker compose -f docker-compose.postgres-fixed.yml down -v"
    echo ""
    print_success "🚀 Votre Listmonk géographique est prêt à l'emploi !"
}

# Exécution du script principal
main() {
    check_prerequisites
    cleanup_previous
    setup_environment
    check_files
    start_postgres
    start_listmonk
    add_geo_extensions
    start_adminer
    validate_installation
    show_final_info
}

# Gestion des erreurs
trap 'print_error "Installation interrompue"; exit 1' INT TERM

# Lancer l'installation
main "$@"