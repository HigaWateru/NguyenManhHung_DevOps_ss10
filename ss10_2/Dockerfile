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
