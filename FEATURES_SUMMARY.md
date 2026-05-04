# Tổng Kết Tính Năng Ứng Dụng Elder Health Monitor

Ứng dụng **Elder Health Monitor** hiện tại hỗ trợ 2 vai trò riêng biệt: **Người đeo (Wearer)** và **Người giám sát (Caregiver)**. Tùy thuộc vào vai trò được chọn ở màn hình Onboarding, giao diện và chức năng của ứng dụng sẽ được điều chỉnh tương ứng. Dưới đây là bảng tổng hợp chi tiết các tính năng hiện có.

---

## 1. Giao Diện Người Đeo Thiết Bị (Wearer Mode)

Đây là chế độ dành cho người cao tuổi trực tiếp đeo thiết bị cảm biến (VD: đồng hồ, đai đeo tim). Giao diện tập trung vào việc đo đạc, cá nhân hóa cảnh báo và tự theo dõi sức khỏe.

### 🏥 Hồ Sơ Y Tế Cá Nhân (Medical Profile)
- **Thông tin cơ bản**: Quản lý thông tin chiều cao, cân nặng, độ tuổi, giới tính.
- **Khai báo bệnh nền**: Cho phép tick chọn các bệnh lý tim mạch/hô hấp có sẵn (Rung nhĩ, Tiểu đường, Suy tim,...). Hiển thị các Banner chú thích (InfoBanner) để người dùng hiểu tầm quan trọng của việc khai báo.
- **Danh sách Thuốc (Medications)**: Lựa chọn các loại thuốc đang sử dụng (VD: Chẹn beta, Máy tạo nhịp tim,...). 
- **AI Tự Động Điều Chỉnh Ngưỡng (Smart Thresholds)**:
  - Dựa vào bệnh nền và thuốc, AI sẽ tự động nới lỏng hoặc siết chặt ngưỡng cảnh báo (Ví dụ: Dùng thuốc chẹn beta sẽ hạ ngưỡng nhịp tim tối thiểu; có rung nhĩ sẽ bỏ qua cảnh báo nhịp không đều thường xuyên).
  - Cung cấp giao diện bảng so sánh giữa **Ngưỡng Mặc Định** và **Ngưỡng Của Bạn** kèm theo lý do giải thích chi tiết.
- **Căn Chỉnh Sinh Tồn (Calibration)**: Nút kích hoạt quá trình tự học nhịp tim và HRV trong 5 phút khi nghỉ ngơi để tạo baseline (đường cơ sở) cá nhân.

### 📊 Dashboard & Giao Diện Chính
- **Vòng Tròn Nhịp Tim (HR Gauge)**: 
  - Hiển thị nhịp tim theo thời gian thực ở trung tâm với vòng cung gradient.
  - Hiệu ứng nhịp đập (pulse animation) đồng bộ với tốc độ nhịp tim.
  - Hiệu ứng nhấp nháy liên tục khi ở mức **Khẩn cấp (CRITICAL)**.
  - Hiển thị dải chỉ số nhỏ bên dưới: Nhịp Min - Trung Bình - Max.
- **Thẻ Tình Trạng Tim (Condition Indicator)**: 
  - Phân tích và hiển thị tên tình trạng nhịp tim hiện tại bằng tiếng Việt (VD: *Ngoại tâm thu, Rung nhĩ đáp ứng thất nhanh*...).
  - Badge tự tin (Confidence Badge) báo hiệu trạng thái *Đang phân tích* nếu dữ liệu chưa chắc chắn.
- **Thẻ Trạng Thái Cảm Xúc (Emotion Card)**: 
  - Đánh giá mức độ thư giãn, căng thẳng hoặc phấn chấn dựa trên hệ thần kinh tự chủ (HRV).
  - Tự động khóa (báo *"Đang vận động - không đánh giá"*) nếu phát hiện người dùng đang đi bộ hoặc tập thể dục.
- **Thẻ Hoạt Động (Activity Badge)**: Hiển thị trạng thái đang nghỉ ngơi, đi bộ chậm, hay vận động mạnh.

### ⚠️ Hệ Thống Cảnh Báo (Alerts)
- Hiển thị ngay một **Banner Cảnh Báo Lâm Sàng** trên Dashboard khi phát hiện nhịp tim có vấn đề (Ví dụ: Cảnh báo Rung nhĩ kèm nút "Xem chi tiết").
- **Trung Tâm Cảnh Báo (Alert Center)**: 
  - Phân trang thời gian: Mới, Hôm nay, Tuần này.
  - Hỗ trợ công tắc (Toggle): **Bỏ qua cảnh báo "THEO DÕI"** để chỉ tập trung vào các cảnh báo nghiêm trọng.
  - Cử chỉ quẹt để đánh dấu đã đọc (Swipe to dismiss).

### 📈 Lịch Sử & Biểu Đồ Nâng Cao (History)
- **Biểu đồ Đường (Line Chart)**: Xem xu hướng nhịp tim trong 24h, 7 ngày, 30 ngày.
- **Biểu đồ Phân Bố (Pie Chart)**: Trực quan hóa tỷ lệ phần trăm các loại nhịp tim trong ngày (Bình thường, Nhanh, Chậm, Ngoại tâm thu).
- **Xu hướng HRV & Phục hồi**: Đánh giá sự phục hồi của cơ thể thông qua chỉ số RMSSD.
- **Phân bố Hoạt Động & Cảm Xúc**: Thống kê thời gian vận động và trạng thái tâm lý trong ngày.

---

## 2. Giao Diện Người Giám Sát (Caregiver Mode)

Đây là chế độ dành cho người nhà (con cái) hoặc Bác sĩ để theo dõi bệnh nhân từ xa.

### 🌐 Kết Nối & Tổng Quan
- **Theo dõi từ xa**: 
  - Kết nối qua MQTT / WebSocket lấy dữ liệu cloud theo thời gian thực.
  - Có một **Banner "Đang theo dõi người thân"** (Remote Mode) luôn hiển thị trên Dashboard để phân biệt với chế độ đeo trực tiếp.
  - Hiển thị tên của Bệnh nhân đang được theo dõi trên AppBar (VD: "Mẹ Lan").
  - Trạng thái kết nối (Online/Offline) với server trung tâm để đảm bảo dữ liệu đang được đồng bộ.

### 📑 Dashboard Chuyên Dụng
- Kế thừa toàn bộ giao diện xem thông số của Người đeo (Vòng tròn HR, Cảm xúc, Hoạt động, Lịch sử).
- Không có chức năng sửa đổi Hồ Sơ Y Tế (Chỉ Read-only) để tránh làm sai lệch thông tin của bệnh nhân.

### 🖨️ Xuất Báo Cáo Y Tế (Clinical Report)
- Chức năng cực kỳ quan trọng cho người chăm sóc: **Tạo báo cáo bác sĩ**.
- Nút bấm xuất file PDF chuyên nghiệp chuẩn y khoa (Hỗ trợ font Tiếng Việt đầy đủ).
- **Nội dung Báo cáo PDF bao gồm**:
  - Thông tin bệnh nhân (Tuổi, Bệnh nền, Thuốc đang dùng).
  - Tóm tắt tổng quan chỉ số (HR, RMSSD, Tỷ lệ nhịp bình thường/bất thường).
  - Danh sách Bảng thống kê các sự kiện bất thường đáng chú ý (Clinical Alerts).
  - Phân tích và đề xuất sơ bộ từ hệ thống AI (Gợi ý khám chuyên khoa nếu phát hiện dấu hiệu).
- Tích hợp sẵn chức năng **Chia sẻ (Share)** file báo cáo thẳng qua Zalo, Email, hoặc in ra giấy.

---

## 3. Kiến Trúc Dữ Liệu Chung (Core Logic)
- **Cơ sở dữ liệu cục bộ (Isar/Memory)**: Đảm bảo app phản hồi tức thì, lưu trữ an toàn hồ sơ bệnh nhân.
- **Xử lý nền (Background Processing)**: Cho phép kết nối và nhận cảnh báo (Push Notification) cả khi tắt app (đang tiếp tục hoàn thiện logic native).
- **Riverpod State Management**: Tự động rebuild các widget phức tạp (Biểu đồ, Dashboard) một cách mượt mà nhất ngay khi có gói dữ liệu ECG/PPG mới đẩy về.
