#!/usr/bin/env bash
# audit.fdanalyzer.com — statik site (repo kökü → nginx root)
#
# Sunucu (ilk kurulum):  sudo bash deploy/audit.fdanalyzer.sh setup
# Sunucu (güncelleme):   sudo bash deploy/audit.fdanalyzer.sh sync
# Sunucu (HTTPS):        sudo CERTBOT_EMAIL=you@example.com bash deploy/audit.fdanalyzer.sh https
# Yerel → sunucu:        bash deploy/audit.fdanalyzer.sh push user@SUNUCU
#
# Ortam değişkenleri:
#   REPO_DIR      — sunucudaki site yolu (varsayılan: /home/sites/audit.fdanalyzer.com)
#   GIT_REMOTE    — git clone/pull adresi (setup/sync için)
#   CERTBOT_EMAIL — Let's Encrypt e-posta (https için)
#   CERT_NAME     — certbot sertifika adı (varsayılan: audit.fdanalyzer.com)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOCAL_REPO="$(cd "${SCRIPT_DIR}/.." && pwd)"

REPO_DIR="${REPO_DIR:-/home/sites/audit.fdanalyzer.com}"
DOMAIN="${DOMAIN:-audit.fdanalyzer.com}"
NGINX_AVAILABLE="/etc/nginx/sites-available/audit.fdanalyzer.conf"
NGINX_ENABLED="/etc/nginx/sites-enabled/audit.fdanalyzer.conf"
CERT_NAME="${CERT_NAME:-audit.fdanalyzer.com}"

usage() {
  cat <<'EOF'
Kullanım:
  sudo bash deploy/audit.fdanalyzer.sh setup     Sunucuda nginx + statik site (ilk kurulum)
  sudo bash deploy/audit.fdanalyzer.sh sync      Sunucuda git pull + nginx reload
  sudo bash deploy/audit.fdanalyzer.sh https     Let's Encrypt TLS (certbot --nginx)
  bash deploy/audit.fdanalyzer.sh push USER@HOST Yerel dosyaları rsync ile sunucuya gönder

HTTPS örneği:
  sudo CERTBOT_EMAIL=admin@fdanalyzer.com bash deploy/audit.fdanalyzer.sh https

Ortam:
  REPO_DIR=/home/sites/audit.fdanalyzer.com
  GIT_REMOTE=https://github.com/KULLANICI/repo.git
  CERTBOT_EMAIL=...
  CERT_NAME=audit.fdanalyzer.com
EOF
}

require_root() {
  if [[ "${EUID}" -ne 0 ]]; then
    echo "HATA: Bu komut root veya sudo ile çalıştırılmalı."
    exit 1
  fi
}

install_nginx_config() {
  local template="${SCRIPT_DIR}/nginx/audit.fdanalyzer.conf"
  if [[ ! -f "${template}" ]]; then
    echo "HATA: ${template} bulunamadı."
    exit 1
  fi
  sed "s|__REPO_DIR__|${REPO_DIR}|g" "${template}" > "${NGINX_AVAILABLE}"
  ln -sf "${NGINX_AVAILABLE}" "${NGINX_ENABLED}"
  rm -f /etc/nginx/sites-enabled/default
}

ensure_certbot() {
  if command -v certbot >/dev/null 2>&1; then
    return 0
  fi
  echo "==> certbot kuruluyor..."
  apt update
  apt install -y certbot python3-certbot-nginx
}

restore_https_if_present() {
  local renewal="/etc/letsencrypt/renewal/${CERT_NAME}.conf"
  if [[ ! -f "${renewal}" ]]; then
    return 0
  fi
  ensure_certbot
  echo "==> Mevcut TLS sertifikası nginx'e yeniden uygulanıyor (${CERT_NAME})..."
  certbot install --cert-name "${CERT_NAME}" --nginx --non-interactive
}

reload_nginx() {
  nginx -t
  systemctl reload nginx
}

fix_permissions() {
  chown -R www-data:www-data "${REPO_DIR}"
  find "${REPO_DIR}" -type d -exec chmod 755 {} \;
  find "${REPO_DIR}" -type f -exec chmod 644 {} \;
}

verify_static_site() {
  if [[ ! -f "${REPO_DIR}/index.html" ]]; then
    echo "HATA: ${REPO_DIR}/index.html yok. Statik site dosyalarını bu dizine koyun veya git clone/pull yapın."
    exit 1
  fi
}

cmd_setup() {
  require_root

  echo "==> Paketler kuruluyor..."
  apt update
  apt install -y nginx git rsync

  echo "==> Site dizini: ${REPO_DIR}"
  mkdir -p "$(dirname "${REPO_DIR}")"

  if [[ ! -d "${REPO_DIR}/.git" ]]; then
    if [[ -z "${GIT_REMOTE:-}" ]]; then
      echo "HATA: Repo yok. GIT_REMOTE tanımlayın veya dosyaları ${REPO_DIR} altına kopyalayın."
      exit 1
    fi
    echo "==> Git clone: ${GIT_REMOTE}"
    git clone "${GIT_REMOTE}" "${REPO_DIR}"
  fi

  verify_static_site

  echo "==> İzinler..."
  fix_permissions

  echo "==> nginx site config..."
  install_nginx_config
  restore_https_if_present

  echo "==> nginx test + reload..."
  systemctl enable nginx
  reload_nginx

  echo ""
  echo "Kurulum tamamlandı."
  echo "  Dizin   : ${REPO_DIR}"
  echo "  nginx root: ${REPO_DIR}"
  echo "  Config  : ${NGINX_AVAILABLE}"
  echo ""
  echo "Site: http://${DOMAIN}/"
  echo ""
  echo "HTTPS (DNS hazırsa):"
  echo "  sudo CERTBOT_EMAIL=admin@fdanalyzer.com bash deploy/audit.fdanalyzer.sh https"
}

cmd_https() {
  require_root

  if [[ -z "${CERTBOT_EMAIL:-}" ]]; then
    echo "HATA: CERTBOT_EMAIL tanımlayın."
    echo "Örnek: sudo CERTBOT_EMAIL=admin@fdanalyzer.com bash deploy/audit.fdanalyzer.sh https"
    exit 1
  fi

  if [[ ! -d "${REPO_DIR}" ]]; then
    echo "HATA: ${REPO_DIR} yok. Önce: sudo bash deploy/audit.fdanalyzer.sh setup"
    exit 1
  fi

  ensure_certbot

  echo "==> nginx HTTP config (certbot öncesi)..."
  install_nginx_config
  reload_nginx

  echo "==> Let's Encrypt sertifikası alınıyor..."
  certbot --nginx \
    --agree-tos \
    --non-interactive \
    --email "${CERTBOT_EMAIL}" \
    --redirect \
    --cert-name "${CERT_NAME}" \
    -d "${DOMAIN}"

  reload_nginx

  echo ""
  echo "HTTPS etkin: https://${DOMAIN}/"
  echo "Yenileme kontrolü: sudo certbot renew --dry-run"
}

cmd_sync() {
  require_root

  if [[ ! -d "${REPO_DIR}" ]]; then
    echo "HATA: ${REPO_DIR} yok. Önce: sudo bash deploy/audit.fdanalyzer.sh setup"
    exit 1
  fi

  if [[ -d "${REPO_DIR}/.git" ]]; then
    echo "==> Git pull..."
    cd "${REPO_DIR}"
    sudo -u www-data git pull --ff-only
  else
    echo "Uyarı: ${REPO_DIR}/.git yok; git pull atlandı."
  fi

  verify_static_site

  echo "==> nginx config güncelleniyor..."
  install_nginx_config
  restore_https_if_present

  echo "==> İzinler..."
  fix_permissions

  echo "==> nginx test + reload..."
  reload_nginx

  echo "Güncelleme tamamlandı: $(date)"
}

cmd_push() {
  local target="${1:-}"
  if [[ -z "${target}" ]]; then
    echo "HATA: push için SSH hedefi gerekli. Örnek: bash deploy/audit.fdanalyzer.sh push user@sunucu"
    exit 1
  fi

  echo "==> rsync → ${target}:${REPO_DIR}/"
  rsync -avz --delete \
    --exclude '.git' \
    --exclude '.DS_Store' \
    "${LOCAL_REPO}/" "${target}:${REPO_DIR}/"

  echo "==> Sunucuda sync..."
  ssh "${target}" "sudo bash '${REPO_DIR}/deploy/audit.fdanalyzer.sh' sync"

  echo "Push tamamlandı."
}

main() {
  local cmd="${1:-}"
  case "${cmd}" in
    setup) cmd_setup ;;
    sync) cmd_sync ;;
    https) cmd_https ;;
    push) cmd_push "${2:-}" ;;
    -h|--help|help|"") usage ;;
    *)
      echo "Bilinmeyen komut: ${cmd}"
      usage
      exit 1
      ;;
  esac
}

main "$@"
