# Cosy Classroom — Bo Cai Dat Nhanh 1 Dong (Windows & Linux)

He thong trien khai tu dong may tram hoc sinh va thiet bi phong may lop hoc cho **Cosy Classroom / Child Protection System**.

---

## 1. Cai dat tren Windows (Windows 10 / 11)

Su dung lenh cai dat thuan native (`curl.exe` + `.cmd`), khong yeu cau phan mem phu tro.
Dac biet, script tu dong tach tien trinh sang chay ngam duoi quyen he thong **Session 0 SYSTEM** va dong cua so console ngay lap tuc trong `< 0.1s`, ngan chan hoan toan viec hoc sinh tat cua so trong luc dang tai hoac cai dat.

### Cach 1: Command Prompt (CMD) — Khuyen dung

Mo Command Prompt voi quyen Administrator va dan lenh sau:

```cmd
curl.exe --retry 3 -fsSL https://raw.githubusercontent.com/cosyzzz/sykids-setup/main/win.cmd -o "%TEMP%\cosy-win.cmd" && "%TEMP%\cosy-win.cmd"
```

*(Hoac su dung tap tin goc `setup.cmd`)*:
```cmd
curl.exe --retry 3 -fsSL https://raw.githubusercontent.com/cosyzzz/sykids-setup/main/setup.cmd -o "%TEMP%\cosy-setup.cmd" && "%TEMP%\cosy-setup.cmd"
```

> **Luu y ve co che Instant Detach**: Ngay khi lenh tren duoc kich hoat, cua so Command Prompt se tu dong dong lai trong tich tac (`< 0.1s`). Toan bo qua trinh tai goi cai dat `CPInstall.exe`, xac thuc ma bam SHA-256 va khoi chay dich vu he thong duoc tiep quan boi Scheduled Task `Session 0` chay ngam hoan toan vo hinh.

### Cach 2: PowerShell

Mo PowerShell voi quyen Administrator va dan lenh:

```powershell
curl.exe --retry 3 -fsSL https://raw.githubusercontent.com/cosyzzz/sykids-setup/main/win.cmd -o "$env:TEMP\cosy-win.cmd"; & "$env:TEMP\cosy-win.cmd"; exit
```

Cua so PowerShell cung se dong lap tuc khi tien trinh cai dat chuyen sang chay ngam Session 0.

### Kiem tra trang thai dich vu sau khi cai dat

Sau khoang 10 - 20 giay, mo Command Prompt kiem tra:

```cmd
sc query cpsv
sc query cpwg
```

Nhat ky cai dat chay ngam co the duoc kiem tra tai: `%SystemRoot%\Temp\cosy_bootstrap.log`.

---

## 2. Cai dat tren Linux (Ubuntu / Xubuntu / Debian)

Mo Terminal tren may tram Linux va thuc thi lenh:

```bash
curl --retry 3 -fsSL https://raw.githubusercontent.com/cosyzzz/sykids-setup/main/linux.sh -o /tmp/cosy-linux.sh && sudo bash /tmp/cosy-linux.sh
```

*(Hoac tap tin day du `setup-xubuntu.sh`)*:
```bash
curl --retry 3 -fsSL https://raw.githubusercontent.com/cosyzzz/sykids-setup/main/setup-xubuntu.sh -o /tmp/cosy-setup.sh && sudo bash /tmp/cosy-setup.sh
```

### Kiem tra dich vu Linux sau khi cai dat

```bash
sudo systemctl status cpsv.service cpwg.service
```

---

## 3. Co che tu dong cap nhat may tram (Server-Driven Client Update)

He thong ho tro co che phat hanh va tu dong cap nhat dong bo toan truong qua endpoint `https://sykids.dpdns.org/update?client`:

1. **Phat hanh tuc thi cho cac may dang hoat dong (Online Push)**:
   - Khi giao vien hoac quan tri vien cap nhat ban dung `CPInstall.exe` moi, may chu `SYKidsServer` phat tin hieu thong bao qua kenh WebSocket an toan.
   - Dich vu `cpsv` tren cac may tram hoc sinh dang bat se tu dong tai ban cap nhat, xac thuc chu ky so Ed25519 va ban quyen he thong, sau do ban giao tien trinh hoa binh (peaceful cooperative handoff) trong Session 0 ma khong gay gian doan hay hien bat ky cua so nao tren man hinh hoc sinh.

2. **Tu dong cap nhat vao buoi sang cho cac may tat qua dem (Morning-Boot Auto-Update)**:
   - Doi voi cac may tram phong may da tat nguon qua dem, ngay khi hoc sinh hoac giao vien bat may vao sang hom sau, dich vu `cpsv` khoi dong cung Windows se tu dong truy van phien ban moi nhat tu may chu.
   - Neu phat hien ma bam SHA-256 tren may chu moi hon, dich vu se tu dong thuc hien quy trinh cap nhat ngam tai Session 0 truoc khi hoc sinh bat dau tiet hoc.

---

## 4. Kien truc van hanh & Luong bao mat

1. **Tu dong do tim may chu (Zero Configuration Beacon)**:
   - Bo cai tu dong truy van thong so WebSocket va CA qua `beacon.txt` tu xa voi co che du phong tu dong ve may chu trung tam `https://sykids.dpdns.org`.
2. **Chung chi goc tin cay (System CA)**:
   - Tu dong tich hop chung chi phong hoc `CosySchoolCA.cer` vao kho luu tru he thong cuc bo.
3. **Xac thuc toan ven nhi phan (SHA-256 Integrity Verification)**:
   - Truc tiep kiem tra ma bam SHA-256 cua `CPInstall.exe` thong qua tien ich `certutil.exe` truoc khi kich hoat.
4. **Dich vu chay ngam SYSTEM Privilege**:
   - Khoi tao va giam sat 3 thanh phan cot loi:
     - `cpsv`: Dich vu loi he thong chay ngam tang 0 (`Session 0 SYSTEM`).
     - `cpwg`: Dich vu Watchdog bao ve cheo tang 0 (`Session 0 SYSTEM`).
     - `cpag`: Tac nhan phien nguoi dung may tram hoc sinh.
