# Let's Encrypt

`dalae37.com` 인증서 발급 및 자동 갱신 구성

### `/opt/dalae37/letsencrypt`

저장소의 `docker/letsencrypt/` 디렉터리를 아래 경로에 배치

```text
/opt/dalae37/letsencrypt/
├── compose.yaml
├── config/
├── hooks/
├── scripts/
├── secret/
└── systemd/
```

### `compose.yaml`

Cloudflare DNS Challenge를 지원하는 Certbot 실행 환경

인증서와 갱신 정보는 호스트의 `/opt/dalae37/letsencrypt/certs`에 저장하고, 설정·API Token·Deploy Hook은 현재 디렉터리의 각 파일을 읽기 전용으로 마운트

최초 발급과 자동 갱신 모두 이 Compose의 `certbot` 서비스를 사용

### `config/`

FQDN별 인증서 발급 및 자동 갱신 설정

`www`와 `api`는 `dalae37.com`의 서브도메인이며 아래 대상으로 구분

```text
서브도메인 www : www.dalae37.com → web-www-dalae37-com
서브도메인 api : api.dalae37.com → web-api-dalae37-com
```

```ini
# config/www.dalae37.com.let
domains = www.dalae37.com
cert-name = www.dalae37.com
```

`www`와 `api`는 FQDN의 첫 번째 서브도메인 라벨이며 systemd 인스턴스에는 전체 FQDN을 사용

파일명과 `domains`, `cert-name`에는 같은 FQDN을 사용

새 서브도메인은 `scripts/renew.sh` 수정 없이 `config/{fqdn}.let` 파일만 추가

> [!IMPORTANT]
> Nginx Docker 컨테이너의 서비스 이름은 반드시 FQDN의 점을 하이픈으로 바꾼 `web-{fqdn}` 형식을 준수
>
> 예: `www.dalae37.com` → `web-www-dalae37-com`
>
> `scripts/renew.sh`가 이 규칙으로 갱신 후 Reload할 Nginx 컨테이너를 찾으므로 이름이 다르면 자동 갱신 과정이 실패

해당 Nginx는 `certs` 디렉터리를 마운트하고 FQDN과 같은 인증서 경로를 사용

### `secret/cloudflare.api`

Cloudflare API Token을 아래 형식으로 기재

```ini
dns_cloudflare_api_token = replace_with_the_real_token
```

실제 Token은 Git에 커밋하지 않고 운영 서버의 파일 권한을 소유자 전용으로 설정

```bash
chmod 600 /opt/dalae37/letsencrypt/secret/cloudflare.api
```

### 최초 발급

각 서버에서 대상 인증서를 최초 1회 발급

```bash
cd /opt/dalae37/letsencrypt

# www 서브도메인 서버
docker compose run --rm --no-deps -T certbot \
  certonly --config /etc/certbot/config/www.dalae37.com.let

# api 서브도메인 서버
docker compose run --rm --no-deps -T certbot \
  certonly --config /etc/certbot/config/api.dalae37.com.let
```

### 자동 갱신

매일 `02:00 (Asia/Seoul)`에 인증서 갱신 여부를 확인

갱신 성공 시 Deploy Hook으로 해당 Nginx 설정을 검사한 뒤 Graceful Reload

#### 설치

`/opt/dalae37/letsencrypt`에서 실행 스크립트와 systemd 파일을 설치

```bash
cd /opt/dalae37/letsencrypt
sudo bash install.sh
```

#### 타이머 활성화

각 서버에서 해당 타이머만 활성화

```bash
# www 서브도메인 서버
sudo systemctl enable --now certbot-renew@www.dalae37.com.timer

# api 서브도메인 서버
sudo systemctl enable --now certbot-renew@api.dalae37.com.timer
```

새 서브도메인도 `certbot-renew@{FQDN}.timer` 형식을 사용

#### 수동 실행

필요한 경우 배치 디렉터리의 스크립트를 직접 실행

```bash
cd /opt/dalae37/letsencrypt

# www 서브도메인 서버
sudo bash scripts/renew.sh www.dalae37.com

# api 서브도메인 서버
sudo bash scripts/renew.sh api.dalae37.com
```

### 확인

Deploy Hook을 포함한 갱신 과정을 테스트

```bash
# www 서브도메인 서버
sudo /usr/local/sbin/certbot-renew www.dalae37.com --dry-run

# api 서브도메인 서버
sudo /usr/local/sbin/certbot-renew api.dalae37.com --dry-run
```

타이머와 서비스 로그를 확인

```bash
systemctl list-timers 'certbot-renew@*'
systemctl status certbot-renew@www.dalae37.com.timer
journalctl -u certbot-renew@www.dalae37.com.service
```
