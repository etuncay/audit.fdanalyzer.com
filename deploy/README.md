# Ubuntu + nginx — audit.fdanalyzer.com

Next.js static export (`out/`) tek sunucuda nginx ile yayınlanır.

| Alan adı | Sunucu yolu | nginx `root` |
|----------|-------------|--------------|
| `audit.fdanalyzer.com` | `/home/sites/audit.fdanalyzer.com` | `/home/sites/audit.fdanalyzer.com/out` |

`next.config.ts`: `output: 'export'`, `trailingSlash: true` — sayfa URL'leri sondaki `/` ile açılır (ör. `/ana-giris-genel-ekranlar/dashboard/`).

## Gereksinimler

- Ubuntu 22.04 / 24.04 LTS
- DNS: `audit.fdanalyzer.com` → sunucu IP
- SSH erişimi

## Tek betik

Tüm işlemler `deploy/audit.fdanalyzer.sh` üzerinden yapılır.

### Sunucuda ilk kurulum

```bash
export GIT_REMOTE="https://github.com/KULLANICI/denetleme.git"  # veya yalnızca denet-app repo URL'si
sudo mkdir -p /home/sites
# İlk seferde repoyu kopyalayıp cd edin; yoksa setup GIT_REMOTE ile clone eder:
cd /home/sites/audit.fdanalyzer.com   # clone / rsync sonrası
sudo GIT_REMOTE="$GIT_REMOTE" bash deploy/audit.fdanalyzer.sh setup
```

Sunucudaki `/home/sites/audit.fdanalyzer.com` dizini **denet-app proje kökü** olmalı (`package.json`, `deploy/`, `src/` veya `app/` burada). Monorepo kullanıyorsanız `denet-app/` içeriğini bu path'e taşıyın veya ayrı repo olarak yayınlayın.

Varsayılan `REPO_DIR`: `/home/sites/audit.fdanalyzer.com`

### Sunucuda güncelleme (git pull + build)

```bash
cd /home/sites/audit.fdanalyzer.com
sudo bash deploy/audit.fdanalyzer.sh sync
```

### Yerel makineden rsync + sunucuda build

```bash
cd /path/to/denet-app
bash deploy/audit.fdanalyzer.sh push user@SUNUCU
```

## HTTPS (Let's Encrypt)

DNS kaydı sunucuya işaret ettikten sonra:

```bash
sudo CERTBOT_EMAIL=admin@fdanalyzer.com bash deploy/audit.fdanalyzer.sh https
```

`sync` nginx şablonunu yazdıktan sonra mevcut sertifikayı `certbot install` ile geri yükler.

## Dosyalar

| Dosya | Açıklama |
|-------|----------|
| `deploy/audit.fdanalyzer.sh` | Kurulum, sync, https, push |
| `deploy/nginx/audit.fdanalyzer.conf` | nginx site şablonu |

## Sorun giderme

```bash
sudo nginx -t
sudo tail -f /var/log/nginx/audit.fdanalyzer.com.error.log
```

404 alıyorsanız `out/` güncel mi kontrol edin: `sudo -u www-data npm run build` (proje kökünde).

## Güvenlik duvarı

```bash
sudo ufw allow OpenSSH
sudo ufw allow 'Nginx Full'
sudo ufw enable
```
