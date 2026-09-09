import { createRouter, createWebHistory } from "vue-router";
import HomePage from "../pages/HomePage.vue";
import ProjectFactoryPage from "../pages/ProjectFactoryPage.vue";
import RandomWorkspacePage from "../pages/RandomWorkspacePage.vue";
import RequestTrackerPage from "../pages/RequestTrackerPage.vue";
import ProjectSettingsPage from "../pages/ProjectSettingsPage.vue";

const router = createRouter({
  history: createWebHistory(),
  scrollBehavior: () => ({ top: 0 }),
  routes: [
    { path: "/", name: "home", component: HomePage, meta: { title: "首页" } },
    { path: "/factory", name: "factory", component: ProjectFactoryPage, meta: { title: "项目工厂" } },
    { path: "/workspace", name: "workspace", component: RandomWorkspacePage, meta: { title: "随机工作台" } },
    { path: "/requests", name: "requests", component: RequestTrackerPage, meta: { title: "请求追踪" } },
    { path: "/settings", name: "settings", component: ProjectSettingsPage, meta: { title: "项目设置" } },
  ],
});

router.afterEach((to) => {
  document.title = String(to.meta.title) + " · Randora";
});

export default router;
