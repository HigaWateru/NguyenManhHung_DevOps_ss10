# Bài 2: Đóng gói ứng dụng Web Backend bằng Single-stage Dockerfile

## 1. Mục tiêu
Xây dựng tệp `Dockerfile` Single-stage chuẩn hóa nhằm đóng gói ứng dụng Web API Node.js/Express thành một Docker Image gọn nhẹ, sẵn sàng triển khai trên môi trường thử nghiệm và sản xuất.

---

## 2. Cấu trúc thư mục
```text
ss10_2/
├── Dockerfile          # Định nghĩa quá trình đóng gói Docker image
├── .dockerignore       # Loại trừ các file không cần thiết khi build image
├── package.json        # Định nghĩa dependencies và script khởi chạy
├── server.js           # Mã nguồn Node.js / Express Web API
└── README.md           # Hướng dẫn chi tiết cách build, chạy và kiểm tra
```

---

## 3. Chi tiết Dockerfile Single-stage
Dockerfile được tối ưu hóa theo best practice với cơ chế **Layer Caching**:
```dockerfile
# 1. Base Image: Sử dụng node:18-alpine nhẹ, tối ưu tài nguyên và bảo mật
FROM node:18-alpine

# 2. WORKDIR: Thiết lập thư mục làm việc chính trong container
WORKDIR /app

# 3. ENV: Khai báo biến môi trường PORT mặc định là 3000
ENV PORT=3000

# 4. COPY: Copy file định nghĩa package để tận dụng Docker layer caching
COPY package*.json ./

# 5. RUN: Cài đặt các dependencies cần thiết
RUN npm install

# 6. COPY: Copy toàn bộ mã nguồn còn lại vào container
COPY . .

# 7. EXPOSE: Khai báo cổng 3000 để container lắng nghe
EXPOSE 3000

# 8. CMD: Lệnh thực thi khởi chạy ứng dụng (sử dụng exec form)
CMD ["node", "server.js"]
```

### Giải thích các chỉ thị:
- `FROM node:18-alpine`: Sử dụng base image phiên bản Node.js 18 trên nền tảng Alpine Linux siêu nhẹ (~170MB so với ~1GB của image đầy đủ), giảm thiểu attack surface.
- `WORKDIR /app`: Mọi chỉ thị tiếp theo (`COPY`, `RUN`, `CMD`) đều thực thi trong `/app`.
- `ENV PORT=3000`: Đặt biến môi trường `PORT` để ứng dụng Node.js đọc qua `process.env.PORT`.
- `COPY package*.json ./` & `RUN npm install`: Đưa bước cài đặt thư viện lên trước khi copy toàn bộ mã nguồn. Khi mã nguồn thay đổi nhưng `package.json` không đổi, Docker sẽ tái sử dụng cache của layer `RUN npm install`, giúp tăng tốc độ build đáng kể.
- `COPY . .`: Sao chép toàn bộ mã nguồn vào image (ngoại trừ các file trong `.dockerignore`).
- `EXPOSE 3000`: Metadata thông báo container lắng nghe tại cổng 3000.
- `CMD ["node", "server.js"]`: Exec form (dạng JSON array) giúp tiến trình `node` chạy trực tiếp với PID 1, nhận tín hiệu OS signals (`SIGTERM`, `SIGINT`) chuẩn xác để graceful shutdown.

---

## 4. Hướng dẫn Build và Kiểm tra

### Bước 1: Build Docker Image
Chạy lệnh sau tại thư mục chứa `Dockerfile`:
```bash
docker build -t hw-backend:v1 .
```

### Bước 2: Khởi chạy Container
Chạy container ở chế độ nền (detached), đặt tên container là `app-single-stage` và ánh xạ port `8080:3000`:
```bash
docker run -d --name app-single-stage -p 8080:3000 hw-backend:v1
```

### Bước 3: Kiểm tra trạng thái Container
```bash
docker ps
```
**Kết quả mong đợi:** Container có tên `app-single-stage` ở trạng thái `Up`, cổng `0.0.0.0:8080->3000/tcp`.

### Bước 4: Kiểm tra log của Container
```bash
docker logs app-single-stage
```
**Kết quả mong đợi:**
```text
Server listening on port 3000
```

### Bước 5: Kiểm tra phản hồi HTTP từ API
```bash
curl -i http://localhost:8080/
```
**Kết quả mong đợi:** Trả về HTTP Status `200 OK` cùng JSON response:
```http
HTTP/1.1 200 OK
X-Powered-By: Express
Content-Type: application/json; charset=utf-8
Content-Length: 61
ETag: W/"3d-eC/8mZkE/4UfXgJz9wQ9e0"
Date: Sat, 10 Oct 2026 13:40:00 GMT
Connection: keep-alive
Keep-Alive: timeout=5

{"status":"success","message":"Hello from Docker Single-stage!"}
```

---

## 5. Dọn dẹp tài nguyên (Clean up)
Sau khi hoàn thành bài test, dọn dẹp container và image:
```bash
docker stop app-single-stage
docker rm app-single-stage
docker rmi hw-backend:v1
```
