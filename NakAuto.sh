#!/usr/bin/env bash
#
# bootstrap.sh — Post-install homelab (Debian/Ubuntu)
# Usage : sudo bash bootstrap.sh
#
set -euo pipefail

# ------------------------------------------------------------------
# CONFIG PAR DÉFAUT — personnalise ici
# ------------------------------------------------------------------
DEFAULT_USER="ryan"
DEFAULT_HOSTNAME="$(hostname)"
DEFAULT_TZ="Europe/Paris"
# Colle ta clé publique SSH ici pour ne plus la retaper à chaque fois :
DEFAULT_SSH_PUBKEY=""

PKGS_BASE="curl wget sudo nano htop git unzip ca-certificates gnupg net-tools"
PKGS_EXTRA_LIST=(
    "qemu-guest-agent" "Agent invité Proxmox (IP visible, shutdown propre)" ON
    "vim" "Éditeur vim" OFF
    "tmux" "Multiplexeur de terminal" OFF
    "tree" "Arborescence de fichiers" ON
    "ncdu" "Analyse d'espace disque" ON
    "rsync" "Synchronisation de fichiers" ON
    "fail2ban" "Protection anti-bruteforce SSH" OFF
    "unattended-upgrades" "MAJ de sécurité automatiques" OFF
)

# ------------------------------------------------------------------
# Pré-vols
# ------------------------------------------------------------------
if [[ $EUID -ne 0 ]]; then
    echo "❌ Lance ce script en root : sudo bash $0"
    exit 1
fi

export DEBIAN_FRONTEND=noninteractive

if ! command -v whiptail &>/dev/null; then
    echo "→ Installation de whiptail..."
    apt-get update -qq && apt-get install -y -qq whiptail
fi

BACKTITLE="Bootstrap Homelab — naki edition"

msg() { whiptail --backtitle "$BACKTITLE" --title "$1" --msgbox "$2" 12 70; }

# ------------------------------------------------------------------
# 1. Menu principal : quoi faire ?
# ------------------------------------------------------------------
CHOICES=$(whiptail --backtitle "$BACKTITLE" --title "Que veux-tu faire ?" \
    --checklist "Sélectionne les étapes (ESPACE pour cocher) :" 20 75 10 \
    "update"    "Mise à jour complète du système"            ON \
    "hostname"  "Changer le hostname"                        OFF \
    "timezone"  "Régler la timezone ($DEFAULT_TZ)"           ON \
    "user"      "Créer un utilisateur + sudo"                ON \
    "sshkey"    "Ajouter une clé SSH publique à l'user"      ON \
    "packages"  "Installer les paquets de base + extras"     ON \
    "docker"    "Installer Docker + Docker Compose"          OFF \
    3>&1 1>&2 2>&3) || { echo "Annulé."; exit 0; }

has() { [[ "$CHOICES" == *"\"$1\""* ]]; }

# ------------------------------------------------------------------
# 2. Mise à jour système
# ------------------------------------------------------------------
if has update; then
    echo "═══ Mise à jour du système ═══"
    apt-get update
    apt-get -y full-upgrade
    apt-get -y autoremove --purge
fi

# ------------------------------------------------------------------
# 3. Hostname
# ------------------------------------------------------------------
if has hostname; then
    NEW_HOSTNAME=$(whiptail --backtitle "$BACKTITLE" --title "Hostname" \
        --inputbox "Nouveau hostname :" 10 60 "$DEFAULT_HOSTNAME" \
        3>&1 1>&2 2>&3) || true
    if [[ -n "${NEW_HOSTNAME:-}" && "$NEW_HOSTNAME" != "$(hostname)" ]]; then
        hostnamectl set-hostname "$NEW_HOSTNAME"
        sed -i "s/127.0.1.1.*/127.0.1.1\t$NEW_HOSTNAME/" /etc/hosts || \
            echo -e "127.0.1.1\t$NEW_HOSTNAME" >> /etc/hosts
        echo "✔ Hostname : $NEW_HOSTNAME"
    fi
fi

# ------------------------------------------------------------------
# 4. Timezone
# ------------------------------------------------------------------
if has timezone; then
    timedatectl set-timezone "$DEFAULT_TZ"
    echo "✔ Timezone : $DEFAULT_TZ"
fi

# ------------------------------------------------------------------
# 5. Utilisateur
# ------------------------------------------------------------------
NEWUSER=""
if has user; then
    NEWUSER=$(whiptail --backtitle "$BACKTITLE" --title "Utilisateur" \
        --inputbox "Nom de l'utilisateur à créer :" 10 60 "$DEFAULT_USER" \
        3>&1 1>&2 2>&3) || true

    if [[ -n "$NEWUSER" ]]; then
        if id "$NEWUSER" &>/dev/null; then
            echo "ℹ L'utilisateur $NEWUSER existe déjà, on passe la création."
        else
            PASS1=$(whiptail --backtitle "$BACKTITLE" --passwordbox \
                "Mot de passe pour $NEWUSER :" 10 60 3>&1 1>&2 2>&3)
            PASS2=$(whiptail --backtitle "$BACKTITLE" --passwordbox \
                "Confirme le mot de passe :" 10 60 3>&1 1>&2 2>&3)
            if [[ "$PASS1" != "$PASS2" || -z "$PASS1" ]]; then
                msg "Erreur" "Les mots de passe ne correspondent pas. Utilisateur non créé."
            else
                useradd -m -s /bin/bash "$NEWUSER"
                echo "$NEWUSER:$PASS1" | chpasswd
                echo "✔ Utilisateur $NEWUSER créé."
            fi
        fi
        # sudo dans tous les cas (idempotent)
        apt-get install -y -qq sudo
        usermod -aG sudo "$NEWUSER"
        echo "✔ $NEWUSER ajouté au groupe sudo."
    fi
fi

# ------------------------------------------------------------------
# 6. Clé SSH
# ------------------------------------------------------------------
if has sshkey; then
    TARGET_USER="${NEWUSER:-$DEFAULT_USER}"
    if id "$TARGET_USER" &>/dev/null; then
        PUBKEY=$(whiptail --backtitle "$BACKTITLE" --title "Clé SSH publique" \
            --inputbox "Colle la clé publique pour $TARGET_USER :" 12 75 "$DEFAULT_SSH_PUBKEY" \
            3>&1 1>&2 2>&3) || true
        if [[ "$PUBKEY" == ssh-* ]]; then
            USER_HOME=$(getent passwd "$TARGET_USER" | cut -d: -f6)
            mkdir -p "$USER_HOME/.ssh"
            touch "$USER_HOME/.ssh/authorized_keys"
            grep -qxF "$PUBKEY" "$USER_HOME/.ssh/authorized_keys" || \
                echo "$PUBKEY" >> "$USER_HOME/.ssh/authorized_keys"
            chmod 700 "$USER_HOME/.ssh"
            chmod 600 "$USER_HOME/.ssh/authorized_keys"
            chown -R "$TARGET_USER:$TARGET_USER" "$USER_HOME/.ssh"
            echo "✔ Clé SSH installée pour $TARGET_USER."
        else
            msg "Clé invalide" "La clé doit commencer par ssh-ed25519 ou ssh-rsa. Étape ignorée."
        fi
    else
        msg "Erreur" "L'utilisateur $TARGET_USER n'existe pas, clé SSH ignorée."
    fi
fi

# ------------------------------------------------------------------
# 7. Paquets
# ------------------------------------------------------------------
if has packages; then
    EXTRAS=$(whiptail --backtitle "$BACKTITLE" --title "Paquets supplémentaires" \
        --checklist "Base déjà incluse : $PKGS_BASE\n\nExtras :" 20 75 8 \
        "${PKGS_EXTRA_LIST[@]}" \
        3>&1 1>&2 2>&3) || true
    EXTRAS=$(echo "$EXTRAS" | tr -d '"')
    echo "═══ Installation des paquets ═══"
    apt-get install -y $PKGS_BASE $EXTRAS
    if [[ "$EXTRAS" == *qemu-guest-agent* ]]; then
        systemctl enable --now qemu-guest-agent || true
    fi
    if [[ "$EXTRAS" == *fail2ban* ]]; then
        systemctl enable --now fail2ban || true
    fi
    echo "✔ Paquets installés."
fi

# ------------------------------------------------------------------
# 8. Docker
# ------------------------------------------------------------------
if has docker; then
    if command -v docker &>/dev/null; then
        echo "ℹ Docker déjà installé."
    else
        echo "═══ Installation de Docker ═══"
        install -m 0755 -d /etc/apt/keyrings
        . /etc/os-release
        curl -fsSL "https://download.docker.com/linux/${ID}/gpg" \
            -o /etc/apt/keyrings/docker.asc
        chmod a+r /etc/apt/keyrings/docker.asc
        echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] \
https://download.docker.com/linux/${ID} ${VERSION_CODENAME} stable" \
            > /etc/apt/sources.list.d/docker.list
        apt-get update
        apt-get install -y docker-ce docker-ce-cli containerd.io \
            docker-buildx-plugin docker-compose-plugin
        systemctl enable --now docker
        echo "✔ Docker installé."
    fi
    if [[ -n "${NEWUSER:-}" ]] && id "$NEWUSER" &>/dev/null; then
        usermod -aG docker "$NEWUSER"
        echo "✔ $NEWUSER ajouté au groupe docker."
    fi
fi

# ------------------------------------------------------------------
# Résumé
# ------------------------------------------------------------------
IP=$(hostname -I | awk '{print $1}')
msg "Terminé 🎉" "Machine prête !\n\nHostname : $(hostname)\nIP       : $IP\nUser     : ${NEWUSER:-non créé}\n\nPense à tester la connexion SSH par clé avant de fermer cette session."
echo ""
echo "═══════════════════════════════════════"
echo " ✔ Bootstrap terminé — $(hostname) ($IP)"
echo "═══════════════════════════════════════"
