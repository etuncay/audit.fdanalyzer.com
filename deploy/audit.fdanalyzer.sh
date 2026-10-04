#!/usr/bin/env bash
# Denet App — audit.fdanalyzer.com (Next.js static export → out/)
#
# Sunucu (ilk kurulum):  sudo bash deploy/audit.fdanalyzer.sh setup
# Sunucu (güncelleme):   sudo bash deploy/audit.fdanalyzer.sh sync
# Sunucu (HTTPS):        sudo CERTBOT_EMAIL=you@example.com bash deploy/audit.fdanalyzer.sh https
# Yerel → sunucu:        bash deploy/audit.fdanalyzer.sh push user@SUNUCU
#
# Ortam değişkenleri:
#   REPO_DIR      — sunucudaki proje yolu (varsayılan: /home/sites/audit.fdanalyzer.com)
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
OUT_DIR="${REPO_DIR}/out"

usage() {
  cat <<'EOF'
Kullanım:
  sudo bash deploy/audit.fdanalyzer.sh setup     Sunucuda nginx + Node + build (ilk kurulum)
  sudo bash deploy/audit.fdanalyzer.sh sync      Sunucuda git pull + build + nginx reload
  sudo bash deploy/audit.fdanalyzer.sh https     Let's Encrypt TLS (certbot --nginx)
  bash deploy/audit.fdanalyzer.sh push USER@HOST Yerel repoyu rsync ile sunucuya gönder

HTTPS örneği:
  sudo CERTBOT_EMAIL=admin@fdanalyzer.com bash deploy/audit.fdanalyzer.sh https

Ortam:
  REPO_DIR=/home/sites/audit.fdanalyzer.com
  GIT_REMOTE=https://github.com/KULLANICI/denetleme.git
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

ensure_node() {
  if command -v node >/dev/null 2>&1; then
    local major
    major="$(node -p "process.versions.node.split('.')[0]")"
    if [[ "${major}" -ge 18 ]]; then
      return 0
    fi
  fi
  echo "==> Node.js 20 kuruluyor..."
  apt update
  apt install -y ca-certificates curl gnupg
  curl -fsSL https://deb.nodesource.com/setup_20.x | bash -
  apt install -y nodejs
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
  chown -R www-data:www-data "${REPO_DIR}/out"
  find "${REPO_DIR}/out" -type d -exec chmod 755 {} \;
  find "${REPO_DIR}/out" -type f -exec chmod 644 {} \;
}

verify_out() {
  if [[ ! -f "${OUT_DIR}/index.html" ]]; then
    echo "HATA: ${OUT_DIR}/index.html yok. Önce build çalıştırın (npm run build)."
    exit 1
  fi
}

run_build() {
  echo "==> npm ci + next build..."
  cd "${REPO_DIR}"
  if [[ -f package-lock.json ]]; then
    sudo -u www-data npm ci
  elif [[ -f pnpm-lock.yaml ]] && command -v pnpm >/dev/null 2>&1; then
    sudo -u www-data pnpm install --frozen-lockfile
    sudo -u www-data pnpm run build
    return 0
  else
    sudo -u www-data npm install
  fi
  sudo -u www-data npm run build
}

cmd_setup() {
  require_root

  echo "==> Paketler kuruluyor..."
  apt update
  apt install -y nginx git rsync
  ensure_node

  echo "==> Repo dizini: ${REPO_DIR}"
  mkdir -p "$(dirname "${REPO_DIR}")"

  if [[ ! -d "${REPO_DIR}/.git" ]]; then
    if [[ -z "${GIT_REMOTE:-}" ]]; then
      echo "HATA: Repo yok. GIT_REMOTE tanımlayın veya dosyaları ${REPO_DIR} altına kopyalayın."
      exit 1
    fi
    echo "==> Git clone: ${GIT_REMOTE}"
    git clone "${GIT_REMOTE}" "${REPO_DIR}"
  fi

  if [[ ! -f "${REPO_DIR}/package.json" ]] && [[ -f "${LOCAL_REPO}/package.json" ]]; then
    echo "==> Yerel dosyalar ${REPO_DIR} altına kopyalanıyor..."
    rsync -a --delete \
      --exclude '.git' \
      --exclude 'node_modules' \
      --exclude '.next' \
      --exclude '.DS_Store' \
      "${LOCAL_REPO}/" "${REPO_DIR}/"
  fi

  chown -R www-data:www-data "${REPO_DIR}"
  run_build
  verify_out

  echo "==> İzinler (out/)..."
  fix_permissions

  echo "==> nginx site config..."
  install_nginx_config
  restore_https_if_present

  echo "==> nginx test + reload..."
  systemctl enable nginx
  reload_nginx

  echo ""
  echo "Kurulum tamamlandı."
  echo "  Repo    : ${REPO_DIR}"
  echo "  Web kökü: ${OUT_DIR}"
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

  ensure_node

  if [[ -d "${REPO_DIR}/.git" ]]; then
    echo "==> Git pull..."
    cd "${REPO_DIR}"
    sudo -u www-data git pull --ff-only
  else
    echo "Uyarı: ${REPO_DIR}/.git yok; git pull atlandı."
  fi

  chown -R www-data:www-data "${REPO_DIR}"
  run_build
  verify_out

  echo "==> nginx config güncelleniyor..."
  install_nginx_config
  restore_https_if_present

  echo "==> İzinler (out/)..."
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
    --exclude 'node_modules' \
    --exclude '.next' \
    --exclude 'out' \
    --exclude '.DS_Store' \
    "${LOCAL_REPO}/" "${target}:${REPO_DIR}/"

  echo "==> Sunucuda build + nginx reload..."
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
