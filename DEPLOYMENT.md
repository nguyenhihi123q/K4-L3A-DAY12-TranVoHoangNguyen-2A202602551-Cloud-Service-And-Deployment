# Thông Tin Deploy — Checkpoint 5

> Điền file này sau khi deploy xong. `pytest tests/test_cp5.py` đọc file này
> để tìm địa chỉ service của bạn và gọi thử.
>
> **Chỉ ghi TÊN biến môi trường, tuyệt đối không dán giá trị API key vào đây.**
> Repo này công khai — dán khóa vào là mất khóa.

## Thông Tin Học Viên

| Mục | Nội dung |
|-----|----------|
| Họ và tên | Trần Võ Hoàng Nguyên |
| Mã học viên | 2A202602551 |
| Repo | K4-L3A-DAY12-TranVoHoangNguyen-2A202602551-CloudServicesAndDeployment |

## Service

> **Đã deploy thật lên cloud (Railway).** Service có địa chỉ công khai HTTPS,
> nối được Redis thật (Redis service riêng trên Railway), có bảo mật API key.

| Mục | Nội dung |
|-----|----------|
| Địa chỉ service (Public URL) | https://day12-agent-production-a9ec.up.railway.app |
| Platform | Railway (build từ `Dockerfile`, healthcheck `/health`, Redis service riêng) |
| Ngày kiểm tra | 2026-09-28 |

## Biến Môi Trường Đã Set Trên Cloud

Ghi tên biến và **nguồn giá trị**, không ghi giá trị:

| Biến | Đã set | Ghi chú |
|------|--------|---------|
| `PORT` | ✅ | Railway tự gán, app đọc `$PORT` |
| `AGENT_API_KEY` | ✅ | đặt trong dashboard Railway, KHÔNG nằm trong repo |
| `REDIS_URL` | ✅ | Variable Reference `${{day12-redis.REDIS_URL}}` — trỏ tới Redis service riêng trên Railway |
| `RATE_LIMIT_PER_MINUTE` | ✅ | 10 |
| `MONTHLY_BUDGET_USD` | ✅ | 10.0 |
| `LOG_LEVEL` | ✅ | INFO |

## Lệnh Kiểm Tra

Thay `<URL>` bằng Public URL ở trên:

```bash
# 1. Liveness — mong đợi 200 {"status":"ok"}
curl -i <URL>/health

# 2. Readiness — mong đợi 200 {"status":"ready"} (đã nối được Redis)
curl -i <URL>/ready

# 3. Không có API key — mong đợi 401
curl -i -X POST <URL>/ask \
  -H "Content-Type: application/json" \
  -d '{"question":"Hello"}'

# 4. Có API key — mong đợi 200 kèm câu trả lời
curl -i -X POST <URL>/ask \
  -H "Content-Type: application/json" \
  -H "X-API-Key: $AGENT_API_KEY" \
  -H "X-User-Id: sv-test" \
  -d '{"question":"Deploy là gì?"}'

# 5. Rate limit — gọi 15 lần, những lần cuối phải trả 429
for i in $(seq 1 15); do
  curl -s -o /dev/null -w "%{http_code} " -X POST <URL>/ask \
    -H "Content-Type: application/json" \
    -H "X-API-Key: $AGENT_API_KEY" \
    -H "X-User-Id: sv-test" \
    -d '{"question":"test"}'
done; echo
```

## Kết Quả Chạy Thật

Output thật khi gọi service **trên cloud (Railway)** qua Internet, ngày 2026-09-28:

```
$ curl https://day12-agent-production-a9ec.up.railway.app/health
HTTP 200  ->  {"status":"ok","service":"day12-agent","version":"1.0.0"}

$ curl https://day12-agent-production-a9ec.up.railway.app/ready
HTTP 200  ->  {"status":"ready","redis":true}          # đã nối được Redis trên Railway

$ curl -X POST https://day12-agent-production-a9ec.up.railway.app/ask -d '{"question":"Hello"}'   # không kèm API key
HTTP 401  ->  {"detail":"invalid or missing API key"}
```

## Ảnh Chụp Màn Hình

Ảnh trong thư mục `screenshots/`:

- `screenshots/railway-dashboard.png` — dashboard Railway: service `day12-agent`
  ở trạng thái **Online** và service Redis riêng `day12-redis` với biến `REDIS_URL`
  (agent nối tới Redis qua Variable Reference).
- `screenshots/local-fallback-docker.png` — bằng chứng bổ sung: chạy stack bằng
  `docker compose` ở máy (`docker compose ps` + gọi `/health` 200, `/ready` 200,
  `/ask` không key 401) — dùng để đối chiếu với bản cloud.

---

## Phương Án Dự Phòng (không dùng — chỉ để tham khảo)

Bài này **đã deploy thật lên Railway** nên không dùng phương án dự phòng. Nếu ai
đó không đăng ký được tài khoản cloud thì vẫn nộp được (CP5 tối đa 60% điểm) bằng
cách: đặt `LOCAL_FALLBACK=true` trong `.env`, chạy `docker compose up -d`, chụp
màn hình vào `screenshots/`, rồi `pytest tests/test_cp5.py -v` (bộ test tự chuyển
sang kiểm tra `http://localhost:8000`).
