<script setup>
import { onMounted, reactive, ref, watch } from "vue";
import { RouterLink, useRoute, useRouter } from "vue-router";
import { ArrowLeft, Check, CopyDocument, DataLine, Link, Lock, Refresh } from "@element-plus/icons-vue";
import { copyText, statusLabels, statusTypes, useRandomManager } from "../composables/useRandomManager";
import { useContractInspector } from "../composables/useContractInspector";

const route = useRoute();
const router = useRouter();
const store = useRandomManager();
const inspector = useContractInspector();
const requestId = ref(route.query.id ? String(route.query.id) : "1");
const signature = reactive({ x: "", y: "" });
const hasQueried = ref(false);
const pageLoading = ref(true);

async function loadBlsData() {
  await inspector.refresh(requestId.value);
  if (inspector.signature.available) {
    signature.x = inspector.signature.x;
    signature.y = inspector.signature.y;
  }
}

async function query() {
  hasQueried.value = false;
  signature.x = "";
  signature.y = "";
  try {
    await store.queryRequest(requestId.value);
    hasQueried.value = true;
    await loadBlsData();
  } catch {}
}

async function initializeRequest() {
  pageLoading.value = true;
  try {
    if (!store.projectMeta.valid && store.projectAddress.value) await store.loadProject();
    if (requestId.value && store.projectMeta.valid) await query();
  } catch {
    hasQueried.value = false;
  } finally {
    pageLoading.value = false;
  }
}

async function fulfill() {
  try {
    await store.fulfillRandomness(store.requestResult.id, signature);
    await query();
  } catch {}
}

async function consume() {
  try {
    await store.consumeRandomness(store.requestResult.id);
    await query();
  } catch {}
}

function goBack() {
  router.push({ path: "/workspace", query: store.projectAddress.value ? { project: store.projectAddress.value } : {} });
}

watch(
  () => route.query.id,
  async (value) => {
    if (!value) return;
    requestId.value = String(value);
    await initializeRequest();
  },
);

onMounted(initializeRequest);
</script>

<template>
  <main class="route-page">
    <section class="page-banner requests-banner">
      <div>
        <el-button class="route-back-button" :icon="ArrowLeft" @click="goBack">返回随机工作台</el-button>
        <span class="page-index">03</span>
        <span class="section-kicker">REQUEST TRACKER</span>
        <h1>请求追踪</h1>
        <p>进入页面后自动读取 Request ID 对应的请求结构体、签名消息与 BLS 验证数据。</p>
      </div>
      <div class="banner-fact">
        <small>TOTAL REQUESTS</small>
        <strong>{{ store.projectMeta.requestCount }}</strong>
        <code>{{ store.projectMeta.valid ? store.projectName.value : "NO PROJECT" }}</code>
      </div>
    </section>
    <section class="route-content request-route-content">
      <section v-if="pageLoading" class="route-main-card empty-route-card">
        <span><Refresh /></span>
        <h2>正在自动读取链上请求</h2>
        <p>正在载入 Request #{{ requestId }} 及其 BLS 验证数据。</p>
      </section>
      <div v-else-if="!store.projectMeta.valid" class="route-main-card empty-route-card">
        <span><Link /></span>
        <h2>尚未载入项目</h2>
        <p>请先在项目工厂选择项目，再从随机请求状态进入请求追踪。</p>
        <RouterLink to="/factory">前往项目工厂</RouterLink>
      </div>
      <section v-else-if="hasQueried && store.requestResult.loaded" class="route-main-card request-result-card">
        <div class="request-detail-head">
          <div><span class="request-hash">REQUEST #{{ store.requestResult.id }}</span><h3>{{ statusLabels[store.requestResult.status] }}</h3></div>
          <el-tag :type="statusTypes[store.requestResult.status]" effect="dark" round>{{ ["NONE", "PENDING", "FULFILLED", "CONSUMED"][store.requestResult.status] }}</el-tag>
        </div>
        <div class="lifecycle route-lifecycle">
          <div class="life-step done"><span><Check /></span><strong>请求已创建</strong><small>Block {{ store.requestResult.blockNumber }}</small></div>
          <i :class="{ done: store.requestResult.status >= 2 }"></i>
          <div class="life-step" :class="{ done: store.requestResult.status >= 2 }"><span><Lock /></span><strong>BLS 已验证</strong><small>写入随机数</small></div>
          <i :class="{ done: store.requestResult.status >= 3 }"></i>
          <div class="life-step" :class="{ done: store.requestResult.status >= 3 }"><span><DataLine /></span><strong>结果已消费</strong><small>防止重复使用</small></div>
        </div>
        <dl class="detail-grid route-detail-grid">
          <div><dt>getRequest().requester</dt><dd>{{ store.requestResult.requester }}</dd><button @click="copyText(store.requestResult.requester)"><CopyDocument /></button></div>
          <div><dt>getRequest().userSeed</dt><dd>{{ store.requestResult.seed }}</dd><button @click="copyText(store.requestResult.seed)"><CopyDocument /></button></div>
          <div><dt>getRequestMessage()</dt><dd>{{ store.requestResult.message }}</dd><button @click="copyText(store.requestResult.message)"><CopyDocument /></button></div>
          <div class="random-value"><dt>getRequest().randomness</dt><dd>{{ store.requestResult.status >= 2 ? store.requestResult.randomness : "0（等待 BLS 签名）" }}</dd><button v-if="store.requestResult.status >= 2" @click="copyText(store.requestResult.randomness)"><CopyDocument /></button></div>
        </dl>

        <section class="inline-bls-panel">
          <div class="subform-heading">
            <div><strong>BLS 验证器与 G1 坐标</strong><span>进入请求追踪后随请求详情自动读取。</span></div>
            <el-button link type="primary" :icon="Refresh" :loading="inspector.loading.value" @click="loadBlsData">重新读取</el-button>
          </div>
          <div v-if="inspector.verifierRows.value.length" class="return-grid inline-return-grid">
            <article v-for="row in inspector.verifierRows.value" :key="row.name" class="return-row" :class="{ failed: !row.ok }">
              <div><code>{{ row.name }}</code><small>{{ row.description }}</small></div>
              <pre>{{ row.value }}</pre>
              <el-button circle :icon="CopyDocument" @click="copyText(row.value)" />
            </article>
          </div>
          <div v-if="inspector.signature.available" class="signature-output">
            <div><small>SIGNATURE X</small><code>{{ inspector.signature.x }}</code><el-button circle :icon="CopyDocument" @click="copyText(inspector.signature.x)" /></div>
            <div><small>SIGNATURE Y</small><code>{{ inspector.signature.y }}</code><el-button circle :icon="CopyDocument" @click="copyText(inspector.signature.y)" /></div>
          </div>
          <div v-else class="console-empty">当前验证器未返回 G1 坐标，或请求消息读取失败。</div>
        </section>

        <div v-if="store.requestResult.status === 1" class="signature-box route-signature-box">
          <div class="subform-heading">
            <div><strong>提交 BLS G1 签名</strong><span>演示 P2 公钥会自动填入 hashToG1(message) 坐标；自定义公钥必须使用对应私钥签名。</span></div>
            <el-tag :type="inspector.signature.demoValid ? 'success' : 'warning'">{{ inspector.signature.demoValid ? "P2 演示签名" : "链下签名" }}</el-tag>
          </div>
          <div class="form-grid two compact">
            <el-form-item label="Signature X"><el-input v-model="signature.x" placeholder="uint256" /></el-form-item>
            <el-form-item label="Signature Y"><el-input v-model="signature.y" placeholder="uint256" /></el-form-item>
          </div>
          <el-button :icon="Lock" :loading="store.loading.fulfill" :disabled="!signature.x || !signature.y" @click="fulfill">验证并写入随机数</el-button>
        </div>
        <div v-if="store.requestResult.status === 2" class="consume-box route-consume-box">
          <div><span class="consume-icon"><DataLine /></span><div><strong>随机数已就绪</strong><p>仅项目 Owner 可以消费，消费后不可再次使用。</p></div></div>
          <el-button class="solid-action" :loading="store.loading.consume" :disabled="!store.isProjectOwner.value" @click="consume">{{ store.isProjectOwner.value ? "消费随机数" : "仅 Owner 可消费" }}</el-button>
        </div>
      </section>
      <section v-else class="route-main-card empty-route-card">
        <span><DataLine /></span>
        <h2>未能自动读取请求</h2>
        <p>请从项目工厂中点击“去签名”或“去消费”，以携带正确的 Request ID 进入。</p>
        <RouterLink to="/factory">返回项目工厂</RouterLink>
      </section>
    </section>
  </main>
</template>
