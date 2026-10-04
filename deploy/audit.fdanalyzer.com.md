# audit.fdanalyzer.com — Deploy Özeti

`denet-app/deploy` **audit.fdanalyzer.com** ve sunucu yolu **`/home/sites/audit.fdanalyzer.com`** için yapılandırıldı. Eski Lumensmind deploy dosyaları kaldırıldı.

## Eklenen / güncellenen dosyalar

| Dosya | Rol |
|--------|-----|
| `deploy/audit.fdanalyzer.sh` | `setup`, `sync`, `https`, `push` |
| `deploy/nginx/audit.fdanalyzer.conf` | nginx: `root` → `.../out` |
| `deploy/README.md` | Detaylı kurulum notları |

## Varsayılanlar

| Ayar | Değer |
|------|--------|
| Domain | `audit.fdanalyzer.com` |
| REPO_DIR | `/home/sites/audit.fdanalyzer.com` (denet-app proje kökü) |
| Web kökü (nginx `root`) | `/home/sites/audit.fdanalyzer.com/out` |
| Build | Sunucuda `npm ci` + `npm run build` (`setup` / `sync`) |

Next.js: `output: 'export'`, `trailingSlash: true` — sayfa URL'leri sondaki `/` ile açılır (ör. `/ana-giris-genel-ekranlar/dashboard/`).

## Sunucuda ilk kurulum

```bash
export GIT_REMOTE="https://github.com/KULLANICI/REPO.git"
sudo mkdir -p /home/sites
cd /home/sites/audit.fdanalyzer.com   # clone / rsync sonrası
sudo GIT_REMOTE="$GIT_REMOTE" bash deploy/audit.fdanalyzer.sh setup
```

Sunucudaki `/home/sites/audit.fdanalyzer.com` dizini **denet-app proje kökü** olmalı (`package.json`, `deploy/`, uygulama kaynakları burada). Monorepo kullanıyorsanız `denet-app/` içeriğini bu path'e taşıyın veya ayrı repo olarak yayınlayın.

## Güncelleme (git pull + build)

```bash
cd /home/sites/audit.fdanalyzer.com
sudo bash deploy/audit.fdanalyzer.sh sync
```

## Yerel makineden gönderme

```bash
cd /path/to/denet-app
bash deploy/audit.fdanalyzer.sh push user@SUNUCU
```

Betik repoyu rsync ile sunucuya gönderir, ardından sunucuda `sync` (build + nginx reload) çalıştırır.

## HTTPS (Let's Encrypt)

DNS kaydı sunucuya işaret ettikten sonra:

```bash
sudo CERTBOT_EMAIL=admin@fdanalyzer.com bash deploy/audit.fdanalyzer.sh https
```

`sync` nginx şablonunu yazdıktan sonra mevcut sertifikayı `certbot install` ile geri yükler.

## Ortam değişkenleri (isteğe bağlı)

| Değişken | Varsayılan | Açıklama |
|----------|------------|----------|
| `REPO_DIR` | `/home/sites/audit.fdanalyzer.com` | Sunucudaki proje yolu |
| `GIT_REMOTE` | — | `setup` için clone URL'si |
| `CERTBOT_EMAIL` | — | `https` için zorunlu |
| `CERT_NAME` | `audit.fdanalyzer.com` | Certbot sertifika adı |
| `DOMAIN` | `audit.fdanalyzer.com` | Site adı |

## Önemli not

`/out` `.gitignore` içinde olduğu için statik dosyalar repoda taşınmaz; **sunucuda build** üretilir (`npm run build` → `out/`).

## Sorun giderme

```bash
sudo nginx -t
sudo tail -f /var/log/nginx/audit.fdanalyzer.com.error.log
```

404 alıyorsanız `out/` güncel mi kontrol edin (proje kökünde):

```bash
sudo -u www-data npm run build
```

## Güvenlik duvarı (örnek)

```bash
sudo ufw allow OpenSSH
sudo ufw allow 'Nginx Full'
sudo ufw enable
```
