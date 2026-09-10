# Refactor UI/UX bộ lọc “Tìm kèo”

## Tóm tắt

- Thiết kế lại modal theo hướng gọn, trực quan, responsive và hỗ trợ light/dark mode.
- Giữ các filter hiện tại, bổ sung “Số sân” với lựa chọn `1`, `2`, `3`, `4+`.
- Tách bộ primitive dùng chung và áp dụng ngay cho modal “Tìm kèo” và “Tìm sân”.
- Mở rộng backend để lọc số sân trước phân trang, bảo đảm danh sách và tổng kết quả chính xác.

## Thay đổi chính

- Tạo `showAppFilterSheet`, `AppFilterSheetScaffold`, `AppFilterSection` và nhóm option/chip dùng chung:
  - Header thống nhất, badge số filter đang chọn, nút đóng.
  - Nội dung cuộn độc lập và action bar cố định.
  - Reset là hành động phụ, Apply/Search là hành động chính.
  - Chiều rộng tối đa khoảng 640 px trên màn hình lớn; mobile dùng gần toàn màn hình.
  - Dùng `LayoutBuilder`, `Wrap` và breakpoint theo chiều rộng khả dụng; bảo đảm touch target tối thiểu 48 dp và text scale 200% không overflow.

- Sắp xếp lại modal “Tìm kèo”:
  - Luôn hiển thị: Ngày, Khung giờ, Lọc nhanh, Môn thể thao, Số sân.
  - Nhóm mở rộng: Khu vực, Trình độ, Chi phí, Nguồn kèo.
  - Nhóm nâng cao tự mở khi đang có filter; tiêu đề nhóm hiển thị tóm tắt/số lựa chọn.
  - Chip được chọn có màu thương hiệu và dấu check, không chỉ dựa vào màu.
  - Chi phí giữ dạng khoảng và “Chia đều” nằm cùng section.
  - Reset cập nhật form tại chỗ, không đóng modal; giữ search, venue/sort theo ngữ cảnh và khôi phục thành phố ưu tiên.
  - Đóng modal bỏ các thay đổi chưa áp dụng; Apply đánh dấu form touched, chặn dữ liệu không hợp lệ rồi mới đóng.

- Migrate modal “Tìm sân” sang cùng scaffold, section, chip group và action bar; giữ nguyên contract, lựa chọn sort, yêu thích, vị trí và hành vi tìm kiếm hiện tại.

## Interface và backend

- Thêm `SessionCourtCountFilter? courtCount` vào `BrowseSessionFilters`, form control, `copyWith`, `reset` và `activeCount`.
- Mapping:
  - `1`, `2`, `3`: số sân chính xác.
  - `4+`: tối thiểu 4 sân.
- Mở rộng `SessionRepository.browseAvailable` và `GET /sessions/available` bằng `minCourts`/`maxCourts`:
  - `1–3` gửi cùng giá trị cho min/max.
  - `4+` chỉ gửi `minCourts=4`.
  - Backend validate số nguyên dương và `minCourts <= maxCourts`, sau đó thêm điều kiện Prisma trên `numberOfCourts` trước count/pagination.
- Không cần migration database. Cập nhật OpenAPI snapshot và localization Việt/Anh/Trung cho số sân, summary và nhãn accessibility.

## Test plan

- Domain: `courtCount` được copy/reset/count đúng và mapping chính xác sang min/max.
- Repository: query serialization cho `1`, `2`, `3`, `4+` và trạng thái không chọn.
- Backend: validation query, lọc exact/at-least, total và pagination sau lọc, tương thích request cũ.
- Session modal: chọn số sân, các chip đa lựa chọn, nhóm nâng cao tự mở, reset tại chỗ, đóng để discard, fee validation và Apply trả đúng model.
- Venue modal: sort/vị trí/yêu thích, reset và Apply vẫn hoạt động sau migration.
- Shared UI: sticky footer, keyboard inset, màn hình hẹp/rộng, dark mode và text scale 200%; chạy `dart analyze`, widget/domain tests liên quan và backend Jest tests.

## Giả định

- Không bổ sung hoặc xóa filter nào khác ngoài “Số sân”; các filter hiện tại vẫn có giá trị nghiệp vụ.
- Không thay đổi web trong đợt này, nhưng backend contract mới cho phép web bỏ client-side filtering sau này.
- Khi triển khai phải bảo toàn các thay đổi chưa commit hiện có, đặc biệt tại localization của app và `sessions.controller.ts`/`sessions.service.ts` của backend.
