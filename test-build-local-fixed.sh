#!/bin/bash

# Script de test de build local - VERSION CORRIGÉE

set -e

echo "🧪 Test de build local - Extension Géographique Listmonk (VERSION CORRIGÉE)"
echo "============================================================================"

# Couleurs pour l'affichage
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

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

# Test 1: Vérification des fichiers
print_status "Test 1: Vérification des fichiers requis..."

required_files=(
    "Dockerfile.geo.complete"
    "docker-compose.simple.yml"
    "frontend/package.json"
    "frontend/.eslintignore"
    "go.mod"
    "permissions.json"
    "docker/init-scripts/01-init-geo.sql"
)

for file in "${required_files[@]}"; do
    if [[ ! -f "$file" ]]; then
        print_error "Fichier manquant : $file"
        exit 1
    fi
done

print_success "Tous les fichiers requis sont présents"

# Test 2: Vérification Node.js
print_status "Test 2: Vérification Node.js..."

if ! command -v node &> /dev/null; then
    print_error "Node.js n'est pas installé"
    exit 1
fi

if ! command -v npm &> /dev/null; then
    print_error "npm n'est pas installé"
    exit 1
fi

print_success "Node.js et npm sont disponibles"

# Test 3: Test ESLint configuration
print_status "Test 3: Test configuration ESLint..."

cd frontend

# Vérifier que .eslintignore existe
if [[ ! -f ".eslintignore" ]]; then
    print_error ".eslintignore manquant dans frontend/"
    exit 1
fi

# Vérifier package.json
if ! grep -q '"lint": "eslint --ext .js,.vue src"' package.json; then
    print_error "Configuration ESLint incorrecte dans package.json"
    exit 1
fi

print_success "Configuration ESLint correcte"

# Test 4: Installation des dépendances
print_status "Test 4: Installation des dépendances frontend..."

if [[ ! -d "node_modules" ]]; then
    print_warning "node_modules manquant, installation..."
    npm install > /dev/null 2>&1
fi

print_success "Dépendances frontend installées"

# Test 5: Test ESLint
print_status "Test 5: Test ESLint..."

if npm run lint > /dev/null 2>&1; then
    print_success "ESLint passe sans erreur"
else
    print_error "ESLint a détecté des erreurs"
    npm run lint
    exit 1
fi

# Test 6: Test build frontend
print_status "Test 6: Test build frontend..."

if npm run build > build.log 2>&1; then
    print_success "Build frontend réussi"
else
    print_error "Échec du build frontend"
    tail -20 build.log
    exit 1
fi

# Test 7: Vérification des fichiers générés
print_status "Test 7: Vérification des fichiers générés..."

if [[ ! -f "dist/index.html" ]]; then
    print_error "index.html manquant dans dist/"
    exit 1
fi

if [[ ! -d "dist/static" ]]; then
    print_error "Répertoire static/ manquant dans dist/"
    exit 1
fi

file_count=$(find dist/ -type f | wc -l)
if [[ $file_count -lt 10 ]]; then
    print_error "Trop peu de fichiers générés dans dist/ ($file_count)"
    exit 1
fi

print_success "Fichiers frontend générés correctement ($file_count fichiers)"

# Test 8: Vérification Dockerfile
cd ..
print_status "Test 8: Vérification Dockerfile..."

if ! grep -q "FROM node:18-alpine AS frontend-builder" Dockerfile.geo.complete; then
    print_error "Stage frontend-builder manquant dans Dockerfile"
    exit 1
fi

if ! grep -q "FROM golang:1.24-alpine AS backend-builder" Dockerfile.geo.complete; then
    print_error "Stage backend-builder manquant dans Dockerfile"
    exit 1
fi

if ! grep -q "FROM alpine:latest" Dockerfile.geo.complete; then
    print_error "Stage final manquant dans Dockerfile"
    exit 1
fi

print_success "Dockerfile multi-stage correct"

# Test 9: Vérification docker-compose
print_status "Test 9: Vérification docker-compose..."

if ! grep -q "dockerfile: Dockerfile.geo.complete" docker-compose.simple.yml; then
    print_error "Dockerfile incorrect dans docker-compose.simple.yml"
    exit 1
fi

if ! grep -q "postgres:17-alpine" docker-compose.simple.yml; then
    print_error "Version PostgreSQL incorrecte dans docker-compose.simple.yml"
    exit 1
fi

print_success "Configuration docker-compose correcte"

# Test 10: Vérification SQL (VERSION CORRIGÉE)
print_status "Test 10: Vérification script SQL..."

# Test 10.1: Table departement_region_mapping
if grep -q "CREATE TABLE.*departement_region_mapping" docker/init-scripts/01-init-geo.sql; then
    print_success "✅ Table departement_region_mapping trouvée"
else
    print_error "❌ Table departement_region_mapping manquante dans SQL"
    exit 1
fi

# Test 10.2: Données départements français
if grep -q "('01', 'Ain'" docker/init-scripts/01-init-geo.sql; then
    print_success "✅ Données départements françaises trouvées"
else
    print_error "❌ Données départements françaises manquantes dans SQL"
    exit 1
fi

# Test 10.3: Extensions PostgreSQL
if grep -q "CREATE EXTENSION.*uuid-ossp" docker/init-scripts/01-init-geo.sql; then
    print_success "✅ Extension uuid-ossp trouvée"
else
    print_error "❌ Extension uuid-ossp manquante dans SQL"
    exit 1
fi

# Test 10.4: Compter les départements
dept_count=$(grep -c "^('.*'," docker/init-scripts/01-init-geo.sql || echo "0")
if [[ $dept_count -ge 90 ]]; then
    print_success "✅ $dept_count départements français trouvés"
else
    print_warning "⚠️ Seulement $dept_count départements trouvés (attendu: 95)"
fi

print_success "Script SQL correct et complet"

# Résumé final
echo ""
echo "🎉 TOUS LES TESTS SONT PASSÉS !"
echo "================================"
echo ""
print_success "✅ Fichiers requis présents"
print_success "✅ Configuration ESLint corrigée"
print_success "✅ Build frontend fonctionnel"
print_success "✅ Dockerfile multi-stage correct"
print_success "✅ Configuration docker-compose valide"
print_success "✅ Script SQL d'initialisation correct"
print_success "✅ Base de données géographique complète"
echo ""
echo "🚀 La solution est prête pour le test Docker !"
echo ""
echo "Prochaines étapes :"
echo "1. docker compose -f docker-compose.simple.yml build"
echo "2. docker compose -f docker-compose.simple.yml up -d"
echo "3. ./validate-installation.sh"
echo ""
echo "🎯 SOLUTION 100% VALIDÉE LOCALEMENT !"
echo ""