# SYKids — Bộ Cài Đặt Nhanh Thiết Bị Đầu Cuối (Windows & Xubuntu)

Kho lưu trữ này chỉ chứa các script khởi chạy dòng lệnh (`0% -> 100%`) dành riêng cho quản trị viên / phụ huynh triển khai nhanh **SYKids Endpoint Agent** thông qua **Mã vé cài đặt 1 lần (`<MA_VE_1_LAN>`)** cấp từ Dashboard.  
*(Phiên bản bộ cài giao diện đồ họa `.exe` đầy đủ được cung cấp riêng trực tiếp trên Dashboard).*

---

## 1. Lấy Mã Vé Cài Đặt 1 Lần (`<MA_VE_1_LAN>`)

- **Bước 1:** Đăng nhập vào **SYKids Dashboard** bằng tài khoản quản trị viên / phụ huynh.
- **Bước 2:** Tạo **Mã vé cài đặt 1 lần** mới *(mỗi vé chỉ kích hoạt duy nhất 01 thiết bị và tự hủy ngay sau khi cài xong để chống nhân bản ID)*.
- **Bước 3:** Sao chép mã vé vừa tạo và thay thế vào vị trí `<MA_VE_1_LAN>` trong câu lệnh tương ứng bên dưới.

---

## 2. Lệnh Copy Nhanh Trên Windows (`Win + R` / `CMD` / `PowerShell`)

- **Chạy từ `CMD` hoặc hộp thoại `Win + R`** *(tải script chuẩn về `%TEMP%` bằng `curl.exe` chính chủ Windows, hiển thị thanh tiến trình `0% -> 100%` và xác nhận quyền UAC chuẩn)*:

```cmd
cmd /c "curl.exe -fsSL https://raw.githubusercontent.com/cosyzzz/sykids-setup/main/setup-windows.ps1 -o "%TEMP%\sykids-setup.ps1" && powershell -NoProfile -ExecutionPolicy Bypass -File "%TEMP%\sykids-setup.ps1" <MA_VE_1_LAN>"
```

- **Chạy trực tiếp trong cửa sổ `PowerShell`**:

```powershell
curl.exe -fsSL https://raw.githubusercontent.com/cosyzzz/sykids-setup/main/setup-windows.ps1 -o "$env:TEMP\sykids-setup.ps1"; powershell -NoProfile -ExecutionPolicy Bypass -File "$env:TEMP\sykids-setup.ps1" "<MA_VE_1_LAN>"
```

---

## 3. Lệnh Copy Nhanh Trên Xubuntu / Ubuntu Linux (`Ctrl + Alt + T`)

- Mở Terminal (`Ctrl + Alt + T`), dán câu lệnh 1 dòng *(hiển thị thanh tiến trình `0% -> 100%` và tự động đăng ký `cp-client.service`)*:

```bash
curl -fsSL https://raw.githubusercontent.com/cosyzzz/sykids-setup/main/setup-xubuntu.sh | sudo bash -s -- <MA_VE_1_LAN>
```

- *(Hoặc dùng `wget` nếu máy chưa cài sẵn `curl`)*:

```bash
wget -qO- https://raw.githubusercontent.com/cosyzzz/sykids-setup/main/setup-xubuntu.sh | sudo bash -s -- <MA_VE_1_LAN>
```

- **Chế độ xem log chi tiết (`--verbose`)**:

```bash
curl -fsSL https://raw.githubusercontent.com/cosyzzz/sykids-setup/main/setup-xubuntu.sh | sudo bash -s -- <MA_VE_1_LAN> --verbose
```

---

## 4. Tùy Chọn Máy Chủ Riêng & Xử Lý Lỗi Thường Gặp

### Chỉ Định Máy Chủ Tùy Chỉnh (Đổi Tên Miền Riêng)

Mặc định script kết nối tới máy chủ `https://sykids.tail983a96.ts.net`. Khi triển khai trên tên miền riêng, truyền thêm tham số `-Server` (Windows) hoặc `--server` (Linux):

- **Windows (`PowerShell`):**

```powershell
curl.exe -fsSL https://raw.githubusercontent.com/cosyzzz/sykids-setup/main/setup-windows.ps1 -o "$env:TEMP\sykids-setup.ps1"; powershell -NoProfile -ExecutionPolicy Bypass -File "$env:TEMP\sykids-setup.ps1" "<MA_VE_1_LAN>" -Server "https://ten-mien-rieng.example.com"
```

- **Xubuntu / Ubuntu Linux:**

```bash
curl -fsSL https://raw.githubusercontent.com/cosyzzz/sykids-setup/main/setup-xubuntu.sh | sudo bash -s -- <MA_VE_1_LAN> --server "https://ten-mien-rieng.example.com"
```

### Bảng Mã Lỗi Cài Đặt Thường Gặp

| Mã Lỗi / Hiện Tượng | Nguyên Nhân | Cách Xử Lý |
| :--- | :--- | :--- |
| **`HTTP 401` / `HTTP 403`** | Mã vé cài đặt bị nhập sai hoặc **đã được sử dụng trước đó** (vé tự hủy sau lần kích hoạt đầu tiên). | Tạo mã vé cài đặt 1 lần mới trên Dashboard và chạy lại lệnh. |
| **`HTTP 410`** | Mã vé **đã hết hạn 48 giờ** kể từ thời điểm khởi tạo mà chưa kích hoạt. | Tạo mã vé cài đặt 1 lần mới trên Dashboard và chạy lại lệnh. |
| **Lỗi kết nối TLS / HTTPS** | Máy đầu cuối mất kết nối mạng hoặc sai lệch ngày giờ hệ thống làm lỗi xác thực chứng chỉ SSL. | Đồng bộ lại ngày giờ tự động của hệ điều hành và kiểm tra kết nối Internet (`443/tcp`). |

### Kiểm Tra Trạng Thái Dịch Vụ Sau Khi Cài Đặt

- **Trên Windows (`CMD` / `PowerShell`):**

```cmd
sc query SYKidsService
```

```powershell
Get-Service SYKidsService
```

- **Trên Xubuntu / Ubuntu Linux:**

```bash
sudo systemctl status cp-client.service
```
