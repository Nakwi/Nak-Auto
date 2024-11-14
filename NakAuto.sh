#!/bin/bash

# Couleurs
CYAN='\033[1;36m'
PURPLE='\033[1;35m'
GREEN='\033[1;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Fonction pour afficher un en-tête stylisé avec Nakwi et des étoiles
display_title() {
  clear
  echo -e "${PURPLE}*************************************************${NC}"
  echo -e "${PURPLE}*                                               *${NC}"
  echo -e "${PURPLE}*       ███╗   ██╗ █████╗ ██╗  ██╗ ██╗          *${NC}"
  echo -e "${PURPLE}*       ████╗  ██║██╔══██╗██║ ██╔╝ ██║          *${NC}"
  echo -e "${PURPLE}*       ██╔██╗ ██║███████║█████╔╝  ██║          *${NC}"
  echo -e "${PURPLE}*       ██║╚██╗██║██╔══██║██╔═██╗  ██║          *${NC}"
  echo -e "${PURPLE}*       ██║ ╚████║██║  ██║██║  ██╗ ██║          *${NC}"
  echo -e "${PURPLE}*       ╚═╝  ╚═══╝╚═╝  ╚═╝╚═╝  ╚═╝ ╚═╝          *${NC}"
  echo -e "${PURPLE}*                                               *${NC}"
  echo -e "${PURPLE}*             ✨ Nakwi Setup ✨                *${NC}"
  echo -e "${PURPLE}*                                               *${NC}"
  echo -e "${PURPLE}*************************************************${NC}"
  echo -e "${CYAN}Bienvenue dans le script de configuration Nakwi. Préparez-vous !${NC}"
  sleep 2
}

# Fonction pour afficher une barre de progression personnalisée en bleu clair
progress_bar() {
  local duration=$1
  local step=0
  echo -ne "${CYAN}["
  while [ $step -lt $duration ]; do
    echo -ne "▓"
    sleep 0.1
    step=$((step + 1))
  done
  echo -e "] ${GREEN}Terminé !${NC}"
}

# Afficher le titre
display_title

# Mise à jour des paquets et du système
echo -e "${YELLOW}🔄 Mise à jour des paquets et du système...${NC}"
sudo apt update -y &>/dev/null
progress_bar 30
sudo apt upgrade -y &>/dev/null
progress_bar 50

# Installer les paquets de base
echo -e "${YELLOW}📦 Installation des paquets de base...${NC}"
sudo apt install -y sudo ssh wget curl vim git ufw &>/dev/null
progress_bar 40

# Ajouter l'utilisateur 'ryan' au groupe sudo
echo -e "${YELLOW}👤 Ajout de l'utilisateur 'ryan' au groupe sudo...${NC}"
sudo usermod -aG sudo ryan &>/dev/null
progress_bar 10

# Configurer le pare-feu et permettre SSH sans confirmation manuelle
echo -e "${YELLOW}🔐 Configuration du pare-feu et permissions SSH...${NC}"
sudo ufw allow OpenSSH &>/dev/null || echo -e "${PURPLE}🔸 La règle existe déjà.${NC}"
sudo ufw --force enable &>/dev/null
progress_bar 20

# Fin du script avec un message personnalisé
echo -e "${GREEN}🎉 Configuration initiale terminée avec succès par Nakwi ! 🎉${NC}"
echo -e "${CYAN}Bienvenue sur votre nouvelle VM prête à l'emploi.${NC}"
