# Bổ sung lựa chọn “Khác” cho CitySelector

## Tóm tắt

Giữ nguyên danh sách tỉnh/thành hiện tại và thêm lựa chọn được bản địa hóa “Khác / Other / 其他”. Lựa chọn này dành cho người dùng ở ngoài danh sách và tương đương chế độ khám phá không lọc theo `city`, nhưng vẫn được lưu riêng với lựa chọn “Tất cả”.

Không mở rộng Google Places hoặc thay đổi API backend trong phạm vi này.

## Thay đổi chính

- Mở rộng `LocationPreferences` bằng loại lựa chọn `all`, `city`, `other`; chỉ `city` có `preferredCity`, còn `all` và `other` đều không gửi tham số `city` tới các API discovery.
- Lưu loại lựa chọn bằng một SharedPreferences key mới. Khi đọc dữ liệu cũ:
  - Có thành phố đã lưu → `city`.
  - Không có thành phố nhưng onboarding đã hoàn tất → `all`.
  - Chưa onboarding → giữ trạng thái chưa quyết định.
- Tách rõ các thao tác controller: chọn thành phố, chọn tất cả và chọn khác; giữ việc chuẩn hóa tên tỉnh/thành Việt Nam cho lựa chọn `city`.
- Thêm hàng “Khác” trong `CitySelectorResults`, hiển thị đúng trạng thái được chọn. Khi tìm kiếm không khớp danh sách, màn hình vẫn cung cấp nút chọn “Khác”.
- Khi dùng GPS:
  - Reverse-geocode thành công và khớp danh sách → chọn tỉnh/thành tương ứng.
  - Reverse-geocode thành công nhưng ở ngoài danh sách → tự động chọn “Khác”.
  - Chỉ hiển thị lỗi khi lấy vị trí hoặc reverse-geocode thực sự thất bại.
- `CitySelector` hiển thị nhãn “Khác” nhưng callback discovery tiếp tục trả `null`, khiến sessions, venues, clubs và tournaments xóa bộ lọc `city`.
- Onboarding dùng chung nội dung selector, không còn ép mặc định Hồ Chí Minh. Sheet onboarding không thể đóng bằng nút close, kéo xuống hoặc chạm ra ngoài; người dùng phải chọn thành phố, “Tất cả” hoặc “Khác”.
- Bổ sung chuỗi bản địa hóa Việt/Anh/Trung cho lựa chọn “Khác” và nội dung liên quan; giữ nguyên trải nghiệm form dựa trên `reactive_forms`.

## Kiểm thử

- Unit test restore/persist cho cả ba loại lựa chọn và migration dữ liệu SharedPreferences cũ.
- Widget test chọn “Khác”, hiển thị trạng thái đã chọn và callback xóa `city`.
- Test tìm kiếm không có kết quả vẫn cho phép chọn “Khác”.
- Test GPS tại Việt Nam vẫn chọn đúng thành phố; GPS ở nước ngoài chuyển sang “Khác”; lỗi quyền/vị trí/geocoder vẫn giữ sheet và báo lỗi.
- Test onboarding dùng cùng selector, hỗ trợ “Khác”, không còn mặc định Hồ Chí Minh và hoàn tất onboarding sau lựa chọn.
- Test discovery trên bốn nhóm nội dung xác nhận lựa chọn “Khác” không gửi bộ lọc `city`.
- Chạy các test location/widget liên quan và `dart analyze`, đồng thời bảo toàn các thay đổi chưa commit đang có trong worktree.

## Giả định

- “Khác” biểu thị người dùng ở ngoài danh sách được hỗ trợ, không phải một thành phố cụ thể.
- “Tất cả” và “Khác” cùng tải dữ liệu toàn cầu không lọc `city`, nhưng được lưu và hiển thị khác nhau để phản ánh đúng lựa chọn của người dùng.
- Danh sách tỉnh/thành Việt Nam, endpoint `new-admin-units` và cấu hình Google Places hiện tại không thay đổi.
