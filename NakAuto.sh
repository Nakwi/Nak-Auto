#!/bin/bash

#####################################
# Script de Configuration Linux Auto
# Par Ryan
# Version 1.0
#####################################

# Couleurs
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color
BOLD='\033[1m'

# Variables globales
NEW_USER="ryan"
STEP_COUNT=0
TOTAL_STEPS=7

# Vérifier si on est root
check_root() {
    if [ "$EUID" -ne 0 ]; then 
        echo -e "${RED}❌ Ce script doit être exécuté en tant que root${NC}"
        echo -e "${YELLOW}💡 Utilisez: sudo bash $0${NC}"
        exit 1
    fi
}

# Fonction pour afficher le header
show_header() {
    clear
    echo -e "${CYAN}${BOLD}"
    echo "╔════════════════════════════════════════════════════════════╗"
    echo "║                                                            ║"
    echo "║        🚀 CONFIGURATION AUTOMATIQUE LINUX 🚀               ║"
    echo "║                    Script by Ryan                          ║"
    echo "║                                                            ║"
    echo "╚════════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
}

# Fonction pour afficher une séparation
separator() {
    echo -e "${BLUE}════════════════════════════════════════════════════════════${NC}"
}

# Fonction spinner de chargement
spinner() {
    local pid=$1
    local delay=0.1
    local spinstr='|/-\'
    while [ "$(ps a | awk '{print $1}' | grep $pid)" ]; do
        local temp=${spinstr#?}
        printf " [${CYAN}%c${NC}]  " "$spinstr"
        local spinstr=$temp${spinstr%"$temp"}
        sleep $delay
        printf "\b\b\b\b\b\b"
    done
    printf "    \b\b\b\b"
}

# Fonction pour afficher la progression
show_progress() {
    STEP_COUNT=$((STEP_COUNT + 1))
    echo -e "\n${PURPLE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BOLD}${CYAN}Progression: [${STEP_COUNT}/${TOTAL_STEPS}]${NC}"
    echo -e "${PURPLE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}\n"
}

# Fonction pour afficher un message de succès
success() {
    echo -e "${GREEN}✓${NC} $1"
}

# Fonction pour afficher un message d'erreur
error() {
    echo -e "${RED}✗${NC} $1"
}

# Fonction pour afficher une info
info() {
    echo -e "${BLUE}ℹ${NC} $1"
}

# Fonction pour poser une question
ask() {
    echo -e "${YELLOW}❓${NC} $1"
}

# Fonction pour demander confirmation
confirm() {
    while true; do
        echo -e "${YELLOW}$1 (o/n): ${NC}\c"
        read -r response
        case $response in
            [oO]|[oO][uU][iI]) return 0 ;;
            [nN]|[nN][oO][nN]) return 1 ;;
            *) echo -e "${RED}Veuillez répondre par 'o' ou 'n'${NC}" ;;
        esac
    done
}

# Étape 1: Création de l'utilisateur
create_user() {
    show_header
    show_progress
    echo -e "${BOLD}${CYAN}═══ ÉTAPE 1: CRÉATION DE L'UTILISATEUR ═══${NC}\n"
    
    if confirm "Voulez-vous créer l'utilisateur '${NEW_USER}' ?"; then
        echo ""
        
        # Vérifier si l'utilisateur existe déjà
        if id "$NEW_USER" &>/dev/null; then
            info "L'utilisateur ${NEW_USER} existe déjà"
        else
            info "Création de l'utilisateur ${NEW_USER}..."
            
            # Créer l'utilisateur
            useradd -m -s /bin/bash "$NEW_USER" &>/dev/null
            
            if [ $? -eq 0 ]; then
                success "Utilisateur ${NEW_USER} créé"
                
                # Définir le mot de passe
                echo -e "\n${YELLOW}Définissez le mot de passe pour ${NEW_USER}:${NC}"
                passwd "$NEW_USER"
                
                # Ajouter aux sudoers
                info "Ajout des droits sudo..."
                usermod -aG sudo "$NEW_USER" 2>/dev/null || usermod -aG wheel "$NEW_USER" 2>/dev/null
                
                # Créer le répertoire .ssh
                mkdir -p /home/$NEW_USER/.ssh
                chmod 700 /home/$NEW_USER/.ssh
                chown -R $NEW_USER:$NEW_USER /home/$NEW_USER/.ssh
                
                success "Droits sudo accordés à ${NEW_USER}"
                success "Répertoire SSH créé"
            else
                error "Échec de la création de l'utilisateur"
            fi
        fi
        
        echo -e "\n${GREEN}Appuyez sur Entrée pour continuer...${NC}"
        read
    else
        info "Étape ignorée"
        echo -e "\n${YELLOW}Appuyez sur Entrée pour continuer...${NC}"
        read
    fi
}

# Étape 2: Mise à jour du système
update_system() {
    show_header
    show_progress
    echo -e "${BOLD}${CYAN}═══ ÉTAPE 2: MISE À JOUR DU SYSTÈME ═══${NC}\n"
    
    if confirm "Voulez-vous mettre à jour le système ?"; then
        echo ""
        info "Mise à jour de la liste des paquets..."
        apt update > /tmp/update.log 2>&1 &
        spinner $!
        
        if [ $? -eq 0 ]; then
            success "Liste des paquets mise à jour"
        else
            error "Erreur lors de la mise à jour de la liste"
        fi
        
        echo ""
        info "Mise à niveau des paquets (cela peut prendre du temps)..."
        apt upgrade -y > /tmp/upgrade.log 2>&1 &
        spinner $!
        
        if [ $? -eq 0 ]; then
            success "Système mis à jour"
        else
            error "Erreur lors de la mise à niveau"
        fi
        
        echo -e "\n${GREEN}Appuyez sur Entrée pour continuer...${NC}"
        read
    else
        info "Étape ignorée"
        echo -e "\n${YELLOW}Appuyez sur Entrée pour continuer...${NC}"
        read
    fi
}

# Étape 3: Installation des paquets de base
install_packages() {
    show_header
    show_progress
    echo -e "${BOLD}${CYAN}═══ ÉTAPE 3: INSTALLATION DES PAQUETS ═══${NC}\n"
    
    info "Paquets qui seront installés:"
    echo -e "${CYAN}  • nano, vim${NC}"
    echo -e "${CYAN}  • git${NC}"
    echo -e "${CYAN}  • curl, wget${NC}"
    echo -e "${CYAN}  • htop, tree, net-tools${NC}"
    echo -e "${CYAN}  • python3, python3-pip${NC}"
    echo -e "${CYAN}  • build-essential${NC}"
    echo ""
    
    if confirm "Voulez-vous installer ces paquets ?"; then
        echo ""
        PACKAGES="nano vim git curl wget htop tree net-tools python3 python3-pip build-essential"
        
        info "Installation en cours..."
        apt install -y $PACKAGES > /tmp/install.log 2>&1 &
        spinner $!
        
        if [ $? -eq 0 ]; then
            success "Tous les paquets ont été installés"
        else
            error "Certains paquets n'ont pas pu être installés"
            info "Consultez /tmp/install.log pour plus de détails"
        fi
        
        echo -e "\n${GREEN}Appuyez sur Entrée pour continuer...${NC}"
        read
    else
        info "Étape ignorée"
        echo -e "\n${YELLOW}Appuyez sur Entrée pour continuer...${NC}"
        read
    fi
}

# Étape 4: Configuration SSH
configure_ssh() {
    show_header
    show_progress
    echo -e "${BOLD}${CYAN}═══ ÉTAPE 4: CONFIGURATION SSH ═══${NC}\n"
    
    info "Cette étape va:"
    echo -e "${CYAN}  • Désactiver le login root${NC}"
    echo -e "${CYAN}  • Autoriser l'utilisateur ${NEW_USER}${NC}"
    echo -e "${CYAN}  • Redémarrer le service SSH${NC}"
    echo ""
    
    if confirm "Voulez-vous configurer SSH ?"; then
        echo ""
        
        # Backup de la config SSH
        if [ -f /etc/ssh/sshd_config ]; then
            cp /etc/ssh/sshd_config /etc/ssh/sshd_config.backup.$(date +%Y%m%d_%H%M%S)
            success "Sauvegarde de la configuration SSH créée"
        fi
        
        # Désactiver le login root
        info "Configuration de SSH..."
        sed -i 's/^#*PermitRootLogin.*/PermitRootLogin no/' /etc/ssh/sshd_config
        sed -i 's/^#*PubkeyAuthentication.*/PubkeyAuthentication yes/' /etc/ssh/sshd_config
        
        # Ajouter l'utilisateur aux utilisateurs autorisés si la directive existe
        if grep -q "^AllowUsers" /etc/ssh/sshd_config; then
            sed -i "s/^AllowUsers.*/& $NEW_USER/" /etc/ssh/sshd_config
        else
            echo "AllowUsers $NEW_USER" >> /etc/ssh/sshd_config
        fi
        
        success "Login root désactivé"
        success "Utilisateur ${NEW_USER} autorisé"
        
        # Redémarrer SSH
        info "Redémarrage du service SSH..."
        systemctl restart sshd 2>/dev/null || systemctl restart ssh 2>/dev/null
        
        if [ $? -eq 0 ]; then
            success "Service SSH redémarré"
            echo ""
            echo -e "${GREEN}╔════════════════════════════════════════════╗${NC}"
            echo -e "${GREEN}║  ⚠️  IMPORTANT: TESTEZ SSH AVANT DE      ║${NC}"
            echo -e "${GREEN}║     FERMER CETTE SESSION !                 ║${NC}"
            echo -e "${GREEN}╚════════════════════════════════════════════╝${NC}"
        else
            error "Erreur lors du redémarrage de SSH"
        fi
        
        echo -e "\n${GREEN}Appuyez sur Entrée pour continuer...${NC}"
        read
    else
        info "Étape ignorée"
        echo -e "\n${YELLOW}Appuyez sur Entrée pour continuer...${NC}"
        read
    fi
}

# Étape 5: Configuration IP statique
configure_network() {
    show_header
    show_progress
    echo -e "${BOLD}${CYAN}═══ ÉTAPE 5: CONFIGURATION RÉSEAU ═══${NC}\n"
    
    if confirm "Voulez-vous configurer une IP statique ?"; then
        echo ""
        
        # Détecter l'interface réseau principale
        INTERFACE=$(ip route | grep default | awk '{print $5}' | head -n1)
        info "Interface réseau détectée: ${INTERFACE}"
        
        # Demander les informations réseau
        echo ""
        ask "Adresse IP statique (ex: 192.168.1.100):"
        read STATIC_IP
        
        ask "Masque de sous-réseau (ex: 255.255.255.0 ou /24):"
        read NETMASK
        
        ask "Passerelle par défaut (ex: 192.168.1.1):"
        read GATEWAY
        
        ask "Serveur DNS primaire (ex: 8.8.8.8):"
        read DNS1
        
        ask "Serveur DNS secondaire (ex: 8.8.4.4) [optionnel]:"
        read DNS2
        
        echo ""
        info "Résumé de la configuration:"
        echo -e "${CYAN}  Interface: ${INTERFACE}${NC}"
        echo -e "${CYAN}  IP: ${STATIC_IP}${NC}"
        echo -e "${CYAN}  Masque: ${NETMASK}${NC}"
        echo -e "${CYAN}  Passerelle: ${GATEWAY}${NC}"
        echo -e "${CYAN}  DNS: ${DNS1}${NC}"
        [ -n "$DNS2" ] && echo -e "${CYAN}  DNS2: ${DNS2}${NC}"
        echo ""
        
        if confirm "Confirmer cette configuration ?"; then
            # Détecter si on utilise netplan ou interfaces
            if [ -d /etc/netplan ]; then
                info "Utilisation de Netplan..."
                
                # Créer la configuration netplan
                cat > /etc/netplan/01-netcfg.yaml << EOF
network:
  version: 2
  renderer: networkd
  ethernets:
    $INTERFACE:
      dhcp4: no
      addresses:
        - $STATIC_IP$(echo $NETMASK | grep -q '/' && echo '' || echo '/24')
      routes:
        - to: default
          via: $GATEWAY
      nameservers:
        addresses:
          - $DNS1
$([ -n "$DNS2" ] && echo "          - $DNS2")
EOF
                
                success "Configuration Netplan créée"
                
                info "Application de la configuration..."
                netplan apply
                
                if [ $? -eq 0 ]; then
                    success "Configuration réseau appliquée"
                else
                    error "Erreur lors de l'application"
                    info "Vous pouvez revenir à l'ancienne config avec: netplan revert"
                fi
                
            else
                info "Utilisation de /etc/network/interfaces..."
                
                # Backup
                cp /etc/network/interfaces /etc/network/interfaces.backup.$(date +%Y%m%d_%H%M%S)
                
                # Configuration
                cat > /etc/network/interfaces << EOF
# Loopback
auto lo
iface lo inet loopback

# Interface principale
auto $INTERFACE
iface $INTERFACE inet static
    address $STATIC_IP
    netmask $NETMASK
    gateway $GATEWAY
    dns-nameservers $DNS1 $([ -n "$DNS2" ] && echo "$DNS2")
EOF
                
                success "Configuration créée"
                
                info "Redémarrage du réseau..."
                systemctl restart networking
                success "Réseau redémarré"
            fi
        else
            info "Configuration annulée"
        fi
        
        echo -e "\n${GREEN}Appuyez sur Entrée pour continuer...${NC}"
        read
    else
        info "Étape ignorée"
        echo -e "\n${YELLOW}Appuyez sur Entrée pour continuer...${NC}"
        read
    fi
}

# Étape 6: Configuration du firewall
configure_firewall() {
    show_header
    show_progress
    echo -e "${BOLD}${CYAN}═══ ÉTAPE 6: CONFIGURATION FIREWALL (UFW) ═══${NC}\n"
    
    if confirm "Voulez-vous configurer le firewall UFW ?"; then
        echo ""
        
        # Installer UFW si nécessaire
        if ! command -v ufw &> /dev/null; then
            info "Installation de UFW..."
            apt install -y ufw > /dev/null 2>&1
            success "UFW installé"
        else
            info "UFW est déjà installé"
        fi
        
        # Configuration
        info "Configuration du firewall..."
        
        # Autoriser SSH (port par défaut)
        ufw allow 22/tcp > /dev/null 2>&1
        success "Port SSH (22) autorisé"
        
        # Demander si d'autres ports doivent être ouverts
        echo ""
        if confirm "Voulez-vous ouvrir d'autres ports ?"; then
            while true; do
                ask "Numéro de port à ouvrir (ou appuyez sur Entrée pour terminer):"
                read PORT
                
                if [ -z "$PORT" ]; then
                    break
                fi
                
                ask "Protocole (tcp/udp/both) [tcp]:"
                read PROTO
                PROTO=${PROTO:-tcp}
                
                if [ "$PROTO" = "both" ]; then
                    ufw allow $PORT > /dev/null 2>&1
                else
                    ufw allow $PORT/$PROTO > /dev/null 2>&1
                fi
                
                success "Port $PORT/$PROTO autorisé"
            done
        fi
        
        # Activer UFW
        echo ""
        info "Activation du firewall..."
        echo "y" | ufw enable > /dev/null 2>&1
        
        if [ $? -eq 0 ]; then
            success "Firewall activé et configuré"
            echo ""
            info "État du firewall:"
            ufw status
        else
            error "Erreur lors de l'activation du firewall"
        fi
        
        echo -e "\n${GREEN}Appuyez sur Entrée pour continuer...${NC}"
        read
    else
        info "Étape ignorée"
        echo -e "\n${YELLOW}Appuyez sur Entrée pour continuer...${NC}"
        read
    fi
}

# Étape 7: Finalisation
finalize() {
    show_header
    show_progress
    echo -e "${BOLD}${CYAN}═══ ÉTAPE 7: FINALISATION ═══${NC}\n"
    
    # Configuration du timezone
    info "Configuration du fuseau horaire..."
    timedatectl set-timezone Europe/Paris 2>/dev/null
    success "Timezone configuré sur Europe/Paris"
    
    echo ""
    separator
    echo -e "${BOLD}${GREEN}✨ CONFIGURATION TERMINÉE ! ✨${NC}"
    separator
    
    echo ""
    echo -e "${BOLD}${CYAN}📋 RÉSUMÉ DE LA CONFIGURATION:${NC}"
    echo ""
    
    # Résumé utilisateur
    if id "$NEW_USER" &>/dev/null; then
        echo -e "${GREEN}✓${NC} Utilisateur: ${BOLD}${NEW_USER}${NC} (avec droits sudo)"
    fi
    
    # Version système
    echo -e "${GREEN}✓${NC} Système mis à jour"
    
    # Paquets
    echo -e "${GREEN}✓${NC} Paquets essentiels installés"
    
    # SSH
    if grep -q "PermitRootLogin no" /etc/ssh/sshd_config 2>/dev/null; then
        echo -e "${GREEN}✓${NC} SSH configuré (root désactivé)"
    fi
    
    # Firewall
    if ufw status | grep -q "Status: active" 2>/dev/null; then
        echo -e "${GREEN}✓${NC} Firewall UFW activé"
    fi
    
    # Timezone
    echo -e "${GREEN}✓${NC} Timezone: Europe/Paris"
    
    echo ""
    echo -e "${BOLD}${CYAN}🔐 INFORMATIONS DE CONNEXION SSH:${NC}"
    echo ""
    echo -e "${CYAN}  Utilisateur: ${BOLD}${NEW_USER}${NC}"
    
    # Afficher l'IP
    IP=$(hostname -I | awk '{print $1}')
    if [ -n "$IP" ]; then
        echo -e "${CYAN}  IP: ${BOLD}${IP}${NC}"
        echo -e "${CYAN}  Commande: ${BOLD}ssh ${NEW_USER}@${IP}${NC}"
    fi
    
    echo ""
    echo -e "${YELLOW}╔════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${YELLOW}║  ⚠️  IMPORTANT:                                           ║${NC}"
    echo -e "${YELLOW}║  • Testez SSH dans une NOUVELLE fenêtre avant de          ║${NC}"
    echo -e "${YELLOW}║    fermer celle-ci !                                      ║${NC}"
    echo -e "${YELLOW}║  • Sauvegardez votre mot de passe                         ║${NC}"
    echo -e "${YELLOW}║  • Si problème SSH: sudo systemctl status sshd            ║${NC}"
    echo -e "${YELLOW}╚════════════════════════════════════════════════════════════╝${NC}"
    
    echo ""
    separator
    echo -e "${GREEN}Merci d'avoir utilisé ce script ! 🚀${NC}"
    separator
    echo ""
}

# Programme principal
main() {
    check_root
    show_header
    
    echo -e "${BOLD}Bienvenue dans le script de configuration automatique Linux !${NC}\n"
    echo -e "${CYAN}Ce script va configurer votre machine en 7 étapes:${NC}"
    echo -e "  1. Création de l'utilisateur"
    echo -e "  2. Mise à jour du système"
    echo -e "  3. Installation des paquets"
    echo -e "  4. Configuration SSH"
    echo -e "  5. Configuration réseau"
    echo -e "  6. Configuration firewall"
    echo -e "  7. Finalisation"
    echo ""
    
    if ! confirm "Voulez-vous commencer la configuration ?"; then
        echo -e "${RED}Configuration annulée.${NC}"
        exit 0
    fi
    
    # Exécution des étapes
    create_user
    update_system
    install_packages
    configure_ssh
    configure_network
    configure_firewall
    finalize
}

# Lancement du script
main
