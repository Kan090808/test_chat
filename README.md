# Matrix Flutter Chat

這是一個使用 [Matrix](https://matrix.org) 協定實作的 Flutter 去中心化文字訊息範例。應用程式提供基本的登入、聊天室列表、訊息瀏覽與傳送等功能，示範如何在 Flutter 中整合 Matrix SDK。

## 功能特色

- 以使用者提供的 homeserver、帳號、密碼登入 Matrix。
- 動態同步已加入的聊天室，支援桌面與行動裝置的響應式介面。
- 顯示聊天室訊息並支援即時傳送純文字訊息。
- 透過下拉重新整理取得最新訊息，並提供登出功能。

## 專案結構

```
lib/
├── main.dart                # 應用程式進入點
├── services/
│   └── matrix_service.dart  # Matrix SDK 包裝與狀態管理
├── screens/
│   ├── login_screen.dart    # 登入畫面
│   ├── rooms_screen.dart    # 聊天室列表與主要版面配置
│   └── chat_screen.dart     # 單一聊天室訊息與輸入框
└── widgets/
    └── message_bubble.dart  # 訊息泡泡元件
```

## 開發與執行

1. 安裝 [Flutter](https://docs.flutter.dev/get-started/install) SDK。
2. 在專案根目錄執行 `flutter pub get` 以安裝相依套件。
3. 執行 `flutter run` 啟動應用程式，或透過 `flutter test` 執行測試。

登入時可使用任一 Matrix homeserver（預設為 `https://matrix-client.matrix.org`），帳號需已在該伺服器註冊並允許密碼登入。
