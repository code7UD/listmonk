#!/bin/bash

# Script de démarrage rapide pour Listmonk avec extension géographique

set -e

echo "🗺️ DÉMARRAGE LISTMONK AVEC EXTENSION GÉOGRAPHIQUE"
echo "================================================="

# Vérifier que Docker est installé
if ! command -v docker &> /dev/null; then
    echo "❌ Docker n'est pas installé. Veuillez installer Docker d'abord."
    exit 1
fi

if ! command -v docker-compose &> /dev/null; then
    echo "❌ Docker Compose n'est pas installé. Veuillez installer Docker Compose d'abord."
    exit 1
fi

# Vérifier que nous sommes sur la bonne branche
CURRENT_BRANCH=$(git branch --show-current 2>/dev/null || echo "unknown")
if [ "$CURRENT_BRANCH" != "feature/french-geographic-segmentation" ]; then
    echo "⚠️ Vous n'êtes pas sur la branche feature/french-geographic-segmentation"
    echo "Basculement vers la bonne branche..."
    git checkout feature/french-geographic-segmentation
fi

# Créer le fichier .env s'il n'existe pas
if [ ! -f ".env" ]; then
    echo "📝 Création du fichier .env..."
    cp .env.example .env
    echo "✅ Fichier .env créé. Vous pouvez le modifier selon vos besoins."
fi

# Créer les répertoires nécessaires
echo "📁 Création des répertoires..."
mkdir -p data/postgres data/uploads demo

# Copier les fichiers de démonstration
echo "📊 Copie des fichiers de démonstration..."
cp demo_geo_data.csv demo/ 2>/dev/null || echo "⚠️ Fichier demo_geo_data.csv non trouvé"
cp demo_geographic_queries.sql demo/ 2>/dev/null || echo "⚠️ Fichier demo_geographic_queries.sql non trouvé"
cp test_geo_data.csv demo/ 2>/dev/null || echo "⚠️ Fichier test_geo_data.csv non trouvé"

# Rendre les scripts exécutables
echo "🔧 Configuration des permissions..."
chmod +x docker/entrypoint.sh
chmod +x docker/scripts/*.sh

# Vérifier et corriger la version Go si nécessaire
echo "🔍 Vérification de la version Go..."
if grep -q "golang:1.21-alpine" Dockerfile.geo; then
    echo "⚠️ Version Go 1.21 détectée, correction vers 1.24..."
    sed -i 's/golang:1.21-alpine/golang:1.24-alpine/g' Dockerfile.geo
    echo "✅ Version Go corrigée"
fi

# Construire et démarrer les services
echo "🚀 Construction et démarrage des services..."
docker-compose -f docker-compose.geo.yml build --no-cache
docker-compose -f docker-compose.geo.yml up -d

# Attendre que les services soient prêts
echo "⏳ Attente du démarrage des services..."
sleep 10

# Vérifier l'état des services
echo "🔍 Vérification de l'état des services..."
docker-compose -f docker-compose.geo.yml ps

# Tester la connectivité
echo "🧪 Test de connectivité..."
if curl -s http://localhost:9000/health > /dev/null; then
    echo "✅ Listmonk est accessible sur http://localhost:9000"
else
    echo "⚠️ Listmonk ne répond pas encore. Vérifiez les logs avec:"
    echo "   docker-compose -f docker-compose.geo.yml logs -f listmonk"
fi

# Afficher les informations de connexion
echo ""
echo "🎉 INSTALLATION TERMINÉE !"
echo "========================="
echo ""
echo "📱 Accès aux services :"
echo "  • Listmonk (interface principale) : http://localhost:9000"
echo "  • Adminer (base de données)       : http://localhost:8080"
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
echo "📚 Documentation :"
echo "  • Guide complet : GEOGRAPHIC_FEATURES.md"
echo "  • Installation Docker : INSTALLATION_DOCKER.md"
echo ""
echo "🔧 Commandes utiles :"
echo "  • Voir les logs : docker-compose -f docker-compose.geo.yml logs -f"
echo "  • Arrêter : docker-compose -f docker-compose.geo.yml down"
echo "  • Redémarrer : docker-compose -f docker-compose.geo.yml restart"
echo "  • Test complet : ./test_complete_implementation.sh"
echo ""
echo "🗺️ Bon géomarketing avec Listmonk !"