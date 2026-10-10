# Bài 4: Thiết lập Custom Network & Named Volume bằng Docker CLI

## 1. Mục tiêu
- **Custom Bridge Network**: Tạo mạng Bridge tùy biến (`app-net`) để kích hoạt cơ chế Docker Embedded DNS, cho phép các container giao tiếp nội bộ thông qua tên service/container name thay vì IP tĩnh dễ thay đổi.
- **Named Volume**: Tạo và gắn Named Volume (`db-data`) vào thư mục dữ liệu PostgreSQL (`/var/lib/postgresql/data`) nhằm đảm bảo tính bền vững của dữ liệu (Data Persistence) qua nhiều vòng đời container.

---

## 2. Cấu trúc thư mục
```text
ss10_4/
├── commands.sh         # Script tự động hóa toàn bộ các bước thiết lập và kiểm thử
├── Dockerfile          # Đóng gói backend container
├── package.json        # Định nghĩa dependencies cho backend
├── server.js           # Mã nguồn backend nhận biến kết nối DB
├── .dockerignore       # Bỏ qua node_modules, log, script khi build image
└── README.md           # Hướng dẫn chi tiết lý thuyết và các bước thực hành
```

---

## 3. Lý thuyết cốt lõi

### 3.1. Default Bridge vs Custom Bridge Network
- **Default Bridge Network** (mặc định của Docker): Không hỗ trợ tự động phân giải DNS bằng tên container (phải dùng option `--link` vốn đã bị deprecated).
- **Custom Bridge Network** (`docker network create`): Tự động tích hợp DNS server nội bộ của Docker (127.0.0.11), cho phép phân giải IP từ tên container (`db-server` -> IP nội bộ của container đó trong mạng).

### 3.2. Container Ephemeral Storage vs Named Volume
- Mặc định, tầng writable layer của container sẽ biến mất khi container bị `docker rm`.
- **Named Volume** được Docker quản lý tại host filesystem (thường tại `/var/lib/docker/volumes/`), tồn tại độc lập hoàn toàn với vòng đời của container. Khi container cũ bị xóa và container mới mount cùng volume, toàn bộ database schema và dữ liệu được bảo toàn.

---

## 4. Hướng dẫn chạy nhanh bằng Script
Cấp quyền thực thi và chạy file script:
```bash
chmod +x commands.sh
./commands.sh
```

---

## 5. Hướng dẫn thực hiện từng bước bằng Docker CLI thủ công

### Bước 1: Tạo Custom Bridge Network
```bash
docker network create --driver bridge app-net
```
*Kiểm tra:*
```bash
docker network ls | grep app-net
```

### Bước 2: Tạo Named Volume
```bash
docker volume create db-data
```
*Kiểm tra:*
```bash
docker volume ls | grep db-data
```

### Bước 3: Khởi chạy Database Container
Chạy container PostgreSQL 15, tham gia mạng `app-net` và mount volume `db-data`:
```bash
docker run -d \
  --name db-server \
  --network app-net \
  -v db-data:/var/lib/postgresql/data \
  -e POSTGRES_DB=mydb \
  -e POSTGRES_USER=myuser \
  -e POSTGRES_PASSWORD=mypassword \
  postgres:15-alpine
```

### Bước 4: Khởi chạy Backend Container
Build backend image và chạy container tham gia mạng `app-net`:
```bash
docker build -t hw-backend:v1 .
docker run -d \
  --name app-container \
  --network app-net \
  -p 8080:3000 \
  -e DB_HOST=db-server \
  -e DB_PORT=5432 \
  -e DB_NAME=mydb \
  -e DB_USER=myuser \
  -e DB_PASSWORD=mypassword \
  hw-backend:v1
```

### Bước 5: Kiểm tra Network và DNS Resolution
Kiểm tra cấu hình IP trong mạng:
```bash
docker network inspect app-net
```
Thực hiện ping từ `app-container` sang `db-server`:
```bash
docker exec -it app-container ping -c 2 db-server
```
**Kết quả mong đợi:** Lệnh ping giải mã thành công IP của `db-server` (ví dụ `172.18.0.2`), nhận đủ 2 packets phản hồi:
```text
PING db-server (172.18.0.2): 56 data bytes
64 bytes from 172.18.0.2: seq=0 ttl=64 time=0.158 ms
64 bytes from 172.18.0.2: seq=1 ttl=64 time=0.089 ms
```

---

## 6. Kiểm thử tính bền vững của dữ liệu (Data Persistence Test)

### 6.1. Thêm dữ liệu mẫu vào DB ban đầu
```bash
docker exec -i db-server psql -U myuser -d mydb << 'EOF'
CREATE TABLE users (id SERIAL PRIMARY KEY, name VARCHAR(50));
INSERT INTO users (name) VALUES ('Higa'), ('DevOps_Master');
EOF
```
Kiểm tra dữ liệu:
```bash
docker exec -i db-server psql -U myuser -d mydb -c "SELECT * FROM users;"
```
*Kết quả:*
```text
 id |     name      
----+---------------
  1 | Higa
  2 | DevOps_Master
(2 rows)
```

### 6.2. Xóa cứng container Database
```bash
docker rm -f db-server
```
Xác nhận container không còn tồn tại:
```bash
docker ps -a | grep db-server
```

### 6.3. Khởi chạy lại container DB mới gắn cùng Volume `db-data`
```bash
docker run -d \
  --name db-server \
  --network app-net \
  -v db-data:/var/lib/postgresql/data \
  -e POSTGRES_DB=mydb \
  -e POSTGRES_USER=myuser \
  -e POSTGRES_PASSWORD=mypassword \
  postgres:15-alpine
```

### 6.4. Xác minh dữ liệu không bị mất
Chờ 3 giây để PostgreSQL khởi động, sau đó truy vấn lại:
```bash
docker exec -i db-server psql -U myuser -d mydb -c "SELECT * FROM users;"
```
**Kết quả mong đợi:** Bảng `users` cùng toàn bộ 2 bản ghi vẫn nguyên vẹn 100%:
```text
 id |     name      
----+---------------
  1 | Higa
  2 | DevOps_Master
(2 rows)
```

---

## 7. Dọn dẹp tài nguyên (Clean up)
```bash
docker rm -f db-server app-container
docker network rm app-net
docker volume rm db-data
```
