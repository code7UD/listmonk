#!/bin/bash

# Script pour ajouter les colonnes géographiques à la table subscribers
# À exécuter APRÈS l'initialisation de Listmonk

set -e

echo "🗺️ AJOUT DES COLONNES GÉOGRAPHIQUES À LISTMONK"
echo "=============================================="

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

# Déterminer le fichier docker-compose à utiliser
COMPOSE_FILE=""
if [[ -f "docker-compose.alpine-fixed.yml" ]]; then
    COMPOSE_FILE="docker-compose.alpine-fixed.yml"
elif [[ -f "docker-compose.fixed.yml" ]]; then
    COMPOSE_FILE="docker-compose.fixed.yml"
elif [[ -f "docker-compose.final.yml" ]]; then
    COMPOSE_FILE="docker-compose.final.yml"
elif [[ -f "docker-compose.simple.yml" ]]; then
    COMPOSE_FILE="docker-compose.simple.yml"
else
    print_error "Aucun fichier docker-compose trouvé"
    exit 1
fi

print_status "Utilisation du fichier: $COMPOSE_FILE"

# Vérifier que PostgreSQL est en cours d'exécution
print_status "Vérification de PostgreSQL..."
if ! docker compose -f "$COMPOSE_FILE" exec postgres pg_isready -U listmonk -d listmonk &>/dev/null; then
    print_error "PostgreSQL n'est pas accessible"
    print_status "Démarrez d'abord les services avec: docker compose -f $COMPOSE_FILE up -d"
    exit 1
fi

print_success "PostgreSQL est accessible"

# Vérifier que la table subscribers existe
print_status "Vérification de la table subscribers..."
if ! docker compose -f "$COMPOSE_FILE" exec postgres psql -U listmonk -d listmonk -c "\d subscribers" &>/dev/null; then
    print_error "La table subscribers n'existe pas"
    print_status "Initialisez d'abord Listmonk avec: docker compose -f $COMPOSE_FILE exec listmonk ./listmonk --install --yes"
    exit 1
fi

print_success "Table subscribers trouvée"

# Ajouter les colonnes géographiques
print_status "Ajout des colonnes géographiques..."

# Créer le script SQL pour ajouter les colonnes
cat > /tmp/add_geo_columns.sql << 'EOF'
-- Ajouter les colonnes géographiques à la table subscribers existante
DO $$
BEGIN
    -- Colonnes géographiques INSEE
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='subscribers' AND column_name='code_insee') THEN
        ALTER TABLE subscribers ADD COLUMN code_insee VARCHAR(10);
    END IF;
    
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='subscribers' AND column_name='population_commune') THEN
        ALTER TABLE subscribers ADD COLUMN population_commune INTEGER;
    END IF;
    
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='subscribers' AND column_name='nom_commune') THEN
        ALTER TABLE subscribers ADD COLUMN nom_commune VARCHAR(255);
    END IF;
    
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='subscribers' AND column_name='departement_numero') THEN
        ALTER TABLE subscribers ADD COLUMN departement_numero VARCHAR(3);
    END IF;
    
    -- Colonnes adresse
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='subscribers' AND column_name='address1') THEN
        ALTER TABLE subscribers ADD COLUMN address1 TEXT;
    END IF;
    
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='subscribers' AND column_name='city') THEN
        ALTER TABLE subscribers ADD COLUMN city VARCHAR(255);
    END IF;
    
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='subscribers' AND column_name='state') THEN
        ALTER TABLE subscribers ADD COLUMN state VARCHAR(255);
    END IF;
    
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='subscribers' AND column_name='zipcode') THEN
        ALTER TABLE subscribers ADD COLUMN zipcode VARCHAR(10);
    END IF;
    
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='subscribers' AND column_name='country') THEN
        ALTER TABLE subscribers ADD COLUMN country VARCHAR(100);
    END IF;
    
    -- Colonnes personnelles
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='subscribers' AND column_name='title') THEN
        ALTER TABLE subscribers ADD COLUMN title VARCHAR(10);
    END IF;
    
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='subscribers' AND column_name='phone') THEN
        ALTER TABLE subscribers ADD COLUMN phone VARCHAR(50);
    END IF;
    
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='subscribers' AND column_name='website') THEN
        ALTER TABLE subscribers ADD COLUMN website VARCHAR(255);
    END IF;
    
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='subscribers' AND column_name='date_naissance') THEN
        ALTER TABLE subscribers ADD COLUMN date_naissance DATE;
    END IF;
    
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='subscribers' AND column_name='csp') THEN
        ALTER TABLE subscribers ADD COLUMN csp VARCHAR(100);
    END IF;
    
    -- Colonnes entreprise
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='subscribers' AND column_name='siren') THEN
        ALTER TABLE subscribers ADD COLUMN siren VARCHAR(20);
    END IF;
    
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='subscribers' AND column_name='siret') THEN
        ALTER TABLE subscribers ADD COLUMN siret VARCHAR(20);
    END IF;
    
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name='subscribers' AND column_name='telecopie') THEN
        ALTER TABLE subscribers ADD COLUMN telecopie VARCHAR(20);
    END IF;
END $$;

-- Créer les index pour optimiser les requêtes géographiques
CREATE INDEX IF NOT EXISTS idx_subscribers_departement ON subscribers(departement_numero);
CREATE INDEX IF NOT EXISTS idx_subscribers_code_insee ON subscribers(code_insee);
CREATE INDEX IF NOT EXISTS idx_subscribers_population ON subscribers(population_commune);
CREATE INDEX IF NOT EXISTS idx_subscribers_csp ON subscribers(csp);
CREATE INDEX IF NOT EXISTS idx_subscribers_nom_commune ON subscribers(nom_commune);
CREATE INDEX IF NOT EXISTS idx_subscribers_state ON subscribers(state);
CREATE INDEX IF NOT EXISTS idx_subscribers_city ON subscribers(city);

-- Afficher le résultat
SELECT 'Colonnes géographiques ajoutées avec succès' AS status;
EOF

# Exécuter le script SQL
if docker compose -f "$COMPOSE_FILE" exec -T postgres psql -U listmonk -d listmonk < /tmp/add_geo_columns.sql; then
    print_success "Colonnes géographiques ajoutées avec succès"
else
    print_error "Échec de l'ajout des colonnes géographiques"
    exit 1
fi

# Nettoyer le fichier temporaire
rm -f /tmp/add_geo_columns.sql

# Vérifier les colonnes ajoutées
print_status "Vérification des colonnes ajoutées..."
column_count=$(docker compose -f "$COMPOSE_FILE" exec postgres psql -U listmonk -d listmonk -t -c "SELECT COUNT(*) FROM information_schema.columns WHERE table_name='subscribers' AND column_name IN ('code_insee', 'population_commune', 'nom_commune', 'departement_numero', 'address1', 'city', 'state', 'zipcode', 'country', 'title', 'phone', 'website', 'date_naissance', 'csp', 'siren', 'siret', 'telecopie');" | tr -d ' ')

print_success "$column_count colonnes géographiques ajoutées"

# Vérifier la table de mapping
print_status "Vérification de la table de mapping départements..."
dept_count=$(docker compose -f "$COMPOSE_FILE" exec postgres psql -U listmonk -d listmonk -t -c "SELECT COUNT(*) FROM departement_region_mapping;" | tr -d ' ')

if [[ $dept_count -eq 95 ]]; then
    print_success "95 départements français disponibles"
else
    print_warning "Seulement $dept_count départements trouvés"
fi

echo ""
echo "🎉 EXTENSION GÉOGRAPHIQUE INSTALLÉE !"
echo "===================================="
echo ""
print_success "✅ $column_count colonnes géographiques ajoutées à la table subscribers"
print_success "✅ $dept_count départements français disponibles"
print_success "✅ Index optimisés créés"
echo ""
print_status "Fonctionnalités disponibles :"
echo "  • Segmentation par région (13 régions françaises)"
echo "  • Segmentation par département (95 départements)"
echo "  • Recherche de communes avec autocomplete"
echo "  • Filtrage par population communale"
echo "  • Filtrage par CSP (Catégorie Socio-Professionnelle)"
echo "  • Import CSV avec données géographiques françaises"
echo ""
print_status "🌐 Accédez à l'interface Listmonk et allez sur 'Listes' → 'Nouvelle liste' → Onglet 'Géographie'"
echo ""