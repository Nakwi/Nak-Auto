#!/usr/bin/env bash
#
# bootstrap.sh — Post-install homelab (Debian/Ubuntu)
# Usage : sudo bash bootstrap.sh
#
set -euo pipefail

# ------------------------------------------------------------------
# CONFIG — personnalise ici
# ------------------------------------------------------------------
DEFAULT_USER="ryan"
TZ="Europe/Paris"
PKGS="curl wget sudo nano vim git gh htop tree ncdu rsync unzip zip \
ca-certificates gnupg net-tools dnsutils qemu-guest-agent"

# ------------------------------------------------------------------
# Couleurs & helpers
# ------------------------------------------------------------------
R='\033[0;31m'; G='\033[0;32m'; Y='\033[1;33m'; B='\033[1;34m'
C='\033[0;36m'; W='\033[1;37m'; D='\033[0;90m'; N='\033[0m'

ok()    { echo -e "  ${G}✔${N} $1"; }
info()  { echo -e "  ${C}ℹ${N} $1"; }
warn()  { echo -e "  ${Y}⚠${N} $1"; }
err()   { echo -e "  ${R}✖${N} $1"; }
step()  { echo -e "\n${B}▶ $1${N}"; }

ask() { # ask "question" "défaut" -> réponse
    local q="$1" def="${2:-}" ans
    if [[ -n "$def" ]]; then
        read -rp "$(echo -e "  ${W}?${N} $q ${D}[$def]${N} : ")" ans
        echo "${ans:-$def}"
    else
        read -rp "$(echo -e "  ${W}?${N} $q : ")" ans
        echo "$ans"
    fi
}

ask_yn() { # ask_yn "question" "y|n(défaut)" -> 0 si oui
    local q="$1" def="${2:-y}" ans
    read -rp "$(echo -e "  ${W}?${N} $q ${D}[$( [[ $def == y ]] && echo O/n || echo o/N )]${N} : ")" ans
    ans="${ans:-$def}"
    [[ "${ans,,}" == "y" || "${ans,,}" == "o" || "${ans,,}" == "oui" ]]
}

# ------------------------------------------------------------------
# Pré-vols
# ------------------------------------------------------------------
if [[ $EUID -ne 0 ]]; then
    err "Lance ce script en root : sudo bash $0"
    exit 1
fi
export DEBIAN_FRONTEND=noninteractive

clear
echo -e "${C}"
cat <<'BANNER'
  ┌─────────────────────────────────────────────┐
  │   ⚙  BOOTSTRAP HOMELAB — naki edition       │
  │      Post-install Debian / Ubuntu           │
  └─────────────────────────────────────────────┘
BANNER
echo -e "${N}"
info "Machine  : $(hostname)"
info "OS       : $(. /etc/os-release && echo "$PRETTY_NAME")"
info "IP       : $(hostname -I | awk '{print $1}')"
echo ""

# ------------------------------------------------------------------
# Questions (tout d'un coup, ensuite ça déroule)
# ------------------------------------------------------------------
NEW_HOSTNAME=$(ask "Hostname de la machine" "$(hostname)")
NEWUSER=$(ask "Utilisateur à créer" "$DEFAULT_USER")

PASS1=""; PASS2="x"
if id "$NEWUSER" &>/dev/null; then
    info "L'utilisateur $NEWUSER existe déjà — pas de création."
else
    while [[ "$PASS1" != "$PASS2" || -z "$PASS1" ]]; do
        read -srp "$(echo -e "  ${W}?${N} Mot de passe pour $NEWUSER : ")" PASS1; echo
        read -srp "$(echo -e "  ${W}?${N} Confirmation : ")" PASS2; echo
        [[ "$PASS1" != "$PASS2" ]] && warn "Les mots de passe ne correspondent pas, réessaie."
        [[ -z "$PASS1" ]] && warn "Mot de passe vide interdit."
    done
fi

INSTALL_DOCKER=false
ask_yn "Installer Docker + Docker Compose ?" "n" && INSTALL_DOCKER=true

echo ""
echo -e "${D}──────────────────────────────────────────────${N}"

# ------------------------------------------------------------------
# 1. Mise à jour système
# ------------------------------------------------------------------
step "Mise à jour du système"
apt-get update -qq
apt-get -y -qq full-upgrade
apt-get -y -qq autoremove --purge
ok "Système à jour."

# ------------------------------------------------------------------
# 2. Hostname
# ------------------------------------------------------------------
if [[ "$NEW_HOSTNAME" != "$(hostname)" ]]; then
    step "Hostname"
    hostnamectl set-hostname "$NEW_HOSTNAME"
    if grep -q "^127.0.1.1" /etc/hosts; then
        sed -i "s/^127.0.1.1.*/127.0.1.1\t$NEW_HOSTNAME/" /etc/hosts
    else
        echo -e "127.0.1.1\t$NEW_HOSTNAME" >> /etc/hosts
    fi
    ok "Hostname : $NEW_HOSTNAME"
fi

# ------------------------------------------------------------------
# 3. Timezone
# ------------------------------------------------------------------
step "Timezone"
timedatectl set-timezone "$TZ"
ok "Timezone : $TZ"

# ------------------------------------------------------------------
# 4. Paquets de base
# ------------------------------------------------------------------
step "Installation des paquets de base"
echo -e "  ${D}$PKGS${N}"
apt-get install -y -qq $PKGS 2>/dev/null || {
    # gh n'existe pas sur certaines vieilles versions -> retry sans lui
    warn "Un paquet a échoué, nouvelle tentative sans 'gh'..."
    apt-get install -y -qq ${PKGS/gh /}
}
systemctl enable --now qemu-guest-agent &>/dev/null || true
ok "Paquets installés."

# ------------------------------------------------------------------
# 5. Utilisateur
# ------------------------------------------------------------------
step "Utilisateur"
if ! id "$NEWUSER" &>/dev/null; then
    useradd -m -s /bin/bash "$NEWUSER"
    echo "$NEWUSER:$PASS1" | chpasswd
    ok "Utilisateur $NEWUSER créé."
fi
usermod -aG sudo "$NEWUSER"
ok "$NEWUSER est dans le groupe sudo."

# ------------------------------------------------------------------
# 6. Docker (optionnel)
# ------------------------------------------------------------------
if $INSTALL_DOCKER; then
    step "Docker"
    if command -v docker &>/dev/null; then
        info "Docker déjà installé."
    else
        install -m 0755 -d /etc/apt/keyrings
        . /etc/os-release
        curl -fsSL "https://download.docker.com/linux/${ID}/gpg" \
            -o /etc/apt/keyrings/docker.asc
        chmod a+r /etc/apt/keyrings/docker.asc
        echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] \
https://download.docker.com/linux/${ID} ${VERSION_CODENAME} stable" \
            > /etc/apt/sources.list.d/docker.list
        apt-get update -qq
        apt-get install -y -qq docker-ce docker-ce-cli containerd.io \
            docker-buildx-plugin docker-compose-plugin
        systemctl enable --now docker
        ok "Docker installé."
    fi
    usermod -aG docker "$NEWUSER"
    ok "$NEWUSER est dans le groupe docker."
fi

# ------------------------------------------------------------------
# Résumé
# ------------------------------------------------------------------
IP=$(hostname -I | awk '{print $1}')
echo ""
echo -e "${G}"
cat <<'DONE'
  ┌─────────────────────────────────────────────┐
  │            ✔  MACHINE PRÊTE  🎉             │
  └─────────────────────────────────────────────┘
DONE
echo -e "${N}"
echo -e "  ${W}Hostname${N} : $(hostname)"
echo -e "  ${W}IP${N}       : $IP"
echo -e "  ${W}User${N}     : $NEWUSER (sudo$($INSTALL_DOCKER && echo ", docker"))"
echo -e "  ${W}SSH${N}      : ssh $NEWUSER@$IP"
echo ""
$INSTALL_DOCKER && warn "Groupe docker : déconnecte/reconnecte $NEWUSER pour l'activer."
if [[ "$NEW_HOSTNAME" != "$(cat /proc/sys/kernel/hostname 2>/dev/null || hostname)" ]]; then
    info "Un reboot est conseillé pour finaliser le hostname."
fi
echo ""
