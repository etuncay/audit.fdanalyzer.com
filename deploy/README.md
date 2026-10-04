# Ubuntu + nginx — audit.fdanalyzer.com

Statik HTML/JS/CSS (`index.html`, `_next/`, …) repo kökünde; nginx aynı dizini servis eder.

| Alan adı | Sunucu yolu (nginx `root`) |
|----------|----------------------------|
| `audit.fdanalyzer.com` | `/home/sites/audit.fdanalyzer.com` |

## Gereksinimler

- Ubuntu 22.04 / 24.04 LTS
- DNS: `audit.fdanalyzer.com` → sunucu IP
- SSH erişimi

## Betik komutları

```bash
sudo bash deploy/audit.fdanalyzer.sh setup   # ilk kurulum
sudo bash deploy/audit.fdanalyzer.sh sync    # git pull + nginx reload
sudo bash deploy/audit.fdanalyzer.sh https   # TLS (CERTBOT_EMAIL gerekli)
bash deploy/audit.fdanalyzer.sh push user@HOST
```

### İlk kurulum örneği

```bash
export GIT_REMOTE="https://github.com/KULLANICI/audit.fdanalyzer.com.git"
sudo GIT_REMOTE="$GIT_REMOTE" bash deploy/audit.fdanalyzer.sh setup
```

## Sorun giderme

```bash
sudo nginx -t
sudo tail -f /var/log/nginx/audit.fdanalyzer.com.error.log
```

## Güvenlik duvarı

```bash
sudo ufw allow OpenSSH
sudo ufw allow 'Nginx Full'
sudo ufw enable
```
