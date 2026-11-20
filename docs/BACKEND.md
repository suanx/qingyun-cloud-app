# 后端对接教程

本文档说明「轻云」App 如何对接真实后端，并约定接口调用、鉴权、错误处理与联调规范。客户端网络层代码位于 `lib/core/network/`。

**当前已对接的后端是 [lanflare](https://github.com/suanx/lanflare)**（Cloudflare Workers + D1 + 蓝奏云网盘）。App 全部数据来自该后端的真实接口。

## 1. 总览

```
App (lib/features/*)
   ↓ 只依赖
CloudRepository (lib/core/network/cloud_repository.dart)
   ↓
ApiClient (dio 封装) → lanflare /api/*（Cloudflare Workers）
```

- 页面不直接发请求，统一走 `CloudRepository`，后端字段变化只改这一层。
- `lanflare` 返回原生 JSON，由 `ApiClient.getRaw/postRaw` 直接解包；`{ "error": "..." }` 与 HTTP 4xx/5xx 统一映射为 `ApiException`。
- 登录页：`lib/features/login/login_screen.dart`。未登录时路由守卫（`AppRouter._authGuard`）会把所有页面重定向到 `/login`；任意接口返回 401 时自动清凭证并回登录页。

### 1.1 切换 / 配置步骤

1. 部署 lanflare（见其仓库 README），拿到服务地址，例如 `https://lanflare.<你的子域>.workers.dev`。
2. 修改 `lib/core/config/app_config.dart`：
   ```dart
   static const String apiBaseUrl = 'https://lanflare.<你的子域>.workers.dev';
   ```
3. （可选）在 lanflare 侧配置 `STORAGE_TOTAL_BYTES` 变量/secret，作为容量总量；未配置时 App 使用 `AppConfig.fallbackTotalGb`（100 GB）兜底。
4. App 内使用 lanflare 账号登录（`POST /api/auth/login`，开启 TOTP 时额外填验证码）。

## 2. lanflare 接口映射（App 实际使用）

| App 场景 | lanflare 接口 | 说明 |
| --- | --- | --- |
| 登录 | `POST /api/auth/login` `{u,p,code?}` → `POST /api/tokens` | 校验 `{error}` 后读取 `Set-Cookie: lf_session`，再用会话换发 `lf_` 令牌并加密保存；**不存账号口令** |
| 退出登录 | `DELETE /api/tokens/:id` + `TokenStore.clear()` | 先吊销服务端令牌（此时仍有鉴权），再清本地 |
| 登录设备 / 凭证列表 | `GET /api/tokens` | 返回本人 `{items:[{id,name,prefix,created_at,last_used_at,scope}], count}`；服务端只存哈希、只下发前 12 位 prefix |
| 新建 / 重命名 / 吊销凭证 | `POST /api/tokens`、`PATCH /api/tokens/:id`、`DELETE /api/tokens/:id` | 明文仅创建时返回一次；重命名用作设备备注；吊销 = 让该设备下线（仅本人） |
| 两步验证状态 | `GET /api/security/2fa` | 返回 `{enabled, pending_setup}` |
| 两步验证绑定 / 开关 | `POST /api/security/2fa/{setup,enable,disable}` | setup 返回 Base32 密钥、`otpauth://` URI 与二维码模块矩阵；enable/disable 需 6 位动态码 |
| 账户状态 | `GET /api/status` | 返回 `{storage_connected, username, role, vip_until, file_count, share_count, trash_count, token_count}`；驱动首页头图、我的页头图 / VIP 徽章 / 三项统计 / 会员横幅 |
| 管理员用户列表 | `GET /api/admin/users` | 仅 admin；返回 `{items:[{id,username,role,vip_until,disabled,created_at,files}], current_uid}` |
| 设置会员天数 | `POST /api/admin/users/:id/vip` `{days}` | 仅 admin；`days` 为 0~3650 整数，0 = 取消，正数从 `max(now, 现有到期)` 累加；返回 `{ok,username,days,vip_until}`，不接支付 |
| 存储账号状态 | `GET /api/storage/account` | 返回 `{bound, username, connected, checked, check_ok, check_error, bound_at, root_folder_id, root_folder_name, active_file_count}`；`?check=0` 跳过连通性外呼；**不返回会话凭据** |
| 绑定 / 重新绑定存储账号 | `POST /api/storage/login` `{username,password}` | 密码即时换取会话、不落盘；写入账号名与绑定时间，清旧 root 缓存后重建 `.lanflare`；返回 `{ok,logged_in,username,bound_at,root_folder_id}` |
| 解绑存储账号 | `POST /api/storage/logout` | 删除该用户 6 个存储 meta 键，不删 VFS 文件记录 |
| 容量概览 | `GET /api/storage/summary` | 返回 `{used_bytes,total_bytes,by_category}`；total 来自 `STORAGE_TOTAL_BYTES` |
| 文件列表 | `GET /api/list?pid=&sort=` | 节点 `{id,pid,name,type,size_bytes,created_at}`；响应回显 `sort` 与 `storage_ready`；`includeDirs=true` 时目录也进入列表并支持钻取；排序键白名单见 2.8 |
| 目录树 | `GET /api/folders` | 本人全部活跃目录 `{items:[{id,pid,name,path}], count}`，供「移动到…」选择器；`path` 为可读绝对路径 |
| 搜索 | `GET /api/search?q=` | 全局文件名匹配（仅活跃文件，含所在路径） |
| 快捷筛选 / 最近文件统计 | `GET /api/stats/quick` | 返回 `{total_files, counts:{image,doc,video,music,zip,other}, recent_updated_at, recent_files:[{id,name,created_at}]}`；仅统计本人活跃文件，扩展名分组与 `FileCategoryX.fromFileName` 一致 |
| 服务自检 | `GET /api/server-info` | **公开、无需登录**：`{service,version,runtime,server_time,schema_version,max_upload_bytes,signing_mode,storage_total_configured,features}`；`signing_mode` = `dedicated` / `legacy`（见 7.4.1），不含账号或密钥，供设置页在登录前验证自建 VPS 域名 |
| 提交反馈 | `POST /api/feedback` `{category,content,contact?}` | 内容 5~2000 字；同一用户 60 秒冷却、最多 50 条；返回 `{ok,item}` |
| 我的反馈 | `GET /api/feedback` | 本人条目（最多 50 条，时间倒序），含 `status` / `admin_reply` / `replied_at` |
| 反馈管理（仅 admin） | `GET /api/admin/feedback` / `PATCH /api/admin/feedback/:id` | 全量列表（附 username，未处理优先）+ 回复 / 改状态；写回复自动置 `replied_at` |
| 新建文件夹 | `POST /api/mkdir` `{pid,name,ensure:true}` | 同名目录复用 |
| 重命名 | `POST /api/rename` `{id,name}` | 预览页工具调用 |
| 删除 | `POST /api/delete` `{ids:[number]}` | 移入回收站 |
| 回收站 | `GET /api/bin` | 同文件列表结构 |
| 恢复 | `POST /api/restore` `{ids}` | — |
| 彻底删除 | `POST /api/hard-delete` `{ids}` | — |
| 清空回收站 | `POST /api/empty-bin` | — |
| 生成分享 | `POST /api/share` `{id,expiresInDays,password?}` | 返回 `{code,url}`，App 取 `url` 并复制到剪贴板 |
| 解析分享码 / 扫码原文 | `POST /api/resolve-share` `{code}` | 接受完整码 / 分享链接 / 纯 token / 带说明文字的二维码文本；服务端规范化后返回 `{ok,code,name,sizeBytes,chunks,kind?,files?}`，**回显的 `code` 原样传给 `/api/rent`** |
| 转存分享 | `POST /api/rent` `{code,pid}` | `pid` ≥0 整数（0 = 根目录）；返回 `{ok,kind,node,created,skipped}`；需 rw 令牌 |
| 扫码统一解析 | `POST /api/scan/resolve` `{raw,pwd?}` | 后端自动判别两种来源，返回判别联合结果；详见 2.11 |
| 蓝奏导入提交 | `POST /api/import-lanzou` `{importId,pid}` | 消费一次性凭证，落 `alien://` 节点；返回 `{ok,kind,node,created,skipped}`；需 rw 令牌 |
| 我的分享 | `GET /api/my-shares` / `DELETE /api/shares/:id` | 分享列表与撤销 |
| 下载地址 | `GET /api/download?id=` | 302 直连蓝奏云 CDN；兜底 `/api/stream?id=` 代理流（支持 Range） |
| 下载并打开 | `GET /api/stream?id=` + Dio 直写文件 | 保存到应用私有目录 `downloads/`，`open_filex` 打开；进度写本地任务 |
| 每日照片回忆 | `GET /api/recall/daily?today=YYYY-MM-DD` | **新增**：只读聚合本人活跃图片的真实上传日期，返回 `{has_memory,kind,date,title,count,truncated,items:[{id,name,created_at,preview_url}],preview_expires_at}`；缩略图 URL 复用预览 HMAC 签发；详见 2.12 |
| 照片回忆相册 | `GET /api/recall/album` | **新增**：按真实上传日期分组的本人活跃图片，返回 `{has_photos,total_groups,total_photos,truncated,groups:[{date,title,count,items:[{id,name,created_at,preview_url}]}],preview_expires_at}`；零视频生成、零 ffmpeg、零新增依赖；详见 2.13 |
| 在线查看 | `GET /api/preview/url?id=` → `GET /api/preview?...` | **新增**：签发 15 分钟 HMAC URL，供 Image.network / video_player / PDF 缓存下载无请求头加载；支持 Range 与正确 MIME（PDF 见 2.15） |
| 清理建议 | `GET /api/storage/analyze` | 只读分析重复文件 / 大文件 / 空文件夹，返回三组 `item_ids` 与可释放字节数 |
| 执行清理 | `POST /api/storage/clean` `{ids:[number]}` | 把建议中的节点移入回收站（可用 `/api/restore` 恢复）；后端二次校验 id |
| 上传 | `POST /api/upload?pid=` | raw body + 头 `X-Heri-Name: <文件名>`，单请求 ≤ 90MB；大文件走 `/api/upload/chunk` 分块 |
| 分块上传 | `POST /api/upload/chunk?pid=` | 每块一个请求；头含 `X-Heri-File-Size`（真实总字节数），后端严格累加校验后写入正确 `size_bytes`；详见 2.6 |
| 放弃分块上传 | `POST /api/upload/chunk/abort` `{uploadId}` | **新增**：删除未完成的 `.chunk-<uploadId>` 云端目录并清会话；幂等、保护已 finalize 的目录；客户端上传失败时调用 |
| 传输任务 | App 本地模型 | lanflare 无服务端任务列表；`LocalTransferStore` 在上传/下载时记录，dio 回调驱动进度 |

分类映射：lanflare 节点没有 category 字段，App 按 `FileCategoryX.fromFileName(文件扩展名)` 推断（图片/文档/视频/音乐/压缩包/其他）。后端 `/api/storage/summary` 的 `by_category` 也按扩展名归类（image/video/music/doc/archive），前端「存储空间」图例直接使用。

### 2.1 账户状态字段（`GET /api/status`）

`vip_until` 是毫秒 epoch：`0` = 从未开通，小于当前时间 = 已过期，大于当前时间 = 有效期内。App 据此派生「未开通 / 已过期 / VIP 剩余 N 天」三态，不再使用编造数值。`role` 为 `admin` 或 `user`；`storage_connected` 反映蓝奏云会话是否可连通（VPS 上未绑定存储账号时为 false）。四个计数均按 `uid` 限定本人：活跃文件数、分享数、回收站文件数、API 令牌数。

> 原头图的文件 / 分享 / 设备三项计数都是写死的假数值。lanflare 没有独立设备表，第三项改用真实存在的 **API 令牌数**（语义对应「登录凭证」）；「设备管理」页已在这份令牌数据上实现列表、备注与吊销（见 2.3）。

### 2.2 会员管理契约（方案 C，不接支付）

App 内「会员管理」页（`AppRouter.adminVip`，仅 `role=admin` 可见）直接调用后端已有的 admin 接口，不引入订单 / 支付系统：

- 入口三处：我的页「会员管理」cell（仅 admin）、VIP 横幅「查看」弹窗里的「管理会员」（仅 admin）、首页容量卡「升级」与存储页「查看会员」按钮（admin 直达管理页，普通用户展示真实会员状态说明）。
- `days > 0`：服务端按 `max(Date.now(), vip_until) + days × 86400_000` 累加，**重复提交会叠加天数**，前端在弹窗里明确提示「天数为累加」。
- `days = 0`：`vip_until = 0`，取消会员，之后可重新设置。
- 服务端校验 `days` 为 0~3650 的整数、用户 id 为正整数、结果时间戳为 safe integer；每次变更发 `vip_changed` 通知。
- 前端进入页面先调 `GET /api/status` 校验 `isAdmin`，非管理员显示「仅管理员可用」；后端 `requireAdmin()` 是最终防线。
- 权限是**即时生效**的：`getAuth()` 每次请求从 DB 读用户，设置后目标用户无需重新登录即可看到新状态。

### 2.3 登录设备与两步验证契约

**设备 = API 令牌。** lanflare 不维护设备表：每次 App 登录换发一个 `lf_` 令牌，令牌行天然携带「登录时间」(`created_at`) 与「最近活跃」(`last_used_at`，每分钟最多刷新一次)。因此 `GET /api/tokens` 就是真实的登录凭证列表，吊销即让对应设备在下一次请求收到 401。所有令牌接口按 `uid` 限定本人；`ro` 令牌被 `/api/*` guard 拦截所有非 GET 请求，无法改自己的权限或吊销他人凭证。

- **创建**：`POST /api/tokens {name, scope:"rw"|"ro"}`，明文 `lf_...` 只在响应里出现一次，服务端只存 SHA-256 哈希与 12 位 prefix。App 用可选中文本 + 一键复制展示一次，之后只能凭 prefix 识别。
- **重命名**：`PATCH /api/tokens/:id {name}`，≤40 字，作为设备备注（本轮新增）。
- **吊销**：`DELETE /api/tokens/:id`。前端用 `TokenStore.tokenId` 标注「当前设备」并**禁止在此吊销**（否则自己会被 401 踢下线），引导改用「退出登录」——它会先吊销再清本地。
- **通知**：创建 / 吊销会发 `token_created` / `token_revoked`，便于 VPS 运维追踪。

**两步验证（TOTP, RFC 6238）**：

| 端点 | 说明 |
| --- | --- |
| `GET /api/security/2fa` | `{enabled, pending_setup}`；`pending_setup` 表示有未完成的绑定，继续 setup 会覆盖 |
| `POST /api/security/2fa/setup` | 生成新密钥写入 `totp_secret_pending`；返回 `{enabled, secret, uri, qr}` |
| `POST /api/security/2fa/enable` | `{code}` 6 位数字，校验 pending 密钥后转正并清 pending |
| `POST /api/security/2fa/disable` | `{code}` 6 位数字，校验当前密钥后关闭 |

`qr` 是 `{size, modules}`：`modules` 为 `size×size` 的 `'0'/'1'` 行优先矩阵，由后端用已有的 `qrcode-generator` 生成。**不返回 SVG / 图片**，前端用纯 Dart `CustomPainter`（`lib/widgets/qr_code_view.dart`）画格子，零新增依赖；同时展示分组后的 Base32 密钥供手动输入/复制。

开启 2FA 后，`POST /api/auth/login` 会返回 `401 {error:"需要两步验证码", needs_2fa:true}`；登录页已有验证码输入框，失败时自动聚焦并把键盘切成数字，不会把用户锁在门外。`enable/disable` 均校验请求体容错与 6 位数字格式，避免 VPS 上收到畸形 JSON 直接 500。

**自助修改密码（2026-11-20 对接核查新增）**：`POST /api/auth/change-password {current, next}`。此前两端都声称保留「改自己密码」的自助能力，但后端实际没有端点、App 也没有入口，用户只能找管理员重置。现后端已补齐：需登录态，目标用户恒为当前登录者（不接受指定 uid），校验当前密码后才写入，新密码 ≥6 位且不能与当前相同；`/api/auth/*` 属自助写白名单，普通用户可用，`ro` 令牌仍被守卫拦截。App 安全中心已加「修改登录密码」入口（`CloudRepository.changePassword`），成功后现有会话与令牌继续有效。

### 2.4 存储账号绑定契约（历史契约，账号池改造后 App 已不调用）

> **2026-11-20 对接核查更新**：后端已完成「管理员全局存储账号池」改造（见后端 README「存储账号池」与 2.18 预留节口径）：存储账号由管理员在网页端统一管理，App 无绑定入口，池状态经 `GET /api/status` 的 `storage_pool` 展示。本节三个端点在后端仅作管理员运维兼容保留（`GET /api/storage/account` 已改为管理员专用），App 仓库层对应的死代码（`storageAccount / bindStorageAccount / unbindStorageAccount` 与 `StorageAccountStatus / StorageBindResult` 模型）已删除。下文契约仅供运维脚本与历史排查参考。

**两个账号不要混**：`AccountStatus.username` 是 lanflare 的 App 登录账号（users 表）；`StorageAccountStatus.username` 是蓝奏云存储账号（绑定时写入 `u<uid>:storage_account`）。文件物理存放在后者，未绑定时 `/api/delete`、`/api/storage/clean` 等会返回 503「请先绑定存储账号」，上传/下载/分享同样不可用。

| 端点 | 契约 |
| --- | --- |
| `GET /api/storage/account` | `bound` = 是否存有 `ylogin`+`phpdisk_info`；`connected` = 真实外呼 `checkLoggedIn()` 的结果，外呼加 **6 秒 `Promise.race` 超时**（VPS 上存储端不可达时不会挂死页面）；`checked` 区分「未检测」，`check_ok=false` + `check_error` 区分「网络不可达 / 超时」与「会话已失效」；`bound_at` 毫秒时间戳；`active_file_count` 为换绑警告依据。**绝不返回** `ylogin` / `phpdisk_info` / 密码 |
| `POST /api/storage/login` | 校验账号密码长度（≤128 / ≤256），调 `lanzouLogin()` 换会话；密码**只在请求体中出现一次**，服务端只写会话、`storage_account`、`storage_bound_at`；上游失败用 `ApiError(400)` 保留中文错误详情，不再是 500 |
| `POST /api/storage/logout` | 删除 6 个 meta 键：`ylogin`、`phpdisk_info`、`root_lanzou_id`、`root_name`、`storage_account`、`storage_bound_at`；发 `storage_unbound` 通知 |

**本轮修掉的一个真实 bug**：原来的 `/api/storage/login` 只覆盖会话，不清除缓存的 `root_lanzou_id`。换绑到**不同**存储账号时，`ensureRoot()` 会直接返回旧账号的 `.lanflare` 目录 id，导致新上传全部落到旧账号。现在绑定前先删 `root_lanzou_id` / `root_name`，再重建根目录。

`/api/lanzou/login` 与 `/api/lanzou/logout` 是历史别名，本轮改为调用**同一对公共函数**，两条路径行为不再漂移。

**换绑限制（需在 App 内提示）**：`nodes` 表里已有文件的 `lanzou_id` 仍指向原账号，切换账号后旧文件可能无法下载/删除；后端不做跨账号迁移。App 的「重新绑定」确认框会显示真实 `active_file_count` 并二次确认。历史绑定记录没有 `storage_account` / `storage_bound_at`，前端显示「未知（旧绑定记录）」与「—」，不编造数值。

移动端「存储空间 → 管理」进入 `AppRouter.storageAccount` 页：状态卡（账号名/连通性/绑定时间/根目录/活跃文件）、绑定表单（密码 obscure、提交后立即清空、不持久化）、重新检测、解绑（二次确认）。绑定/解绑返回后刷新容量与清理建议。

### 2.5 清理建议契约

`GET /api/storage/analyze` 只读、不调用蓝奏云；统计当前用户 `is_trashed=0` 的节点：

| 分组 key | 判定 | 保留规则 |
| --- | --- | --- |
| `duplicate` | 同名 + 同字节大小的活跃文件 | 每组保留 `created_at` 最新的一份，其余列为可清理 |
| `large` | `size_bytes >= 100MB`（可用 `?threshold=` 调整） | 全部列为建议检查项 |
| `empty_dir` | 无任何活跃子节点的目录 | 全部列为可清理 |

一个节点可能同时落在多组，`total_count` / `total_reclaimable_bytes` / `cleanable_ids` 按 id 去重。`groups[].items` 最多返回 200 条明细，但 `item_ids` 是全量，聚合值始终是精确值。

`POST /api/storage/clean {ids:[]}` 会**重新跑一次分析**，只接受仍在建议集合中的 id，因此客户端无法借这个接口移走任意文件；未绑定存储账号且存在活跃文件时返回 503（与 `/api/delete` 一致）。清理动作复用 `trashNodes()`，是「移入回收站」而非彻底删除，可在回收站恢复。该接口是 POST，`ro` 令牌会被 `/api/*` guard 拦截。

### 2.6 分块上传契约（>90MB，已修正真实大小与残留目录）

`POST /api/upload/chunk?pid=` 每块一个请求，必须携带：

| 头 | 含义 |
| --- | --- |
| `X-Heri-Name` | `Uri.encodeComponent(文件名)`，每块都要带 |
| `X-Heri-Upload-Id` | 本批次唯一 id；仅允许 `[A-Za-z0-9._-]`、≤128 字符（用于 meta key 与云端目录名） |
| `X-Heri-Chunk-Index` | 块序号，**从 0 起**、严格递增且首块先到（乱序/重复块返回 409） |
| `X-Heri-Chunk-Total` | 总块数（上限 4096，全程一致） |
| `X-Heri-File-Size` | **真实文件总字节数**（0 < n ≤ 10GiB）。网页端 `ui.ts` 与 `/docs` 早有此头，旧后端从未读取 |
| `X-Heri-Finalize` | 仅最后一块传 `1`，触发合并入库 |
| `Content-Length` | 本块字节数，单块同样受 90MB 上限约束 |

非 finalize 块返回 `{ok:true, received:index, sum}`，finalize 块返回 `{ok:true, node}`。App 按 8MB 切块、网页端按 90MB 切块，均串行发送、仅末块置 finalize。

**修正 ①：`size_bytes` 不再是最后一块大小。** 新增 `lanflare/src/chunk_session.ts` 会话状态机（只用现有 `meta` 表，**无新增表 / 迁移 / schema 变更**）：

- 服务端按 `index === next` 严格串行累加每块 `Content-Length` 得到 `sum`，并与 `X-Heri-File-Size` 声明比对；**只有 `sum === declared` 才允许 finalize**，写入节点的 `size_bytes` 是验证过的真实总大小。
- 累计超过声明、声明前后不一致、块数不符、缺块、序号跳变一律 **409** 并给出真实字节数，绝不静默写错值。旧客户端不带该头时以服务端 `sum` 为准（仍是真实累加值，不是编造值）。
- `size_bytes` 影响容量环 `SUM(size_bytes)`、分类统计、大小排序、分享落地页与文件列表显示，因此这是数据正确性修复，不是显示微调。

**修正 ②：中途失败不再残留 `.chunk-<uploadId>` 云端目录。** 三条互补路径：

| 路径 | 说明 |
| --- | --- |
| 客户端显式放弃 | 新增 `POST /api/upload/chunk/abort {uploadId}`；App 与网页端在分块上传抛异常时调用（幂等、不覆盖原异常） |
| 新批次惰性清理 | `index=0` 时扫描本人 **24 小时前**的废弃会话，每批最多 3 个，逐外呼删除云端目录；失败保留 meta 供下次重试，不影响本次上传 |
| 安全护栏 | 删云端目录前查 `nodes` 是否仍有节点引用该 `lanzou_id`（**含回收站节点**，恢复需要数据）：有则**绝不删云端数据**，只清会话（`protected=true`）。因此「finalize 成功但响应丢失 → 客户端 abort」不会误删已上传文件 |

会话 bookkeeping 写在现有 `meta` 的 `chunksession:<id>` / `chunkfolder:<id>` 键里：`vfs.ts` 新增 `metaListKeys()` 供过期扫描，D1Like 最小接口，D1 与 VPS SQLite 通用。`finalize` 是**先插入节点、再清会话**，配合上面的护栏保证任何竞态都只清记录不动数据。

`POST /api/upload/chunk/abort` 返回 `{ok, cleaned, hadSession, protected}`：未知 / 已清理的 id 是 no-op；未绑定存储账号返回 503 且**保留记录**供重试；`ro` 令牌被 `/api/*` guard 拦截。

### 2.7 快捷筛选统计契约（搜索页）

原型搜索页有三组写死的假数值（图片 / 文档 / 传输任务计数），配有按地点聚合、写死更新时间一类编造描述；还列了几条带「热」「新」徽章的编造热搜词，而私有网盘根本没有全站热度。本轮全部替换为真实数据：

| 展示位 | 真实来源 |
| --- | --- |
| 「图片 · N 个文件」 | `GET /api/stats/quick` 的 `counts.image` |
| 「文档 · N 个文件 · 最近更新 X」 | 同上 `counts.doc` + `recent_updated_at`（毫秒 epoch，前端派生「今天 HH:mm / 昨天 / 日期 / 暂无文件」） |
| 「传输记录 · N 个任务进行中」 | **本地** `LocalTransferStore.instance.running.length`（真实任务模型，随任务状态变化刷新） |
| 「最近文件」列表 | 同上接口 `recent_files`（最多 5 个，按 `created_at` 倒序），点击后以文件名主名作为搜索词 |

后端 `src/stats.ts` 用**一条聚合 SQL**算出分类计数与 `MAX(created_at)`，再用一条小查询取最近 5 个文件；只用 `D1Like` 最小接口，D1 与 VPS SQLite 都能跑。扩展名集合与前端 `FileCategoryX.fromFileName` 逐项对齐（含 `svg` / `flv` / `csv`，这三样是 `/api/storage/summary` 的 `by_category` 没覆盖的）。

**口径差异（有意为之）**：`/api/stats/quick` 明确带 `is_trashed = 0`，与 `/api/search` 的 `searchNodes()` 一致；而 `/api/storage/summary` 的 `used_bytes` / `by_category` **没有**排除回收站文件，那是容量口径（删到回收站仍占空间）。两者不要互相校验，语义不同。

**状态处理**：统计加载中显示 `—` 与「统计加载中」，失败显示 `?` 与「统计不可用」，**任何情况下都不回退到编造数值**；「最近文件」区有独立刷新入口。无文件时显示「暂无文件，上传后可在此快速定位」。搜索框 hint 也从「搜索文件名 / 内容」收敛为「搜索文件名」——后端只做文件名 LIKE 匹配，不索引内容。

### 2.8 文件页排序 / 批量操作契约

原型文件页右上「排序」「更多」两个按钮都是 `功能待接入` toast，SectionHead 还写死「按修改时间」，而后端 `listChildren()` 实际上是 `ORDER BY type, name COLLATE NOCASE`（按名称）——**文案与实现相反**。本轮全部对齐为真实行为。

**排序**：`GET /api/list?pid=N&sort=KEY`，`KEY` 取 `name_asc`（默认）/ `name_desc` / `time_desc` / `time_asc` / `size_desc` / `size_asc`。后端 `LIST_SORT_ORDERS` 是**固定 SQL 片段白名单**，客户端字符串只做查表，未知值静默回退 `name_asc`（保证网页端 `ui.ts`、CLI、旧版 App 不传 sort 时行为不变），响应回显实际生效的 `sort`。SQL 始终 `ORDER BY type, <order>, id ASC`：目录排在文件前，前端再拆成两组；`id` 作稳定 tie-break 保证重复加载不乱序。

前端 `FileSort` 枚举的 `query` 与后端键逐字一致；`files()` **只在 `/api/list` 分支传 sort**，`/api/search` 仍按后端默认顺序（搜索页不用排序）。`ProtoSectionHead.more` 改为动态显示 `_sort.label`，点击与右上排序按钮打开同一菜单。默认 `time_desc`，与文件习惯一致，也顺带让首页/相册拿到时间倒序的真实顺序。

**批量操作**：右上「更多」打开菜单（批量管理 / 排序 / 新建文件夹 / 刷新 / 返回上一级 / 回到根目录）。进入批量模式后，文件行与文件夹卡片显示选中态，底部操作栏提供「移动」「删除」。

| 操作 | 接口 | 说明 |
| --- | --- | --- |
| 移动 | `GET /api/folders` 选目标 + `POST /api/move {ids,pid}` | 目标选择器列出**全部**活跃目录（带绝对路径）与根目录；前端按 `pid` 关系算出「被移动目录自身 + 全部子孙」并禁用，后端 `moveNodes()` 二次防环，同名冲突返回 409 |
| 删除 | `POST /api/delete {ids}` | 移入回收站（可恢复），二次确认，文件夹内文件一并处理 |
| 重命名 | `POST /api/rename {id,name}` | 行操作菜单；前后端都禁止 `/`、`\`、控制字符与超过 255 字，避免污染 `/api/folders` 的 path |
| 查看详情 | 本地 `CloudFile` | 名称 / 类型 / 分类 / 大小 / 创建时间 / 节点 ID / 所在目录，全部为真实字段 |

**行内菜单**：文件行尾 `more_vert` 与文件夹卡片右上角 `more_horiz` 原为纯装饰图标，现在都打开真实操作菜单（打开 / 重命名 / 移动到… / 移入回收站 / 查看详情）。单文件与批量模式复用同一组 `_rename` / `_moveIds` / `_deleteIds` 方法，不产生两套逻辑。

**目录钻取**：维护 `_trail` 返回栈，进入子目录记录父 pid 与父名称，支持「返回上一级」「回到根目录」并显示真实目录名（不再是 `#id`）。

**本轮顺带加固的后端校验**：`/api/list` 校验 pid 为有限非负整数；`/api/move` / `/api/delete` 用 `parseIds()` 校验 `ids` 为 1~500 个正整数（去重），畸形 JSON 返回 400 而不是 500；`/api/mkdir` / `/api/rename` 的名称经 `validateNodeName()` 统一校验。响应契约不变，网页端与 CLI 不受影响。

### 2.9 设置 / 帮助与反馈契约

原型「帮助与反馈」「设置」两个 cell 都是 `功能待接入` toast。本轮做成真实功能，且对 VPS 自部署是关键一环。

**设置页（`/settings`）**

| 功能 | 真实实现 |
| --- | --- |
| 服务地址 | `AppConfig.apiBaseUrl` 是编译默认值；用户在设置页填写的覆盖值写入 `SharedPreferences`（key `qingyun_api_base_url_override`），`SettingsStore.applyToApiClient()` 在 `main()` 启动时同步给 `ApiClient.shared`，保存时立即生效 |
| 地址校验 | `SettingsStore.normalizeBaseUrl()` 只接受 http/https 的 origin：去掉尾斜杠，拒绝路径 / 查询 / userinfo / 非法端口；非法输入不写入 |
| 测试连接 | `GET /api/server-info`（公开端点），测量往返延迟并展示真实 `runtime`（`node-sqlite` = VPS / `cloudflare-workers` = D1）、`version`、`schema_version`、`server_time`、`max_upload_bytes`、`storage_total_configured`；**第 18 步起** `signing_mode` 也做成真实状态行（独立密钥 / 兼容模式 / 未知，见 2.17）；返回 `service != lanflare` 时明确提示「不是 lanflare 服务」 |
| 清除搜索历史 | `SettingsStore.clearSearchHistory()`，与搜索页共用 `qingyun_search_history` key（原为私有常量，已统一） |
| 清除传输记录 | `LocalTransferStore.clear()`，返回真实清除条数；设置页监听任务模型实时显示当前条数 |
| 关于 / 文档 | 显示 `AppConfig.versionLabel`、真实生效的基地址；复制 `<baseUrl>/docs`，不编造第三方链接 |

**切换服务后必须重新登录**：新 VPS 是独立数据库，原服务的令牌 / 会话在新库里不存在，任意接口会 401 → 全局跳登录页。设置页保存后明确提示，并提供「退出登录并切换服务」按钮，底部脚注也写明这一点。

**帮助与反馈页（`/help`）**

FAQ 7 条全部描述本项目**已落地**的真实行为（双账号模型、2FA、回收站需手动清空、90MB/8MB 分块、换绑不迁移、服务地址切换、反馈可见范围），不再是装饰文案。

后端新增 `src/feedback.ts` + `feedback` 表：

- `POST /api/feedback`：分类白名单 `bug/feature/question/other`，内容 5~2000 字、联系方式 ≤100 字；**数据库级**限流（同一 uid 60 秒冷却、最多 50 条），Worker 冷启动 / VPS 重启都不会丢状态；提交时发 `feedback_new` 通知
- `GET /api/feedback`：只返回本人条目（uid 限定）
- `GET /api/admin/feedback` + `PATCH /api/admin/feedback/:id`：`requireAdmin()` 守卫，管理员看全量并回复 / 标记 `open/replied/closed`，回复 ≤2000 字；清空回复会归零 `replied_at`
- `ro` 令牌被全局守卫拦在写接口外；提交后用户能在「我的反馈」看到管理员回复，闭环不依赖任何第三方服务

**VPS 迁移**：`schema.sql` 已加 `CREATE TABLE IF NOT EXISTS feedback` + 索引；`migrations/007_feedback.sql` 供已存在的库升级。`src/server/main.ts` 本来就逐语句重放所有迁移，全新库与旧库都会得到该表，**无需改启动代码**。Cloudflare D1 运营者需手动执行一次 007（命令写在迁移文件头注释里）。`GET /api/server-info` 回显的 `schema_version` 同步为 7（其后存储账号池迁移 008 落地后已升为 **8**，以服务端 `SCHEMA_VERSION` 常量为准）。

### 2.10 扫一扫 / 分享转存契约

首页「扫一扫」原为 `功能待接入` toast。本轮做成完整真实链路：

**扫码 → `POST /api/resolve-share` → 展示解析结果 + 选目标目录 → `POST /api/rent` → 显示新建/跳过数量 → 查看文件。**

**后端扩展**：`src/share.ts` 新增 `normalizeShareCode(db, raw)`，把扫码原文规范化成标准分享码：

| 输入 | 规范化结果 |
| --- | --- |
| `lanflare://f/<id>` / `lanflare://<payload>` / `heri://` 旧码 | 原样（scheme 统一小写） |
| 带说明文字的二维码文本（如「分享码：lanflare://...」） | 提取其中的完整码 |
| `https://host/s/<token>` 分享链接 | 取 `/s/` 段；查 `shares` 表：命中 → `lanflare://f/<token>`，未命中 → `lanflare://<token>`（加密 payload） |
| 纯 token | 同上（按 `shares.id` 是否存在决定前缀） |

**为什么必须放在后端**：`/s/<token>` 的 token 既可能是 `shares.id`（短码），也可能是加密 payload token，只有服务端查库/解密能区分；客户端自己拼前缀会静默得到「分享不存在」。`POST /api/resolve-share` 现在**回显规范化后的 `code`**，前端把它原样传给 `/api/rent`，保证两次请求解释一致。网页端 `ui.ts` 的转存对话框同样受益（现在可直接粘贴分享链接）。

同时加固：`/api/resolve-share`、`/api/rent` 加 JSON 容错（畸形 body 从 500 变 400）、码长度 ≤8192；`/api/rent` 的 `pid` 必须为 ≥0 整数（原来 `Number(pid) || 0` 会静默接受负数）。`ro` 令牌仍被全局守卫拦在写接口外。`/docs` 已补齐这两个端点的说明。

**短码跨实例边界**：短 `lanflare://f/<id>` 只在创建它的实例有效（VPS 是独立 SQLite 库）。扫到别的 lanflare 服务生成的短链接，本实例查库失败 → 明确报错；跨实例转存请让对方使用完整 `lanflare://<payload>` 码（payload 自包含文件内容描述，不依赖短码表）。页面脚注也写明这一点。

**扫的是哪种二维码**：lanflare 的分享体系是自己的 `lanflare://` 码 / `/s/<token>` 链接（由 `POST /api/share` 生成，App「分享」复制的就是这个链接）。**蓝奏云原生分享链接自 2.11 起也已支持**，扫码页统一走 `POST /api/scan/resolve` 自动判别，无需用户选择来源。

> **勘误（上一轮说明有误）**：上一步曾写「蓝奏原生链接当前不支持」「需后端新增接口、用已绑定存储账号的 session 调 `getShareInfo`」。核实源码后确认两点都不对：lanflare 仓库里 `src/lanzou_import.ts`（纯解析 + 域名白名单）、`src/lanzou.ts` 的 `probeLanzouShare()`、`src/share.ts` 的 `importLanzouShare()` **早已写好，只是零调用、没有对外端点**；而且导入路径**完全不需要存储账号 session**——抓公开分享页探测，落 `alien://` 节点，下载时懒解析直链。第 10 步做的是把这套死代码接成端点，不是重新实现。

**前端**：新增 `/scan` 页与 2 个精确版本依赖 `mobile_scanner 3.5.7`、`permission_handler 11.3.1`（与项目「钉死版本、不用 `^`」约定一致）。AndroidManifest 声明 `CAMERA` 权限 + `uses-feature ... required="false"`（无摄像头设备仍可安装）；运行时用 `permission_handler` 申请，永久拒绝可跳系统设置，**再次授权后重新检测**。

**权限不可用时页面仍可用**：始终提供「手动输入分享码」入口，走完全相同的 `/api/resolve-share` → `/api/rent` 链路，是可完成转存的真实降级，不是占位。连续识别由 `_handled` 去重，不会重复发起请求；失败后自动允许重扫。目标目录复用第 7 步的 `GET /api/folders`，默认根目录，可转存到任意子目录。

**顺带修复一处上一轮回归**：设置页支持覆盖服务地址后，`cloud_repository.dart` 的下载 URL 兜底仍硬编码 `AppConfig.apiBaseUrl`，会让自建 VPS 下的 302 相对 `Location` 与 `/api/stream` 兜底指向默认域名。现改为 `_client.baseUrl`（跟随运行时覆盖）；全仓已无其它运行时拼接 URL 的硬编码。

**iOS 资产**：项目只打 Android APK，`ios/` 目录按你的要求保留且未改动。若将来恢复 iOS 构建，需补 `Info.plist` 的 `NSCameraUsageDescription`（mobile_scanner / permission_handler 都需要）与相应 Podfile 配置；当前 iOS 工程不含扫码能力。

### 2.11 蓝奏原生分享导入契约（统一扫码入口）

**目标**：扫码页同时支持轻云分享码与蓝奏云原生分享链接，前端不猜、不拼码；VPS 上安全可用。

**后端接线**（lanflare）：

| 文件 | 内容 |
| --- | --- |
| `src/scan.ts`（新增） | `resolveScanInput()` 统一判别 + `commitLanzouImport()` 一次性提交 |
| `src/index.ts` | 新增 `POST /api/scan/resolve` 与 `POST /api/import-lanzou`；导入成功发 `lanzou_imported` 通知 |
| `src/share.ts` | `normalizeShareCode()` 的蓝奏守卫文案改指向统一入口（并修正「需要 session」的错误注释） |
| `src/apidocs.ts` | `/docs` 补 2 个端点 |

复用的既有能力（**本轮未重写**）：`parseLanzouShare()` 解析链接 / 提取码 / 文件与文件夹类型并做域名白名单，`probeLanzouShare()` 抓分享页（8 秒超时、逐跳重定向白名单、1MB 上限、WAF cookie 处理、文件夹最多 200 项），`importLanzouShare()` 把探测结果落成 `alien://` 节点。

**统一入口 `POST /api/scan/resolve` `{raw, pwd?}`** 返回判别联合：

- `source=lanflare`：`{code, name, sizeBytes, chunks, kind?, files?}`，`code` 原样传给 `POST /api/rent`（与 2.10 完全一致，网页端 `ui.ts` 的旧端点也保持不变）
- `source=lanzou`：`{importId?, name, sizeBytes, kind, files, needsPassword, probed, error?, host}`。要提取码、探测失败或文件夹列不出文件时**不发 `importId`**，返回真实原因；补 `pwd` 后重新调用同一入口即可

**`POST /api/import-lanzou` `{importId, pid}`**：消费凭证后落库，返回 `{ok,kind,node,created,skipped}`。

**VPS 安全设计（重点）**：

- 探测结果（URL / 名称 / 大小 / 文件列表）**只存服务端** `meta` 表的 uid 隔离一次性 ticket（`scanimport:<id>`，10 分钟过期、提交前即删除），客户端只拿不透明 `importId`。因此客户端无法伪造任意 URL 借 VPS 发起 SSRF，也无法灌入假的大小 / 文件列表。
- 提交时二次校验：ticket 格式、uid、过期、spec 的 URL（`assertLanzouUrl` 域名白名单）、items（`parseLanzouItems` 上限 200）、提取码字符集、pid ≥0 整数。`importLanzouShare()` 内部还会再校验一次 URL。
- `ro` 令牌被全局守卫拦在写接口外；导入端点受 `/api/*` 登录守卫保护。
- **不需要绑定存储账号**：导入的是懒加载 `alien://` 节点，下载走 `resolveDirectLink(payload.l, payload.p)`，与 `/api/rent` 转存的文件行为一致。

**前端**（qingyun-cloud-app）：

- 新增 `ScanSource` / `ScanResolution` 模型（判别联合，含 `blocker` 派生：需要提取码 / 探测失败 / 结果不完整）；删除已被统一入口取代的 `ResolvedShare` 与 `resolveShare()` 死代码
- 仓库新增 `scanResolve(raw, {pwd})`、`importLanzou(importId, pid)`；`rentShare()` 保留给 lanflare 分支
- 扫码页 `_resolve()` 改走统一入口；`_rent()` 按 `source` 分流到 `/api/rent` 或 `/api/import-lanzou`
- 新增「需要提取码」卡：输入框 +「验证并继续」，用**同一份扫码原文**重新解析（原文不落地、不拼码）；探测失败显示后端给的真实错误 +「重试解析」，不编造名称与大小
- 预览卡显示来源、分享站点、真实名称 / 大小 / 文件数；手动输入说明覆盖 `lanzou.com/i…` / `b…` 与「提取码：xxxx」文本
- 相机权限、无摄像头降级、目标目录选择、连续识别去重、完成卡全部沿用 2.10

**边界**：短 `lanflare://f/<id>` 仍只在本实例有效；蓝奏链接要求**服务端能访问分享页**（VPS 出网受限时 `probed=false`，页面如实报错并允许重试）；蓝奏文件夹分享依赖 `filemoreajax.php` 可列出文件，列不出时不允许导入，避免建出空目录。**iOS 资产仍按你的要求保留且未改动**，扫码能力只在 Android 生效。

### 2.12 为你推荐 / 每日照片回忆契约

原型卡带有一组编造的「往年今日」张数与旅行地点文案。**纯网盘后端没有 EXIF / GPS / 人脸聚类 / 内容生成服务**，地点、拍摄时间、文案都不可得，不能编造。可真实查询的只有 `nodes.created_at`（上传时间）与扩展名，因此本轮把卡片改成**基于真实上传日期的照片聚合**。

**后端**（lanflare）：新增 `src/recall.ts` 的 `dailyRecall(db, uid, today)` + `GET /api/recall/daily`，`/docs` 同步。

| 规则 | 说明 |
| --- | --- |
| 优先 `on_this_day` | 上传日的 UTC 月日 = 客户端本地今日月日、且年份严格早于今年 → 取**最近的一个**往年同日 |
| 回退 `recent_day` | 无往年同日 → 取图片数最多的一天（并列取日期最新）；新账号只有本周照片也能出真实卡片 |
| 无图片 | `has_memory=false`、`items=[]`、`count=0`，前端显示中性文案，**不编造任何数值** |

- `title` 是由真实日期派生的中文标签（如 `2024 年 11 月 19 日`）；`count` 用独立的整数范围 `COUNT` 精确统计该日活跃图片总数，**不受 4000 行分组扫描上限影响**；`items` 最多 6 张、按时间倒序。
- 只统计 `uid` 本人、`type='file'`、`is_trashed=0` 且扩展名命中图片白名单（与 `stats.ts` / `FileCategoryX` 一致）的节点。**无新增表、无迁移、无存储账号会话、无外呼调用**，D1 与 VPS SQLite shim 都只用到 `D1Like` 最小接口。
- 每个 `items` 由 handler 补一个 `preview_url`：复用 `/api/preview/url` 的 `previewHmacKey`（来自 `lanflare/src/signing.ts`）/ `previewHex` / `previewPayload` / `PREVIEW_TTL_MS`，签出 15 分钟有效的 `/api/preview?...` URL，**首页一次请求即可拿到整张卡**。签名材料见 7.4：第 15 步已支持独立 `APP_SIGNING_KEY`，不再与登录口令同源。
- **时区口径（真实数据边界，非 bug）**：分组用 `created_at` 的 **UTC** 日历日；前端传设备**本地** `today=YYYY-MM-DD` 判定「往年」。UTC+8 凌晨前后上传的照片可能落在相邻的 UTC 日，这是可解释的口径差异；`truncated=true` 表示分组扫描命中 4000 行上限，超大图库可能识别不到更早的往年同日。

**前端**（qingyun-cloud-app）：

- 新增 `RecallPhoto` / `DailyRecall` 模型（`tag` 派生「往年的这一天 / 照片回忆」，`subtitle` 用真实 `count`），仓库新增 `dailyRecall()` 并传设备本地日期
- 首页 `_MemoryCard` 改为动态：加载中「正在整理回忆…」、无数据「暂无推荐内容 / 上传照片后会在这里生成回忆」、失败「回忆暂时无法加载」，**全仓最后一处首页占位消失**；有数据时显示真实中文日期 + 真实张数 + 右上叠放最多 3 张真实缩略图
- 缩略图用 `Image.network(签名URL)`，`errorBuilder` 退回半透明色块：预览过期或 VPS 暂时取不到直链时，文字仍是真实数据，不出现假图 / 假数值
- 「去看看」仍跳相册页（相册页已按 `FileCategory.image` 列真实图片并支持在线预览），与本卡形成自然衔接

**后续已落地**：`lib/features/album/album_screen.dart` 的「我的照片回忆」横幅当时保留中性占位，属回忆视频能力；**已在 2.13 按 A 方案用真实照片轮播实现**，占位清零。`DESIGN_SPEC.md` 只描述首页结构，未写占位文案，无需改动。

### 2.13 我的照片回忆 / 真实照片轮播契约（方案 A）

**选型**：相册页「我的照片回忆」横幅原属回忆视频（需 ffmpeg / 内容生成服务）。按你确认的 **A 方案**，改为**真实照片轮播 / 幻灯片**——复用已有签名预览 URL，**零新增依赖、零视频生成、零新增表 / 迁移、无外呼调用**。

**后端**（lanflare）：

| 文件 | 内容 |
| --- | --- |
| `src/recall.ts` | 新增 `recallAlbum(db, uid)`：复用 `imagePredicate()` / `ymdOf()` / `chineseDate()`，同一条只读 SQL 扫描后按 UTC 日历日分组 |
| `src/index.ts` | 新增 `GET /api/recall/album`；抽出 `signRecallPhotos()` 供 `/api/recall/daily` 与 `/api/recall/album` **共用同一套预览 HMAC 签发**（`src/signing.ts`，不再重复代码） |
| `src/apidocs.ts` | `/docs` 补端点 |

- 上限：扫描 **4000** 行、最近 **60** 个回忆日、每日最多 **30** 张可播放图片；`truncated=true` 如实标记扫描命中上限。
- `count` 是该日在扫描集里的**真实图片数**（≥ 可播放 `items`），`total_photos` 是返回的可播放照片总数，`title` 是真实中文日期。**不编造数值、不编造地点 / 文案**。
- 每张图返回 `preview_url`：与 `/api/recall/daily`、`/api/preview/url` 共用 `previewHmacKey` / `previewHex` / `previewPayload` / `PREVIEW_TTL_MS`，15 分钟有效；响应带 `preview_expires_at`。
- 数据边界与 2.12 一致：UTC 日历日分组、`uid` 本人、`type='file'`、`is_trashed=0`、图片扩展名白名单；只用到 `D1Like` 最小接口，D1 与 VPS SQLite 通用。

**前端**（qingyun-cloud-app）：

- 新增 `RecallAlbumGroup` / `RecallAlbum` 模型（`summary` 用真实 `totalPhotos` / `totalGroups`），仓库新增 `recallAlbum()`
- 新增 `/recall-album` 页 `lib/features/album/recall_album_screen.dart`：**全部用 Flutter SDK 自带能力** —— `PageView` + `Timer.periodic` 4 秒自动轮播、`Image.network(签名URL)`、`errorBuilder` 色块兜底；手动滑动、上一张 / 下一张 / 暂停继续、日期胶囊切组、循环播放
- **预览续签**：按 `preview_expires_at` 在到期前 60 秒静默重拉，只替换 URL 与数据、**保持当前组 / 张与 PageController 不跳帧**；且仅在服务端返回**新的**过期时间才继续调度，避免时钟异常时每 30 秒无限续签造成请求放大。续签失败保留旧 URL 继续播放、稍后重试，不打断轮播
- 相册页 `_MemoryBanner` 改为真实数据驱动：加载中「正在整理回忆…」、失败「回忆暂时无法加载 · 点击重试」（点击重拉）、无数据「上传照片后会在这里生成回忆」、有数据 `已收录 N 张照片 · M 个回忆日`；点击进入轮播页。**全仓最后一处「功能待接入」清零**
- 横滑日期胶囊遵守 `DESIGN_SPEC.md` 约束：`SingleChildScrollView(horizontal) + Row`，不用固定高度横向 ListView

**本轮不动**：首页 `_MemoryCard` 仍跳相册页（2.12 已确认行为），未改指向轮播页；如要把「去看看」直接接到 `/recall-album`，告诉我单独改。

### 2.14 传输记录本地持久化契约

lanflare 的上传是同步 / 分块即传、下载是直链或代理流，**没有服务端任务列表**。第 6 步起传输页、搜索页的「N 个任务进行中」都取自 App 本地 `LocalTransferStore` 的真实任务，但一直是**纯内存模型，重启即丢**。本轮改为本机持久化。

| 项 | 契约 |
| --- | --- |
| 存储 | `shared_preferences` 的 `qingyun_transfer_history_v1`（项目已有依赖，**零新增依赖**），JSON 数组 |
| **落盘范围** | **仅终态记录**（`done` / `failed`）。`running` / `paused` **不落盘**——后端上传同步完成、无断点续传，若恢复成 running 会造出「没有请求在跑却一直显示进行中」的假任务，污染搜索页真实统计 |
| 写盘时机 | 任务 `complete` / `fail`、`remove`、设置页 `clear`；**进度回调不触发 IO**（dio 高频回调） |
| 一致性 | 写操作走串行 `_writeChain`，调用点即取快照，避免快速连续变更时旧快照覆盖新快照；写失败只上报，绝不影响传输本身 |
| 恢复 | `main()` 在 `runApp` 之前 `await LocalTransferStore.instance.load()`，页面不闪空。防御式解析：坏 JSON / 非列表 / 非对象 / 空 id / 重复 id / 非终态一律跳过；单条异常不阻断启动 |
| 上限 | 最新 **100** 条，超出截断，避免长期使用时 JSON 无限膨胀 |
| 清除 | 设置页「清除传输记录」同时清内存与磁盘，重启后不「复活」；确认文案已改为「含重启后保留的历史」 |
| 数据真实性 | 全部来自真实上传 / 下载任务，无演示数据；重启后 `running.length` 恒为 0，搜索页不会显示残留的进行中任务 |

**本轮一并修正的 3 处关联真实性问题**（都由持久化放大，属同一闭环）：

1. 传输页「今天已完成」→ **「最近完成」**：持久化后列表可能包含前几天的记录，原写死「今天」不再成立。
2. 速度卡 `active: true` → `active: running.isNotEmpty`：无任务时不再显示「传输进行中」。
3. 失败卡片的「重试」→ **「移除记录」**：本地模型不保存源文件路径，`resume()` 只会把状态改回 `running`，但**并没有重新发起任何网络请求**，会造出永远卡住的假任务并污染搜索页统计；改为真实可用的移除（同步清盘）。

> ⚠️ **演进说明**：第 3 条是第 14 步当时为消除「假任务」做的中间处理——**第 17 步已把暂停 / 继续 / 重试做成真实能力**（持有 `CancelToken` + 重新发起一整次请求），失败卡片重新提供「重试」与「重新选择文件」，见 2.16。上表其余口径不变。

### 2.15 PDF 内联预览契约

预览页此前对 PDF 只显示「下载后用系统应用打开」（7.1 的 🔶）。本轮做成真实内联渲染，**后端零改动**——复用已有的 `GET /api/preview/url`（签发）+ `GET /api/preview`（HMAC 自校验、支持 Range）。

| 环节 | 实现 |
| --- | --- |
| 取流 | `GET /api/preview/url?id=` 拿 `{url, expires_at, size_bytes, content_type}`，`content_type == application/pdf` 判定为 PDF |
| 下载 | `ApiClient.downloadCapabilityUrl()`：只接受 http/https 绝对地址、必须有 host；用**不带任何拦截器的独立 Dio**，不把 Bearer 令牌 / 会话 Cookie 发到公开能力 URL |
| 续签 | 缓存未命中且 `expires_at - now < 60s`（或缺失）时重新调一次 `/api/preview/url`；后端只在请求开始校验一次 `exp`，流式传输期间不会中途失效 |
| 落盘 | `getTemporaryDirectory()/pdf_preview/pdf_<id>_<size_bytes>.pdf`，缓存键**只由数字 id + 服务端大小组成，不取用户文件名**，杜绝路径穿越与特殊字符 |
| 原子性 | 先写 `.part` → 校验字节数与 `size_bytes` 一致（0 = 未知则不比）→ 删除旧缓存 → `rename()` 成正式缓存；中途失败删 `.part`，不会留下「半份 PDF」被误当有效缓存。续签返回的新 `size_bytes` 若与首次不同，缓存键与校验基准同步改用新值，避免「下载新内容却按旧大小校验」的误报 |
| 缓存复用 | 命中且大小一致直接返回本地路径，**已看过的 PDF 断网也能打开**；系统回收临时目录后自动重新下载 |
| 刷新 | 工具条「重新加载」清该条缓存并强制重新签发下载，用于云端文件被替换后同步 |
| 传输记录 | 该下载**只用于查看，不写入 `LocalTransferStore`**——否则每打开一次 PDF 都会在传输页产生一条噪声记录；进度由页面内进度条展示 |
| 渲染 | `flutter_pdfview 1.3.2`：`PDFView(filePath:)`（Android 用 AndroidPdfViewer，iOS 用系统 PDFKit）。`onRender` / `onPageChanged` 显示真实页码与总页数，`PDFViewController.setPage()` 翻页，`password` 支持加密 PDF，`onError` / `onPageError` 上报并提供「打开密码 / 重新加载 / 下载后打开」三个真实降级入口 |

**平台依赖（只影响 Android 构建，iOS 资产零改动）**：

- 选 `1.3.2`（与 Flutter 3.24.5 / Dart 3.5 同期稳定版），而非 `1.4.x` —— 后者插件自身要求 AGP 8.11 + `compileSdk 35` 且 iOS > 12.0，与本项目 AGP 8.1.0 / `compileSdk 34` / Podfile 12.0 冲突。
- Android `minSdk 21` 满足；`MainActivity` 已有 `android:hardwareAccelerated="true"`（AndroidPdfViewer 需要）。
- 1.3.2 的 `com.github.barteksc:android-pdf-viewer` 只发布在 **JitPack**，已在 `android/build.gradle` 的 `allprojects.repositories` 末尾加 `maven { url 'https://jitpack.io' }` 兜底，其余依赖仍优先走 google() / mavenCentral()。
- iOS 侧 PDFKit 要求 > 11.0，项目 `ios/Podfile` 为 `platform :ios, '12.0'`，**无需修改任何 `ios/` 文件**（该项目只打包 Android，但保留本地 iOS 可运行能力）。

> ⚠️ **本轮新增了一个 Dart 依赖**，因此 `pubspec.lock` 必须在本地用 Flutter 3.24.5 重新 `flutter pub get` 生成并提交；`release.yml` 会硬校验 lock，缺了或过期都会拒绝发版。

### 2.16 暂停 / 继续 / 重试契约（真实取消与重发）

lanflare **没有断点续传、没有服务端任务表**。因此「暂停」在 HTTP 层只能是取消当前请求，「继续 / 重试」只能是从头重新发起一整次传输。第 14 步为了避免「状态 running 但没有请求在跑」的假任务，把失败卡片改成了「移除记录」；本步把真实能力补齐，**后端零改动**。

| 环节 | 实现 |
| --- | --- |
| CancelToken | `ApiClient.uploadStream()` / `downloadToFile()` 新增可选 `cancelToken`，透传给 Dio。单请求上传、分块上传的**每一块**、下载都挂同一个 token |
| 运行时注册表 | `LocalTransferStore` 新增 `_runtime`（**纯内存、不落盘**）：`cancel` 真正取消请求，`restart` 重新发起并复用同一个任务 id。重启恢复的历史记录没有 runtime，`canRestart=false`，只显示「移除记录」，不显示点了没反应的重试按钮 |
| 暂停 | `store.pause(id)` 先落地 `paused`，再调用 `cancel()`；进度回调因状态不是 running 自动忽略；Dio 抛 `DioExceptionType.cancel` → `ApiException.cancelled()`（`code=-3`），各方法**不覆盖成 failed、不落盘** |
| 分块取消 | 取消同样触发 `_abortChunkUpload(uploadId)`，清掉云端 `.chunk-<id>` 残留（第 13 步的 abort 幂等且有护栏）。重发会生成**新 uploadId**，不会复用被清理的会话 |
| 继续 / 重试 | `resume()` / `retry()` 调用 `restart` 闭包 → `startOrReset(id)` 把状态置回 running、**进度归零**（请求从头开始，不能显示旧百分比冒充续传）→ 生成新 CancelToken → 重新 `attachRuntime` 覆盖旧句柄 |
| 源路径 | 上传重发闭包在**内存**里保留本次选择的本地路径，重试无需重新选文件；路径**不落盘**。原文件被删 / 移动时抛真实错误「源文件不可读，请重新选择文件」，任务落为 failed |
| 重新选择文件 | 传输页对失败 / 已暂停的上传任务额外提供「重新选择文件」：`UploadHelper.pickAndUpload(replaceTaskId:)` 选到新文件才移除旧记录（含磁盘缓存）并发起全新上传；**用户在选择器里取消则旧记录原样保留** |
| 下载重试 | 下载只需 `fileId + name` 即可重发，无需用户操作 |
| 磁盘一致性 | 从 failed 重置为 running 时写一次快照，把磁盘里那条旧的失败记录移除，避免重启后「复活」；paused 仍不落盘 |
| 页面误报 | 首页 / 文件页 / 预览页的 catch 识别 `ApiException.isCancelled`，主动暂停**不再弹「上传失败 / 下载失败」toast**；`restart` 是异步触发且无人 await，闭包内吞掉异常避免未处理异步错误 |

**UI 口径**：胶囊「进行中」列表现在包含 running + paused（否则一点暂停卡片就消失）；副标题显示「N 个任务进行中 · M 个已暂停」；paused 卡片明确写「已暂停 · 请求已取消（继续将重新开始）」，底部标签「可继续 / 可重试 / 可移除」，`全部暂停` 提示语也说明会重新开始。

**仍如实登记的缺口**：真正的**断点续传**（从已上传的字节继续）依然没有——需要后端任务表 + 分块续传协议（2.6 的服务端会话状态机已具备部分基础）。当前「继续」是重新从头传，UI 已明确告知，不伪装成续传。

### 2.17 设置页签名密钥状态契约

第 15 步后端给 `GET /api/server-info` 加了 `signing_mode`，但前端 `ServerInfo` 一直没读它（7.4.1 当时明确写「App 当前忽略该字段」），2.9 表格却已把它列进「展示真实」——属于**文档虚写**。本步把字段真正接入设置页，闭环最后一个「后端已返回、前端没用上」的字段，**后端逻辑零改动**（仅补 `/docs` 字段列表）。

| 环节 | 实现 |
| --- | --- |
| 字段 | `ServerInfo.signingMode`（`json['signing_mode']?.toString() ?? ''`），旧版服务端不返回时为空 |
| 三态 | `dedicated` → 「独立密钥 · 安全」，用 `mintDeep` 安全色；`legacy` → 「兼容模式 · 与登录口令同源」，用 `coral` 警示色；空 / 未知值 → 「未知（服务端未返回）」灰色，**不猜测、不编造成 legacy** |
| 风险提示 | 仅 `legacy` 时追加一行真实建议「建议在服务端配置 `APP_SIGNING_KEY` 后重启（切换会使网页端需重新登录）」；App 不能代改服务端配置，不提供点了没反应的假按钮 |
| 展示位置 | 「测试连接」结果卡片内，与运行模式 / 版本 / 数据库结构等真实字段并列；**未点测试连接时 `_serverInfo == null`，不显示任何签名状态**（不编造、不发自动请求） |
| 不泄露 | 公开端点只返回模式名，不返回密钥材料；前端只做展示，不缓存、不上报、不写本地存储 |
| 关于区 | 不重复添加——签名密钥属于**服务端运行状态**，不是应用自身信息；连接结果卡片是唯一展示位 |

**后端同步**：`lanflare/src/apidocs.ts` 的 `/api/server-info` 字段列表补上第 15 步漏列的 `signing_mode`，并指向「安全」章节的详细说明；`index.ts` / `signing.ts` 实现逐字未动。

### 2.18 首页容量卡分段进度条（真实占比）

第 19 步顺带清掉运行代码里最后一处编造数值：`home_screen.dart` 的 `_StorageBar` 五段 `Expanded` flex 原本写死为 `36 / 20 / 8 / 4 / 32`，与同页「真实 `used/total` 容量环」「真实 GB 数字」自相矛盾，而 `docs/DESIGN_SPEC.md` 第 4 节还把它描述成「四段进度条」。现在两者都对齐真实数据。

| 环节 | 实现 |
| --- | --- |
| 数据来源 | `StorageSummary.byCategory`（`GET /api/storage/summary` 的 `by_category`），单位字节；四段依次为 `image` / `video` / `doc` / `music + archive`，配色与存储页 2×2 图例逐项一致 |
| 权重 | 每段 `max(1, bytes * 1000 / totalBytes)`，剩余段 `max(1, 1000 − 已用权重)`；`totalBytes = totalGb × 1024³`。只是相对权重，超出 1000 时按相对比例分配，绝不写死 |
| 空态 | 某分类为 0 就**不画该段**（不编造 1% 假占比）；`summary == null` 或 `totalGb <= 0` 时整条中性 `track`，与容量环 `ratio = 0` 的表现一致 |
| 视觉不变 | 高 4、圆角 2、四段配色 `0xFF4C8DFF` / `mint` / `amber` / `0xFFA78BFF` 与 `DESIGN_SPEC.md` 一致，纯视觉参数未改 |
| 后端 | **零改动**，复用已有 `by_category` |

**文档同步**：`docs/DESIGN_SPEC.md` 第 19 步补「数据口径」总说明，把原型 8 屏之外的 11 个真实功能页补进 4.2 节，并把所有写死占比 / 热搜榜 / 假日期分组 /「今天已完成 3 项」/ 过期重定向清单换成实现口径；色板、圆角、间距、渐变、回弹约束等设计度量**逐字保留**。至此全仓（含文档）再无把编造数值当作展示数据的地方。

### 2.19 管理员全局存储账号池（多后端地基，第 1 步）

这是「管理员配置多蓝奏账号做随机上传均衡 + HuggingFace / Telegram 多账号」的**地基步**。⚠️ 模型经你纠正后定稿：**存储账号由管理员统一配成一个全局池，与 App 用户无关**；普通用户看不到、绑不了、选不了账号。VFS 文件树仍按 `nodes.uid` **每用户独立**（各自文件 / 回收站 / 分享 / 统计不共享），池只决定物理字节落在哪。上一版把注册表做成「每用户各自绑定」是错的，已作废重写。

| 环节 | 实现 |
| --- | --- |
| 全局池 | `lanflare/storage_accounts` 表，**无 `uid`、无「每用户默认账号」**；字段 `id / kind / purpose / label / credentials(JSON) / root_ref / enabled / weight / created_at / source`。凭据只存会话与账号名，**密码永不落盘** |
| 节点归属 | `nodes` 新增 `provider`（默认 `lanzou`）与 `account_id`（默认 `''` = 存量文件 / `alien://`），索引 `account_id` 与 `(uid, account_id)`。文件树可见性仍由 `uid` 决定 |
| 存量兼容 | 不做「惰性提升」。旧 6 个 per-user `meta` 键原样保留，存量文件（`account_id=''`）下载/预览/回收站仍读旧会话，**升级零回归**；旧 `/api/storage/login|logout|account` 保留为管理员历史兼容端点，不再向普通用户暴露 |
| 用途 contract | `purpose=auto` 的**蓝奏账号**组成随机上传池（第 2 步接选择器，均衡默认关闭）；**HuggingFace / Telegram 强制 `manual`**，仅网页端管理员手动用，App 只走蓝奏池。设 auto 会 400 |
| 能力表（第 1 步当时） | `PROVIDER_CAPABILITIES`：`lanzou`（已实现，>90MB 走 8MB 分块）、`huggingface`（单文件 50GB、浏览器上传 5GB、commit 60s 超时）、`telegram`（Bot API 50MB/对象、本地 Server 2GB、需 `getFile` 代理）。后两种**第 1 步当时**绑定返回明确 400；HF 已在 2.21 生效 |
| 配置优先级 | env `STORAGE_ACCOUNTS_JSON`（JSON 数组）**仅在池表为空时首次种子**；之后以 DB 为准，网页端管理员增删改重启不丢，删掉的账号不复活。蓝奏种子用会话 Cookie，不接受明文密码、启动不外呼 |
| 账号管理 API | `GET/POST/PATCH/DELETE /api/storage/accounts[/:id]`，**四个全部 `requireAdmin()`**：列表脱敏（永不返回 `ylogin`/`phpdisk_info`/token）、新增蓝奏账号、改备注/启停/权重(1~100)/用途、移除。全局护栏：账号被**任意用户**的文件引用（含回收站）返回 409 |
| 权限模型 | 普通用户对文件树**只读**：上传 / 新建目录 / 改名 / 移动 / 删除 / 恢复 / 清空回收站 / 分享 / 转存 / 存储绑定 / 清理建议提交均需管理员（统一中间件 + `POST /s/:token/rent` 单独校验）。账号自助（自己的令牌 / 2FA / 反馈 / 改自己密码）保留；`ro` 令牌仍禁止一切写操作 |
| 版本 / 迁移 | `SCHEMA_VERSION` 7 → 8；`features` 加 `admin_storage_pool` / `readonly_users`；`migrations/008_storage_accounts.sql`。VPS 启动自动逐语句重放，D1 运营者需手动执行一次 |
| 前端 | **本步零改动**（纯后端地基）。App 的存储账号页、上传入口隐藏、管理员池管理页在第 2 步一起落地，避免先出点了没反应或 403 的假入口 |

**边界说明**：第 1 步是地基中间态，随机均衡在**第 2 步（见 2.20）**已真正生效；存量文件仍按 `account_id=''` 走旧 per-user 会话读取，零回归。

### 2.20 多蓝奏账号随机均衡上传（第 2 步，已生效）

这是「多账号预防单账号上传下载被限制」真正落地的一步。**全局池、管理员配置、与 App 用户无关**；文件树仍按 `uid` 每用户独立；一个文件只存一处，不做多副本。

| 环节 | 实现 |
| --- | --- |
| 均衡开关 | 全局设置存 `meta` 全局键 `pool:balance_mode`，`GET/POST /api/admin/storage-balance`（仅 admin）。取值 `off`（默认，第一个启用账号）/ `random`（等概率随机，CSPRNG）/ `weighted`（按权重 1~100 加权随机），其他值 400 |
| 选择器 | `src/storage_selector.ts::selectUploadTarget(db, uid, sizeBytes)`：取启用的 `purpose=auto` 蓝奏账号 → 按能力表过滤单文件上限 → 校验会话凭据可用 → 按模式选一个 → `nodes.account_id` / `provider` 写入实际归属。上传响应回显真实 `storage_mode` / `account_id` / `account_label` |
| 全局 root | 每个池账号一个 **GLOBAL** `.lanflare` 根目录（`meta` 全局键 `pool:root:<id>`），不是 `N账号 × N用户`；旧账号仍用历史 `u<uid>:root_lanzou_id` |
| 升级兜底 | 池为空（管理员还没配）时回退旧 per-user 会话并如实标记 `mode=legacy`，**升级零中断**；这是兼容路径，不是用户绑定功能。池一旦有可用账号，所有新上传都走池 |
| 按节点分派 | `src/storage_accounts.ts::sessionForNode()` 是唯一解析点：池节点用**自己账号**的会话，`alien://` 不需要会话，存量节点用旧 per-user 会话。下载 / 预览 / stream / WebDAV GET / MCP / 分享 / 文件夹分享全部接入 |
| 批量混合 | `vfs.trashNodes/restoreNodes/hardDeleteNodes` 内按每个 `node.account_id` 解析会话，`formhash` 按会话缓存（同一批混合新旧文件时不会删错账号） |
| 分块一致性 | `chunk_session.ts` 的会话状态持久化 `accountId`；只在 `index=0` 选一次账号，后续块 / `abort` / 24h 残留清理都用**同一账号**会话，不会把一半分块传到另一个账号 |
| 覆盖的上传入口 | `POST /api/upload`、`POST /api/upload/chunk`、WebDAV PUT（含 VPS 大文件 spool 分块 `largeput.ts`）、MCP `lanflare_upload_file` |
| 前端 | 网页端「存储账号池」页改为**仅管理员可见**：账号列表（脱敏）、新增蓝奏账号、启停 / 权重 / 用途 / 移除、均衡开关。App 新增 `AdminGate` + `AdminOnly`，普通用户隐藏上传 / 新建 / 批量 / 重命名 / 移动 / 删除 / 清空回收站 / 撤销分享 / 一键清理 / 预览写操作；删除用户级 `StorageAccountScreen` 与路由，「管理」改为只读的真实池概览弹窗 |
| 状态暴露 | `GET /api/status` 新增 `is_admin` 与 `storage_pool`（账号总数 / 自动池数 / 均衡模式 / 生效模式 / 是否兼容回退），App 与网页端都读真实值；`server-info.features` 加 `upload_balancing` |

**只读入口收口（第 2 步验收补全）**：逐页核对后补齐三处漏网入口——首页头图「扫一扫」图标包 `AdminOnly`（普通用户不渲染，避免点进去只拿到 403）；`/scan` 深链直达时「转存到云盘」按钮同样包 `AdminOnly`，但**解析结果仍可查看**（纯读），普通用户显示「当前为只读账号，转存需管理员」；存储页「一键清理」由原来的 `canClean && isAdmin ? onClean : (){}`（看得见、点了没反应的假按钮）改为 `AdminOnly` 整体不渲染并给中性说明。后端 `GET /api/storage/account`（历史 per-user 绑定详情，会回显账号名与 root id）加 `requireAdmin()`：App 与网页端都已改用 `GET /api/status` 的 `storage_pool` 概览，普通用户不应再有任何读取账号信息的通道。

**边界**：本步只有蓝奏账号参与自动随机池；HuggingFace 已在 **2.21**、Telegram 已在 **2.22** 各自作为独立手动通道生效（均不进随机池）；下载回文件所属账号，未做多副本，也未做「按已用容量最少优先」策略（默认等概率随机）。全局 `pool:root:<id>` 在多个用户首次并发上传到同一账号时理论上可能各建一个同名 `.lanflare` 目录（蓝奏允许同名、不影响已写入文件），单实例 VPS 首次配置后即缓存，不做分布式锁。

### 2.21 HuggingFace 私库手动通道（第 22 步，已生效）

> **App 零改动**：这是纯后端 + 网页端管理员能力。App 用户与 HF 账号**完全无关**，永远只走蓝奏随机池（2.20）；HF 账号由管理员在网页端「存储账号池」配置成全局手动通道，可配多个。前端本步只同步文档口径，`lib/` 与 `ios/` 逐字未动。

| 环节 | 实现 |
| --- | --- |
| 账号登记 | 「存储账号池」页新增 `huggingface`：填 `hf_token`（write 权限）+ 私有 `hf_repo`（`username/repo`），可选 `hf_api_base`（默认 `https://huggingface.co`，仅 https / 本地 http）、`hf_repo_type`（model/dataset/space）。令牌只发一次、输入框前端清空、列表 `publicAccount()` 永不回显；与蓝奏会话 Cookie 一样存 `storage_accounts.credentials`。支持 `STORAGE_ACCOUNTS_JSON` 种子（首次导入、DB 为准） |
| 强制手动 | `resolvePurpose()` 对 HF 恒返回 `manual`，设 auto 会 400；`listAutoAccounts()` 只取 `kind=lanzou`，HF 绝不进随机池。首次登记会尽力检查 / 自动创建私有仓库，失败不阻断、列表「检测」可重试 |
| 上传 | 管理员在文件页「上传目标」下拉选中 HF 账号 → `POST /api/admin/storage/upload?account_id=..&pid=..`（multipart `files`）或 `POST /api/upload?account_id=..`（单文件）。**整批多文件合并为一次 Hub commit**：preupload 判 regular/LFS → LFS batch PUT → commit NDJSON，避免高频小文件撑大 git 历史。单文件 ≤90MB、单批 ≤720MB |
| 物理引用 | 对象键 `u<uid>/<sha256>.bin`，`nodes.lanzou_id = hf://<key>`、`provider=huggingface`、`account_id` 指向该全局账号；文件树可见性仍由 `uid` 决定 |
| 读取分派 | `download.ts::openNodeStream()` 是统一入口：HF 节点走 `hfOpenStream()`（`/resolve/main/` + Range，服务端跟随 302 到 CDN 并**剥离令牌**），其余走原蓝奏路径。已接入 `/api/download`、`/api/preview`、`/api/stream`、WebDAV GET/HEAD、公开分享页兜底 |
| 删除 / 回收站 | 软删（`trashNodes`）对 HF **只置 `is_trashed` 不删对象**，恢复是纯 DB 翻转；彻底删除 / 清空回收站（`hardDeleteNodes`）按 `account_id` 分组、一次 commit 删除多个对象，仍带「其他活跃节点引用则跳过」护栏 |
| 分享 | HF 私库**没有蓝奏式分享码 / 公开直链**：`/api/share`、文件夹分享、MCP `create_share` / `download_url` 对 HF 节点返回明确 400 / 真实提示，不假装成功 |

**真实约束**：HF Hub 单 LFS 对象理论上限 50GB、commit 约 60s 超时（本步单请求 ≤90MB，大文件走 2.23 分片会话）；私库令牌不下发客户端，所有读走服务端代理；preupload 尊重仓库 `.gitattributes` 的 LFS 规则，不靠本地大小阈值硬猜；`hf_api_base` 有 SSRF 白名单（仅 https / 本地 http）。Telegram 已在 **2.22** 作为独立手动通道生效。

### 2.22 Telegram Bot 手动通道（第 23 步，已生效）

> **App 零改动**：与 2.21 一样是纯后端 + 网页端管理员能力。多账号管理员全局配置、强制 `manual`，App 永远只走蓝奏随机池（2.20）。`lib/` 与 `ios/` 逐字未动。**至此蓝奏 / HF / Telegram 三种 provider 全部实现。**

| 环节 | 实现 |
| --- | --- |
| 账号登记 | 「存储账号池」新增 `telegram`：填 `tg_bot_token`（`<id>:<secret>`）+ `tg_chat_id`（数字 ID / `@频道名`），可选 `tg_api_base`（默认 `https://api.telegram.org`；本地 Bot API Server 填 `http://内网:8081`）、`tg_file_base`（`--local` 模式 FILE_SERVER/nginx 的 token-less 地址）、`tg_work_dir`。令牌只发一次、前端清空输入框、列表 `publicAccount()` 永不回显；与 HF 一样支持 `STORAGE_ACCOUNTS_JSON` 首次种子 |
| 强制手动 | `resolvePurpose()` 对 TG 恒 `manual`、设 auto 400；`listAutoAccounts()` 只取 `kind=lanzou`，TG 绝不进随机池。首次登记尽力 `getMe`（失败不阻断、列表「检测」可重试） |
| 16MB 分片 | 云 Bot API **上传 ≤50MB 但下载只有 20MB**，故统一按 16MB 分片，两头都安全；本地 Bot API Server（单对象 2GB）也用同一套。每片一条 `sendDocument` 消息，保存 `file_id` + `message_id` |
| 物理引用 | 分片清单（含 `file_id` / `message_id` / 每片真实字节）经 **AES-GCM 密封**存进 `nodes.lanzou_id = tg://…`（与 `alien://` 对称，零新增表 / 免 GC，密钥独立存 `meta.tg_ref_key`）；`provider=telegram`、`account_id` 指向该全局账号、`chunks=片数` |
| 上传 | 文件页「上传目标」选中 TG 账号 → `POST /api/admin/storage/upload?account_id=..&pid=..`（multipart `files`）或 `POST /api/upload?account_id=..`（单文件）。单文件 ≤90MB、单批 ≤720MB，超出真实 413；先全部上传成功再写 VFS 节点，半成品不留节点 |
| 读取分派 | `download.ts::openNodeStream()` 统一入口：TG 节点解密清单 → 逐片 `getFile` → 云 `/file/bot<token>/<path>` 或 `--local` 的 token-less FILE_SERVER URL → 服务端拼接 + Range（不假设 Telegram 支持 Range，逐片读全后裁）。已接入 `/api/download`、`/api/preview`、`/api/stream`、WebDAV GET/HEAD、公开分享页兜底；**bot token 只在服务端内部请求里出现，绝不下发客户端** |
| 删除 / 回收站 | 软删只置 `is_trashed` 保留对象（恢复是纯 DB 翻转）；彻底删除按 `account_id` 分组、尽力 `deleteMessage` 删每条分片消息。**Telegram 没有删文件 API**，`file_id` 可能仍可下载——UI / 文档 / 代码均如实标注，不假装物理删除，失败仍移除 VFS 行 |
| 分享 | TG 对象**没有蓝奏式分享码 / 公开直链**：`/api/share`、文件夹整体分享、MCP `create_share` / `download_url` 一律返回明确 400 / 真实提示 |

**真实约束**：云 API 单文档上传 50MB、`getFile` 下载 20MB（`file_path` 生成的下载 URL ≥1 小时有效，过期重新 `getFile`）；本地 Bot API Server 可到 2GB 但 `--local` 模式返回磁盘绝对路径，必须配 `tg_file_base` 才能跨容器代理，`tg_api_base` 有 SSRF 白名单（https 任意 / http 仅本机·内网·Docker 服务名）。`file_id` 属于单个 bot、可能过期失效，`getFile` 会返回真实 400。>90MB 大文件走 2.23 分片会话（≤512MB）。

### 2.23 HF / Telegram 大文件分片上传（第 24 步，已生效）

> **App 零改动**：纯后端 + 网页端管理员能力，`lib/` 与 `ios/` 逐字未动。单请求体上限仍是 90MB，但**单个文件现在可到 512MB**；前 22/23 步的下载、预览、stream、WebDAV、回收站、彻底删除链路**全部零改动**。

| 环节 | 实现 |
| --- | --- |
| 触发 | 网页端「上传目标」选中 HF / TG 账号后，≤90MB 的文件仍走原批量端点（**保留小文件合并一次 Hub commit**）；>90MB 的文件自动走分片会话。每文件独立 `upload_id`，由服务端 `crypto.randomUUID()` 生成 |
| 会话 | `POST /api/admin/storage/upload/begin?account_id=..` 声明 JSON `{name,size,pid}` → 返回 `{upload_id,chunk_bytes:16MB,total_chunks,max_bytes:512MB,provider}`。状态存 `meta`（键 `mchunk:<id>:meta` / `mchunk:<id>:p<i>`，per-uid），**零新增表、零迁移、不动 SCHEMA_VERSION**；24h TTL 惰性清理 |
| 分片 | `POST /api/admin/storage/upload/chunk?account_id=..&upload_id=..&index=..`，请求体是**原始 16MB 二进制**（非 multipart）。严格 `index === next`、每片字节数**精确等于** `min(16MB, declared - i*16MB)`、累计不超声明总大小；重放/跳号/截断/多余一律 **409**，绝不写出大小错误的文件 |
| TG 落地 | 每片到达**立即** `sendDocument` 发一条消息，会话累积 `TgPart[]`；`finalize` 只把清单 AES-GCM 密封成 `tg://…`（无网络外呼扇出，避免单请求里并发几十次发送超时）。`chunks = 片数`，读取走 2.22 原样 `tgOpenStream()` |
| HF 落地 | 每片 base64 暂存 `meta`；`finalize` 逐片读出并校验长度 → 拼成完整字节 → `hfUploadObjects(..., {maxObjectBytes:512MB, forceLfs:true})` **一次 Hub commit、强制 LFS**（大文件绝不走 base64-in-commit）→ 产出普通 `hf://<key>`、`chunks=1`，读取走 2.21 原样 `hfOpenStream()` |
| 写树 | `finalize` / `abort` 走 `?account_id=..` + JSON `{upload_id}`；`name` / `pid` **取自会话状态**（服务端权威），不信任客户端重传；同名文件由其**自己所属账号** `trashNodes()` 移入回收站后再插入节点。响应回显真实 `provider` / `commits` 或 `messages` / `parts` |
| 取消 / 护栏 | `POST /api/admin/storage/upload/abort` 幂等：TG 尽力 `deleteMessage` 删本次已发消息、HF 删暂存行（尚未 commit、无云端对象）；finalize 已成功则会话已清、abort 是空操作，不会误删已入库文件。HF >90MB 在 Cloudflare Workers 运行时返回明确 503（内存不足以拼装），需 Node/SQLite VPS |

**真实约束**：单文件 ≤512MB（再大仍返回真实 413；要继续放开需改成流式拼装 / 分块对象 + 读取拼接）；512MB = 32 片，TG 对应 32 条消息（云 API 每条 ≤50MB、`getFile` 下载 ≤20MB，16MB 片两头都安全）；HF finalize 会在 VPS 内存中拼装完整对象后一次 LFS commit，故 Worker 运行时不支持 HF 大文件。`api_tokens` 的 `ro` 令牌仍禁止一切写操作，四个端点全部 `requireAdmin()`。TTL 清理只清 DB：崩溃遗留的 TG 会话其已发消息可能留在 Telegram（与 HF 未提交 LFS 孤儿 blob 同级），客户端主动 abort 则会同步删除。

## 3. 鉴权

### 3.1 凭证与存储

- `TokenStore`（`lib/core/network/token_store.dart`）使用 `flutter_secure_storage`
  把凭证加密保存到系统密钥库（Android Keystore / iOS Keychain）；App 启动时会自动
  清除旧版本残留在 `shared_preferences` 里的明文凭证。
- 登录链路（`POST /api/auth/login` → `POST /api/tokens`）：
  1. 校验 `{error}` 业务失败；成功后后端下发 `Set-Cookie: lf_session=<exp.uid.username.sig>`（30 天，`HttpOnly / Secure / SameSite=Lax`）。
  2. 客户端临时保存会话值，用它调用 `POST /api/tokens {name:"qingyun-android", scope:"rw"}` 换发 `lf_...` 令牌；服务端只存 SHA-256 哈希，明文仅返回一次。
  3. 加密保存令牌及 `info.id`；**账号口令不落盘**。
  4. 退出登录先 `DELETE /api/tokens/:id` 吊销、再清本地；下次登录会顺带吊销上一次残留的令牌，避免服务端无限累积。
- 降级：`POST /api/tokens` 失败（网络 / 权限）时保留会话凭证走 `Cookie: lf_session=`，登录仍成功，异常只上报不弹错。
- 凭证格式与请求头自动匹配：
  - `lf_...` API 令牌 → `Authorization: Bearer <token>`（默认）；
  - 其他值 → `Cookie: lf_session=<value>`（令牌换发失败时的降级）；
  - `basic:<base64(u:p)>` → `Authorization: Basic <b64>`（仅兼容历史版本已写入加密存储的旧凭证，客户端不再生成）。
- Android 已关闭自动备份，避免 Keystore 密钥材料被云端备份后解包失败。

### 3.2 401 处理约定

- 任意接口返回 HTTP 401 → `ApiClient.onUnauthorized` 触发 → `TokenStore.clear()` + 跳转登录页（`AppRouter.handleUnauthorized`，在 `main.dart` 注册）。
- 401 路径**只清本地、不吊销服务端令牌**，避免网络抖动时误吊销；被服务端吊销的令牌会在下次请求自然返回 401。
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
2. **HTTPS**：Android `usesCleartextTraffic` 未开启；workers.dev 域名自带 HTTPS。
3. **文件上传**：≤90MB 单请求直传；更大文件走 lanflare `/api/upload/chunk` 分块协议，进度经 dio `onSendProgress` 回调写入 `LocalTransferStore`。
4. **下载**：优先 302 直链（VIP），非 VIP 走 Worker 代理流；客户端只拿 URL，交给系统下载能力或流式接收。
5. **幂等性**：上传/删除/恢复等操作建议携带客户端生成的 `request_id`，后端去重，避免弱网重复提交。
6. **日志**：联调期可在 `ApiClient` 添加 `LogInterceptor`；上线前务必关闭请求/响应体日志，防止凭证泄露。
7. **联调自检清单**：
   - [ ] BaseUrl 指向已部署的 lanflare
   - [ ] 登录页登录成功 → 加密存储的是 `lf_` 令牌（非账号口令）→ 重启 App 免登录
   - [ ] 首页头图与我的页显示真实用户名；在 App「会员管理」页给用户加 30 天后，VIP 徽章 / 横幅显示剩余天数与到期日；取消会员后回到「未开通」
   - [ ] 普通账号看不到「会员管理」入口；直接访问 `/admin-vip` 显示「仅管理员可用」
   - [ ] 设备页能看到本次登录的令牌并标记「当前设备」；新建令牌后明文只显示一次，吊销另一台设备后其请求返回 401
   - [ ] 安全中心开启两步验证后，退出登录重新登录需填 6 位动态码；输错时登录页自动聚焦验证码框
   - [ ] 网页端「API 令牌」中可见 `qingyun-android`；退出登录后该令牌被吊销
   - [ ] 首页容量卡 / 最近文件显示真实数据；容量环占比、GB 数字与四段进度条同向变化（上传一张图片后照片段变宽），未取到容量数据时进度条为整条中性灰、不显示编造占比
   - [ ] `docs/DESIGN_SPEC.md` 只保留设计度量（色值 / 圆角 / 间距 / 渐变 / 动效时长），所有原型写死占比、热搜词、日期分组与示例条数都已改成真实接口口径或明确标注为排版占位
   - [ ] 文件页分类筛选、搜索页关键字搜索生效
   - [ ] 上传后文件出现在列表，传输页进度条实时更新
   - [ ] 上传一个 >90MB 文件，列表/容量环/分享落地页显示的 `size_bytes` 等于本地文件真实大小（不是最后一块大小）；人为少发一块或改 `X-Heri-File-Size` 时 finalize 返回 409 且不生成节点
   - [ ] 分块上传到一半断网 → 网页端/App 自动调用 abort，云端 `.chunk-<id>` 目录被清理；重复 abort 返回 no-op；若该目录已被文件节点引用，abort 返回 `protected=true` 且文件仍可下载
   - [ ] 回收站恢复 / 清空、分享链接生成可用
   - [ ] 存储页显示真实清理建议（重复 / 大文件 / 空文件夹），一键清理后回收站可找到对应文件
   - [ ] 退出登录后访问任意页面回到登录页
   - [ ] >90MB 文件分块上传成功，且列表容量显示与文件实际大小一致（2.6 已修正，不再是最后一块大小）
   - [ ] 全新 VPS 部署后未绑定存储账号：存储页「管理」显示「未绑定」，上传提示需先绑定；绑定后状态卡显示真实账号名与「已连接」，上传成功
   - [ ] 解绑后 `GET /api/storage/account` 的 `bound=false` 且 `storage_account` / `bound_at` 为空；换绑不同账号后 `root_folder_id` 发生变化
   - [ ] 搜索页「快捷筛选」的图片 / 文档计数与文件页实际分类数一致；上传一张图片后计数 +1；「最近文件」显示真实文件名而非编造的热搜词；传输记录数随上传任务开始 / 结束实时变化
   - [ ] 文件页切换 6 种排序，列表顺序真实变化且 SectionHead 文案同步；传非法 sort 时后端回显 `name_asc` 不报错
   - [ ] 批量选择后移动到另一目录成功；把文件夹移到自身子目录时该项在选择器里禁用（后端也返回 400）；删除后回收站能找到并可恢复
   - [ ] 设置页填自建 VPS 域名 → 测试连接返回 `runtime=node-sqlite` 且 `service=lanflare` → 保存后重新登录能正常使用；填错域名时明确报错而不是静默失败
   - [ ] 提交一条反馈后「我的反馈」出现该条目；60 秒内再提交返回 429；管理员账号能看到全量列表并回复，用户端刷新后显示回复内容
   - [ ] 扫描 lanflare 分享二维码（或粘贴 `https://<服务>/s/<token>`），解析卡片显示真实文件名与大小；选择子目录转存后文件出现在该目录；连续识别不会重复发起解析
   - [ ] 拒绝相机权限后，用「手动输入分享链接」仍能完成同一条转存链路；在设置页改服务地址后下载兜底 URL 指向新域名
   - [ ] 扫描蓝奏云原生分享链接（带 `?pwd=` 或「提取码：」），预览卡显示来源「蓝奏云原生分享」与真实文件名；不带提取码时弹出输入框，补填后能列出文件夹内文件；选子目录导入后文件出现在该目录、下载能取到直链
   - [ ] 蓝奏分享页不可达时显示真实错误而不是假名称 / 假大小；同一 `importId` 提交第二次返回 404；换一个账号用同一 `importId` 无法导入
   - [ ] 上传几张图片后首页「为你推荐」显示真实中文日期与真实张数，缩略图能加载；用往年的 `created_at` 造一条记录后卡片标为「往年的这一天」
   - [ ] 全新账号（无任何图片）首页显示「暂无推荐内容 / 上传照片后会在这里生成回忆」，不出现编造数值或「功能待接入」；断网时显示「回忆暂时无法加载」而非假数据
   - [ ] 相册页横幅显示真实「已收录 N 张照片 · M 个回忆日」；点击进入回忆页后能自动轮播、手动滑动、暂停 / 继续、按日期切组，图片为本人真实照片
   - [ ] 全新账号相册横幅显示「上传照片后会在这里生成回忆」、回忆页显示空态；断网时横幅显示「点击重试」且重试可用
   - [ ] 停留超过 15 分钟后预览 URL 自动续签、轮播不跳帧；VPS 暂时取不到直链时显示中性色块而不是假图
   - [ ] 配置 `APP_SIGNING_KEY` 后 `GET /api/server-info` 返回 `signing_mode: "dedicated"`；不配置返回 `"legacy"`，且两种模式下登录 / 预览 / 回忆卡 / 轮播都正常
   - [ ] 全新 VPS 库与旧库升级后 `nodes.provider` / `nodes.account_id` / 全局 `storage_accounts` 表都存在（**表内无 `uid` / `is_default` 列**）；旧绑定的 `root_lanzou_id` 未被重建，存量文件上传 / 下载 / 预览 / 回收站行为与升级前一致
   - [ ] `STORAGE_ACCOUNTS_JSON` 只在池表为空时导入一次：重启后不重复、网页端删掉的账号不复活；蓝奏种子缺 `ylogin`/`phpdisk_info` 被跳过且不阻断启动
   - [ ] 普通用户 `POST /api/upload`、`POST /api/mkdir`、`POST /api/delete`、`POST /s/:token/rent` 均 403；`POST /api/tokens`、`POST /api/feedback`、`POST /api/auth/logout` 仍可用；管理员全部放行
   - [ ] 普通用户调 `GET /api/storage/accounts` 返回 403；管理员列表不返回 `ylogin` / `phpdisk_info` / `hf_token` / 任何 token；HF / Telegram 账号 `purpose` 恒为 `manual`（设 auto 400）、`enabled=1` 可用；解绑被任意用户文件引用的账号返回 409
   - [ ] 管理员新增 HF 账号后点「检测」返回真实 Hub HTTP 状态；「上传目标」选该 HF 账号、一次多选 3 个文件，`commits=1` 且 3 个节点 `provider=huggingface` / `account_id` 正确；这 3 个文件能下载 / 预览 / 移入回收站后恢复，彻底删除后 Hub 仓库对象消失；普通用户看不到「上传目标」下拉
   - [ ] 对 HF / TG 节点调 `/api/share` 或文件夹整体分享返回明确 400；下载响应里不出现 `hf_token` / `tg_bot_token`；`/api/server-info` 的 `features` 含 `huggingface_storage` 与 `telegram_storage`
   - [ ] 管理员新增 TG 账号后「检测」返回真实 `getMe`（bot_username / bot_id）；「上传目标」选该账号上传 1 个 20MB 文件 → 2 条分片消息（`chunks=2`、`nodes.lanzou_id` 以 `tg://` 开头）；下载字节与源文件逐字节一致、Range 206 正确；移入回收站后恢复可下载；彻底删除调用 `deleteMessage` 且 VFS 行移除
   - [ ] `--local` 模式未配 `tg_file_base` 时下载返回明确 503 而不是 500；公网 http 的 `tg_api_base` 被 SSRF 白名单拒绝；非法 `chat_id` / bot token 登记被拒
   - [ ] 手动目标上传 1 个 120MB 文件：网页端自动 `begin → 8 片 × 16MB → finalize`，`total_chunks=8`；乱序 / 重放 / 少一字节的片返回 409；`finalize` 前调 `abort` 后会话键全清、TG 已发消息被尽力删除
   - [ ] HF 120MB 文件 finalize 后 `nodes.lanzou_id` 仍是普通 `hf://u<uid>/<sha256>.bin`、`chunks=1`、`commits=1` 且 `hf_modes=["lfs"]`，下载字节与源文件逐字节一致；TG 120MB 文件 `tg://` 清单含 8 个 part、`chunks=8`，跨片 Range 206 正确
   - [ ] 同一批混选 3 个小文件 + 1 个 120MB 大文件：小文件仍 `commits=1` 合并、大文件单独分片；超过 512MB 的 `begin` 返回真实 413；`/api/server-info` 含 `manual_chunk_bytes=16777216` 与 `manual_max_file_bytes=536870912`
   - [ ] 管理员开 `random` 后连续上传 10 个文件，`nodes.account_id` 出现多个池账号且每个文件都能下载 / 预览 / 分享；关 `off` 后全部落到同一个账号；`weighted` 下权重高的账号命中更多
   - [ ] 一个 >90MB 分块上传的所有分块落在同一账号（`chunk_session` 的 `accountId` 生效），abort 后云端残留被该账号会话清理，不误删别的账号目录
   - [ ] 存量文件（`account_id=''`）与池文件混合批量删除 / 恢复 / 清空回收站都成功，不会用错账号会话或 formhash
   - [ ] 普通用户在 App 看不到上传 / 新建 / 删除等入口，网页端看不到「存储账号池」导航；管理员两者都可见且可操作
   - [ ] 设置页点「测试连接」：dedicated 显示绿色「独立密钥 · 安全」、legacy 显示红色「兼容模式 · 与登录口令同源」并带配置建议、未检测时不显示签名行；旧版后端不返回该字段时显示「未知（服务端未返回）」而非猜测成 legacy
   - [ ] 打开 PDF 内联渲染：页码与总页数真实、上一页/下一页可用；加密 PDF 输入正确密码后渲染、错误密码给出真实错误；渲染失败时三个降级入口都可用
   - [ ] 看过的 PDF 杀 App 重进（或断网）能命中缓存秒开；点「重新加载」后缓存被清并重新下载；云端替换同名文件（`size_bytes` 变化）后旧缓存自动作废
   - [ ] PDF 下载到一半断网：不留 `.part` 半文件，重试后成功；签名 URL 剩余不足 60 秒时自动续签再下载；传输页**不出现**因预览 PDF 产生的任务记录
   - [ ] 上传大文件途中点「暂停」：请求真的停止（抓包无后续块）、传输页卡片仍可见且显示「已暂停 · 请求已取消」、云端 `.chunk-<id>` 残留被 abort 清理、首页/文件页**不弹**「上传失败」toast
   - [ ] 点「继续」：进度从 0 重新开始（不是接着 60% 跑）、生成新 uploadId、最终完成且云端只生成 1 个文件；点「重试」对失败任务同样能真正重新发成功
   - [ ] 上传失败后删掉本地源文件再点「重试」：显示「源文件不可读，请重新选择文件」而不是静默成功；点「重新选择文件」选新文件后旧记录消失、新任务出现并成功；在选择器里取消则旧记录保留
   - [ ] 下载途中暂停 / 重试同样生效；「全部暂停」一次取消所有进行中任务；杀 App 重启后历史失败记录只显示「可移除」，不显示可点的「重试」
   - [ ] dedicated 模式下用改造前的 `APP_PASSWORD` 派生签名手工构造 `/api/preview?...` 返回 403；登录后网页端 Cookie 可正常鉴权；`lf_` 令牌切换密钥后仍可用
   - [ ] 上传 / 下载完成后 **杀掉 App 重启**：传输页「已完成」/「失败」记录仍在且为真实任务；「正在传输」为空、搜索页「N 个任务进行中」为 0、速度卡显示「空闲中」
   - [ ] 设置页「清除传输记录」后重启，记录不「复活」；失败卡片点「移除记录」后该条从磁盘一并消失
   - [ ] 传输到一半强杀 App：重启后**不出现**卡在 60% 的假 running 任务（未完成任务不落盘）

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

---

## 7. 前端功能对齐清单

以 App 页面交互为准，逐一核对前后端契约。图例：✅ 已接通真实接口；⚠️ 前端占位（后端无对应能力，见 7.2）；🔶 部分接通。

### 7.1 功能 → 接口 → 状态

| 页面 / 功能 | 前端入口 | 后端接口 / 数据处理 | 状态 |
| --- | --- | --- | --- |
| 登录（含 TOTP） | 登录页提交 | `POST /api/auth/login {u,p,code?}` → `POST /api/tokens` | ✅ |
| 退出登录 | 我的页 | `DELETE /api/tokens/:id` + 清本地凭证 | ✅ |
| 账户身份 / 会员状态 | 首页头图、我的页头图 / VIP 徽章 / 会员横幅 | `GET /api/status`（用户名、角色、`vip_until`、四项计数） | ✅ |
| 会员管理（仅 admin） | 我的页「会员管理」、会员管理页 | `GET /api/admin/users` + `POST /api/admin/users/:id/vip` | ✅ |
| 登录设备管理 | 我的页「设备管理」、设备管理页 | `GET /api/tokens` + `POST` / `PATCH /api/tokens/:id` / `DELETE` | ✅ |
| 两步验证 | 我的页「安全中心」、安全中心页 | `GET /api/security/2fa` + `POST .../setup` / `enable` / `disable` | ✅ |
| 存储账号管理 | 存储页「管理」、存储账号页 | `GET /api/storage/account` + `POST /api/storage/login` / `logout` | ✅ |
| 容量环 / 分段进度条 / 存储页 | 首页 / 存储页 | `GET /api/storage/summary`（含 `by_category`）；分段条按真实字节占比渲染，见 2.18 | ✅ |
| 清理建议 / 一键清理 | 存储页清理卡片 | `GET /api/storage/analyze` + `POST /api/storage/clean` | ✅ |
| 文件列表 / 分类筛选 | 文件页胶囊 | `GET /api/list?pid=&sort=` + 本地扩展名分类 | ✅ |
| 排序 | 文件页右上 / SectionHead | `GET /api/list?sort=`（后端 SQL 白名单） | ✅ |
| 批量管理 / 行操作菜单 | 文件页右上「更多」、行尾与文件夹卡片菜单 | `GET /api/folders` + `POST /api/move` / `delete` / `rename` | ✅ |
| 目录钻取 / 新建文件夹 / 返回上级 | 文件夹卡片 / FAB / 更多菜单 | `GET /api/list?pid=` + `POST /api/mkdir` + 本地返回栈 | ✅ |
| 搜索 / 历史 | 搜索页 | `GET /api/search?q=` + 本地持久化历史 | ✅ |
| 快捷筛选 / 最近文件 | 搜索页 | `GET /api/stats/quick` + 本地 `LocalTransferStore.running` | ✅ |
| 设置 / 服务地址 / 连接自检 | 我的页「设置」、设置页 | `GET /api/server-info` + 本地 `SettingsStore` / `LocalTransferStore`；展示真实 `signing_mode` 三态（见 2.17） | ✅ |
| 管理员全局存储账号池 | 网页端「存储账号池」页（仅 admin） | `GET/POST/PATCH/DELETE /api/storage/accounts`（见 2.19） | ✅ |
| HF 私库手动通道 | 网页端「存储账号池」+ 文件页「上传目标」（仅 admin，App 不用） | `POST /api/admin/storage/accounts/:id/test`、`POST /api/admin/storage/upload`（见 2.21） | ✅ |
| Telegram Bot 手动通道 | 网页端「存储账号池」+ 文件页「上传目标」（仅 admin，App 不用） | 同上端点（`kind=telegram`）+ `getFile` 代理下载（见 2.22） | ✅ |
| HF / TG 大文件分片上传 | 网页端「上传目标」（仅 admin，>90MB 自动触发） | `POST /api/admin/storage/upload/begin|chunk|finalize|abort`（见 2.23） | ✅ |
| 多蓝奏账号随机均衡上传 | 网页端均衡开关 + App 上传（透明） | `GET/POST /api/admin/storage-balance` + 服务端选择器（见 2.20） | ✅ |
| 普通用户文件树只读 | App 全部写入口（已隐藏） | 统一中间件 403 + `AdminOnly` 隐藏入口；账号自助保留 | ✅ |
| 帮助与反馈 | 我的页「帮助与反馈」、帮助页 | `POST` / `GET /api/feedback` + `GET` / `PATCH /api/admin/feedback/:id` | ✅ |
| 扫一扫 / 分享转存 | 首页「扫一扫」、扫码页 | `POST /api/scan/resolve` + `POST /api/rent` / `POST /api/import-lanzou` + `GET /api/folders` | ✅ |
| 上传（≤90MB） | 首页上传 / FAB | `POST /api/upload?pid=` raw + `X-Heri-Name` | ✅ |
| 上传（>90MB） | 同上 | `POST /api/upload/chunk` 8MB/块 + Finalize | ✅ |
| 下载并打开 | 预览页下载 | `GET /api/stream?id=` → 保存到应用目录 → `open_filex` | ✅ |
| 在线看图片 | 预览页 | `GET /api/preview/url` → `Image.network(签名URL)` | ✅ |
| 在线看视频/音频 | 预览页 | 同上 → `video_player`（Range 流式） | ✅ |
| 在线看文本 | 预览页 | 同上 → `Dio.get<String>(签名URL)` 展示 | ✅ |
| 在线看 PDF | 预览页 | `GET /api/preview/url` → 能力 URL 下载到私有缓存 → `flutter_pdfview` 原生渲染；带缓存、续签、密码、翻页（见 2.15） | ✅ |
| 在线看其他格式 | 预览页 | 无内联渲染，提示下载后用系统应用打开 | 🔶 |
| 分享 / 复制 / 撤销 | 预览页、我的页 | `POST /api/share`、`GET /api/my-shares`、`DELETE /api/shares/:id` | ✅ |
| 重命名 / 删除 | 预览页工具 | `POST /api/rename`、`POST /api/delete` | ✅ |
| 回收站恢复/清空 | 回收站页 | `GET /api/bin`、`POST /api/restore`、`POST /api/empty-bin` | ✅ |
| 传输进度 | 传输页 | 本地 `LocalTransferStore` + dio 回调（真实进度） | ✅ |
| 暂停 / 继续 / 重试 / 重新选文件 | 传输页卡片、全部暂停 | `CancelToken` 真取消 + 重新发起一整次传输；分块取消会 abort 云端残留（见 2.16） | ✅ |
| 传输记录持久化 / 清除 | 传输页、搜索页、设置页 | 本地 `shared_preferences`（仅终态任务，重启恢复；见 2.14） | ✅ |
| 相册 | 相册页 | `GET /api/list?pid=0` 过滤图片分类 | ✅ |
| 首页为你推荐回忆卡 | 首页「为你推荐」 | `GET /api/recall/daily?today=`（真实日期聚合 + 签名缩略图） | ✅ |
| 我的照片回忆 / 轮播 | 相册页横幅、照片回忆页 | `GET /api/recall/album`（真实分组 + 签名 URL + 自动续签） | ✅ |

### 7.2 后端暂无法提供 / 未实现的能力

| 前端展示 | 原因 | 影响范围 | 待处理方式 |
| --- | --- | --- | --- |
| 生成 MP4 回忆视频（未选 B 方案） | 需 ffmpeg / 视频合成与回传存储账号，VPS 开销大 | **无影响**：已按 A 方案用真实照片轮播实现，不生成视频 | 若将来要真 MP4，需后端新增合成服务、ffmpeg 依赖、回传与失败重试；当前 App 已具备完整回忆播放能力 |
| 真正的断点续传（从已传字节继续） | lanflare 上传同步完成，无断点续传协议与服务端任务表 | **无影响**：第 17 步已实现真实暂停（CancelToken 取消）、继续 / 失败重试（重新发起一整次请求）与「重新选择文件」，见 2.16；代价是重发从头开始，UI 已明确告知 | 若将来要真续传，需后端任务表 + 分块续传协议（2.6 的服务端会话状态机已具备部分基础） |

### 7.3 配置项

| 位置 | 配置 | 用途 |
| --- | --- | --- |
| `AppConfig.apiBaseUrl` | `https://lz.miro.us.ci` | 后端自定义域（国内可达） |
| `AppConfig.fallbackTotalGb` | 100 | 后端未配 `STORAGE_TOTAL_BYTES` 时的容量兜底 |
| `AppConfig.maxUploadBytes` | 90MB | 单请求/分块上传阈值（与 Worker `MAX_UPLOAD_BYTES` 一致） |
| Cloudflare Secret `STORAGE_TOTAL_BYTES` | 字节数 | 容量总量；未配置返回 0，App 用兜底值 |
| Cloudflare Secret / VPS env `APP_PASSWORD` | 主账号登录口令 | 仅用于登录认证与首账号 bootstrap。**仅在 `legacy` 模式**（未配 `APP_SIGNING_KEY`）下才兼作签名材料 |
| Cloudflare Secret / VPS env `APP_SIGNING_KEY` | 独立高熵签名密钥（`openssl rand -hex 32`） | **第 15 步新增**：会话 Cookie（salt `lanflare-key:`）与预览 URL（salt `lanflare-preview-key:`）各自从它派生，与登录口令分离
| VPS env `STORAGE_ACCOUNTS_JSON` | 管理员全局账号池首次种子 | **第 20 步新增**：仅在池表为空时导入一次，之后以 DB 为准；蓝奏用会话 Cookie、HF/TG 用令牌，均不接受登录明文口令（见 2.20）；同一部署所有实例必须一致。`GET /api/server-info` 的 `signing_mode` 回显 `dedicated` / `legacy`，不泄露密钥 |


### 7.4 在线查看鉴权设计

图片/视频组件无法附加 `Authorization` 头，因此采用**短期签名能力 URL**：

1. App 调 `GET /api/preview/url?id=<id>`（走正常 Bearer 令牌 / 会话 Cookie 鉴权）。
2. 后端对 `uid:id:exp` 做 HMAC-SHA256 签名，返回 15 分钟有效的 `/api/preview?id=&uid=&exp=&sig=`。**签名材料由 `lanflare/src/signing.ts` 统一解析**：

   | 模式 | 条件 | 派生式 |
   | --- | --- | --- |
   | `dedicated`（推荐） | 配置了 `APP_SIGNING_KEY` | `SHA-256("lanflare-preview-key:" + APP_SIGNING_KEY)` |
   | `legacy`（兼容） | 未配置 | `SHA-256("lanflare-preview-key:" + APP_PASSWORD)`（与改造前逐字一致） |

   会话 Cookie 同理，salt 为 `lanflare-key:`。两个用途始终用不同 salt，密钥不可互推；`APP_SIGNING_KEY` 与登录口令完全分离后，**口令泄露不再足以伪造任意 uid 的会话或预览链接**。
3. `Image.network` / `video_player` / `Dio` 直接加载该 URL（守卫对精确路径 `/api/preview` 放行，路由内自校验 HMAC 与过期时间）。**客户端零改动**：URL 格式、字段名、TTL 全部不变。
4. 过期后重新签发即可；URL 泄露仅在 15 分钟内有效。

### 7.4.1 第 15 步：签名密钥分离（后端改造）

- 新增 `lanflare/src/signing.ts`（纯 WebCrypto，无 D1 / 无网络 / 无 Node-only API）：`signingMaterial()` / `signingMode()` / `sessionHmacKey()` / `previewHmacKey()`。
- `auth.ts` 删除本地 `hmacKey()`；`createSessionToken()` 改为接收 `Env`，`verifySessionToken()` 改用共享 `sessionHmacKey(env)`。`index.ts` 删除本地 `previewHmacKey()`，签发端点、`/api/preview` 校验端点、`signRecallPhotos()`（每日回忆卡 + 相册轮播）全部改为 `previewHmacKey(env)` —— **四处签发/校验口径完全一致**，不会出现「回忆卡能看、预览页 403」的分裂。
- `Env` 类型新增 `APP_SIGNING_KEY?: string`；VPS `src/server/main.ts` 读取并传入，启动时打印 `signing: DEDICATED` 或告警 `LEGACY`，短密钥告警，日志绝不打印密钥值。
- `/api/server-info` 新增 `signing_mode` 字段（公开、无鉴权、不泄露密钥），供设置页 / 运维确认配置是否生效。**第 18 步已把它接入 App 设置页**（`ServerInfo.signingMode` + 三态展示，见 2.17）；本步当时 App 忽略该字段，属于历史中间状态。
- `wrangler.jsonc` / `docker-compose.yml` / `examples/docker-compose.caddy.yml` / `README.md` / `/docs` 全部同步配置方法。

> **切换影响（必须记住）**：首次配置或轮换 `APP_SIGNING_KEY` 时，所有既有 `lf_session` Cookie 签名失效 → **网页端需重新登录**；切换前签发的预览 URL 在剩余 TTL 内会 403，App 的静默续签（第 12 步）与 `errorBuilder` 会在下一次拉取后恢复。数据库里以 SHA-256 哈希存储的 `lf_` API 令牌**不受影响**，App 无需重新登录。不配置则零影响（`legacy` 模式逐字兼容）。多实例部署必须同时、同值切换。
