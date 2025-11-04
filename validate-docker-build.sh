#!/bin/bash

# Script de validation de la construction Docker
# À exécuter sur un système avec Docker installé

set -e

echo "🔍 Validation de la construction Docker Listmonk Géographique"
echo "============================================================"

# Couleurs pour l'affichage
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Fonction d'affichage coloré
print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Vérifications préliminaires
print_status "Vérification des prérequis..."

# Vérifier Docker
if ! command -v docker &> /dev/null; then
    print_error "Docker n'est pas installé"
    echo "Installez Docker : https://docs.docker.com/get-docker/"
    exit 1
fi

# Vérifier Docker Compose
if ! command -v docker compose &> /dev/null; then
    print_error "Docker Compose n'est pas installé"
    echo "Installez Docker Compose : https://docs.docker.com/compose/install/"
    exit 1
fi

print_success "Docker et Docker Compose sont installés"

# Vérifier les fichiers nécessaires
print_status "Vérification des fichiers..."

required_files=(
    "Dockerfile.geo.complete"
    "docker-compose.simple.yml"
    "frontend/package.json"
    "permissions.json"
    "go.mod"
    "Makefile"
    "docker/init-scripts/01-init-geo.sql"
)

for file in "${required_files[@]}"; do
    if [[ ! -f "$file" ]]; then
        print_error "Fichier manquant : $file"
        exit 1
    fi
done

print_success "Tous les fichiers requis sont présents"

# Vérifier l'espace disque
print_status "Vérification de l'espace disque..."
available_space=$(df . | awk 'NR==2 {print $4}')
required_space=10485760  # 10GB en KB

if [[ $available_space -lt $required_space ]]; then
    print_warning "Espace disque faible : $(($available_space/1024/1024))GB disponible, 10GB recommandé"
else
    print_success "Espace disque suffisant : $(($available_space/1024/1024))GB disponible"
fi

# Test de construction
print_status "Test de construction de l'image..."
print_warning "Cette étape peut prendre 10-15 minutes..."

# Construire l'image
if docker build -f Dockerfile.geo.complete -t listmonk-geo-test . > build.log 2>&1; then
    print_success "Construction de l'image réussie"
else
    print_error "Échec de la construction"
    echo "Consultez build.log pour les détails"
    tail -20 build.log
    exit 1
fi

# Test de l'image
print_status "Test de l'image construite..."

if docker run --rm listmonk-geo-test ./listmonk --help > /dev/null 2>&1; then
    print_success "L'image fonctionne correctement"
else
    print_error "L'image ne fonctionne pas"
    exit 1
fi

# Test du docker-compose
print_status "Validation du docker-compose..."

if docker compose -f docker-compose.simple.yml config > /dev/null 2>&1; then
    print_success "Configuration docker-compose valide"
else
    print_error "Configuration docker-compose invalide"
    docker compose -f docker-compose.simple.yml config
    exit 1
fi

# Nettoyage
print_status "Nettoyage..."
docker rmi listmonk-geo-test > /dev/null 2>&1

print_success "Validation terminée avec succès !"
echo ""
echo "🎉 Votre environnement est prêt pour l'installation de Listmonk Géographique"
echo ""
echo "Prochaines étapes :"
echo "1. Configurez le fichier .env"
echo "2. Lancez : docker compose -f docker-compose.simple.yml up -d"
echo "3. Initialisez : docker compose -f docker-compose.simple.yml exec listmonk ./listmonk --install --yes"
echo ""
echo "📖 Consultez NOTICE_INSTALLATION_COMPLETE.md pour les instructions détaillées"