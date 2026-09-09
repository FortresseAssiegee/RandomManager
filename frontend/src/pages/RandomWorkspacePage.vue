<script setup>
import { computed, onMounted, ref } from "vue";
import { RouterLink, useRoute, useRouter } from "vue-router";
import { ArrowLeft, ArrowRight, CopyDocument, Link, MagicStick } from "@element-plus/icons-vue";
import ActivityFeed from "../components/ActivityFeed.vue";
import { copyText, shortAddress, toBytes32, useRandomManager } from "../composables/useRandomManager";

const route = useRoute();
const router = useRouter();
const store = useRandomManager();
const seed = ref("round-001");
const projectLoaded = ref(false);
const projectLoading = ref(true);
const seedPreview = computed(() => {
  try {
    return seed.value ? toBytes32(seed.value) : "";
  } catch {
    return "";
  }
});

async function loadCurrentProject() {
  projectLoading.value = true;
  projectLoaded.value = false;
  const address = route.query.project ? String(route.query.project) : store.projectAddress.value;
  if (!address) {
    projectLoading.value = false;
    return;
  }
  try {
    if (!store.projectAddress.value || address.toLowerCase() !== store.projectAddress.value.toLowerCase()) {
      await store.bindProject(address);
    } else {
      await store.loadProject();
    }
    projectLoaded.value = store.projectMeta.valid;
  } catch {
    projectLoaded.value = false;
  } finally {
    projectLoading.value = false;
  }
}

function goBack() {
  router.push("/factory");
}

async function request() {
  try {
    const id = await store.requestRandomness(seed.value);
    router.push({ path: "/requests", query: { id } });
  } catch {}
}

onMounted(loadCurrentProject);
</script>

<template>
  <main class="route-page">
    <section class="page-banner workspace-banner">
      <div>
        <el-button class="route-back-button" :icon="ArrowLeft" @click="goBack">返回项目工厂</el-button>
        <span class="page-index">02</span>
        <span class="section-kicker">RANDOM WORKSPACE</span>
        <h1>随机工作台</h1>
        <p>进入页面后自动载入当前项目，并可直接提交新的随机数请求。</p>
      </div>
      <div class="banner-fact">
        <small>CURRENT PROJECT</small>
        <strong>{{ store.projectMeta.valid ? store.projectName.value : "尚未绑定" }}</strong>
        <code>{{ store.projectAddress.value || "0x—" }}</code>
      </div>
    </section>
    <section class="route-content workspace-layout">
      <div class="workspace-main">
        <section v-if="projectLoading" class="route-main-card empty-route-card">
          <span><Link /></span>
          <h2>正在自动载入当前项目</h2>
          <p>正在读取项目所有者、请求计数、验证器与运行状态。</p>
        </section>
        <section v-else-if="projectLoaded && store.projectMeta.valid" class="route-main-card request-card">
          <div class="project-card route-project-card">
            <div class="project-card-main">
              <span class="project-monogram">{{ store.projectName.value.slice(0, 1).toUpperCase() }}</span>
              <div>
                <small>loadProject() 返回值</small>
                <h3>{{ store.projectName.value }}</h3>
                <button @click="copyText(store.projectAddress.value)">{{ shortAddress(store.projectAddress.value, 12, 8) }} <el-icon><CopyDocument /></el-icon></button>
              </div>
            </div>
            <div class="project-stats">
              <div><span>OWNER</span><strong>{{ shortAddress(store.projectMeta.owner) }}</strong></div>
              <div><span>REQUESTS</span><strong>{{ store.projectMeta.requestCount }}</strong></div>
              <div><span>STATUS</span><strong :class="{ paused: store.projectMeta.paused }">{{ store.projectMeta.paused ? "已暂停" : "运行中" }}</strong></div>
            </div>
          </div>
          <div class="request-composer route-composer">
            <div class="composer-heading">
              <span class="composer-icon"><MagicStick /></span>
              <div>
                <strong>生成新的随机数请求</strong>
                <p>填写 seed 并发送交易，返回的 Request ID 将在请求追踪页自动展示。</p>
              </div>
            </div>
            <el-form label-position="top">
              <el-form-item label="用户随机种子"><el-input v-model="seed" size="large" placeholder="输入随机种子" /></el-form-item>
              <div v-if="seedPreview" class="seed-preview"><span>BYTES32 INPUT</span><code>{{ seedPreview }}</code></div>
              <el-button class="solid-action full" :icon="MagicStick" :loading="store.loading.request" :disabled="!seed || store.projectMeta.paused" @click="request">{{ store.projectMeta.paused ? "项目已暂停" : "发起随机数请求" }}</el-button>
            </el-form>
          </div>
        </section>
        <section v-else class="route-main-card empty-route-card">
          <span><Link /></span>
          <h2>尚未选择当前项目</h2>
          <p>请先在项目工厂创建项目，或从链上历史中设为当前项目。</p>
          <RouterLink to="/factory">前往项目工厂 <ArrowRight /></RouterLink>
        </section>
      </div>
      <ActivityFeed />
    </section>
  </main>
</template>
