# 两段式静帧

以后出图只走这条。`docs/explicit-still-mode.md` 和 `autodl/run_explicit8.py` 已停用。演员锁仍以 `library/cast/CAST.md` 为准。监督 bot（漫监）只做管理：监督、纠偏、续指令，卡住才短报。不得绕过工作流自己出图、改提示词或改规则。

## 两段式

1. 第一段由 Codex CLI 生成姿势、脸、衣服和身体，只做非露骨锁定（`/home/ubuntu/.local/bin/codex exec`，参考图用 `-i` 附上）。身体板锁姿势和表情，定妆 `ref.png` 锁脸、衣服和身体。不加大尺度，不把破限提示词交给 Codex。许仙（顾承安）自己的脚不盖住，那只脚不是缺陷。不调用 agy。
2. 第一段、一采、二采的打分都由 Codex CLI 看图并执行。八项、H1–H7 和 JSON 是脚本里的固定前缀，字节不变；每次只在后面加上待分图路径和「只打这一张」。禁止 OpenCode Go vision、deepseek-v4-flash-vision、agy 和其它识图回退。Codex 未登录或不可用就失败退出。硬门没过或八项均分低于 9，只在 Codex 里重出这一张。这一分没过时，本地模型不得加大尺度。
3. Codex 锁定图过 9 之后，Qwen 只喂这一张锁图。`write_explicit_edit_with_grok` 用 grok-4.7 xhigh 看这张图，指令只写要改的衣服和胸口接触，不贴整场提示词，不写“不要改姿势”。挂 `qwen-image-edit-plus-nsfw-lora`，文件在 F34 `/root/autodl-tmp/loras/qwen-image-edit-plus-nsfw-lora.safetensors`。LoRA 强度用去衣调参定下的 `QWEN_LORA_SCALE`；还没定下之前不填数。
4. Qwen 分两采，同一种子、同一条提示、同一 LoRA 强度。一采定内容：448×600、16 步，脸、姿势、解剖、衣着或接触、硬门都要过；写实纹理和分辨率不挡一采。过了才进二采。二采只放大：把一采结果低去噪放到 896×1200，denoise 先 0.35、40 步，掉分只降到 0.30、再 0.25，步数只降不升。不改内容，不重写提示，不换种子，不重开一采。一采和二采各自记下渲染耗时。
5. 本机没有 `codex` 就失败退出，不许改走 agy，也不许改用本地 Qwen 直接出锁定图。已安装但 `codex login status` 不是已登录，同样失败退出。脚本不执行登录，不开机。

出片四个节点都要当轮短报，并带上图和八项分：工作流做好、启动、一采结果、二采结果。一采是定内容的图，二采是只放大的图。没过门也报。做好和启动还没有新图时只报节点，不拿别的图充数。

出片只使用自己的参数：一采 16 步定内容；二采从 40 步、denoise 0.35 往下降。接触强度写在一采指令里。二采不把 denoise 升到 0.45。资产档由资产流程自己定，出片不代跑资产。

这台 Cursor 环境的第一段只许 `/home/ubuntu/.local/bin/codex`。禁止 agy。禁止降级到 `autodl/run_explicit8.py` 或本地 Qwen 直接出锁定图。不要代填账号，不要开机。

## 新 VM 检查表

Cursor 环境换成新 VM 之后先做下面三步。脚本不代登录，不开机。硬门不变：没有 `codex` 或 `codex login status` 不是已登录，都失败退出；禁止 agy；禁止降级。第二段仍是 F34。

1. 路径。`command -v codex` 必须是 `/home/ubuntu/.local/bin/codex`。非交互 shell 的 PATH 没有它时，脚本再看 `~/.local/bin/codex`。两条都没有就失败退出。补装之后仍要落在这条路径。不要改走 agy。
2. 登录状态。运行 `codex login status`。退出码是 0，并且输出里有 `Logged in`，才算已登录。这台环境已登录时的一行是 `Logged in using ChatGPT`。不是这一类输出，入口失败退出。脚本不自己执行登录。
3. 缺登录时的设备码。由人在这台 VM 上运行 `codex login --device-auth`。CLI 按这个顺序打印：用 ChatGPT 设备码登录；在浏览器打开它给的链接并登录账号；填入它给的一次性码。无浏览器时，用它打印的 URL 手工打开。回到这台 VM 再跑 `codex login status`，看到 `Logged in` 才停。设备码不写进仓库或脚本。不要改用 API key 降级。这一步不开 F34。

## F34 开关机检查表

干活才开机。当前批次或任务做完，或暂停，就立刻关机留盘。禁止空转。禁止为「等下一步」挂着机。除非用户当次明确说「别关」或「先别开」。当次原话放在环境变量 `F34_TURN`。

1. 开机只发生在第二段 Qwen 真的要出图时。第一段 Codex 不开 F34。用户当次说「先别开」就不开。入口是 `f34_begin_work`，网站 `POST https://www.autodl.com/api/v1/instance/power_on`，实例只许 `xaxna66hqt-c5c9c7fc`。
2. 这一批做完、暂停、空转或停下来等下一步，`f34_shutdown_hook` 立刻 `POST https://www.autodl.com/api/v1/instance/power_off`。不调用释放或删除。数据盘保持 `107374182400` 字节。用户当次说「别关」才跳过。关机钩子本身不开机。
3. 关机后读 `GET https://www.autodl.com/api/v1/wallet/balance` 的 `assets`（厘），写进当轮报告。不要开、不要删 G09 `sa4eaxgcuq-26e36fc9`。开发者接口看不到 F34，不要改走 `/api/v1/dev/instance/pro/power_off`。

四人穿衣身体参考在 `library/cast/<id>/body-clothed/front.png`、`side.png`、`back.png`。脸用定妆，身体和姿势不锁，衣服是短袖 T 恤加及膝运动短裤或长裤，简单、贴身、好去掉，站姿中性。Codex 按 9.0 门打分时必须附上该演员的定妆 ref。背面的身份按发型、发色、肤色、体型和定妆是否一致来认，不因为看不到脸扣分。过了才可以交给本地 Qwen 去掉这张图上的衣服，结果写入 `body-nude/`。去衣这一步 Qwen 只喂这张穿衣底图，不再额外喂穿衣定妆 ref，脸在打分时对定妆。底图按自身比例输出（宽 896），把头和双脚留在画面里。每张过门后拷到 `/opt/cursor/artifacts/body-nude/<id>-<view>.png`，并写一行 DONE_ONE（演员、视角、均分、硬门、路径），不等确认就继续下一张。这一批还在出图时不中途关机；做完或暂停就立刻关机留盘。指令由 `body_undress_rules` 约束：只点名这张图里实际穿着的那几件衣服并去掉，不要大段描述衣服的样子，锁脸、姿势和体型。林晚棠同时去掉古装盘发和发饰，换成自然散发，并去掉古装妆、眉间花钿、浓唇色和眼妆，换成素颜或极淡自然妆。顾承安同时去掉发髻和额前头巾或发带，换成自然的现代短发或散发；若有角色妆也同样去掉。五官、脸型和肤色仍锁定妆 ref。这两人的裸体身体打分时发型和妆容都不算身份扣分，身份按脸、肤色、体型认。伊莲和阿德里安发型和妆容不变。林晚棠这套是人形，不是蛇尾身体。这 9 张去衣干活才开机。这一批做完或暂停就立刻关机留盘。关机之后立刻读 AutoDL 网站钱包 `assets`（单位厘），把余额数字写进当轮报告，漫画把这个数字转给额度 bot。关机流程不能跳过读余额。没过就重写指令继续重出，不设 3 次上限。同一张连续 15 次仍过不了，立刻关机留盘，并报回卡在哪一张。林晚棠正面已过门并保留。去衣循环暂停在侧面，因为无 LoRA 的结果把胸、下体和皮肤磨平。暂停后不把 F34 空开。数据盘上的适配器是 `ScottzillaSystems/qwen-image-edit-plus-nsfw-lora` 的 `qwen-image-edit-plus-nsfw-lora.safetensors`，放在 `/root/autodl-tmp/loras/`，基座是 `Qwen/Qwen-Image-Edit-2511`。diffusers 0.40 用 `load_lora_weights` 加载，这台机器没有 ComfyUI。身体去衣的 Qwen 改成两采，从这次 LoRA 调参开始用。一采约 448×600、16 步。一采只看构图、脸、身体结构、衣服是否去掉，以及硬门：身份、姿势、解剖、服装各自不低于 9，且硬门为空。照片感、美感和皮肤纹理不挡一采，留给二采。二采仍按完整八项均分 9.0 和硬门。一采的条件图按 448×600 的面积编码，不再用管线默认的约 1024² 把条件图编成 896×1184。权重是 BF16，transformer 约 39GB、文本编码器约 16GB，32GB 的 5090 放不下整模型。transformer 用 fp8 或 8bit 后常驻 GPU，VAE 一起留下，文本编码器不用时放在 CPU，LoRA 用 fuse_lora。一采条件图按 448×600 编码。改前 sequential offload、条件图约 896×1184、LoRA 未融合时，16 步约 155–165 秒，每步约 9.7–10.3 秒，显存约 12GB。二采用同一种子和同一条提示，把一采结果放大到 896×1200，denoise 从 0.35 只降到 0.30、0.25，只补轻度细节。二采掉分不重写提示，也不重开一采。一采和二采各自记渲染耗时。输入只喂穿衣底图。正面两采定参后按该强度、种子和去噪继续剩下 8 张。二采过门后写入 `library/cast/<id>/body-nude/<view>.png`，同目录 `scores.json` 记八项分、均分、硬门、种子、LoRA 强度、去噪和一采、二采耗时，并在 F34 数据盘留一份 `/root/autodl-tmp/assets/body-nude/`。无 LoRA 的已过门林晚棠正面另存 `front-smooth.png`。<!-- LORA_LOCK: pending -->

## F34 SSH 与内存（2026-10-05）

18:41（北京时间）之前 SSH 是通的：sequential offload 跑完林晚棠正面一采 8 次，主机内存约 56–58GiB，CPU 大约 1 核，GPU 显存约 12GiB、利用率约 20%–54%。18:40:06 仍是 cpu 89、内存 58424MiB、显存 12362MiB、利用率 44%。换成 group offload 的 worker 之后，18:41:36 的最后一条 GPU 样本变成显存 690MiB、利用率 0，CPU 1538，内存 60925MiB。从 18:42:16 起 GPU 样本消失，CPU 维持大约 1600%（16 核打满，峰值 2218），内存钉在 61442–61585MiB。cgroup 上限是 66571993088 字节（63488MiB），61585/63488 = 97%。到 19:54 仍是这个状态，内存 61599MiB，CPU 约 1600，GPU 样本仍为空。平台 `oom_killed` 一直是 false。

根因是这两件事叠在一起：group offload 把容器内存顶到 cgroup 上限的 97%、CPU 打满 16 核，sshd 没能清掉启动中的连接；之后新连接要么 120 秒没有 banner，要么在约 25 秒后收到 `Exceeded MaxStartups`。端口映射没有整体故障，容器也没有被 cgroup 冻住。

四种可能对过现场：

- 主机内存顶满、CPU 打满，sshd 清不掉启动中的连接。这是 MaxStartups 一直满的原因。AutoPanel `/autopanel/v1/monitor` 从开机 15:20:55 到 19:22 有 964 个点，内存和 CPU 的台阶与上面的时间对齐。网站实例接口的 `cpu_usage_percent` 在 1577–1601 之间变动，`mem_usage_percent` 是 97，`mem_usage` 约 64571830272，和这条曲线是同一批数。`usage_info.valid` 为 false，`valid_at` 停在 2026-10-03，时间戳是旧的，不能拿来当采样时间。swap 计数和 dmesg 还没读到，所以不能把根因写成已经证实的 swap 抖动；能证实的是内存贴着 cgroup 上限并且 16 核持续打满。
- paramiko 并发把 sshd MaxStartups 或代理限流打满。这是 SSH 这条路上直接读到的拒绝原因，而且现在还占着坑。15 次单连接探测里有 4 次在 TCP 成功后返回 `Exceeded MaxStartups`，分别是 19:30:43（25.1 秒）、19:34:30（8.9 秒）、19:50:51（19.8 秒）、19:52:38（6.5 秒）。另外 11 次是 120 秒 0 字节。诊断时本机已经没有 paramiko 或 ssh 进程，本地编排也停了二十分钟以上，默认 LoginGraceTime 解释不了坑还在。代理机自己的 22 端口 0.37 秒仍返回 `SSH-2.0-OpenSSH_8.9p1 Ubuntu-3ubuntu0.3`，未映射的 1 和 35240 约 0.3 秒 RST，所以不是整台代理在限流。和内存台阶放在一起：18:41 内存顶满、CPU 打满之后，sshd 没把启动中的连接清掉，MaxStartups 就一直满。本机编排器已经改成一条连接复用、banner 超时 120 秒。机器上的 MaxStartups 还没改成，因为没有 `SSH-2.0` banner，进不去。
- `connect.weste.seetacloud.com` 的端口映射坏了。不成立。该主机解析到 116.172.94.204，35239 的 TCP 握手 0.3–0.6 秒成功，只是没有 banner。同一条代理上的 AutoPanel 静态页 1 秒内返回，容器里的 `/autopanel/v1/monitor` 约 3 秒返回 JSON。容器网络没有整体断开。
- cgroup 内存限制把容器冻住。不成立。冻住时 CPU 应接近 0，这里是 16 核打满，而且 AutoPanel 的监控接口还在答。上限 62GiB 本身是压力来源，不是一次 freezer。

19:24 到 19:52 只留一个连接尝试者，每轮 banner 等待 120 秒，共 15 次。35239 的 TCP 全部在 0.7 秒内成功。11 次 120 秒收齐 0 字节，4 次收到 `Exceeded MaxStartups`，一次都没有 `SSH-2.0`。因此没有执行 `pkill`，没有在机器上改 MaxStartups，没有改后的每步耗时。group offload 不再使用。下一步只走 8bit 或已有 fp8 权重，让 transformer 和 VAE 留在 GPU，文本编码器留在 CPU，并且拒绝再把 39GB 的 BF16 整份读进内存。改前每步 9.7–10.3 秒、显存约 12GB 仍然有效。这一段写的是 19:52 之前：当时没有改后的步时，也没有关机。

授权重启后同一台 F34 于 2026-10-05 20:17:56+08 回到 running，数据盘仍是 107374182400 字节。sshd 已是 MaxStartups 100:30:200、MaxSessions 30。快照 `6f3ccc0b56e431dc6a0c2b2039706d7d26f22cb9` 的 transformer 五个分片都能打开，键数 483+468+466+474+42 等于 index 的 1933；text encoder 四个分片键数 459+131+122+17 等于 index 的 729；VAE 单文件 253806966 字节、194 个键，能打开。LoRA 文件 590058864 字节，打开后 1680 个键。torch 2.11.0+cu128，CUDA 12.8，能力 (12, 0)，架构列表含 sm_120。diffusers 0.40.0，bitsandbytes 0.50.2，peft 0.21.2。torchao 未安装。8bit 由 bitsandbytes 加载成功（`quant bitsandbytes-8bit 0.50.2`、`placement bitsandbytes-8bit`、`fuse_ok`），没有整份读入 39GB BF16。林晚棠正面一采 scale 0.85、seed 33、16 步：65.13 秒，4.07 秒/步。一采结束后 GPU 22252/32607 MiB，进程 VmHWM 26937936 KB。一采门已过。二采在 transformer 常驻时对 896×1200 编码 OOM；VAE 编码时先把 transformer 放到 CPU。LoRA 强度仍未写入。

新神话姿势锁见 `library/stills/myth-poses/POSE.md`。m01–m04 已出过一版，目检未收，见下文。

## 资产锁

- 样张只算 `library/samples/approved/` 里用户最初那几张。p01–p08 的姿势、表情和蛇尾复刻这些样张，不另起形状。m01 的蛇尾形状也复刻样张；m01–m04 的姿势仍以 `library/stills/myth-poses/POSE.md` 为准，不抄成另一格身体板。
- 身体板 `library/cast/body-boards/p01.png`–`p08.png`（八格样张裁图）锁姿势和表情。定妆 `library/cast/<id>/ref.png` 锁同一批人的脸和衣着。不要拆成两套。
- 脸是同一批人的定妆：p01–p04 林晚棠 `lin_wantang` + 顾承安 `gu_chengan`；p05–p08 伊莲·沃斯 `elena_voss` + 阿德里安·凯恩 `adrian_kane`。神话名只是角色，不另起一张脸。
- 可以比身体板更露、衣服更开、身体贴得更近。姿势、构图、表情、身份不变。不要多余的人、文字、水印，不要未成年人。

## 蛇尾锁

林晚棠的水下和蛇身格（p01、p02，以及神话蛇身格 m01）只有一条珍珠白蛇尾，没有鱼鳍、没有尾鳍、没有鱼尾、没有第二截尾巴。p02 的青色只是水光，尾巴本身仍是珍珠白钝尾。蛇身格里白蛇自己长出人腿或人脚才算不合格。顾承安自己的脚，和满分基准 `library/stills/explicit-8/anchor-10.jpg` 地上那只一样，不扣。人腿只作为明确的人身格出现（p03、p04、雨桥、药铺，以及神话人身格 m02）。雨桥没有蛇尾。同一格里不能又有人腿又有蛇尾。m02 不要蛇尾。m03、m04 不要蛇尾。

尾巴是不断的同一条。鳞片铺到圆钝尾尖，尾尖连在同一条尾巴上，不要断尖。和基准那张一样的圆钝尾尖算对。尾尖长成蛇头（眼、嘴、第二张脸）、断开的珍珠球，或切断的断尖，才算不合格。正向提示词不写 stump；stump 只放负向。

## 脸、姿势、眼睛

脸和衣服锁四位定妆：林晚棠、顾承安、伊莲·沃斯、阿德里安·凯恩，参考图 `library/cast/<id>/ref.png`。不要另起一张脸。p01–p08 的姿势和表情锁身体板。m01–m04 的姿势和表情锁 `library/stills/myth-poses/POSE.md`，不要抄定妆全身站姿，也不要抄成另一格身体板。伊莲眼睛是琥珀褐，不是绿。只有阿德里安有尖耳；伊莲和其他人都不长尖耳。阿德里安尖耳留着，不要武器。脸或衣着跑偏、姿势或表情跑偏，都算不合格。

## 禁令

出图后由 `autodl/run_explicit_two_stage.py` 调用 Codex CLI 按 `docs/still-score-two-stage.md` 打分。硬门没过，或八项均分低于 9，第一段只在 Codex 里重出，本地模型不得加尺度。第二段只有 Codex 这一分过了才允许开始。监督 bot 不得改由自己的一条生成指令来补。下面任何一条出现，这张就不算完成：

- H1 鱼尾、鱼鳍、尾鳍。
- H2 尾尖是蛇头（眼、嘴、第二张脸）、断开的珍珠球，或切断的断尖。和满分基准一样的圆钝连体尾尖不算。
- H3 白蛇自己长出人腿或人脚。许仙自己的脚不算。人身格的人腿是对的。雨桥没有蛇尾。
- H4 伊莲尖耳或绿眼。阿德里安没了尖耳，或拿了武器。别人长尖耳。
- H5 不是正好两人，多一张脸，或拼贴。
- H6 看起来像未成年人。
- H7 看得见的手多指、多一只手、断肢。

## 哪张图不能当样例

`library/stills/explicit-8/` 和神话姿势这轮出的文件都不要当样张。更早的不合格副本仍在：`archive/p02-human-leg.png`（人腿和蛇尾同时出现）、`archive/p01-unscaled-tip.png`（钝尖前面一截光滑无鳞）。不要复制，不要当批准样例。

这轮目检（2026-10-03，未收，不要当成已收）：

- explicit-8 p01：尾连着，但是左边有人脚。不算过。
- explicit-8 p02：上一轮尾尖是带眼的蛇头，已作废。2026-10-03 15:14 重出是一条鳞片铺到圆钝尾尖的蛇尾，没有头，也没有人脚。用户还没拍板收。
- m01：尾尖又是蛇头。不算过。
- m02：人身骑坐，没有蛇尾，方向对。用户还没拍板收。
- m03：在车上，但是坐着，不是站着靠栏挤压。不算过。
- m04：石地喂籽，但女的长了尖耳。不算过。
- p03–p08 是用户说过效果不错的那批。不要改它们的提示词去重跑。它们不证明蛇尾合格。
- 上面是更早那几份文件的记录。新的收留仍是 `docs/still-score-two-stage.md`：第 10 张亭中盘蛇是满分基准，许仙（顾承安）自己的脚不扣，硬门没过或均分低于 9 不算完成。这和出图后的目视是同一条，不是另一次检查。

## 出图

- 出图、打分、不达标重出，都在 `autodl/run_explicit_two_stage.py` 里完成。文件落盘不算收。第一段的生成，以及第一段、一采、二采的打分，都只许 Codex CLI。禁止 OpenCode Go vision。缺 Codex 失败退出。这一分没过，本地模型不加尺度。过了之后必须先由 `write_explicit_edit_with_grok` 用 grok-4.7 xhigh 自己看锁定图，点出这张图里实际还合着的衣服再写加尺度指令，Qwen 不能跳过这一步，也不能改回笼统的一句。第二段没过 9 只降低 denoise 和步数重做二采，不重写提示，不换种子，不退回第一段。
- 这次不跑图。p03–p08 的提示词不改，也不为这次重跑。
- 只在 AutoDL F34 `xaxna66hqt-c5c9c7fc`（西北B / west-E，RTX 5090 D）上跑本地 Qwen。不要开、不要删旧的 G09 `sa4eaxgcuq-26e36fc9`。干活才开机。用户当次说先别开就不开。
- 模型 `Qwen/Qwen-Image-Edit-2511`，用机上缓存，离线，不要重下权重。一采 448×600、16 步定内容。二采 896×1200，先 40 步、denoise 0.35，掉分只降到 0.30 再 0.25，步数只降不升。`true_cfg_scale` 4。同一张的种子和提示词不动，不重开一采。
- 入口 `autodl/run_explicit_two_stage.py`。脚本连读两份 prompts，再由 Codex 按 `docs/still-score-two-stage.md` 做目视。已知缺陷、硬门或均分低于 9，都是没完成。Codex 这一分没过时不进入本地加尺度。没有登录好的 Codex 时入口直接停住，不登录，不开机。
- 必须设置 `EXPLICIT_ONLY`。未设置时脚本退出，不会把 p01–p08 和 m01–m04 一起重跑。p03–p08 的提示词不改，也不为写规则而重跑。
- p01–p08 参考顺序仍是该格身体板在前，再跟两位演员的定妆。m01–m04 没有新身体板，参考图只有两位演员的定妆，姿势写在提示词里。
- 只跑 p01、p02：`EXPLICIT_ONLY=p01,p02 python autodl/run_explicit_two_stage.py`
- 只跑 m01–m04：`EXPLICIT_ONLY=m01,m02,m03,m04 EXPLICIT_OUT=/root/autodl-tmp/out/myth-poses python autodl/run_explicit_two_stage.py`
- 当前批次或任务做完或暂停就立刻关机留盘，权重缓存不删。禁止空转，禁止为等下一步挂着机。用户当次说别关才不关。F34 每次关机之后立刻读 AutoDL 余额（`GET /api/v1/wallet/balance` 的 `assets`，单位厘），把余额数字写进当轮报告。漫画把这个数字转给额度 bot。关机流程不能跳过读余额。

再出同类静帧时照这个锁，包括一条不断的圆钝鳞尾、白蛇自己没有人腿人脚、鳞到尖、尾尖不是头。fal 静帧模式不能代替这一条。监督 bot 也不能代替 `autodl/run_explicit_two_stage.py`。现在不要跑这个入口。
