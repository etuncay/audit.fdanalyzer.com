# audit.fdanalyzer.com — Deploy Özeti

Statik site dosyaları **`/home/sites/audit.fdanalyzer.com`** dizininde tutulur; nginx `root` doğrudan bu klasöre işaret eder. Sunucuda Node/npm veya build yok.

## Dosyalar

| Dosya | Rol |
|--------|-----|
| `deploy/audit.fdanalyzer.sh` | `setup`, `sync`, `https`, `push` |
| `deploy/nginx/audit.fdanalyzer.conf` | nginx site şablonu |
| `deploy/README.md` | Detaylı kurulum notları |

## Varsayılanlar

| Ayar | Değer |
|------|--------|
| Domain | `audit.fdanalyzer.com` |
| REPO_DIR / nginx `root` | `/home/sites/audit.fdanalyzer.com` |

Next.js static export: `trailingSlash: true` — sayfa URL'leri sondaki `/` ile açılır (ör. `/ana-giris-genel-ekranlar/dashboard/`).

## Sunucuda ilk kurulum

```bash
export GIT_REMOTE="https://github.com/KULLANICI/REPO.git"
sudo mkdir -p /home/sites
sudo GIT_REMOTE="$GIT_REMOTE" bash deploy/audit.fdanalyzer.sh setup
```

(`setup` repoyu clone eder veya `REPO_DIR` zaten doluysa nginx’i bağlar.)

## Güncelleme

```bash
cd /home/sites/audit.fdanalyzer.com
sudo bash deploy/audit.fdanalyzer.sh sync
```

## Yerel makineden gönderme

```bash
bash deploy/audit.fdanalyzer.sh push user@SUNUCU
```

## HTTPS (Let's Encrypt)

```bash
sudo CERTBOT_EMAIL=admin@fdanalyzer.com bash deploy/audit.fdanalyzer.sh https
```

## Not

`/deploy/` URL üzerinden erişilemez (nginx `deny`).

## Sorun giderme

```bash
sudo nginx -t
sudo tail -f /var/log/nginx/audit.fdanalyzer.com.error.log
ls -la /home/sites/audit.fdanalyzer.com/index.html
```
