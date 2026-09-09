# RandomManager Frontend

Randora 是 RandomManager 合约的 Vue 3 可视化控制台，支持项目创建、链上项目与请求历史、随机请求、BLS G1 验证数据、随机数消费和项目设置。

## 开发

运行 npm install，然后运行 npm run dev。

默认地址：http://127.0.0.1:5173

## 构建

运行 npm run build，使用 npm run preview 预览生产构建。

## 正式源码结构

- src/main.js：唯一前端入口
- src/router/index.js：唯一路由配置
- src/pages/：五个正式页面
- src/components/：项目目录与活动组件
- src/composables/：合约交互与链上历史
- vite.config.js：唯一构建配置
