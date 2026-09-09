import { createApp } from "vue";
import ElementPlus from "element-plus";
import zhCn from "element-plus/es/locale/lang/zh-cn";
import "element-plus/dist/index.css";
import "./styles/main.css";
import "./styles/routes.css";
import "./styles/contract-console.css";
import "./styles/contract-console-overrides.css";
import "./styles/logical-pages.css";
import AppShell from "./AppShell.vue";
import router from "./router";

createApp(AppShell).use(ElementPlus, { locale: zhCn }).use(router).mount("#app");
