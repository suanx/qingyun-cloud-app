# 后端对接教程

本文档说明「轻云」App 如何对接真实后端，并约定接口调用、鉴权、错误处理与联调规范。客户端网络层代码位于 `lib/core/network/`。

**当前已对接的后端是 [lanflare](https://github.com/suanx/lanflare)**（Cloudflare Workers + D1 + 蓝奏云网盘）。下文同时保留原 envelop 约定作为自定义后端的参考规范。

## 1. 总览

```
App (lib/features/*)
   ↓ 只依赖
CloudRepository (lib/core/network/cloud_repository.dart)
   ↓ useMockData=false 时
ApiClient (dio 封装) → lanflare /api/*（Cloudflare Workers）
```

- 页面不直接发请求，统一走 `CloudRepository`，后端字段变化只改这一层。
- `lanflare` 返回原生 JSON（无 envelop），由 `ApiClient.getRaw/postRaw` 直接解包；`{ "error": "..." }` 与 HTTP 4xx/5xx 统一映射为 `ApiException`。
- 登录页：`lib/features/login/login_screen.dart`。未登录时路由守卫（`AppRouter._authGuard`）会把所有页面重定向到 `/login`；任意接口返回 401 时自动清凭证并回登录页。

### 1.1 切换 / 配置步骤

1. 部署 lanflare（见其仓库 README），拿到服务地址，例如 `https://lanflare.<你的子域>.workers.dev`。
2. 修改 `lib/core/config/app_config.dart`：
   ```dart
   static const String apiBaseUrl = 'https://lanflare.<你的子域>.workers.dev';
   static const bool useMockData = false;   // true = 内置示例数据
   ```
3. （可选）在 lanflare 侧配置 `STORAGE_TOTAL_BYTES` 变量/secret，作为容量总量；未配置时 App 使用 `AppConfig.fallbackTotalGb`（100 GB）兜底。
4. App 内使用 lanflare 账号登录（`POST /api/auth/login`，开启 TOTP 时额外填验证码）。

## 2. lanflare 接口映射（App 实际使用）

| App 场景 | lanflare 接口 | 说明 |
| --- | --- | --- |
| 登录 | `POST /api/auth/login` `{u,p,code?}` | 成功后存 Basic 凭证（`Authorization: Basic base64(u:p)`），等价网页会话、rw 权限 |
| 退出登录 | 本地 `TokenStore.clear()` | lanflare 会话基于凭证头，无需服务端注销 |
| 容量概览 | `GET /api/storage/summary` | 返回 `{used_bytes,total_bytes,by_category}`；total 来自 `STORAGE_TOTAL_BYTES` |
| 文件列表 | `GET /api/list?pid=` | 节点 `{id,pid,name,type,size_bytes,created_at}`；`includeDirs=true` 时目录也进入列表并支持钻取 |
| 搜索 | `GET /api/search?q=` | 全局文件名匹配 |
| 新建文件夹 | `POST /api/mkdir` `{pid,name,ensure:true}` | 同名目录复用 |
| 重命名 | `POST /api/rename` `{id,name}` | 预览页工具调用 |
| 删除 | `POST /api/delete` `{ids:[number]}` | 移入回收站 |
| 回收站 | `GET /api/bin` | 同文件列表结构 |
| 恢复 | `POST /api/restore` `{ids}` | — |
| 彻底删除 | `POST /api/hard-delete` `{ids}` | — |
| 清空回收站 | `POST /api/empty-bin` | — |
| 生成分享 | `POST /api/share` `{id,expiresInDays,password?}` | 返回 `{code,url}`，App 取 `url` 并复制到剪贴板 |
| 我的分享 | `GET /api/my-shares` / `DELETE /api/shares/:id` | 分享列表与撤销 |
| 下载地址 | `GET /api/download?id=` | 302 直连蓝奏云 CDN；兜底 `/api/stream?id=` 代理流（支持 Range） |
| 下载并打开 | `GET /api/stream?id=` + Dio 直写文件 | 保存到应用私有目录 `downloads/`，`open_filex` 打开；进度写本地任务 |
| 在线查看 | `GET /api/preview/url?id=` → `GET /api/preview?...` | **新增**：签发 15 分钟 HMAC URL，供 Image.network / video_player 无请求头加载；支持 Range 与正确 MIME |
| 上传 | `POST /api/upload?pid=` | raw body + 头 `X-Heri-Name: <文件名>`，单请求 ≤ 90MB；大文件走 `/api/upload/chunk` 分块 |
| 传输任务 | App 本地模型 | lanflare 无服务端任务列表；`LocalTransferStore` 在上传/下载时记录，dio 回调驱动进度 |

分类映射：lanflare 节点没有 category 字段，App 按 `FileCategoryX.fromFileName(文件扩展名)` 推断（图片/文档/视频/音乐/压缩包/其他）。后端 `/api/storage/summary` 的 `by_category` 也按扩展名归类（image/video/music/doc/archive），前端「存储空间」图例直接使用。

## 3. 鉴权

### 3.1 凭证与存储

- `TokenStore`（`lib/core/network/token_store.dart`）把凭证持久化到 `shared_preferences`（key：`lanflare_credential`）。
- 凭证格式与请求头自动匹配：
  - `lf_...` API 令牌 → `Authorization: Bearer <token>`；
  - `basic:<base64(u:p)>` → `Authorization: Basic <b64>`（登录页走这条）；
  - 其他值 → `Cookie: lf_session=<value>`（旧式会话兜底）。
- 正式发布建议替换为 `flutter_secure_storage` 等加密存储（接口保持一致）。

### 3.2 401 处理约定

- 任意接口返回 HTTP 401 → `ApiClient.onUnauthorized` 触发 → `TokenStore.clear()` + 跳转登录页（`AppRouter.handleUnauthorized`，在 `main.dart` 注册）。
- 原 GET 请求可安全重试一次；非幂等请求（上传/删除）不要自动重试。

## 4. 错误处理

### 4.1 客户端异常模型

所有失败都会变成 `ApiException`（`lib/core/network/api_exception.dart`）：

| 场景 | code | message 示例 |
| --- | --- | --- |
| lanflare 业务失败 | `statusCode*100` | `{ "error": "..." }` 原文透出 |
| 连接失败/断网 | `-1` | “网络连接不可用，请检查网络后重试” |
| 超时 | `-2` | “请求超时，请稍后重试” |
| 取消 | `-3` | “请求已取消” |
| 503（蓝奏云未绑定） | `503*100` | “存储账号未绑定，请先在网页端绑定蓝奏云账号” |

### 4.2 页面处理规范

1. **列表/详情类**：失败时展示 `QyEmptyState`（标题 + 描述 + “重新加载”按钮），不要弹窗打断。
2. **操作类**（上传、删除、分享）：失败用 `showQyToast(context, e.message, success: false)`。
3. **文案**：后端 message 面向用户可直接展示；禁止把堆栈/内部码透给用户。

## 5. 联调注意事项

1. **环境分离**：`AppConfig` 可扩展为 `dev/staging/prod` 三套 BaseUrl，用 `--dart-define=ENV=dev` 注入，避免联调直连生产。
2. **HTTPS**：Android `usesCleartextTraffic` 未开启，iOS 默认 ATS；workers.dev 域名自带 HTTPS。
3. **文件上传**：≤90MB 单请求直传；更大文件走 lanflare `/api/upload/chunk` 分块协议，进度经 dio `onSendProgress` 回调写入 `LocalTransferStore`。
4. **下载**：优先 302 直链（VIP），非 VIP 走 Worker 代理流；客户端只拿 URL，交给系统下载能力或流式接收。
5. **幂等性**：上传/删除/恢复等操作建议携带客户端生成的 `request_id`，后端去重，避免弱网重复提交。
6. **日志**：联调期可在 `ApiClient` 添加 `LogInterceptor`；上线前务必关闭请求/响应体日志，防止凭证泄露。
7. **联调自检清单**：
   - [ ] `useMockData = false` 且 BaseUrl 指向已部署的 lanflare
   - [ ] 登录页登录成功 → 凭证持久化 → 重启 App 免登录
   - [ ] 首页容量卡 / 最近文件显示真实数据
   - [ ] 文件页分类筛选、搜索页关键字搜索生效
   - [ ] 上传后文件出现在列表，传输页进度条实时更新
   - [ ] 回收站恢复 / 清空、分享链接生成可用
   - [ ] 退出登录后访问任意页面回到登录页

## 6. 快速自测脚本示例

```bash
BASE=https://lanflare.<你的子域>.workers.dev

# 1) 登录（保存 Set-Cookie 或改用 API Token）
curl -i -X POST "$BASE/api/auth/login" -H 'Content-Type: application/json' -d '{"u":"<账号>","p":"<密码>"}'

# 2) 容量概览（Bearer 令牌方式）
curl -H "Authorization: Bearer lf_xxx" "$BASE/api/storage/summary"
# 期望：{"used_bytes":9012345,"total_bytes":107374182400}

# 3) 文件列表
curl -H "Authorization: Bearer lf_xxx" "$BASE/api/list?pid=0"
# 期望：{"items":[{"id":1,"pid":0,"name":"a.jpg","type":"file","size_bytes":123,"created_at":1730000000000}]}
```

App 侧对应展示：容量卡 `used/total` 自动格式化为 `x.x / y GB`；文件大小/时间由 `CloudRepository.humanSize / relativeTime` 格式化。

## 7. 自定义后端（可选，envelop 规范）

如果后续要替换为自研后端，建议沿用以下约定（`ApiClient.get/post/put/delete` 仍保留 envelop 解析）：

- 统一前缀 `/api/v1`，响应 envelop：
  ```json
  { "code": 0, "message": "ok", "data": {} }
  ```
- `code == 0` 成功；`code != 0` 抛 `ApiException(code, message)`。
- 登录返回 `access_token` / `refresh_token`，客户端以 `Authorization: Bearer <access_token>` 携带；`code = 40100` 视为未授权。

---

## 8. 前端功能对齐清单（v0.1.13 起）

以 App 页面交互为准，逐一核对前后端契约。图例：✅ 已接通真实接口；⚠️ 前端占位（后端无对应能力，见 8.2）；🔶 部分接通。

### 8.1 功能 → 接口 → 状态

| 页面 / 功能 | 前端入口 | 后端接口 / 数据处理 | 状态 |
| --- | --- | --- | --- |
| 登录（含 TOTP） | 登录页提交 | `POST /api/auth/login {u,p,code?}` | ✅ |
| 退出登录 | 我的页 | 本地清凭证 | ✅ |
| 容量环 / 存储页 | 首页 / 存储页 | `GET /api/storage/summary`（含 `by_category`） | ✅ |
| 文件列表 / 分类筛选 | 文件页胶囊 | `GET /api/list?pid=` + 本地扩展名分类 | ✅ |
| 目录钻取 / 新建文件夹 | 文件夹卡片 / FAB | `GET /api/list?pid=` + `POST /api/mkdir` | ✅ |
| 搜索 / 历史 | 搜索页 | `GET /api/search?q=` + 本地持久化历史 | ✅ |
| 上传（≤90MB） | 首页上传 / FAB | `POST /api/upload?pid=` raw + `X-Heri-Name` | ✅ |
| 上传（>90MB） | 同上 | `POST /api/upload/chunk` 8MB/块 + Finalize | ✅ |
| 下载并打开 | 预览页下载 | `GET /api/stream?id=` → 保存到应用目录 → `open_filex` | ✅ |
| 在线看图片 | 预览页 | `GET /api/preview/url` → `Image.network(签名URL)` | ✅ |
| 在线看视频/音频 | 预览页 | 同上 → `video_player`（Range 流式） | ✅ |
| 在线看文本 | 预览页 | 同上 → `Dio.get<String>(签名URL)` 展示 | ✅ |
| 在线看 PDF / 其他 | 预览页 | 无内联渲染，提示下载后用系统应用打开 | 🔶 |
| 分享 / 复制 / 撤销 | 预览页、我的页 | `POST /api/share`、`GET /api/my-shares`、`DELETE /api/shares/:id` | ✅ |
| 重命名 / 删除 | 预览页工具 | `POST /api/rename`、`POST /api/delete` | ✅ |
| 回收站恢复/清空 | 回收站页 | `GET /api/bin`、`POST /api/restore`、`POST /api/empty-bin` | ✅ |
| 传输进度 | 传输页 | 本地 `LocalTransferStore` + dio 回调 | ✅ |
| 相册 | 相册页 | `GET /api/list?pid=0` 过滤图片分类 | ✅ |

### 8.2 后端暂无法提供 / 未实现的能力

| 前端展示 | 原因 | 影响范围 | 待处理方式 |
| --- | --- | --- | --- |
| 扫一扫上传 | 需移动端摄像头扫码 SDK，且 lanflare 无「扫码→解析蓝奏链接→转存」的移动端封装（后端有 `POST /api/resolve-share`、`POST /api/rent` 可复用） | 首页四宫格「扫一扫」仍为 toast | 引入 `mobile_scanner`，扫码后调 `/api/rent` 转存；需真机摄像头权限配置 |
| 会员升级 / 开通 | lanflare 只有 admin 设置 VIP 的接口，无订单/支付系统 | 首页与存储页「升级」按钮为 toast | 接入支付渠道 + 订单回调后调 `POST /api/admin/users/:id/vip`（或新增自助购买端点） |
| 分类清理建议（4.6GB 可清理） | 后端无重复文件/大文件/长期未访问扫描接口 | 存储页清理卡片为展示占位 | 新增 `GET /api/storage/analyze` 返回重复/大文件清单，再接一键清理 |
| 设备管理 / 安全中心 | lanflare 无设备表、无登录设备管理（仅 HMAC 会话） | 我的页对应 cell 为 toast | 后端加设备表与会话元数据，前端再做设备列表/下线 |
| 回忆视频 / 为你推荐 | 需内容生成与推荐服务，网盘后端不提供 | 相册回忆横幅、首页推荐卡标注示例 | 独立内容服务或运营配置接口 |
| 服务端传输任务 | lanflare 上传同步完成、下载无任务概念 | App 重启后传输记录丢失（本地内存模型） | 本地持久化 `LocalTransferStore`，或后端新增任务表 |
| PDF 内联渲染 | 需引入 PDF 渲染引擎，包体积与原生依赖成本高 | 预览页 PDF 走「下载并打开」 | 后续按需引入 `flutter_pdfview` |

### 8.3 配置项

| 位置 | 配置 | 用途 |
| --- | --- | --- |
| `AppConfig.apiBaseUrl` | `https://lz.miro.us.ci` | 后端自定义域（国内可达） |
| `AppConfig.fallbackTotalGb` | 100 | 后端未配 `STORAGE_TOTAL_BYTES` 时的容量兜底 |
| `AppConfig.maxUploadBytes` | 90MB | 单请求/分块上传阈值（与 Worker `MAX_UPLOAD_BYTES` 一致） |
| Cloudflare Secret `STORAGE_TOTAL_BYTES` | 字节数 | 容量总量；未配置返回 0，App 用兜底值 |
| Cloudflare Secret `APP_PASSWORD` | 密码 | 同时作为预览签名 URL 的 HMAC 密钥种子 |
| `AppConfig.useMockData` | false | true 时使用内置示例数据，跳过登录 |

### 8.4 在线查看鉴权设计

图片/视频组件无法附加 `Authorization` 头，因此采用**短期签名能力 URL**：

1. App 调 `GET /api/preview/url?id=<id>`（走正常 Bearer/Basic/Cookie 鉴权）。
2. 后端用 `APP_PASSWORD` 派生 HMAC 密钥，对 `uid:id:exp` 签名，返回 15 分钟有效的 `/api/preview?id=&uid=&exp=&sig=`。
3. `Image.network` / `video_player` / `Dio` 直接加载该 URL（守卫对精确路径 `/api/preview` 放行，路由内自校验 HMAC 与过期时间）。
4. 过期后重新签发即可；URL 泄露仅在 15 分钟内有效。
