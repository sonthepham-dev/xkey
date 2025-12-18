# XKeyIM - Input Method Kit Vietnamese

XKeyIM là Input Method sử dụng Input Method Kit (IMKit) của Apple, cung cấp trải nghiệm gõ tiếng Việt mượt mà hơn trong Terminal và IDE.

## Ưu điểm so với CGEvent injection

| Aspect | CGEvent (XKey) | IMKit (XKeyIM) |
|--------|----------------|----------------|
| Flickering | Có thể xảy ra | Không có |
| Terminal support | Cần tune timing | Native support |
| Setup | Không cần | Cần enable trong System Settings |

## Bundle Identifiers

| Component | Bundle ID |
|-----------|-----------|
| XKey (main app) | `com.codetay.XKey` |
| XKeyIM (input method) | `com.codetay.inputmethod.XKey` |
| App Group | `group.com.codetay.xkey` |

> **Lưu ý:** Bundle ID của Input Method cần có format `*.inputmethod.*` để macOS nhận diện đúng.

## Cài đặt

### Cách 1: Từ XKey Settings
1. Mở XKey Settings → Nâng cao
2. Bật "IMKit Mode"
3. Click "Cài đặt XKeyIM..."
4. Làm theo hướng dẫn để copy XKeyIM.app vào `~/Library/Input Methods/`

### Cách 2: Manual
1. Build XKeyIM target trong Xcode
2. Copy `XKeyIM.app` vào `~/Library/Input Methods/`
3. Logout/Login lại
4. Mở System Settings → Keyboard → Input Sources
5. Click "+" và thêm "XKey Vietnamese"

## Cấu trúc Project

```
XKeyIM/
├── Info.plist                  # IMKit configuration
├── XKeyIM.entitlements         # Entitlements for debug build
├── XKeyIMRelease.entitlements  # Entitlements for release build
├── main.swift                  # Entry point
├── XKeyIMController.swift      # IMKInputController subclass
├── en.lproj/
│   └── InfoPlist.strings       # English localization
├── vi.lproj/
│   └── InfoPlist.strings       # Vietnamese localization
└── README.md                   # This file
```

## Build Instructions

### Bước 1: Tạo XKeyIM Target trong Xcode

1. Mở `XKey.xcodeproj` trong Xcode
2. File → New → Target...
3. Chọn **macOS** → **App** → Next
4. Cấu hình:
   - Product Name: `XKeyIM`
   - Bundle Identifier: `com.codetay.inputmethod.XKey`
   - Language: Swift
   - User Interface: None
5. Click **Finish**

### Bước 2: Cấu hình Target Settings

1. Chọn **XKeyIM target** trong Project Navigator

2. Tab **General**:
   - Bundle Identifier: `com.codetay.inputmethod.XKey`
   - Minimum Deployments: macOS 12.0+

3. Tab **Build Settings**:
   - **Info.plist File** = `XKeyIM/Info.plist`
   - **Code Signing Entitlements** = `XKeyIM/XKeyIMRelease.entitlements` (cho Release)

4. Tab **Signing & Capabilities**:
   - Chọn Team
   - Click **+ Capability** → Thêm **App Groups**
   - Chọn `group.com.codetay.inputmethod.XKey`

### Bước 3: Setup App Group trong Apple Developer Portal

1. Đăng nhập https://developer.apple.com
2. Certificates, Identifiers & Profiles → Identifiers

**Tạo App Group (nếu chưa có):**
1. Click "+" → App Groups
2. Description: `XKey Shared Settings`
3. Identifier: `group.com.codetay.inputmethod.XKey`

**Tạo App ID cho XKeyIM:**
1. Click "+" → App IDs → App
2. Platform: macOS
3. Description: `XKey Input Method`
4. Bundle ID: `com.codetay.inputmethod.XKey`
5. Capabilities: ✅ App Groups
6. Chọn `group.com.codetay.inputmethod.XKey`

**Tạo Provisioning Profile:**
1. Profiles → Click "+"
2. Chọn "macOS App Development" hoặc "Developer ID Application"
3. Chọn App ID: `com.codetay.inputmethod.XKey`
4. Chọn certificate và devices
5. Download và double-click để install

### Bước 4: Thêm Source Files vào Target

XKeyIM cần dùng chung code engine với XKey. Trong Xcode:

1. Chọn các file trong **Project Navigator**
2. Mở **File Inspector** (panel bên phải)
3. Trong section **Target Membership**, check ✅ **XKeyIM**

**Các file cần check Target Membership:**
```
XKey/Core/Engine/
├── VNEngine.swift           ✅
├── VNCharacter.swift        ✅
├── SpellChecker.swift       ✅
└── ... (các file engine khác)

XKey/Core/Models/
├── InputMethod.swift        ✅
├── CodeTable.swift          ✅
└── ... (các model cần thiết)
```

### Bước 5: Build

**Sử dụng build script:**
```bash
cd XKey
./build_release.sh
```

**Hoặc build thủ công:**
```bash
xcodebuild -project XKey.xcodeproj \
  -scheme XKeyIM \
  -configuration Release \
  build
```

### Bước 6: Install

```bash
# Copy vào Input Methods
cp -R Release/XKeyIM.app ~/Library/Input\ Methods/

# Logout/Login để macOS nhận diện
```

### Bước 7: Enable Input Source

1. Mở **System Settings** → **Keyboard** → **Input Sources**
2. Click **Edit...** → **+**
3. Tìm "Vietnamese" → Chọn "XKey Vietnamese"
4. Click **Add**

## Info.plist Configuration

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleIdentifier</key>
    <string>com.codetay.inputmethod.XKey</string>
    
    <key>CFBundleDisplayName</key>
    <string>XKey Vietnamese</string>
    
    <key>InputMethodConnectionName</key>
    <string>XKeyIM_Connection</string>
    
    <key>InputMethodServerControllerClass</key>
    <string>XKeyIMController</string>
    
    <key>InputMethodServerDelegateClass</key>
    <string>XKeyIMController</string>
    
    <key>TISIntendedLanguage</key>
    <string>vi</string>
    
    <key>tsInputMethodCharacterRepertoireKey</key>
    <array>
        <string>Vitn</string>
    </array>
    
    <key>tsInputMethodIconFileKey</key>
    <string>AppIcon</string>
    
    <key>LSBackgroundOnly</key>
    <true/>
    
    <key>LSUIElement</key>
    <true/>
    
    <key>LSMultipleInstancesProhibited</key>
    <true/>
</dict>
</plist>
```

## Troubleshooting

### XKeyIM không xuất hiện trong Input Sources
- Kiểm tra bundle ID có format `*.inputmethod.*`
- Logout/Login lại (hoặc restart máy)
- Kiểm tra Console.app cho lỗi

### Build lỗi "Provisioning profile doesn't include App Groups"
- Tạo App ID mới trong Apple Developer Portal với App Groups capability
- Tạo Provisioning Profile mới cho App ID đó
- Download và install profile
- Trong Xcode, chọn đúng Team và profile

### Build lỗi "Cannot find VNEngine"
- Đảm bảo đã thêm các file engine vào XKeyIM target membership
- Check Target Membership trong File Inspector

### Settings không sync giữa XKey và XKeyIM
- Kiểm tra App Group được enable trong cả 2 targets
- Kiểm tra App Group identifier khớp nhau: `group.com.codetay.inputmethod.XKey`
- Rebuild cả 2 targets

## Notes

- XKeyIM chạy như background process, không có UI riêng
- Settings được quản lý từ XKey.app thông qua App Group
- Có thể chạy song song với XKey (CGEvent mode)
- Cần logout/login sau khi install lần đầu để macOS nhận diện
