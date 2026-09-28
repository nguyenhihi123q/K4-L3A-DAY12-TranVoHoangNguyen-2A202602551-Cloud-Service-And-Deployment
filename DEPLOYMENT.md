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

> **Phương án đang dùng: LOCAL_FALLBACK (chạy cục bộ bằng Docker Compose).**
> Chưa deploy lên cloud thật (chưa có tài khoản Railway + repo public để push).
> Nền tảng dự kiến khi deploy thật: **Railway**. Vì dùng phương án dự phòng nên
> CP5 tối đa 60% điểm (9/15) — xem `grade.py`.

| Mục | Nội dung |
|-----|----------|
| Địa chỉ service | http://localhost:8000 (Docker Compose, `LOCAL_FALLBACK=true`) |
| Platform | Chạy cục bộ bằng Docker Compose; nền tảng dự kiến deploy thật: Railway |
| Ngày kiểm tra | 2026-09-28 |

## Biến Môi Trường Đã Set Trên Cloud

Ghi tên biến và **nguồn giá trị**, không ghi giá trị:

| Biến | Đã set | Ghi chú |
|------|--------|---------|
| `PORT` | ✅ | platform tự gán |
| `AGENT_API_KEY` | ✅ | đặt trong dashboard, không nằm trong repo |
| `REDIS_URL` | ✅ | `redis://redis:6379/0` — service `redis` trong Docker Compose (khi deploy thật: Redis add-on / Upstash) |
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

Output thật khi chạy stack bằng Docker Compose ở máy (LOCAL_FALLBACK):

```
$ docker compose ps
SERVICE   STATUS                   PORTS
agent     Up (healthy)             0.0.0.0:8000->8000/tcp
redis     Up (healthy)             0.0.0.0:6379->6379/tcp

$ curl http://localhost:8000/health
HTTP 200  ->  {"status":"ok","service":"day12-agent","version":"1.0.0"}

$ curl http://localhost:8000/ready
HTTP 200  ->  {"status":"ready","redis":true}          # đã nối được Redis

$ curl -X POST http://localhost:8000/ask -d '{"question":"Hello"}'   # không kèm API key
HTTP 401  ->  {"detail":"invalid or missing API key"}
```

## Ảnh Chụp Màn Hình

Ảnh trong thư mục `screenshots/`:

- `screenshots/local-fallback-docker.png` — kết quả `docker compose ps` (2 container
  `agent` + `redis` đều healthy) kèm output gọi `/health` (200), `/ready` (200) và
  `/ask` không key (401) — chụp từ output thật của stack đang chạy.

---

## Nếu Dùng Phương Án Dự Phòng

Không đăng ký được tài khoản cloud? Vẫn nộp được bài, nhưng CP5 tối đa 60% điểm:

1. Đặt `LOCAL_FALLBACK=true` trong `.env`
2. Chạy `docker compose up -d` rồi kiểm tra `docker compose ps`
3. Chụp màn hình vào `screenshots/`
4. Chạy `pytest tests/test_cp5.py -v` — bộ test sẽ tự chuyển sang kiểm tra
   `http://localhost:8000`
5. Ghi rõ lý do không deploy được vào phần dưới đây:

```
Lý do dùng phương án dự phòng: chưa có tài khoản cloud (Railway/Render) và
repo public trên GitHub để push tại thời điểm làm bài. App đã sẵn sàng cho
cloud (đọc $PORT, bind 0.0.0.0, /health không chạm Redis, có railway.toml +
render.yaml), nên khi có tài khoản chỉ cần push repo + set env là deploy được.
Trong lúc đó, chạy cục bộ bằng Docker Compose để kiểm chứng service hoạt động.
```
