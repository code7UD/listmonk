#!/bin/bash

# Script de correction pour la version Go dans Docker

echo "🔧 CORRECTION DE LA VERSION GO DANS DOCKER"
echo "=========================================="

# Vérifier que nous sommes dans le bon répertoire
if [ ! -f "Dockerfile.geo" ]; then
    echo "❌ Erreur: Dockerfile.geo non trouvé. Assurez-vous d'être dans le répertoire listmonk-geo"
    exit 1
fi

echo "📝 Correction de la version Go dans Dockerfile.geo..."

# Corriger la version Go de 1.21 à 1.24
sed -i 's/golang:1.21-alpine/golang:1.24-alpine/g' Dockerfile.geo

echo "✅ Version Go corrigée dans Dockerfile.geo"

# Vérifier la correction
if grep -q "golang:1.24-alpine" Dockerfile.geo; then
    echo "✅ Correction appliquée avec succès"
else
    echo "❌ Erreur lors de la correction"
    exit 1
fi

echo ""
echo "🚀 Relancement de la construction Docker..."

# Nettoyer les images précédentes
docker-compose -f docker-compose.geo.yml down 2>/dev/null || true
docker system prune -f 2>/dev/null || true

# Reconstruire avec la bonne version
docker-compose -f docker-compose.geo.yml build --no-cache

if [ $? -eq 0 ]; then
    echo "✅ Construction Docker réussie !"
    echo ""
    echo "🚀 Démarrage des services..."
    docker-compose -f docker-compose.geo.yml up -d
    
    echo ""
    echo "⏳ Attente du démarrage complet (30 secondes)..."
    sleep 30
    
    echo ""
    echo "🔍 Vérification de l'état des services..."
    docker-compose -f docker-compose.geo.yml ps
    
    echo ""
    echo "🧪 Test de connectivité..."
    if curl -s http://localhost:9000/health > /dev/null; then
        echo "✅ Listmonk est accessible sur http://localhost:9000"
        echo ""
        echo "🎉 INSTALLATION RÉUSSIE !"
        echo "========================"
        echo ""
        echo "📱 Accès aux services :"
        echo "  • Listmonk : http://localhost:9000"
        echo "  • Adminer  : http://localhost:8080"
        echo ""
        echo "🔑 Identifiants :"
        echo "  • Utilisateur : admin"
        echo "  • Mot de passe : admin123!"
    else
        echo "⚠️ Listmonk ne répond pas encore. Vérifiez les logs avec :"
        echo "   docker-compose -f docker-compose.geo.yml logs -f listmonk"
    fi
else
    echo "❌ Erreur lors de la construction Docker"
    echo ""
    echo "🔍 Vérification des logs d'erreur..."
    docker-compose -f docker-compose.geo.yml logs
    exit 1
fi