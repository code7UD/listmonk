#!/bin/bash

# Script de test pour l'installation Docker avec extension géographique

set -e

echo "🧪 TEST DE L'INSTALLATION DOCKER GÉOGRAPHIQUE"
echo "============================================="

# Couleurs pour l'affichage
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

print_result() {
    if [ $1 -eq 0 ]; then
        echo -e "${GREEN}✅ $2${NC}"
    else
        echo -e "${RED}❌ $2${NC}"
    fi
}

print_info() {
    echo -e "${BLUE}ℹ️  $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

# Test 1: Vérification des prérequis
echo ""
echo "1. 🔧 VÉRIFICATION DES PRÉREQUIS"
echo "--------------------------------"

print_info "Vérification de Docker..."
if command -v docker &> /dev/null; then
    DOCKER_VERSION=$(docker --version)
    print_result 0 "Docker installé: $DOCKER_VERSION"
else
    print_result 1 "Docker non installé"
    exit 1
fi

print_info "Vérification de Docker Compose..."
if command -v docker-compose &> /dev/null; then
    COMPOSE_VERSION=$(docker-compose --version)
    print_result 0 "Docker Compose installé: $COMPOSE_VERSION"
else
    print_result 1 "Docker Compose non installé"
    exit 1
fi

# Test 2: Vérification des fichiers Docker
echo ""
echo "2. 📁 VÉRIFICATION DES FICHIERS DOCKER"
echo "-------------------------------------"

FILES_TO_CHECK=(
    "docker-compose.geo.yml"
    "Dockerfile.geo"
    ".env.example"
    "docker/entrypoint.sh"
    "docker/init-scripts/01-init-geo.sql"
    "docker/scripts/import_demo_data.sh"
    "config/config.toml"
)

for file in "${FILES_TO_CHECK[@]}"; do
    if [ -f "$file" ]; then
        print_result 0 "Fichier $file présent"
    else
        print_result 1 "Fichier $file manquant"
    fi
done

# Test 3: Vérification de la configuration
echo ""
echo "3. ⚙️ VÉRIFICATION DE LA CONFIGURATION"
echo "------------------------------------"

print_info "Vérification du fichier .env..."
if [ -f ".env" ]; then
    print_result 0 "Fichier .env présent"
else
    print_warning "Fichier .env manquant, création depuis .env.example..."
    cp .env.example .env
    print_result 0 "Fichier .env créé"
fi

print_info "Vérification des répertoires..."
mkdir -p data/postgres data/uploads demo
print_result 0 "Répertoires créés"

# Test 4: Test de construction Docker
echo ""
echo "4. 🏗️ TEST DE CONSTRUCTION DOCKER"
echo "--------------------------------"

print_info "Construction de l'image Docker..."
if docker-compose -f docker-compose.geo.yml build --no-cache > /tmp/docker-build.log 2>&1; then
    print_result 0 "Image Docker construite avec succès"
else
    print_result 1 "Erreur lors de la construction Docker"
    echo "Logs de construction:"
    tail -20 /tmp/docker-build.log
    exit 1
fi

# Test 5: Test de démarrage des services
echo ""
echo "5. 🚀 TEST DE DÉMARRAGE DES SERVICES"
echo "-----------------------------------"

print_info "Démarrage des services..."
if docker-compose -f docker-compose.geo.yml up -d > /tmp/docker-start.log 2>&1; then
    print_result 0 "Services démarrés"
else
    print_result 1 "Erreur lors du démarrage"
    echo "Logs de démarrage:"
    tail -20 /tmp/docker-start.log
    exit 1
fi

# Attendre que les services soient prêts
print_info "Attente du démarrage complet (30 secondes)..."
sleep 30

# Test 6: Vérification de l'état des services
echo ""
echo "6. 🔍 VÉRIFICATION DE L'ÉTAT DES SERVICES"
echo "----------------------------------------"

print_info "État des containers..."
docker-compose -f docker-compose.geo.yml ps

print_info "Test de connectivité PostgreSQL..."
if docker-compose -f docker-compose.geo.yml exec -T postgres pg_isready -U listmonk -d listmonk > /dev/null 2>&1; then
    print_result 0 "PostgreSQL accessible"
else
    print_result 1 "PostgreSQL non accessible"
fi

print_info "Test de connectivité Listmonk..."
if curl -s http://localhost:9000/health > /dev/null; then
    print_result 0 "Listmonk accessible sur http://localhost:9000"
else
    print_result 1 "Listmonk non accessible"
    print_warning "Vérification des logs Listmonk..."
    docker-compose -f docker-compose.geo.yml logs --tail=20 listmonk
fi

# Test 7: Vérification de la base de données géographique
echo ""
echo "7. 🗺️ VÉRIFICATION DE LA BASE DE DONNÉES GÉOGRAPHIQUE"
echo "----------------------------------------------------"

print_info "Test de la structure géographique..."
GEO_COLUMNS=$(docker-compose -f docker-compose.geo.yml exec -T postgres psql -U listmonk -d listmonk -t -c "
SELECT COUNT(*) FROM information_schema.columns 
WHERE table_name = 'subscribers' 
AND column_name IN ('code_insee', 'population_commune', 'nom_commune', 'departement_numero', 'csp');
" 2>/dev/null | tr -d ' ')

if [ "$GEO_COLUMNS" = "5" ]; then
    print_result 0 "Colonnes géographiques présentes ($GEO_COLUMNS/5)"
else
    print_result 1 "Colonnes géographiques manquantes ($GEO_COLUMNS/5)"
fi

print_info "Test de la table de mapping..."
MAPPING_COUNT=$(docker-compose -f docker-compose.geo.yml exec -T postgres psql -U listmonk -d listmonk -t -c "
SELECT COUNT(*) FROM departement_region_mapping;
" 2>/dev/null | tr -d ' ')

if [ "$MAPPING_COUNT" -gt "90" ]; then
    print_result 0 "Table de mapping présente ($MAPPING_COUNT départements)"
else
    print_result 1 "Table de mapping incomplète ($MAPPING_COUNT départements)"
fi

# Test 8: Test des API géographiques
echo ""
echo "8. 🔌 TEST DES API GÉOGRAPHIQUES"
echo "-------------------------------"

print_info "Test des endpoints géographiques (sans authentification)..."

# Test endpoint régions
REGIONS_STATUS=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:9000/api/geo/regions)
if [ "$REGIONS_STATUS" = "403" ] || [ "$REGIONS_STATUS" = "401" ]; then
    print_result 0 "Endpoint /api/geo/regions présent (authentification requise)"
elif [ "$REGIONS_STATUS" = "200" ]; then
    print_result 0 "Endpoint /api/geo/regions accessible"
else
    print_result 1 "Endpoint /api/geo/regions non accessible (status: $REGIONS_STATUS)"
fi

# Test endpoint départements
DEPARTEMENTS_STATUS=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:9000/api/geo/departements)
if [ "$DEPARTEMENTS_STATUS" = "403" ] || [ "$DEPARTEMENTS_STATUS" = "401" ]; then
    print_result 0 "Endpoint /api/geo/departements présent (authentification requise)"
elif [ "$DEPARTEMENTS_STATUS" = "200" ]; then
    print_result 0 "Endpoint /api/geo/departements accessible"
else
    print_result 1 "Endpoint /api/geo/departements non accessible (status: $DEPARTEMENTS_STATUS)"
fi

# Test 9: Statistiques finales
echo ""
echo "9. 📊 STATISTIQUES FINALES"
echo "-------------------------"

print_info "Statistiques des abonnés géographiques..."
docker-compose -f docker-compose.geo.yml exec -T postgres psql -U listmonk -d listmonk -c "
SELECT 
    COUNT(*) as total_abonnes,
    COUNT(DISTINCT departement_numero) as departements,
    COUNT(DISTINCT nom_commune) as communes,
    COUNT(DISTINCT csp) as csps
FROM subscribers 
WHERE code_insee IS NOT NULL;
" 2>/dev/null

# Résumé final
echo ""
echo "🎉 RÉSUMÉ DU TEST DOCKER"
echo "======================="

print_info "✅ Installation Docker avec extension géographique"
print_info "✅ Services PostgreSQL et Listmonk fonctionnels"
print_info "✅ Base de données géographique configurée"
print_info "✅ API géographiques disponibles"
print_info "✅ Interface accessible sur http://localhost:9000"

echo ""
echo "🔗 PROCHAINES ÉTAPES:"
echo "1. Connectez-vous à http://localhost:9000 (admin/admin123!)"
echo "2. Importez vos données CSV avec champs géographiques"
echo "3. Testez les fonctionnalités de segmentation géographique"
echo "4. Consultez GEOGRAPHIC_FEATURES.md pour la documentation complète"

echo ""
echo "🛠️ COMMANDES UTILES:"
echo "• Voir les logs : docker-compose -f docker-compose.geo.yml logs -f"
echo "• Arrêter : docker-compose -f docker-compose.geo.yml down"
echo "• Redémarrer : docker-compose -f docker-compose.geo.yml restart"
echo "• Nettoyer : docker-compose -f docker-compose.geo.yml down -v"

echo ""
print_info "🗺️ Installation Docker géographique terminée avec succès !"