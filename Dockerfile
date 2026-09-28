# ═══════════════════════════════════════════════════════════════════
# CP2 — Dockerfile production-ready (multi-stage, non-root, healthcheck)
# Build:  docker build -t day12-agent:prod .
#         docker images day12-agent:prod     # xem dung lượng (< 500MB)
# ═══════════════════════════════════════════════════════════════════

# ── Stage 1: builder — cài dependency (được phép nặng, sẽ bị vứt đi) ──
FROM python:3.11-slim AS builder

WORKDIR /app

# COPY requirements trước + cài vào /install để tận dụng layer cache:
# sửa code không phải cài lại toàn bộ thư viện.
COPY requirements.txt .
RUN pip install --no-cache-dir --prefix=/install -r requirements.txt

# ── Stage 2: runtime — chỉ mang KẾT QUẢ sang, không mang compiler ──
FROM python:3.11-slim AS runtime

WORKDIR /app

# Copy các package đã cài từ builder (không cài lại)
COPY --from=builder /install /usr/local

# Copy source code SAU khi dependency đã sẵn sàng
COPY app ./app
COPY utils ./utils

# Chạy bằng user thường — thoát được khỏi app cũng không thành root trên host
RUN useradd --create-home --uid 10001 appuser
USER appuser

EXPOSE 8000

# Docker tự kiểm tra container còn phục vụ được không
HEALTHCHECK --interval=30s --timeout=5s --retries=3 \
    CMD python -c "import urllib.request; urllib.request.urlopen('http://127.0.0.1:8000/health').read()" || exit 1

# Đọc cổng từ biến PORT (Railway/Render/Cloud Run tự gán); mặc định 8000
CMD ["sh", "-c", "uvicorn app.main:app --host 0.0.0.0 --port ${PORT:-8000}"]
