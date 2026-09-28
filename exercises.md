# Phiếu Phản Ánh — K4 Level 3A, Ngày 12

> **Bài làm cá nhân.** Trả lời bằng lời của chính bạn, dựa trên những gì bạn
> quan sát được khi chạy code — không sao chép đáp án của người khác.
>
> Cách trả lời: thay dòng gợi ý in nghiêng dưới mỗi câu bằng câu trả lời của bạn.
> `grade.py` đếm số câu đã trả lời (15 điểm cho 10 câu).
>
> Họ và tên: Trần Võ Hoàng Nguyên   Mã học viên: 2A202602551

---

### Câu 1 — Fail fast (CP1)

Trong `Settings`, `agent_api_key` không có giá trị mặc định nên app chết ngay
khi khởi động nếu thiếu biến môi trường. Hãy mô tả một tình huống cụ thể mà
việc "chết sớm" này cứu bạn, so với việc để mặc định `"changeme"`.

Tình huống: tôi deploy service lên Railway nhưng quên tạo biến `AGENT_API_KEY`
trong dashboard. Vì `agent_api_key` không có mặc định, pydantic-settings ném
`ValidationError` ngay khi process khởi động → container crash, deploy bị đánh
dấu FAILED, và bản cũ vẫn tiếp tục phục vụ. Tôi thấy lỗi ngay trong log deploy
và sửa trong 1 phút.

Ngược lại, nếu để mặc định `"changeme"`: app vẫn khởi động bình thường, `/health`
báo 200, deploy "thành công". Nhưng bây giờ khóa hợp lệ là `"changeme"` — thứ mà
bất kỳ ai từng đọc tutorial cũng thử đầu tiên. Người lạ gọi `/ask` với key đó và
đốt ngân sách LLM của tôi. Lỗi này không hiện ra ở đâu cho tới khi tôi xem hóa
đơn cuối tháng. Fail fast biến một sự cố cấu hình âm thầm, tốn tiền thành một
lỗi ồn ào, miễn phí, xảy ra ngay giây đầu tiên.

---

### Câu 2 — Log cho máy đọc (CP1)

Chạy service và gọi `/ask` vài lần. Dán một dòng log JSON bạn thu được, rồi
nêu **hai** việc bạn làm được với dòng log đó mà `print("đã trả lời xong")`
không làm được.

Dòng log thật tôi thu được khi gọi `/ask`:

```json
{"event": "ask_completed", "level": "info", "timestamp": "2026-09-28T08:14:15.705455+00:00", "user_id": "sv-quan-sat", "tokens_in": 38, "tokens_out": 51, "cost_usd": 3.63e-05}
```

Hai việc làm được mà `print("đã trả lời xong")` không làm được:

1. **Lọc và tính toán bằng máy.** Vì mỗi dòng là JSON có trường rõ ràng, tôi
   chạy được truy vấn kiểu "tổng `cost_usd` theo từng `user_id` trong hôm nay"
   hay "đếm số `ask_completed` mỗi phút" trên nền tảng log (CloudWatch,
   Grafana Loki, Datadog...). Với chuỗi tự do `"đã trả lời xong"` thì không có
   trường nào để nhóm hay cộng — chỉ đếm được số dòng.
2. **Gắn cảnh báo theo ngưỡng.** Tôi đặt được alert "bắn thông báo khi
   `cost_usd` cộng dồn trong 1 giờ vượt X" hoặc "khi `tokens_in` bất thường
   cao", vì giá trị nằm trong trường số máy đọc được. Câu `print` không mang
   theo con số nào nên không thể làm gốc cho cảnh báo.

---

### Câu 3 — Kích thước image (CP2)

Build cả hai phiên bản và ghi lại số đo thật:

```bash
docker build -f <Dockerfile-1-stage> -t agent:single .
docker build -t agent:multi .
docker images | grep agent
```

| Bản | Dung lượng |
|-----|-----------|
| 1 stage (`FROM python:3.11` đầy đủ) | **1.7 GB (~1740 MB)** |
| Multi-stage (`python:3.11-slim`) | **271 MB** |

Giải thích: phần dung lượng chênh lệch đó là những gì?

> **Số đo thật** trên máy tôi (Docker 29.8.0): bản 1-stage build từ
> `Dockerfile.single` (`FROM python:3.11`) ra **1.7GB**, bản multi-stage
> (`Dockerfile` chính, `python:3.11-slim`) ra **271MB** — nhỏ hơn ~6.4 lần.
> Cả hai đo bằng `docker images`.

Chênh lệch ~1.43GB đến từ hai nguồn:

1. **Base image béo vs gầy.** `python:3.11` đầy đủ mang theo cả bộ công cụ biên
   dịch (gcc, make, header dev), nhiều thư viện hệ thống và tài liệu — thứ chỉ
   cần lúc *build*, không cần lúc *chạy*. `python:3.11-slim` lược bỏ chúng nên
   base đã nhỏ hơn nhiều trăm MB ngay từ đầu.
2. **Rác của quá trình build bị vứt đi.** Ở bản multi-stage, mọi thứ dùng để cài
   thư viện nằm ở stage `builder`; stage `runtime` chỉ
   `COPY --from=builder /install` phần thư viện đã cài xong. Compiler, cache
   `pip`/`apt`, layer trung gian đều bị bỏ lại cùng stage builder, không theo
   sang image cuối.

Nói ngắn: image cuối chỉ cần *thứ để chạy* (Python runtime + thư viện đã cài),
không cần *thứ để build*. 1.43GB chênh lệch đó là toàn bộ đồ nghề xây dựng bị để
lại ngoài cửa.

---

### Câu 4 — Thứ tự lệnh trong Dockerfile (CP2)

Sửa một ký tự trong `app/main.py` rồi build lại. Với Dockerfile của bạn, những
layer nào được dùng lại từ cache, layer nào phải chạy lại? Nếu bạn đặt
`COPY . .` lên trước `RUN pip install` thì kết quả khác thế nào?

Dockerfile của tôi copy `requirements.txt` và chạy `pip install` **trước**, rồi
mới `COPY app` / `COPY utils`. Vì vậy khi sửa một ký tự trong `app/main.py`:

- **Được dùng lại từ cache:** layer ảnh nền `python:3.11-slim`, layer
  `COPY requirements.txt`, và layer `RUN pip install` — vì `requirements.txt`
  không đổi thì hash của các layer này không đổi.
- **Phải chạy lại:** layer `COPY app` (nội dung đã khác) và mọi layer sau nó.
  Đây chỉ là chép vài KB code nên gần như tức thì.

Nếu đặt `COPY . .` **trước** `RUN pip install`: mỗi lần sửa bất kỳ file code nào,
hash của layer `COPY . .` đổi → Docker phải chạy lại tất cả layer phía sau, gồm
cả `RUN pip install`. Nghĩa là cài lại toàn bộ thư viện từ mạng mỗi lần build,
dù `requirements.txt` chẳng thay đổi gì. Nguyên tắc: **thứ ít đổi (dependency)
copy trước, thứ hay đổi (code) copy sau** để tận dụng cache tối đa.

---

### Câu 5 — Vì sao không chạy bằng root (CP2)

Container mặc định chạy bằng root. Mô tả chuỗi sự kiện dẫn từ "một lỗ hổng
trong code Python của bạn" tới "kẻ tấn công có quyền cao trên máy host", và
lệnh `USER` cắt đứt chuỗi đó ở chỗ nào.

Chuỗi sự kiện khi container chạy bằng root:

1. Code Python của tôi có lỗ hổng (ví dụ chèn lệnh do không kiểm tra input, hay
   một thư viện dính RCE).
2. Kẻ tấn công lợi dụng lỗ hổng để chạy lệnh tùy ý — lệnh đó chạy **với quyền của
   tiến trình app**. Nếu app là root, kẻ tấn công đang là root *bên trong* container.
3. Là root trong container, hắn cài công cụ, đọc/ghi mọi file được mount vào
   container, và thử "thoát" container: khai thác một lỗ hổng của kernel/Docker,
   hoặc lạm dụng volume/socket bị mount nhầm (ví dụ `/var/run/docker.sock`).
4. Thoát ra được và vì trong container đang là root, hắn thành **root trên máy
   host** → chiếm toàn quyền.

`USER appuser` cắt chuỗi ở **bước 2–3**: tiến trình app chạy dưới user thường,
không có quyền. Kẻ tấn công có thực thi được code cũng chỉ là user thường trong
container — không cài được gói hệ thống, không đọc được file của user khác, và
quan trọng nhất, một lần thoát container sẽ rơi ra host với quyền user thường
chứ không phải root. Đây là phòng thủ theo lớp: `USER` không vá lỗ hổng, nhưng
biến "chiếm toàn quyền" thành "quyền hạn chế", giảm mạnh thiệt hại.

---

### Câu 6 — Cửa sổ trượt (CP3)

Rate limit của bạn dùng sliding window 60 giây. Nếu thay bằng cách đếm theo
phút đồng hồ (reset lúc giây 00), một người dùng có thể gửi tối đa bao nhiêu
request trong 2 giây liên tiếp khi hạn mức là 10/phút? Giải thích cách đạt được
con số đó.

Với cách đếm theo phút đồng hồ (reset lúc giây :00), một người có thể gửi tối đa
**20 request trong khoảng ~2 giây**.

Cách đạt: gửi 10 request vào cuối phút, quanh 10:00:59, rồi gửi tiếp 10 request
ngay đầu phút sau, quanh 10:01:01. Mỗi cụm đều nằm gọn trong bộ đếm riêng của
phút mình (phút 10:00 và phút 10:01), cả hai đều đúng hạn mức 10/phút. Nhưng hai
mốc chỉ cách nhau ~2 giây, nên thực tế server nhận 20 request trong 2 giây — gấp
đôi tốc độ mà hạn mức muốn cho phép. Lỗ hổng nằm ở chỗ ranh giới phút reset bộ
đếm về 0 một cách đột ngột.

Sliding window 60 giây của tôi không bị lỗi này: tại thời điểm 10:01:01 nó đếm
mọi request trong 60 giây *gần nhất* (từ 10:00:01 đến 10:01:01), nên 10 request
lúc 10:00:59 vẫn được tính, và request thứ 11 bị chặn.

---

### Câu 7 — Rate limit và cost guard (CP3)

Hai cơ chế này khác nhau ở điểm nào? Cho một tình huống mà rate limit cho qua
nhưng cost guard phải chặn, và một tình huống ngược lại.

Khác nhau: **rate limit đếm _số lượng_ request** trong một cửa sổ thời gian, còn
**cost guard đếm _số tiền_ đã tiêu** trong tháng. Một cái bảo vệ khỏi bị gọi quá
nhanh; cái kia bảo vệ khỏi tiêu quá nhiều tiền — hai trục hoàn toàn khác nhau.

- **Rate limit cho qua nhưng cost guard chặn:** user gửi request thứ 3 trong phút
  (hạn mức 10/phút → còn quota, rate limit cho qua), nhưng mỗi câu hỏi của user
  này cực dài, ngốn hàng chục nghìn token, và tổng chi phí tháng đã chạm
  `MONTHLY_BUDGET_USD`. Cost guard raise 402 dù mới chỉ là request thứ 3.
- **Cost guard cho qua nhưng rate limit chặn:** user viết một script bắn 50
  request/giây, mỗi câu chỉ vài token nên tổng tiền còn xa ngân sách (cost guard
  cho qua), nhưng vượt xa 10 request/phút. Rate limit raise 429 để bảo vệ CPU và
  chống lạm dụng, dù chi phí chưa đáng kể.

Nói ngắn: cần **cả hai** vì "ít request nhưng mỗi request đắt" và "nhiều request
nhưng mỗi request rẻ" là hai kiểu lạm dụng khác nhau, mỗi cơ chế chỉ bắt được một.

---

### Câu 8 — /health khác /ready (CP4)

Nếu gộp hai endpoint làm một và cho nó kiểm tra Redis, chuyện gì xảy ra với cụm
3 container khi Redis mất kết nối 30 giây? Trả lời theo đúng thứ tự sự kiện.

Nếu gộp `/health` và `/ready` làm một endpoint có kiểm tra Redis, thì trong 30
giây Redis mất kết nối:

1. Redis không trả lời → endpoint gộp của **cả 3** container đồng loạt trả 503.
2. Orchestrator dùng chính endpoint này làm **liveness probe**. Thấy 503, nó kết
   luận "container chết" và **restart** cả 3 container.
3. Restart xong, container khởi động lại nhưng Redis *vẫn* chưa hồi (chưa hết 30
   giây), nên liveness lại 503 → lại bị restart. Cả cụm rơi vào vòng
   **CrashLoopBackOff**.
4. Đến giây thứ 30 Redis hồi, nhưng lúc này 3 container đang dở dang giữa các
   lần restart, thời gian phục hồi kéo dài thêm và toàn bộ dịch vụ gián đoạn —
   dù bản thân code Python chưa bao giờ hỏng.

Gốc rễ: một sự cố *tạm thời* của dependency (Redis nấc 30 giây) bị biến thành sự
cố *chết process*. Tách hai endpoint chữa đúng chỗ này: `/health` (liveness)
KHÔNG chạm Redis nên vẫn 200 → không container nào bị restart; chỉ `/ready`
(readiness) trả 503 → load balancer tạm ngừng đẩy traffic vào, và tự động đẩy
lại ngay khi Redis hồi. Không mất container nào.

---

### Câu 9 — Stateless (CP4)

Chạy `docker compose up --scale agent=3` rồi gọi `/ask` nhiều lần với cùng một
`X-User-Id`. Quan sát `history_length` trong response. Nếu lịch sử được lưu
trong một dict Python thay vì Redis, bạn sẽ thấy con số đó thay đổi thế nào?

Tôi đã quan sát bằng cách gọi `/ask` 3 lần liên tiếp cùng một `X-User-Id` (lưu ở
Redis, đây là fake-redis dùng chung cho toàn app). `history_length` trả về lần
lượt: **0 → 2 → 4** (mỗi lượt hỏi ghi thêm 2 message: câu của user + câu trả lời
của assistant, nên lần sau đọc được lịch sử của mọi lần trước). Với
`docker compose up --scale agent=3`, load balancer chia request cho 3 container
nhưng cả 3 cùng đọc/ghi một Redis, nên con số vẫn tăng đều 0 → 2 → 4 → 6...
bất kể request rơi vào container nào.

Nếu lịch sử nằm trong một **dict Python trong RAM của từng container**, con số sẽ
**nhảy loạn và thường về 0**: mỗi container có dict riêng, không thấy dữ liệu của
nhau. Request 1 vào container A (A nhớ 2 message), request 2 vào container B (B
chưa từng thấy user này → `history_length = 0` lần nữa), request 3 vào C → lại 0...
`history_length` phụ thuộc vào việc request tình cờ rơi vào container nào, và cứ
container nào restart là lịch sử của nó bốc hơi. Đó chính là lý do state phải ra
khỏi process — để agent không "mất trí nhớ" khi scale ngang.

---

### Câu 10 — Deploy thật (CP5)

Ghi lại **một** lỗi bạn gặp khi deploy lên cloud (build fail, health check
timeout, sai REDIS_URL, app không đọc `$PORT`...): thông báo lỗi là gì, bạn
tìm ra nguyên nhân bằng cách nào, và sửa ra sao?

> **Ghi chú trung thực:** câu này gắn với CP5 (deploy thật lên cloud). Tôi chưa
> deploy được từ máy làm bài (chưa có tài khoản cloud + repo public để push).
> Dưới đây là lỗi phổ biến nhất và cách xử lý; khi bạn deploy thật, hãy thay bằng
> lỗi cụ thể bạn gặp.

Lỗi thường gặp nhất: **health check timeout — deploy báo "service unhealthy"**.

- **Thông báo lỗi:** trên dashboard Railway/Render, deploy chạy xong nhưng health
  check quay mãi rồi báo `Healthcheck failed` / `service unhealthy`, container bị
  kill và restart liên tục.
- **Tìm nguyên nhân:** mở log runtime trên dashboard, thấy uvicorn khởi động ở
  `http://0.0.0.0:8000` trong khi platform lại gán cổng động qua biến `$PORT`
  (ví dụ cổng 8080) và gọi health check vào đúng cổng đó → không ai lắng nghe ở
  cổng platform mong đợi.
- **Cách sửa:** cho app đọc `$PORT` do platform cấp thay vì hardcode 8000. Trong
  `Dockerfile` tôi đã dùng `CMD ["sh","-c","uvicorn app.main:app --host 0.0.0.0
  --port ${PORT:-8000}"]` và trong `config.py` có trường `port`. Sau khi bind
  đúng `$PORT`, health check `/health` trả 200 và deploy chuyển sang trạng thái
  healthy.

(Các lỗi hay gặp khác để đối chiếu: quên set `AGENT_API_KEY` → app crash lúc
khởi động; `REDIS_URL` trỏ sai/không tạo Redis add-on → `/ready` trả 503.)
