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
| 容量概览 | `GET /api/storage/summary` | 返回 `{used_bytes,total_bytes}`；total 来自 `STORAGE_TOTAL_BYTES` |
| 文件列表 | `GET /api/list?pid=0` | 节点 `{id,pid,name,type,size_bytes,created_at}`；仅取 `type=file` |
| 搜索 | `GET /api/search?q=` | 全局文件名匹配 |
| 删除 | `POST /api/delete` `{ids:[number]}` | 移入回收站 |
| 回收站 | `GET /api/bin` | 同文件列表结构 |
| 恢复 | `POST /api/restore` `{ids}` | — |
| 彻底删除 | `POST /api/hard-delete` `{ids}` | — |
| 清空回收站 | `POST /api/empty-bin` | — |
| 生成分享 | `POST /api/share` `{id,expiresInDays,password?}` | 返回 `{code,url}`，App 取 `url` |
| 我的分享数 | `GET /api/my-shares` | App 取 `items.length` |
| 下载地址 | `GET /api/download?id=` | 302 直连蓝奏云 CDN；兜底 `/api/stream?id=` 代理流（支持 Range） |
| 上传 | `POST /api/upload?pid=0` | raw body + 头 `X-Heri-Name: <文件名>`，单请求 ≤ 90MB；大文件走 `/api/upload/chunk` 分块 |
| 传输任务 | App 本地模型 | lanflare 无服务端任务列表；`LocalTransferStore` 在上传/下载时记录，dio 回调驱动进度 |

分类映射：lanflare 节点没有 category 字段，App 按 `FileCategoryX.fromFileName(文件扩展名)` 推断（图片/文档/视频/音乐/压缩包/其他）。

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
