export const vi = {
  appName: "Mini-ERP Chuỗi khách sạn",
  appDescription:
    "Nền tảng quản lý thu mua, kho và chi phí vận hành khách sạn.",
  common: {
    loading: "Đang tải dữ liệu…",
    tryAgain: "Thử lại",
  },
  auth: {
    loginTitle: "Đăng nhập",
    loginDescription:
      "Dùng tài khoản được quản trị viên cấp để truy cập hệ thống.",
    emailLabel: "Email tài khoản",
    passwordLabel: "Mật khẩu",
    signIn: "Đăng nhập",
    signOut: "Đăng xuất",
    callbackTitle: "Đang xác minh lời mời",
    callbackErrorTitle: "Liên kết không còn hợp lệ",
    callbackErrorDescription:
      "Liên kết có thể đã hết hạn hoặc đã được sử dụng. Hãy nhờ quản trị viên gửi lời mời mới.",
    setPasswordTitle: "Tạo mật khẩu",
    setPasswordDescription:
      "Tạo mật khẩu riêng có ít nhất 12 ký tự để hoàn tất kích hoạt tài khoản.",
    confirmPasswordLabel: "Nhập lại mật khẩu",
    setPasswordAction: "Lưu mật khẩu và tiếp tục",
    passwordErrors: {
      tooShort: "Mật khẩu phải có ít nhất 12 ký tự.",
      mismatch: "Hai mật khẩu không khớp.",
      updateFailed:
        "Chưa thể lưu mật khẩu. Vui lòng thử lại hoặc liên hệ quản trị viên.",
    },
    accountUnavailable: "Tài khoản chưa được kích hoạt",
    accountUnavailableDescription:
      "Tài khoản không còn quyền truy cập hệ thống. Hãy liên hệ quản trị viên.",
    errors: {
      invalidInput: "Vui lòng nhập email hợp lệ và mật khẩu.",
      invalidCredentials: "Email hoặc mật khẩu không chính xác.",
      inactiveAccount: "Tài khoản đã bị khóa. Hãy liên hệ quản trị viên.",
      accountNotReady:
        "Tài khoản chưa được thiết lập đầy đủ. Hãy liên hệ quản trị viên.",
      serviceError:
        "Chưa thể xác minh tài khoản. Vui lòng thử lại sau hoặc liên hệ quản trị viên.",
    },
  },
  property: {
    dashboard: "Tổng quan",
    welcome: "Chào mừng đến với hệ thống quản lý khách sạn",
    dashboardDescription:
      "Không gian làm việc của khách sạn đã sẵn sàng. Các phân hệ nghiệp vụ sẽ được bổ sung theo lộ trình.",
    switchLabel: "Khách sạn đang làm việc",
    switchAction: "Chuyển khách sạn",
    noAccessTitle: "Bạn chưa được phân quyền khách sạn",
    noAccessDescription:
      "Tài khoản đã đăng nhập nhưng chưa được gán quyền truy cập khách sạn. Hãy liên hệ quản trị viên.",
  },
  errors: {
    pageTitle: "Không thể tải trang",
    pageDescription:
      "Đã xảy ra lỗi khi tải dữ liệu. Vui lòng thử lại; nếu lỗi tiếp diễn, hãy liên hệ quản trị viên.",
    notFoundTitle: "Không tìm thấy trang",
    notFoundDescription:
      "Đường dẫn không tồn tại hoặc khách sạn này không nằm trong phạm vi truy cập của bạn.",
    backHome: "Về trang chủ",
  },
} as const;
