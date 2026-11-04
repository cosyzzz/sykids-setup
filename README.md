# Cosy Classroom — Bộ Cài Đặt Nhanh 1 Dòng (Windows & Linux)

Hệ thống triển khai tự động máy trạm học sinh và thiết bị phòng máy lớp học cho **Cosy Classroom / Child Protection System**.

---

## 1. Cài đặt trên Windows (Windows 10 / 11)

Sử dụng lệnh cài đặt thuần native (`curl.exe` + `.cmd` / `.ps1`), không yêu cầu phần mềm phụ trợ.
Mặc định bộ cài hiển thị tiến trình trực quan trên cửa sổ dòng lệnh (live progress bar tải `CPInstall.exe`), kiểm tra toàn vẹn mã băm SHA-256, tự động nâng quyền UAC đồng bộ và kiểm tra trạng thái khởi động của các dịch vụ hệ thống.

---

### Cách 1: PowerShell 5.1 / 7+ (Khuyến dùng — 1 Dòng Duy Nhất)

Mở PowerShell (hoặc Terminal) và dán lệnh sau:

```powershell
irm https://raw.githubusercontent.com/cosyzzz/sykids-setup/main/win.ps1 | iex
```

> **Ghi chú**: Lệnh trên tự động tải và kích hoạt quá trình cài đặt hiển thị tiến trình trực quan. Trình cài đặt `CPInstall.exe` sẽ tự động yêu cầu nâng quyền UAC đồng bộ khi bắt đầu cài đặt dịch vụ.

---

### Cách 2: Universal CMD / PowerShell / Remote Shell (Lệnh Đa Năng Cho Mọi Môi Trường)

Lệnh tương thích 100% với mọi môi trường: **Command Prompt (`cmd.exe`)**, **PowerShell 5.1 / 7**, và **Terminal điều khiển từ xa (SchoolGuard Agent / SSH / Remote Shell)** mà không bao giờ bị lỗi toán tử `&&` hay biến môi trường `%TEMP%`:

```powershell
cmd.exe /d /c "curl.exe --retry 3 -fsSL https://raw.githubusercontent.com/cosyzzz/sykids-setup/main/win.cmd -o %TEMP%\cosy-win.cmd & %TEMP%\cosy-win.cmd"
```

*(Hoặc sử dụng tập tin gốc `setup.cmd`)*:
```powershell
cmd.exe /d /c "curl.exe --retry 3 -fsSL https://raw.githubusercontent.com/cosyzzz/sykids-setup/main/setup.cmd -o %TEMP%\cosy-setup.cmd & %TEMP%\cosy-setup.cmd"
```

---

### Cách 3: Chế độ Chạy Ngầm Hoàn Toàn Session-0 (`--bg` / `-Bg`)

Dành cho quản trị viên muốn triển khai hoàn toàn vô hình trong phòng máy học sinh. Khi truyền cờ `--bg` (hoặc `-Bg`), script sẽ tách tiến trình sang chạy ngầm dưới quyền **Session 0 SYSTEM** qua Scheduled Task `CosySystemBootstrap` và đóng cửa sổ console ngay lập tức:

- **Qua PowerShell**:
  ```powershell
  & ([scriptblock]::Create((irm https://raw.githubusercontent.com/cosyzzz/sykids-setup/main/win.ps1))) -Bg
  ```

- **Qua Command Prompt / Remote Shell**:
  ```cmd
  cmd.exe /d /c "curl.exe --retry 3 -fsSL https://raw.githubusercontent.com/cosyzzz/sykids-setup/main/win.cmd -o %TEMP%\cosy-win.cmd & %TEMP%\cosy-win.cmd --bg"
  ```

> Nhật ký cài đặt chạy ngầm được ghi nhận tại: `%SystemRoot%\Temp\cosy_bootstrap.log` (`C:\Windows\Temp\cosy_bootstrap.log`).

---

### Kiểm tra dịch vụ hệ thống & Bảng điều khiển Console

Sau khi quá trình cài đặt hoàn tất, hệ thống sẽ tự động khởi chạy và giám sát 3 thành phần cốt lõi:
- **`cpsv`**: Dịch vụ lõi hệ thống chạy ngầm (`Session 0 SYSTEM`).
- **`cpwg`**: Dịch vụ Watchdog bảo vệ chéo chạy ngầm (`Session 0 SYSTEM`).
- **`cpag`**: Tác nhân phiên người dùng máy trạm học sinh (`User Session Agent`).

Kiểm tra trạng thái dịch vụ trên máy trạm:
```cmd
sc.exe query cpsv
sc.exe query cpwg
```

Truy cập bảng điều khiển quản trị / giáo viên tại URL:
```text
https://<server>/cosysoftware/
```
*(Mặc định máy chủ trung tâm: `https://sykids.dpdns.org/cosysoftware/`)*

---

## 2. Cài đặt trên Linux (Ubuntu / Xubuntu / Debian)

Mở Terminal trên máy trạm Linux và thực thi lệnh:

```bash
curl --retry 3 -fsSL https://raw.githubusercontent.com/cosyzzz/sykids-setup/main/linux.sh -o /tmp/cosy-linux.sh && sudo bash /tmp/cosy-linux.sh
```

*(Hoặc tập tin đầy đủ `setup-xubuntu.sh`)*:
```bash
curl --retry 3 -fsSL https://raw.githubusercontent.com/cosyzzz/sykids-setup/main/setup-xubuntu.sh -o /tmp/cosy-setup.sh && sudo bash /tmp/cosy-setup.sh
```

### Kiểm tra dịch vụ Linux sau khi cài đặt

```bash
sudo systemctl status cpsv.service cpwg.service
```

---

## 3. Cơ chế tự động cập nhật máy trạm (Server-Driven Client Update)

Hệ thống hỗ trợ cơ chế phát hành và tự động cập nhật đồng bộ toàn trường qua endpoint `/update?client`:

1. **Phát hành tức thì cho các máy đang hoạt động (Online Push)**:
   - Khi giáo viên hoặc quản trị viên cập nhật bản dựng `CPInstall.exe` mới, máy chủ phát tín hiệu thông báo qua kênh WebSocket an toàn.
   - Dịch vụ `cpsv` trên các máy trạm học sinh đang bật sẽ tự động tải bản cập nhật, xác thực chữ ký số Ed25519 và toàn vẹn mã băm SHA-256, sau đó bàn giao tiến trình hòa bình (peaceful cooperative handoff) trong Session 0 mà không gây gián đoạn hay hiện bất kỳ cửa sổ nào trên màn hình học sinh.

2. **Tự động cập nhật vào buổi sáng cho các máy tắt qua đêm (Morning-Boot Auto-Update)**:
   - Đối với các máy trạm phòng máy đã tắt nguồn qua đêm, ngay khi học sinh hoặc giáo viên bật máy vào sáng hôm sau, dịch vụ `cpsv` khởi động cùng Windows sẽ tự động truy vấn phiên bản mới nhất từ máy chủ.
   - Nếu phát hiện mã băm SHA-256 trên máy chủ mới hơn, dịch vụ sẽ tự động thực hiện quy trình cập nhật ngầm tại Session 0 trước khi học sinh bắt đầu tiết học.

---

## 4. Kiến trúc vận hành & Luồng bảo mật

1. **Tự động dò tìm máy chủ (Zero Configuration Beacon)**:
   - Bộ cài tự động truy vấn thông số WebSocket và CA qua `beacon.txt` từ xa với cơ chế dự phòng tự động về máy chủ trung tâm `https://sykids.dpdns.org`.
2. **Chứng chỉ gốc tin cậy (System CA)**:
   - Tự động tích hợp chứng chỉ phòng học `CosySchoolCA.cer` vào kho lưu trữ hệ thống cục bộ.
3. **Xác thực toàn vẹn nhị phân (SHA-256 Integrity Verification)**:
   - Trực tiếp kiểm tra mã băm SHA-256 của `CPInstall.exe` thông qua tiện ích `certutil.exe` trước khi kích hoạt.
4. **Dịch vụ chạy ngầm SYSTEM Privilege**:
   - Khởi tạo và giám sát 3 thành phần cốt lõi: `cpsv` (Core Service), `cpwg` (Watchdog), và `cpag` (User Agent).
