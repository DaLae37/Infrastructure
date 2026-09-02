# Infrastructure

`dalae37.com`의 인프라 저장소

### `infrastructure.yaml`

`dalae37.com` 인프라의 자원과 현재 정보를 기재

#### Naming Convention

인프라 자원은 아래 규칙을 사용

```text
{environment}-{provider}-{location}-{role}{index}
ex : prod-aws-seoul-web01
```

호스트 네임은 아래 규칙을 사용

```text
{role}{index}
ex : web01
```

### `docker/`

Docker 관련 이미지 및 구성 정보 디렉터리

## License

[The Unlicense](LICENSE)
