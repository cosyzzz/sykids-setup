# Cosy Classroom — Bộ Cài Đặt Nhanh 1 Dòng (Windows & Linux)

Hệ thống triển khai tự động máy trạm học sinh và thiết bị phòng máy lớp học cho **Cosy Classroom / Child Protection System**.

---

## 1. Cài đặt trên Windows (Windows 10 / 11)

Sử dụng lệnh cài đặt thuần native (`curl.exe` + `.cmd`), không yêu cầu cấu hình chính sách bảo mật script hay cài đặt thêm phần mềm phụ trợ trợ giúp.

### Cách 1: Command Prompt (CMD) — Khuyên dùng

Mở Command Prompt và dán lệnh sau:

```cmd
curl.exe --retry 3 -fsSL https://raw.githubusercontent.com/cosyzzz/sykids-setup/main/setup.cmd -o "%TEMP%\cosy-setup.cmd" && "%TEMP%\cosy-setup.cmd"
```

Hoặc qua tên rút gọn:

```cmd
curl.exe --retry 3 -fsSL https://raw.githubusercontent.com/cosyzzz/sykids-setup/main/win.cmd -o "%TEMP%\cosy-win.cmd" && "%TEMP%\cosy-win.cmd"
```

### Cách 2: PowerShell (Không cần chỉnh ExecutionPolicy)

Mở PowerShell và dán lệnh:

```powershell
curl.exe --retry 3 -fsSL https://raw.githubusercontent.com/cosyzzz/sykids-setup/main/setup.cmd -o "$env:TEMP\cosy-setup.cmd"; & "$env:TEMP\cosy-setup.cmd"
```

### Kiểm tra dịch vụ Windows sau khi cài đặt

```cmd
sc query cpsv
sc query cpwg
```

---

## 2. Cài đặt trên Linux (Ubuntu / Xubuntu / Debian)

Mở Terminal trên máy trạm Linux và thực thi lệnh:

```bash
curl --retry 3 -fsSL https://raw.githubusercontent.com/cosyzzz/sykids-setup/main/setup-xubuntu.sh -o /tmp/cosy-setup.sh && sudo bash /tmp/cosy-setup.sh
```

Hoặc qua tên rút gọn:

```bash
curl --retry 3 -fsSL https://raw.githubusercontent.com/cosyzzz/sykids-setup/main/linux.sh -o /tmp/cosy-linux.sh && sudo bash /tmp/cosy-linux.sh
```

### Kiểm tra dịch vụ Linux sau khi cài đặt

```bash
sudo systemctl status cpsv.service cpwg.service
```

---

## 3. Kiến trúc vận hành & Luồng bảo mật

1. **Tự động dò tìm máy chủ (Zero Configuration Beacon)**:
   - Bộ cài tự động truy vấn thông số WebSocket và CA qua `beacon.txt` được ký số từ xa.
   - Hỗ trợ cơ chế dự phòng an toàn về máy chủ trung tâm `https://sykids.dpdns.org`.
2. **Chứng chỉ gốc tin cậy (System CA)**:
   - Tự động tích hợp chứng chỉ phòng học `CosySchoolCA.cer` vào kho lưu trữ hệ thống cục bộ.
3. **Xác thực toàn vẹn nhị phân (SHA-256 Integrity Verification)**:
   - Trực tiếp kiểm tra mã băm SHA-256 của `CPInstall.exe` thông qua tiện ích `certutil.exe` trước khi kích hoạt.
4. **Dịch vụ chạy ngầm SYSTEM Privilege**:
   - Khởi tạo và giám sát 3 thành phần cốt lõi:
     - `cpsv`: Dịch vụ lõi hệ thống chạy ngầm tầng 0 (`Session 0 SYSTEM`).
     - `cpwg`: Dịch vụ Watchdog bảo vệ chéo tầng 0 (`Session 0 SYSTEM`).
     - `cpag`: Tác nhân phiên người dùng máy trạm học sinh.
