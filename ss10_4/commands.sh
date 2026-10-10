#!/usr/bin/env bash
# ==============================================================================
# Bài 4: Thiết lập Custom Network & Named Volume bằng Docker CLI
# Script tự động hóa toàn bộ quy trình thiết lập, kiểm tra DNS và Data Persistence
# ==============================================================================

set -e

echo "=========================================================="
echo ">>> [BƯỚC 1]: Dọn dẹp tài nguyên cũ (nếu có)"
echo "=========================================================="
docker rm -f db-server app-container 2>/dev/null || true
docker network rm app-net 2>/dev/null || true
# Lưu ý: Không xóa db-data nếu muốn giữ volume cũ; xóa ở đây để khởi tạo môi trường sạch cho lần test đầu tiên
docker volume rm db-data 2>/dev/null || true

echo ""
echo "=========================================================="
echo ">>> [BƯỚC 2]: Tạo Custom Bridge Network tên 'app-net'"
echo "=========================================================="
docker network create --driver bridge app-net
echo "-> Danh sách network (lọc app-net):"
docker network ls | grep app-net

echo ""
echo "=========================================================="
echo ">>> [BƯỚC 3]: Tạo Named Volume tên 'db-data'"
echo "=========================================================="
docker volume create db-data
echo "-> Danh sách volume (lọc db-data):"
docker volume ls | grep db-data

echo ""
echo "=========================================================="
echo ">>> [BƯỚC 4]: Khởi chạy Database Container (PostgreSQL 15)"
echo "    - Tên container : db-server"
echo "    - Network        : app-net"
echo "    - Mount volume   : db-data -> /var/lib/postgresql/data"
echo "=========================================================="
docker run -d \
  --name db-server \
  --network app-net \
  -v db-data:/var/lib/postgresql/data \
  -e POSTGRES_DB=mydb \
  -e POSTGRES_USER=myuser \
  -e POSTGRES_PASSWORD=mypassword \
  postgres:15-alpine

echo "-> Chờ PostgreSQL khởi động hoàn tất..."
until docker exec db-server pg_isready -U myuser -d mydb >/dev/null 2>&1; do
  echo "   Đang đợi PostgreSQL sẵn sàng..."
  sleep 2
done
echo "-> PostgreSQL đã sẵn sàng nhận kết nối!"

echo ""
echo "=========================================================="
echo ">>> [BƯỚC 5]: Build và khởi chạy Backend Container"
echo "    - Tên container : app-container"
echo "    - Network        : app-net"
echo "    - Port           : 8080:3000"
echo "    - Hostname DB    : db-server"
echo "=========================================================="
# Build image nếu có Dockerfile tại thư mục hiện tại, hoặc dùng image hw-backend:v1
if [ -f "Dockerfile" ]; then
  docker build -t hw-backend:v1 .
fi

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

echo "-> Danh sách containers đang chạy:"
docker ps

echo ""
echo "=========================================================="
echo ">>> [BƯỚC 6]: Kiểm tra mạng và DNS Resolution nội bộ"
echo "=========================================================="
echo "-> 6.1. Inspect network app-net:"
docker network inspect app-net

echo ""
echo "-> 6.2. Ping từ app-container sang db-server qua hostname (DNS):"
docker exec -i app-container ping -c 2 db-server

echo ""
echo "=========================================================="
echo ">>> [BƯỚC 7]: KIỂM TRA TÍNH BỀN VỮNG DỮ LIỆU (DATA PERSISTENCE)"
echo "=========================================================="
echo "-> 7.1. Tạo bảng 'users' và thêm dữ liệu mẫu vào PostgreSQL:"
docker exec -i db-server psql -U myuser -d mydb << 'EOF'
CREATE TABLE IF NOT EXISTS users (
  id SERIAL PRIMARY KEY,
  username VARCHAR(50) NOT NULL,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
INSERT INTO users (username) VALUES ('higa_devops'), ('docker_persisted_user');
EOF

echo "-> 7.2. Kiểm tra dữ liệu TRƯỚC KHI xóa container:"
docker exec -i db-server psql -U myuser -d mydb -c "SELECT * FROM users;"

echo ""
echo "-> 7.3. XÓA CỨNG CONTAINER DB (docker rm -f db-server)..."
docker rm -f db-server

echo "-> Kiểm tra container sau khi xóa (phải không còn db-server):"
docker ps -a | grep db-server || echo "   Xác nhận: db-server đã bị xóa thành công!"

echo ""
echo "-> 7.4. Khởi chạy lại container DB MỚI gắn cùng Named Volume db-data:"
docker run -d \
  --name db-server \
  --network app-net \
  -v db-data:/var/lib/postgresql/data \
  -e POSTGRES_DB=mydb \
  -e POSTGRES_USER=myuser \
  -e POSTGRES_PASSWORD=mypassword \
  postgres:15-alpine

echo "-> Chờ PostgreSQL container mới khởi động..."
until docker exec db-server pg_isready -U myuser -d mydb >/dev/null 2>&1; do
  echo "   Đang đợi PostgreSQL container mới sẵn sàng..."
  sleep 2
done

echo ""
echo "-> 7.5. XÁC MINH DỮ LIỆU TRÊN CONTAINER MỚI (phải còn nguyên):"
docker exec -i db-server psql -U myuser -d mydb -c "SELECT * FROM users;"

echo ""
echo "=========================================================="
echo ">>> HOÀN THÀNH TẤT CẢ CÁC BƯỚC BÀI 4 THÀNH CÔNG RỰC RỠ! <<<"
echo "=========================================================="
