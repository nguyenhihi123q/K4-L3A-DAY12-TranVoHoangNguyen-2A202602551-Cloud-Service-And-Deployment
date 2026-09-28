# Ghi Chú Làm Việc — Lab Day 12 (Cloud & Deployment)

File này ghi lại **quy trình + cách làm từng bước** để bạn tiện theo dõi và tự
giải thích được khi Lab Coach hỏi. Mỗi checkpoint gồm: mục tiêu → việc đã làm →
lý do → kết quả test.

---

## Môi trường (CP0 — Setup)

**Đã làm:**
1. Tạo virtualenv: `python -m venv .venv`
2. Cài thư viện: `./.venv/Scripts/python.exe -m pip install -r requirements.txt`
3. Tạo `.env` từ mẫu, sinh khóa ngẫu nhiên bằng
   `python -c "import secrets; print(secrets.token_urlsafe(32))"`, đặt
   `REDIS_URL=fake://` (chưa cần Docker cho CP1/CP3/CP4).

**Cách chạy test (luôn dùng python trong venv):**
```bash
./.venv/Scripts/python.exe -m pytest tests/test_cp1.py -v
```

**Lưu ý:** VSCode báo lỗi "Cannot find module fastapi/pydantic_settings" là do
IDE trỏ vào Python global, không phải venv. Test chạy bằng venv nên vẫn xanh —
lỗi đó bỏ qua được (hoặc chọn interpreter `.venv` trong VSCode để hết báo).

**`.env` đã nằm trong `.gitignore`** → không bao giờ commit (tránh −10đ).

---

## CP1 — 12-Factor Config, Health & Logging  ✅ 13/13 pass

**Mục tiêu:** tách cấu hình khỏi code, log JSON một dòng, `/health` độc lập.

### 1. `app/config.py` — khai báo 6 trường `Settings`
```python
port: int = 8000
agent_api_key: str            # KHÔNG mặc định → fail fast
redis_url: str = "redis://localhost:6379/0"
rate_limit_per_minute: int = 10
monthly_budget_usd: float = 10.0
log_level: str = "INFO"
```
**Vì sao `agent_api_key` không có mặc định?** Có mặc định = app vẫn khởi động khi
quên set secret trên cloud, chạy âm thầm và chỉ lộ khi xem hóa đơn. Không mặc
định = pydantic ném `ValidationError` ngay lúc khởi động (fail fast).
pydantic-settings tự map `agent_api_key` ← biến môi trường `AGENT_API_KEY`.

### 2. `app/logging_utils.py` — `log_event()`
Gộp `event`, `level.lower()`, `timestamp` + mọi `**fields` vào 1 dict, in bằng
`json.dumps(record, ensure_ascii=False)` — **một dòng**, không `indent`.
- `ensure_ascii=False` để tiếng Việt không bị thành `\uXXXX`.
- Một dòng vì cloud gom log theo dòng; JSON xuống dòng = log vỡ mảnh.

### 3. `app/main.py` — `/health`
```python
if lifecycle.shutting_down:
    return JSONResponse(status_code=503, content={"status": "shutting_down"})
return {"status": "ok", "service": SERVICE_NAME, "version": SERVICE_VERSION}
```
**Không nhận tham số `Depends(...)` nào** — test kiểm tra chữ ký hàm rỗng. Lý do:
`/health` là liveness probe, không được chạm Redis; nếu phụ thuộc Redis thì Redis
nấc một cái là orchestrator restart cả cụm container.

**Kết quả:** `pytest tests/test_cp1.py -v` → **13 passed**.

---

## CP2 — Docker  ✅ 16/16 pass (đã có Docker, build thật thành công)

**Mục tiêu:** đóng gói app thành image gọn, an toàn, chạy được ở mọi nơi.

### 1. `Dockerfile` — multi-stage
- **Stage `builder`** (`python:3.11-slim`): `COPY requirements.txt` rồi
  `pip install --prefix=/install`. Copy requirements TRƯỚC → sửa code không phải
  cài lại thư viện (Docker cache theo layer).
- **Stage `runtime`** (`python:3.11-slim`): `COPY --from=builder /install /usr/local`
  rồi mới `COPY app`, `COPY utils`. Compiler ở builder bị vứt đi → image nhỏ.
- **Non-root:** `useradd ... appuser` + `USER appuser`. Thoát khỏi app cũng không
  thành root trên host.
- **HEALTHCHECK:** gọi `urllib.request.urlopen(.../health)`.
- **CMD:** `uvicorn ... --host 0.0.0.0 --port ${PORT:-8000}` — bind `0.0.0.0`
  (không phải 127.0.0.1) để ngoài container gọi được; đọc `$PORT` vì cloud tự gán.

### 2. `.dockerignore`
Thêm `.env`, `.env.*` (không leak secret vào image), `__pycache__/`, `.venv/`,
`.git`, `.pytest_cache/`, `screenshots/`, `*.md`. **Giữ lại** `app`, `utils`,
`requirements.txt` (image cần) — ignore nhầm thì build xong không chạy.

### 3. `docker-compose.yml` — thêm service `agent`
```yaml
agent:
  build: .
  ports: ["8000:8000"]
  environment:
    AGENT_API_KEY: ${AGENT_API_KEY}      # đọc từ .env, KHÔNG hardcode
    REDIS_URL: redis://redis:6379/0      # `redis` = tên service = hostname
  depends_on: { redis: { condition: service_healthy } }
  healthcheck: ...
```
`localhost` trong container là chính nó, nên phải trỏ REDIS_URL tới hostname
`redis` (tên service).

**Kết quả:** `pytest tests/test_cp2.py -v` → **16 passed** (đã có Docker Desktop 29.8.0).

> ✅ **Đã build thật.** Số đo `docker images`:
> - Multi-stage (`Dockerfile` chính, `python:3.11-slim`) = **271 MB** (< 500MB → đạt).
> - 1-stage (`Dockerfile.single`, `FROM python:3.11` đầy đủ) = **1.7 GB** — dùng để
>   so sánh cho **câu 3 exercises** (chênh ~6.4 lần). File `Dockerfile.single` chỉ để
>   đo, không dùng deploy; image `day12-agent:single` đã xóa sau khi đo.
> - 2 test build image (`test_build_thanh_cong`, `test_image_du_nho`) trước đây bị skip
>   vì thiếu Docker, nay **pass** → CP2 lên 16/16.

---

## CP3 — API Security  ✅ 22/22 pass

**Mục tiêu:** URL public phải có cổng gác. 3 lớp bảo vệ, chặn **TRƯỚC** khi gọi LLM
(vì tiền mất ở bước gọi LLM).

### 1. `app/auth.py` — xác thực `X-API-Key`
```python
expected = get_settings().agent_api_key
if x_api_key is None or not secrets.compare_digest(x_api_key, expected):
    raise HTTPException(401, "invalid or missing API key")
return x_user_id or ANONYMOUS_USER
```
- Dùng `secrets.compare_digest` **thay vì `==`**: `==` dừng ở ký tự đầu khác nhau
  → thời gian phản hồi rò rỉ độ dài khớp của key (timing attack). `compare_digest`
  luôn chạy hết chuỗi.
- Trả `user_id` (từ header `X-User-Id`) để rate limit / tính tiền theo từng user;
  không gửi thì coi là `anonymous`.

### 2. `app/rate_limiter.py` — sliding window bằng Redis ZSET
- **Sliding window** (đếm 60 giây gần nhất) chứ không đếm theo phút đồng hồ — tránh
  lỗ hổng "10 request lúc 10:00:59 + 10 lúc 10:01:01 = 20 request/2 giây vẫn lọt".
- `hit_count`: `zremrangebyscore(key, 0, now-60)` xóa entry cũ → `zcard(key)` đếm.
- `check`: **kiểm tra trước, ghi nhận sau**. Nếu `hit_count >= limit` → raise 429
  (kèm header `Retry-After: 60`). Chưa vượt mới `zadd` member DUY NHẤT
  `f"{now}:{uuid4}"` (hai request cùng timestamp không ghi đè nhau) + `expire` để key tự dọn.
- Ghi trước rồi mới đếm sẽ chặn nhầm ngay ở request thứ `limit`.

### 3. `app/cost_guard.py` — chặn theo *số tiền*
- Rate limit chặn *số lượng*; cost guard chặn *chi phí* (1 request 50k token vẫn đốt sạch tiền).
- Key `cost:<user>:<YYYY-MM>` — mỗi user, mỗi tháng một sổ.
- `spent`: `get(key)`, chưa có → `0.0`, có thì `float(...)` (Redis trả chuỗi).
- `check`: `spent + estimated > budget` → raise **402** (Payment Required — đúng ngữ nghĩa hết tiền).
- `record`: `incrbyfloat(key, cost)` + `expire(KEY_TTL)` (giữ ~40 ngày để đối soát).

### 4. `app/main.py` — `/ask` ráp mọi thứ theo ĐÚNG thứ tự
```python
limiter.check(user_id)      # 429
guard.check(user_id)        # 402  → cả 2 chặn TRƯỚC khi tốn tiền
history = store.get_history(user_id)
result = ask_llm(payload.question, history)
store.append(user_id, "user", payload.question)
store.append(user_id, "assistant", result["answer"])
guard.record(user_id, result["cost_usd"])
log_event("ask_completed", ...)   # log JSON 1 dòng
```
`user_id` đến từ `Depends(verify_api_key)` → request thiếu key hợp lệ dừng ở 401,
không chạm vào thân hàm. Câu hỏi rỗng bị `AskRequest` (Field min_length=1) chặn 422.

**Kết quả:** `pytest tests/test_cp3.py -v` → **22 passed**.

---

## CP4 — Scaling & Reliability  ✅ 19/19 pass

**Mục tiêu:** app **stateless** (state ở Redis, không ở RAM) + tắt êm (graceful shutdown).

### 1. `app/store.py` — history sống trong Redis (List)
- **Vì sao?** State trong dict RAM → scale 3 instance thì user hỏi câu 1 vào instance A,
  câu 2 vào instance B là "mất trí nhớ"; container restart cũng mất sạch. Redis là
  nơi mọi instance cùng nhìn thấy.
- `ping`: `self.client.ping()` trong `try/except` → `True`/`False`, **nuốt mọi Exception**
  (để `/ready` báo trạng thái chứ không nổ 500).
- `append`: `rpush` (đẩy vào cuối) → `ltrim(key, -20, -1)` chỉ giữ 20 message gần nhất
  (không thì prompt phình vô hạn, tiền token cũng vậy) → `expire` TTL 7 ngày (tự dọn).
- `get_history`: `lrange(key, 0, -1)` rồi `json.loads` từng phần tử; rỗng → `[]`.

### 2. `app/lifecycle.py` — graceful shutdown
- `request_shutdown(signum, frame)`: bật `self.shutting_down = True` **rồi gọi lại
  handler cũ** của uvicorn:
  ```python
  previous = self._previous.get(signum)
  if callable(previous):
      previous(signum, frame)
  ```
  Mỗi tín hiệu chỉ có **một** handler; đăng ký của mình là ghi đè của uvicorn. Không
  gọi lại nó thì app bật cờ "đang tắt" rồi chạy tiếp mãi tới khi bị SIGKILL — đúng
  cái graceful shutdown muốn tránh.
- `install`: với `SIGTERM` (orchestrator yêu cầu tắt) và `SIGINT` (Ctrl+C):
  `getsignal` nhớ handler cũ TRƯỚC → `signal.signal(...)` ghi đè SAU.

### 3. `app/main.py` — `/ready` (readiness probe)
```python
if lifecycle.shutting_down:
    return JSONResponse(503, {"status": "shutting_down"})
if not store.ping():
    return JSONResponse(503, {"status": "not ready", "redis": False})
return {"status": "ready", "redis": True}
```
Khác `/health`: `/ready` **được phép** kiểm tra dependency (Redis). Load balancer dùng
nó để quyết định có đẩy traffic vào instance này không. Đang tắt hoặc Redis chết → 503
để LB ngừng gửi request mới.

**Kết quả:** `pytest tests/test_cp4.py -v` → **19 passed**.

> ✅ Đã hết `NotImplementedError` trong toàn bộ `app/` (đã kiểm tra bằng grep).

---

## Wrap-up — exercises.md  ✅ 10/10 câu

Đã trả lời cả 10 câu phản ánh bằng tiếng Việt, dựa trên code đã viết + quan sát thật:
- **Câu 2 & 9** dùng số liệu chạy thật: gọi `/ask` 3 lần cùng một user, thu được
  dòng log JSON thật và thấy `history_length` tăng 0 → 2 → 4.
- **Câu 3 (kích thước image)** dùng số đo thật từ `docker images` (multi-stage
  271MB vs 1-stage 1.7GB); **Câu 10 (lỗi deploy)** ghi lỗi THẬT gặp khi deploy
  Railway (`REDIS_URL` trỏ sai `${{day12-redis.DATABASE_URL}}` → `/ready` 503;
  thiếu `AGENT_API_KEY` → `/ask` 500), cùng cách tìm ra và sửa.
- Đã điền họ tên + MSSV vào đầu file.

> Đã sửa dòng hướng dẫn ở đầu `exercises.md` (bỏ chuỗi mẫu `> *Câu trả lời...*`
> trong ngoặc) để `grade.py` không đếm nhầm dòng hướng dẫn là 1 câu chưa trả lời
> → nhờ vậy chấm đúng 10/10.

---

## CP5 — Cloud Deployment  ✅ 15/15 (DEPLOY THẬT trên Railway)

**Đã deploy thật lên Railway** (không dùng phương án dự phòng nữa):

1. Kết nối GitHub ↔ Railway, tạo project; Railway build service `day12-agent` từ
   `Dockerfile` (theo `railway.toml`: builder=dockerfile, healthcheck `/health`).
2. Thêm một **Redis service riêng** (`day12-redis`) trong cùng project.
3. Set biến môi trường trên dashboard service `day12-agent`:
   - `AGENT_API_KEY` = khóa bí mật (đặt trực tiếp trên dashboard, KHÔNG vào repo).
   - `REDIS_URL` = **Variable Reference** `${{day12-redis.REDIS_URL}}` → agent nối
     tới Redis service thật (không phải `fake://`, không phải localhost).
   - `LOG_LEVEL`, `RATE_LIMIT_PER_MINUTE`, `MONTHLY_BUDGET_USD`; `PORT` do Railway tự gán.
4. **Generate Domain** → Public URL: `https://day12-agent-production-a9ec.up.railway.app`.
5. Kiểm chứng thật qua Internet (`curl`):
   - `GET /health` → **200** `{"status":"ok",...}`
   - `GET /ready` → **200** `{"status":"ready","redis":true}` (nối được Redis trên cloud)
   - `POST /ask` không key → **401**
6. Điền Public URL vào `DEPLOYMENT.md`, đặt `LOCAL_FALLBACK=false` trong `.env`
   → bộ test tự chuyển sang gọi thẳng URL cloud.

**Kết quả:** `pytest tests/test_cp5.py -v` → **8 passed, 5 skipped**
(4 test `TestDeploymentDoc` + 4 test `TestPublicDeployment` core pass; test `/ask`
có-key và 4 test `TestLocalFallback` bỏ qua). `grade.py` → **CP5 15/15** (deploy thật,
không còn bị cắt trần 60%).

> Vì sao cần Redis service riêng + Variable Reference? App stateless, state ở Redis.
> Trên cloud không có `docker-compose` nên phải dùng Redis service của platform và
> trỏ `REDIS_URL` của agent tới nó bằng reference — sai reference thì `/ready` trả 503.

---

## BONUS — CI/CD GitHub Actions  ✅ 12/13 pass (1 test cần repo public đã push)

**Đã tạo `.github/workflows/ci.yml`** với 3 job:
- **test**: `actions/checkout@v4` + `setup-python@v5` → cài `requirements.txt` →
  `pytest -m "not docker" --ignore=tests/test_cp5.py --ignore=tests/test_bonus_cicd.py`
  (loại 2 file cần deploy sống / badge live để CI không đỏ oan). Env `AGENT_API_KEY: ci-dummy`, `REDIS_URL: fake://`.
- **build**: `needs: test` → `docker build` (bắt lỗi Dockerfile sớm).
- **deploy**: `needs: [test, build]` + `if: github.ref == 'refs/heads/main' && github.event_name == 'push'`
  → token lấy từ `${{ secrets.RAILWAY_TOKEN }}` (KHÔNG hardcode) → smoke test `/health`.
- Đã thêm **badge CI** vào `README.md`.

> Test duy nhất còn đỏ là `test_badge_bao_passing`: nó tải badge live từ GitHub và
> đòi badge báo `passing`. Cái này cần repo **public đã push** và workflow **đã chạy
> thật** — không làm được offline. README đã điền username `nguyenhihi123q`; badge
> sẽ sống khi repo đổi đúng tên `...-CloudServicesAndDeployment` và để chế độ public.

---

## 📊 Điểm hiện tại (chạy `python grade.py`)

| Phần | Kết quả | Điểm |
|------|---------|------|
| CP1 | 13/13 | 15/15 |
| CP2 | 16/16 (build thật) | 15/15 |
| CP3 | 22/22 | 20/20 |
| CP4 | 19/19 | 20/20 |
| CP5 | 8/8 (deploy thật, 5 skip) | 15/15 |
| Exercises | 10/10 | 15/15 |
| **Bắt buộc** | | **100/100** |
| Bonus CI/CD | 12/13 | +9.2/10 |
| **TỔNG (trần 100)** | | **100/100** |

**Đã đạt trần 100/100** với CP5 **deploy thật 15/15** trên Railway (không còn dùng
phương án dự phòng). Phần bắt buộc đã full 100/100 kể cả khi bỏ bonus. Điểm bonus bị
cắt vì tổng đã chạm trần 100 — không ảnh hưởng kết quả.

> ⚠️ **Nhắc lại rủi ro trừ điểm:** tên thư mục hiện là `...-Cloud-Service-And-Deployment`
> nhưng chuẩn yêu cầu `...-CloudServicesAndDeployment` (viết liền). Khi tạo repo GitHub,
> đặt đúng tên `K4-L3A-DAY12-TranVoHoangNguyen-2A202602551-CloudServicesAndDeployment`
> để tránh **−5đ**.
