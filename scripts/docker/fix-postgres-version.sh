#!/bin/bash

# Script pour résoudre les problèmes de version PostgreSQL

set -e

# Couleurs
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() { echo -e "${BLUE}ℹ️ $1${NC}"; }
log_success() { echo -e "${GREEN}✅ $1${NC}"; }
log_warning() { echo -e "${YELLOW}⚠️ $1${NC}"; }
log_error() { echo -e "${RED}❌ $1${NC}"; }

echo "🔧 RÉSOLUTION PROBLÈME POSTGRESQL"
echo "================================="
echo ""

log_warning "Problème détecté: Incompatibilité de version PostgreSQL"
echo "PostgreSQL 17 (données existantes) vs PostgreSQL 15 (Docker)"
echo ""

log_info "Solutions disponibles:"
echo "1. Nettoyage complet des volumes (RECOMMANDÉ)"
echo "2. Mise à jour vers PostgreSQL 17"
echo "3. Migration des données"
echo ""

read -p "Choisissez une option (1-3) [1]: " choice
choice=${choice:-1}

case $choice in
    1)
        log_info "Option 1: Nettoyage complet des volumes"
        echo ""
        
        log_warning "⚠️ ATTENTION: Cette action supprimera TOUTES les données PostgreSQL existantes"
        read -p "Êtes-vous sûr de vouloir continuer? (oui/non) [non]: " confirm
        
        if [ "$confirm" = "oui" ] || [ "$confirm" = "yes" ] || [ "$confirm" = "y" ]; then
            log_info "Arrêt de tous les services Docker..."
            docker-compose -f docker-compose.simple.yml down -v 2>/dev/null || true
            docker-compose -f docker-compose.geo.yml down -v 2>/dev/null || true
            docker-compose -f docker-compose.custom.yml down -v 2>/dev/null || true
            
            log_info "Suppression des volumes PostgreSQL..."
            docker volume rm $(docker volume ls -q | grep -E "(postgres|listmonk)") 2>/dev/null || true
            
            log_info "Nettoyage des containers et images..."
            docker container prune -f
            docker image rm $(docker images -q postgres) 2>/dev/null || true
            
            log_success "Nettoyage terminé!"
            log_info "Vous pouvez maintenant relancer: ./install-listmonk-geo.sh"
        else
            log_info "Opération annulée"
        fi
        ;;
        
    2)
        log_info "Option 2: Mise à jour vers PostgreSQL 17"
        echo ""
        
        log_info "Mise à jour du docker-compose vers PostgreSQL 17..."
        
        # Mettre à jour tous les fichiers docker-compose
        for file in docker-compose.simple.yml docker-compose.geo.yml; do
            if [ -f "$file" ]; then
                log_info "Mise à jour de $file..."
                sed -i 's/postgres:15-alpine/postgres:17-alpine/g' "$file"
                sed -i 's/postgres:15/postgres:17/g' "$file"
            fi
        done
        
        log_success "Fichiers mis à jour vers PostgreSQL 17"
        log_info "Redémarrage des services..."
        
        # Redémarrer avec la nouvelle version
        docker-compose -f docker-compose.simple.yml down
        docker-compose -f docker-compose.simple.yml up -d
        
        log_success "PostgreSQL 17 déployé!"
        ;;
        
    3)
        log_info "Option 3: Migration des données"
        echo ""
        
        log_warning "Migration automatique non implémentée"
        log_info "Pour une migration manuelle:"
        echo "1. Sauvegardez vos données: pg_dump"
        echo "2. Nettoyez les volumes: Option 1"
        echo "3. Restaurez avec: psql"
        echo ""
        log_info "Ou utilisez l'option 1 pour un nouveau départ"
        ;;
        
    *)
        log_error "Option invalide"
        exit 1
        ;;
esac

echo ""
log_info "🔧 Commandes utiles:"
echo "• Diagnostic complet: ./scripts/docker/diagnose.sh"
echo "• Installation propre: ./install-listmonk-geo.sh --clean && ./install-listmonk-geo.sh"
echo "• Logs PostgreSQL: docker-compose logs postgres"