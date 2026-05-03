# Elderly Care Monitor - Ứng Dụng Giám Sát Sức Khoẻ

Ứng dụng Flutter giám sát sức khỏe người cao tuổi theo thời gian thực (nhịp tim, cảnh báo ngã, v.v.), hỗ trợ đa nền tảng (Web, Windows, Android) và hoạt động với 2 vai trò: **Người đeo** (Local IoT) và **Người giám sát** (Remote Cloud).

---

## 🛠 Yêu Cầu Cài Đặt (Prerequisites)

1. [Cài đặt Flutter SDK](https://docs.flutter.dev/get-started/install) (phiên bản >= 3.2.0)
2. Cài đặt IDE: **VS Code** hoặc **Android Studio**
3. Cài đặt extension:
   - Nếu dùng VS Code: Cài extension `Flutter` và `Dart`
   - Nếu dùng Chrome/Edge: Cài đặt sẵn trình duyệt để chạy nền Web.

---

## 🚀 Hướng Dẫn Chạy App Bằng Terminal (Command Line)

Mở terminal tại thư mục gốc của project (`d:\DATN\app`):

### 1. Tải các gói phụ thuộc (Dependencies)
Cài đặt toàn bộ các thư viện cần thiết:
```bash
flutter pub get
```

### 2. Chạy ứng dụng trên Trình duyệt (Chrome - Khuyên dùng để test UI nhanh)
```bash
flutter run -d chrome
```

### 3. Chạy ứng dụng trên máy tính Windows (Desktop App)
```bash
flutter run -d windows
```

### 4. Chạy ứng dụng trên máy ảo/điện thoại Android
*Lưu ý: Bạn cần mở Android Emulator hoặc cắm cáp kết nối điện thoại Android (đã bật USB Debugging).*
```bash
flutter run -d android
```

---

## 🧪 Hướng Dẫn Test & Demo Tính Năng

Hiện tại app đang được bật sẵn **Chế độ Demo (Demo Mode)**. Điều này có nghĩa là ứng dụng sẽ tự động sinh ra dữ liệu giả (Mock Data) thay vì bắt buộc kết nối với Jetson Nano / MQTT thật.

### Luồng Test Chi Tiết (Workflow):

#### Bước 1: Onboarding (Chọn vai trò)
- Khi mở app lần đầu, bạn sẽ được hỏi chọn vai trò:
  - **Người đeo**: Trải nghiệm giao diện theo dõi sức khoẻ dành cho người cao tuổi.
  - **Người giám sát**: Trải nghiệm giao diện cho người thân theo dõi từ xa.
- Chọn **"Người đeo"** và nhấn **"Tiếp tục"**.

#### Bước 2: Bảng Điều Khiển (Dashboard)
- Giao diện sẽ tự động nhảy dữ liệu **Nhịp tim (HR)** mỗi 3 giây.
- Các chỉ số khác (HRV, Hoạt động, Cảm xúc) thay đổi động.
- Chờ khoảng 30-60 giây, ứng dụng sẽ sinh ra các cảnh báo ngẫu nhiên (Vd: "Phát hiện ngã", "Nhịp tim cao"). Màn hình sẽ chớp cảnh báo (Alert banner).

#### Bước 3: Xem Lịch Sử (History)
- Mở tab **Lịch sử** ở thanh điều hướng dưới cùng.
- Trải nghiệm biểu đồ (Line Chart, Bar Chart) dữ liệu mẫu của 24h qua.
- Thử chuyển đổi các mốc thời gian (24h, 7 Ngày, 30 Ngày).

#### Bước 4: Trung Tâm Cảnh Báo (Alert Center)
- Nhấn vào biểu tượng cái Chuông (Tab Cảnh Báo).
- Bạn sẽ thấy danh sách các sự kiện sức khoẻ đã mô phỏng.
- **Thử thao tác:** Vuốt ngang (swipe) một cảnh báo để xoá/đánh dấu đã đọc.

#### Bước 5: Chuyển đổi vai trò & Remote Mode
- Đi tới tab **Cài đặt** (Bánh răng).
- Kéo xuống khu vực "Thiết lập vai trò", đổi sang **Người giám sát**.
- Nhập tên người theo dõi (VD: "Bố An"), nhập Cloud URL bất kỳ.
- Quay lại Dashboard, bạn sẽ thấy thanh trạng thái phía trên đổi thành màu xanh dương và ghi: *"Đang giám sát từ xa: Bố An"*.

---

## ⚙️ Tắt Chế Độ Demo (Chạy với Hardware Thật)

Khi bạn muốn kết nối với mạch Jetson Nano thật:
1. Mở file: `lib/core/services/storage_service.dart`
2. Đổi giá trị mặc định của `demo_mode` thành `false`:
```dart
  bool get isDemoMode =>
      getSetting<bool>('demo_mode', defaultValue: false)!; 
```
3. Khởi động lại ứng dụng. Ứng dụng sẽ bắt đầu lắng nghe MQTT ở địa chỉ IP gateway mà bạn nhập trong màn hình Cài đặt.
