# models/

这里放**你自己的** Live2D 导出包工作副本。

真正给 Vite 开发服务器挂出去的路径是：

```text
public/models/<角色名>/*.model3.json
```

建议流程：

1. Cubism Editor 导出到任意目录
2. `npm run check-model -- /path/to/export`
3. 复制到 `public/models/local/`（或你的角色名目录）
4. 研究台加载 `/models/local/xxx.model3.json`

`models/local/` 默认忽略大文件内容，避免误传贴图与 moc3。需要版本管理模型时，另建资源仓库或 LFS，并再核对外包/样例许可。
