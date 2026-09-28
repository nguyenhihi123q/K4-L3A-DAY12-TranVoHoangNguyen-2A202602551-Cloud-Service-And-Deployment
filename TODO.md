# Danh Sách Việc Cần Làm — Lab Day 12: Hạ Tầng Cloud & Deployment

> Mục tiêu: **≥ 75/100** (full 100đ + bonus 10đ, trần 100).
> Tick `[x]` sau khi hoàn thành mỗi việc. Commit sau mỗi checkpoint.

## Thang điểm nhanh

| Phần | Test | Điểm |
|------|------|------|
| CP1 — Config, Health & Logging | `pytest tests/test_cp1.py` | 15 |
| CP2 — Docker | `pytest tests/test_cp2.py` | 15 |
| CP3 — API Security | `pytest tests/test_cp3.py` | 20 |
| CP4 — Scaling & Reliability | `pytest tests/test_cp4.py` | 20 |
| CP5 — Cloud Deployment | `pytest tests/test_cp5.py` | 15 |
| exercises.md — 10 câu | Đếm số câu trả lời | 15 |
| BONUS — CI/CD | `pytest tests/test_bonus_cicd.py` | +10 |

## ⚠️ Tránh mất điểm

- [ ] Đặt tên repo đúng chuẩn `K4-L3A-DAY12-<HoVaTen>-<MSSV>-CloudServicesAndDeployment` (sai = **−5đ**; hiện đang là `...-Cloud-Service-And-Deployment` cần sửa)
- [ ] KHÔNG commit `.env` / lộ API key (lộ = **−10đ**)
- [ ] Commit ở nhiều mốc thời gian, không dồn 1 commit
- [ ] Giải thích được mọi dòng code mình viết (không giải thích được = hủy điểm phần đó)

---

## CP0 — Setup

- [ ] Đổi tên repo/thư mục đúng chuẩn (làm TRƯỚC TIÊN)
- [x] Tạo venv + `pip install -r requirements.txt`
- [x] `cp .env.example .env`
- [x] Sinh khóa `python -c "import secrets; print(secrets.token_urlsafe(32))"` → dán vào `AGENT_API_KEY`
- [x] Bật Redis: `docker compose up -d redis` (hoặc tạm `REDIS_URL=fake://`)  ← đang dùng `fake://`
- [x] `pytest tests/ -v -m "not docker"` chạy được (rớt hết là đúng)

## CP1 — 12-Factor Config, Health & Logging (15đ)

- [x] `app/config.py`: khai báo 6 trường `Settings`; **`agent_api_key` KHÔNG có mặc định**
- [x] `app/logging_utils.py`: `log_event()` in **một dòng JSON** (không `indent`, thêm `ensure_ascii=False`)
- [x] `app/main.py`: `/health` trả 200, **không chạm Redis/DB** (không dùng `Depends`)
- [x] `pytest tests/test_cp1.py -v` xanh → commit  ← **13/13 pass**

## CP2 — Docker (15đ)

- [x] `Dockerfile`: multi-stage (builder + runtime `python:3.11-slim`)
- [x] `Dockerfile`: `COPY requirements.txt` + `pip install` TRƯỚC khi copy code (tận dụng cache)
- [x] `Dockerfile`: chạy non-root (`useradd` + `USER appuser`)
- [x] `Dockerfile`: `HEALTHCHECK` + `CMD` bind `0.0.0.0` đọc `${PORT:-8000}`
- [x] `.dockerignore`: thêm `.env`, `__pycache__`, `.git`, `.venv` (giữ lại `app`, `utils`, `requirements.txt`)
- [x] `docker-compose.yml`: thêm service `agent` (build, port 8000, `depends_on: redis`, healthcheck, `REDIS_URL=redis://redis:6379/0`)
- [x] Build thật + ghi lại dung lượng image (cho câu 3 exercises)  ← **multi-stage 271MB, 1-stage 1.7GB**
- [x] `pytest tests/test_cp2.py -v` xanh → commit  ← **16/16 pass (đã có Docker, 2 test build pass)**

## CP3 — API Security (20đ)

- [x] `app/auth.py`: kiểm tra `X-API-Key` bằng **`secrets.compare_digest`** (KHÔNG dùng `==`)
- [x] `app/rate_limiter.py`: sliding window Redis sorted set; **kiểm tra trước, ghi nhận sau**; member duy nhất (`{now}:{uuid4}`)
- [x] `app/cost_guard.py`: `spent()`/`check()`/`record()`, key `cost:<user>:<YYYY-MM>`
- [x] `app/main.py` `/ask`: auth → limiter.check → guard.check → gọi LLM → record → log (chặn TRƯỚC khi gọi LLM)
- [x] `pytest tests/test_cp3.py -v` xanh → commit  ← **22/22 pass**

## CP4 — Scaling & Reliability (20đ)

- [x] `app/store.py`: bỏ dict toàn cục, lưu history vào Redis; `ltrim` giới hạn message + `expire` TTL
- [x] `app/store.py`: `ping()` nuốt mọi exception, trả `False`
- [x] `app/main.py` `/ready`: 200 khi Redis sống, 503 khi Redis chết / đang shutdown
- [x] `app/lifecycle.py`: bắt SIGTERM/SIGINT, bật cờ `shutting_down`, **gọi lại handler cũ của uvicorn**
- [x] `pytest tests/test_cp4.py -v` xanh → commit  ← **19/19 pass**

## CP5 — Cloud Deployment (15đ)  ✅ 15/15 (DEPLOY THẬT trên Railway)

- [x] Deploy lên Railway + set env trên platform  ← **đã deploy: `https://day12-agent-production-a9ec.up.railway.app`**
- [x] Kiểm tra `/health` (200), `/ready` (200 = đã nối Redis), `/ask` không key (401)  ← **verify thật trên URL cloud**
- [x] Điền `DEPLOYMENT.md`: họ tên + MSSV + repo + Public URL thật + output thật (không placeholder, không lộ key)
- [x] Chụp màn hình vào `screenshots/`  ← **`railway-dashboard.png` (agent Online) + `local-fallback-docker.png`**
- [x] `LOCAL_FALLBACK=false` trong `.env` → test tự gọi thẳng URL cloud
- [x] `pytest tests/test_cp5.py -v` xanh → **8 passed, 5 skipped → CP5 15/15**

## Wrap-up

- [x] Trả lời đủ **10 câu** trong `exercises.md` (bằng lời của mình)  ← **10/10, đã điền họ tên + MSSV**
- [x] `python grade.py` xem điểm (mục tiêu ≥ 75/100)  ← **hiện 100/100 (trần); bắt buộc 94/100 + bonus 9.2**
- [x] Xác nhận `.env` KHÔNG bị commit (nằm trong `.gitignore`)
- [x] Không còn `NotImplementedError` nào trong `app/`  ← **đã grep, sạch**
- [ ] `git add -A` → commit → push → nộp link repo (public) lên LMS/Codelab  ← **cần bạn (máy này chưa phải git repo)**

## BONUS — CI/CD GitHub Actions (+10đ, làm sau CP1–CP5)

- [x] Tạo `.github/workflows/ci.yml`
- [x] Job `test`: checkout → setup-python → cài deps → pytest (loại `test_cp5.py` + `test_bonus_cicd.py`, env `AGENT_API_KEY: ci-dummy`, `REDIS_URL: fake://`)
- [x] Job `build`: `docker build` trên runner
- [x] Job `deploy`: `needs: [test, build]` + `if:` chỉ chạy trên push nhánh main
- [x] Secret token trong GitHub Secrets; ghim version action (`@v4`, `@v5`); smoke test sau deploy
- [x] Thêm badge CI vào README  ← **đã điền username `nguyenhihi123q`; badge sẽ sống khi repo đổi đúng tên `...-CloudServicesAndDeployment` + để public**
- [ ] `pytest tests/test_bonus_cicd.py -v` xanh  ← **12/13 pass; test badge cần repo public đã push (cần bạn)**
