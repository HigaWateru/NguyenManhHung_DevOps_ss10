# Bài 5: Tự động hóa điều phối đa dịch vụ với Docker Compose & File .env

## 1. Mục tiêu
- **Infrastructure as Code (IaC)**: Định nghĩa toàn bộ hạ tầng đa container (Web API Backend + PostgreSQL Database) qua tệp `docker-compose.yml`.
- **Bảo mật và cấu hình môi trường**: Tách biệt toàn bộ tham số nhạy cảm (DB name, credentials, port) vào tệp `.env`, cung cấp tệp mẫu `.env.example` và đưa `.env` vào `.gitignore` để tránh rò rỉ secret lên Git.
- **Tự động hóa điều phối (Orchestration)**: Sử dụng Docker Compose CLI v2 (`docker compose`) để quản lý vòng đời ứng dụng một cách nhất quán.

---

## 2. Cấu trúc thư mục
```text
ss10_5/
├── docker-compose.yml  # Bản thiết kế hạ tầng đa dịch vụ (backend + database)
├── .env                # Chứa giá trị cấu hình thực tế và thông tin nhạy cảm (không commit)
├── .env.example        # Bản mẫu cấu hình cho các thành viên trong nhóm / môi trường CI/CD
├── .gitignore          # Bỏ qua tệp .env và node_modules khi đưa lên Git
├── Dockerfile          # Đóng gói service backend
├── package.json        # Định nghĩa dependencies cho backend
├── server.js           # Mã nguồn backend nhận cấu hình từ biến môi trường
├── .dockerignore       # Bỏ qua file rác khi build image
└── README.md           # Hướng dẫn chi tiết triển khai và kiểm thử
```

---

## 3. Chi tiết cấu hình Docker Compose v2

### 3.1. Tệp `docker-compose.yml`
```yaml
services:
  database:
    image: postgres:15-alpine
    environment:
      POSTGRES_DB: ${DB_NAME}
      POSTGRES_USER: ${DB_USER}
      POSTGRES_PASSWORD: ${DB_PASSWORD}
    volumes:
      - pgdata:/var/lib/postgresql/data
    networks:
      - backend-net

  backend:
    build: .
    ports:
      - "${PORT}:8080"
    environment:
      PORT: 8080
      DB_HOST: database
      DB_NAME: ${DB_NAME}
      DB_USER: ${DB_USER}
      DB_PASSWORD: ${DB_PASSWORD}
    depends_on:
      - database
    networks:
      - backend-net

volumes:
  pgdata:

networks:
  backend-net:
```

### 3.2. Quản lý biến môi trường với `.env`
Tệp `.env` được Docker Compose tự động nạp khi khởi chạy:
```env
# Port ánh xạ trên Host machine
PORT=8080

# Cấu hình Database PostgreSQL
DB_NAME=mydb
DB_USER=myuser
DB_PASSWORD=mypassword_secret123
```

Tệp `.env.example` dùng để chia sẻ mẫu cấu hình an toàn:
```env
# Port ánh xạ trên Host machine
PORT=8080

# Cấu hình Database PostgreSQL
DB_NAME=mydb
DB_USER=myuser
DB_PASSWORD=your_secure_password_here
```

Tệp `.gitignore`:
```gitignore
.env
node_modules/
```

---

## 4. Hướng dẫn vận hành với Docker Compose CLI v2

### Bước 1: Khởi tạo tệp `.env` từ `.env.example` (nếu chưa có)
```bash
cp .env.example .env
# Chỉnh sửa mật khẩu hoặc giữ mặc định
```

### Bước 2: Khởi chạy toàn bộ hệ thống
Khởi chạy dịch vụ ở chế độ detached (`-d`), Docker Compose sẽ tự động:
1. Tạo bridge network `backend-net`
2. Tạo volume `pgdata`
3. Build image cho service `backend`
4. Khởi chạy service `database` trước, sau đó khởi chạy `backend` (theo `depends_on`)

```bash
docker compose up -d --build
```

### Bước 3: Kiểm tra trạng thái các dịch vụ
```bash
docker compose ps
```
**Kết quả mong đợi:** Cả 2 service đều ở trạng thái `running` (hoặc `Up`):
```text
NAME                IMAGE                COMMAND                  SERVICE    CREATED          STATUS          PORTS
ss10_5-backend-1    ss10_5-backend       "docker-entrypoint.s…"   backend    10 seconds ago   Up 9 seconds    0.0.0.0:8080->8080/tcp
ss10_5-database-1   postgres:15-alpine   "docker-entrypoint.s…"   database   10 seconds ago   Up 10 seconds   5432/tcp
```

### Bước 4: Xem log dịch vụ realtime
```bash
docker compose logs -f
```
*(Nhấn `Ctrl + C` để thoát màn hình xem log)*

### Bước 5: Kiểm tra kết nối API qua HTTP
```bash
curl -i http://localhost:8080/
```
**Kết quả mong đợi:**
```http
HTTP/1.1 200 OK
Content-Type: application/json; charset=utf-8

{
  "status": "success",
  "message": "Hello from Multi-service Docker Compose Backend!",
  "service": "backend",
  "database_info": {
    "host": "database",
    "database": "mydb",
    "user": "myuser"
  }
}
```

Kiểm tra health endpoint:
```bash
curl http://localhost:8080/health
```

---

## 5. Dừng và dọn dẹp hệ thống (Clean up)

### Dừng và xóa containers, networks (giữ lại volumes dữ liệu):
```bash
docker compose down
```

### Dừng và xóa toàn bộ containers, networks và volumes (nếu muốn reset sạch sẽ):
```bash
docker compose down -v
```
