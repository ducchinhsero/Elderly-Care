# Tong ket tinh nang ung dung Elder Health Monitor

Tai lieu nay mo ta cac tinh nang dang co trong Flutter app theo trang thai hien tai cua du an.

## 1. Luong nguoi deo

Nguoi deo la nguoi dung gan Raspberry/Polar H10. App doc du lieu tu backend edge noi bo:

- Base URL mac dinh: `http://elderlycare.local:8000`.
- Co the thay bang IP Raspberry trong Settings.
- Du lieu realtime den tu REST `/latest-result`, WebSocket `/ws/vitals` va MQTT LAN neu moi truong ho tro.

Tinh nang:

- Onboarding chon vai tro, nhap ten, tuoi, nguoi giam ho va ma thiet bi.
- Dashboard hien thi tinh trang hien tai theo ngon ngu de hieu:
  - Tinh trang.
  - Viec nen lam.
  - Thong tin do duoc.
- Hien thi nhan than thien thay cho thuat ngu ky thuat:
  - `AFib` -> dau hieu nhip tim khong deu.
  - `PVC/PAC` -> nhip den som.
  - `RMSSD/HRV` -> muc phuc hoi/cang thang co the.
  - `baseline` -> muc binh thuong cua rieng ban.
- Trang thai ket noi Raspberry/Polar:
  - Raspberry chua ket noi.
  - Raspberry da ket noi, can kiem tra Polar.
  - Raspberry va Polar dang hoat dong.
- Nut khoi dong Polar thu cong trong Settings khi auto-start khong hoat dong.
- Thiet lap Wi-Fi Raspberry bang AP `ElderlyCare-Setup-XXXX` va portal `http://10.42.0.1`.

## 2. Luong nguoi giam sat

Nguoi giam sat theo doi tu xa qua cloud/base URL duoc cau hinh trong build hoac settings noi bo.

Tinh nang:

- Luu caregiver name, target patient id/name va access code.
- Ket noi realtime qua:
  - `/ws/alerts` cho canh bao high/critical.
  - `/ws/vitals` cho sinh hieu.
  - HTTP polling fallback `/alerts/realtime` moi khoang 10 giay.
  - `/events` cho timeline day du.
- Alert Center uu tien canh bao nghiem trong, co trang thai da doc/da kiem tra.
- CTA cho canh bao nghiem trong:
  - `Da kiem tra nguoi dung` -> `POST /alerts/{event_id}/ack`.
  - Resolve -> `POST /alerts/{event_id}/resolve`.
- Dashboard caregiver hien thi nguoi dang duoc theo doi va trang thai ket noi.

## 3. Canh bao

Mapping hien thi chinh:

| Backend | UI |
|---|---|
| `SAFE` / `normal` / `low` | On dinh |
| `WATCH` / `medium` | Can theo doi |
| `ALERT` / `high` | Can kiem tra |
| `CRITICAL` / `critical` | Can ho tro ngay |

Moi canh bao nen du 3 y:

- Chuyen gi dang xay ra.
- Vi sao can chu y.
- Ban nen lam gi.

Canh bao nghiem trong:

- Te nga manh.
- Nhip tim qua nhanh/qua cham nguy hiem theo ngu canh.
- Dau hieu nhip tim khong deu muc cao.
- Tin hieu xau keo dai lam he thong khong danh gia duoc.

## 4. Du lieu va bao cao

- History doc `/history`.
- Health Summary doc `/health-report`.
- Alert timeline doc `/events`.
- Urgent alert doc `/alerts/realtime`.
- Profile local luu bang Hive; backend profile endpoint `/api/user/{id}` van duoc giu cho tuong thich.

Bao cao trong app nen hien thi "tom tat de hieu" truoc, thuat ngu ky thuat nam trong phan mo rong. He thong la cong cu theo doi/sang loc, khong phai chan doan y khoa.

## 5. Du lieu ky thuat

Settings co phan "Du lieu ky thuat" de caregiver/dev xem:

- Base URL hien tai.
- Trang thai `/health`.
- Cac endpoint app dang dung.
- Header/API key/device/access code dang dung.
- Mapping canh bao backend -> noi dung nguoi dung thay.
- Raw payload chi nen mo bang phan "xem du lieu goc", khong hien mac dinh.

## 6. Gioi han hien tai

- Push notification native chua phai duong canh bao production chinh.
- Flutter Web khong ho tro raw TCP MQTT; dung REST/WebSocket cho Web.
- PDF/report nang va guided baseline nhieu buoc la tinh nang phu, khong phai luong chinh cua demo on dinh.
- App khong tu dieu khien chan doan y khoa; moi ket qua bat thuong can duoc xac nhan boi nguoi cham soc/nhan vien y te khi can.
