# 后端对接教程

本文档说明如何把「轻云」App 从内置示例数据（mock）切换到真实后端，并约定接口调用、鉴权、错误处理与联调规范。客户端网络层代码位于 `lib/core/network/`。

## 1. 总览

```
App (lib/features/*)
   ↓ 只依赖
CloudRepository (lib/core/network/cloud_repository.dart)
   ↓ useMockData=false 时
ApiClient (dio 封装) → 后端 REST API
```

- 页面不直接发请求，统一走 `CloudRepository`，后端字段变化只改这一层。
- 切换步骤：
  1. 修改 `lib/core/config/app_config.dart`：
     ```dart
     static const String apiBaseUrl = 'https://your-api.example.com';
     static const bool useMockData = false;
     ```
  2. 登录成功后调用 `TokenStore.save(token)` 保存 token。

## 2. 接口调用约定

### 2.1 请求

- Base URL：`AppConfig.apiBaseUrl`，所有路径以 `/api/v1` 开头（见 `ApiEndpoints`）。
- 方法：`GET / POST / PUT / DELETE`，请求体 `application/json`。
- 鉴权外的公共 Header：
  ```
  Content-Type: application/json
  Accept: application/json
  ```

### 2.2 响应 envelop（必须遵守）

所有接口返回：

```json
{
  "code": 0,
  "message": "ok",
  "data": { }
}
```

- `code == 0`：成功，`data` 为业务数据（对象或数组）。
- `code != 0`：业务失败，`ApiClient` 会抛出 `ApiException(code, message)`，页面无需自己解析 envelop。

### 2.3 核心接口清单

| 场景 | 方法 & 路径 | 入参 | data 返回 |
| --- | --- | --- | --- |
| 登录 | `POST /api/v1/auth/login` | `{ account, password }` | `{ access_token, refresh_token, user }` |
| 刷新 token | `POST /api/v1/auth/token/refresh` | `{ refresh_token }` | `{ access_token, refresh_token }` |
| 登出 | `POST /api/v1/auth/logout` | — | `null` |
| 容量概览 | `GET /api/v1/storage/summary` | — | `{ used_gb, total_gb }` |
| 文件列表 | `GET /api/v1/files` | `?category=image&keyword=xxx` | `CloudFile[]` |
| 文件详情 | `GET /api/v1/files/{id}` | — | `CloudFile` |
| 下载 | `GET /api/v1/files/{id}/download` | — | `{ url }`（302 到签名下载地址亦可） |
| 分享 | `POST /api/v1/files/{id}/share` | `{ allow_download, require_password, expire_days }` | `{ link, password? }` |
| 回收站 | `GET /api/v1/trash` | — | `CloudFile[]` |
| 恢复 | `POST /api/v1/trash/{id}/restore` | — | `null` |
| 传输列表 | `GET /api/v1/transfers` | — | `TransferTask[]` |
| 暂停/继续/取消 | `POST /api/v1/transfers/{id}/pause|resume|cancel` | — | `null` |

`CloudFile` 字段（`lib/core/models/cloud_models.dart`）：

```json
{
  "id": "f1",
  "name": "海边日落.JPG",
  "category": "image",          // image|doc|video|music|zip|other
  "size_label": "4.2 MB",
  "updated_label": "今天 14:32",
  "starred": false
}
```

> 时间/大小建议后端直接返回展示用文案（`*_label`），与设计稿文案一致；如返回原始值，请在 Repository 层格式化。

## 3. 鉴权

### 3.1 流程

1. 登录接口返回 `access_token`（有效期建议 2h）与 `refresh_token`（建议 30d）。
2. 客户端把 token 存入 `TokenStore`；正式接入请替换为 `flutter_secure_storage` 等加密存储。
3. `ApiClient` 的拦截器自动为每个请求附加：
   ```
   Authorization: Bearer <access_token>
   ```

### 3.2 401 处理约定

- 后端在 token 失效时返回 HTTP `401`，或 envelop `code = 40100`。
- 客户端通过 `ApiException.isUnauthorized` 识别，处理建议：
  1. 用 `refresh_token` 调 `/auth/token/refresh` 换新 token（建议加单飞锁，避免并发刷新）；
  2. 刷新失败 → `TokenStore.clear()` 并跳转登录页；
  3. 原 GET 请求可安全重试一次，非幂等请求（POST/支付类）不要自动重试。

### 3.3 权限设计建议

- 云盘场景至少区分：`owner`（本人文件全权）、`viewer`（只读分享）、`editor`（可上传/编辑）。
- 分享接口返回的 `link` 应为带签名参数的短链，服务端校验有效期与提取码。

## 4. 错误处理

### 4.1 客户端异常模型

所有失败都会变成 `ApiException`（`lib/core/network/api_exception.dart`）：

| 场景 | code | message 示例 |
| --- | --- | --- |
| 业务失败 | 后端 envelop.code | 后端 message 原样透出 |
| HTTP 4xx/5xx | `statusCode*100` | “登录态已失效，请重新登录” 等 |
| 连接失败/断网 | `-1` | “网络连接不可用，请检查网络后重试” |
| 超时 | `-2` | “请求超时，请稍后重试” |
| 取消 | `-3` | “请求已取消” |

### 4.2 页面处理规范

1. **列表/详情类**：失败时展示 `QyEmptyState`（标题 + 描述 + “重新加载”按钮），不要弹窗打断。
2. **操作类**（上传、删除、分享）：失败用 `showQyToast(context, e.message, success: false)`。
3. **可重试判断**：`isServerError` 或网络类错误（code `-1/-2`）才提示重试；`isUnauthorized` 走 3.2 流程。
4. **文案**：后端 message 面向用户可直接展示；禁止把堆栈/内部码透给用户。

## 5. 联调注意事项

1. **环境分离**：`AppConfig` 可扩展为 `dev/staging/prod` 三套 BaseUrl，用 `--dart-define=ENV=dev` 注入，避免联调直连生产。
2. **HTTPS**：Android `usesCleartextTraffic` 未开启，iOS 默认 ATS，联调环境也请使用 HTTPS；自签证书需另行配置信任策略。
3. **文件上传**：大文件走 `multipart/form-data`（`ApiClient.raw` 已暴露原始 dio 能力），建议分片 + 断点续传，进度通过 `/transfers` 轮询或 WebSocket 推送。
4. **下载**：优先让后端返回带时效的签名 URL，客户端用系统下载能力，避免 App 内长期占用连接。
5. **幂等性**：上传/删除/恢复等操作建议携带客户端生成的 `request_id`，后端去重，避免弱网重复提交。
6. **日志**：联调期可在 `ApiClient` 添加 `LogInterceptor`；上线前务必关闭请求/响应体日志，防止 token 泄露。
7. **版本兼容**：envelop 中可增加 `server_version`；客户端检测到不兼容接口时提示升级，而不是静默失败。
8. **联调自检清单**：
   - [ ] `useMockData = false` 且 BaseUrl 正确
   - [ ] 登录 → token 保存 → 带 Authorization 请求成功
   - [ ] token 过期自动刷新一次成功
   - [ ] 断网/超时页面有兜底 UI
   - [ ] 文件列表分类/搜索过滤生效
   - [ ] 回收站恢复、分享链接生成可用

## 6. 快速自测脚本示例

后端就绪前，可用任意 HTTP 服务核对 envelop：

```bash
curl -H "Authorization: Bearer <token>" https://your-api.example.com/api/v1/storage/summary
# 期望：{"code":0,"message":"ok","data":{"used_gb":47.2,"total_gb":128}}
```

App 侧对应展示：`47.2 / 128 GB`（首页容量卡片、容量管理页）。
