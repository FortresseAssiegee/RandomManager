<script setup>
import { reactive, ref, watch } from "vue";
import { ArrowRight, CopyDocument, DataLine, Key, Link, Plus, Position, Refresh, Search, Tickets } from "@element-plus/icons-vue";
import { RouterLink, useRouter } from "vue-router";
import { copyText, explorerAddress, explorerTx, p2Generator, shortAddress, useRandomManager } from "../composables/useRandomManager";
import { useProjectRequestDirectory } from "../composables/useProjectRequestDirectory";

const store = useRandomManager();
const router = useRouter();
const directory = useProjectRequestDirectory();
const statusText = ["不存在", "等待签名", "已生成随机数", "已消费"];
const statusType = ["info", "warning", "success", "info"];
const createDialogVisible = ref(false);
const lookupName = ref("");
const lookupResult = ref("");
const lookupRequested = ref(false);
const prediction = reactive({ visible: false, address: "", salt: "" });
const form = reactive({
  projectName: "lucky-draw-01",
  owner: "",
  salt: "randora-v1",
  ...p2Generator,
});

watch(
  () => store.account.value,
  (value) => {
    if (value && !form.owner) form.owner = value;
  },
  { immediate: true },
);

function isCurrent(project) {
  return store.projectAddress.value && project.proxy.toLowerCase() === store.projectAddress.value.toLowerCase();
}

async function refreshDirectory() {
  directory.resetDirectory();
  await directory.loadDirectory(true);
}

async function activate(project) {
  try {
    await store.bindProject(project.proxy);
    return true;
  } catch {
    return false;
  }
}

async function openWorkspace(project) {
  if (await activate(project)) router.push({ path: "/workspace", query: { project: project.proxy } });
}

async function openRequest(project, request) {
  if (await activate(project)) router.push({ path: "/requests", query: { id: request.id } });
}

function openCreateDialog() {
  prediction.visible = false;
  createDialogVisible.value = true;
}

function resetKey() {
  Object.assign(form, p2Generator);
}

async function predict() {
  prediction.visible = false;
  try {
    Object.assign(prediction, await store.predictProject(form), { visible: true });
  } catch {}
}

async function create() {
  prediction.visible = false;
  try {
    await store.createProject(form);
    createDialogVisible.value = false;
    await refreshDirectory();
  } catch {}
}

async function lookup() {
  lookupRequested.value = false;
  lookupResult.value = "";
  try {
    lookupResult.value = await store.lookupProject(lookupName.value);
    lookupRequested.value = true;
  } catch {}
}

async function loadLookup() {
  try {
    await store.bindProject(lookupResult.value);
    await refreshDirectory();
  } catch {}
}

refreshDirectory();
</script>

<template>
  <section class="unified-request-directory">
    <div class="request-directory-head">
      <div>
        <span class="section-kicker">PROJECT DIRECTORY</span>
        <h2>当前项目、链上历史与随机请求</h2>
        <p>每次进入项目工厂都会重新读取项目事件，并查询每个项目的用户种子、随机数和处理状态。</p>
      </div>
      <el-button :icon="Refresh" :loading="directory.loading.value" @click="refreshDirectory">刷新链上数据</el-button>
    </div>

    <div class="request-current-zone">
      <div class="request-zone-label"><span>CURRENT PROJECT</span><i>当前操作上下文</i></div>
      <div v-if="store.projectMeta.valid" class="request-current-summary">
        <span>{{ store.projectName.value.slice(0,1).toUpperCase() }}</span>
        <div>
          <small>ACTIVE RANDOM PROJECT</small>
          <h3>{{ store.projectName.value }}</h3>
          <button @click="copyText(store.projectAddress.value)">{{ store.projectAddress.value }} <CopyDocument /></button>
        </div>
        <dl>
          <div><dt>OWNER</dt><dd>{{ shortAddress(store.projectMeta.owner) }}</dd></div>
          <div><dt>REQUESTS</dt><dd>{{ store.projectMeta.requestCount }}</dd></div>
          <div><dt>STATUS</dt><dd>{{ store.projectMeta.paused ? "已暂停" : "运行中" }}</dd></div>
        </dl>
        <RouterLink :to="{ path: '/workspace', query: { project: store.projectAddress.value } }">打开工作台 <ArrowRight /></RouterLink>
      </div>
      <div v-else class="request-directory-empty compact">
        <Link />
        <strong>尚未选择当前项目</strong>
        <span>可创建项目，或从下方历史中设为当前项目</span>
      </div>
    </div>

    <div class="request-directory-tools">
      <el-button class="create-project-button" :icon="Plus" @click="openCreateDialog">创建项目</el-button>
      <div class="directory-lookup">
        <el-input v-model="lookupName" size="large" placeholder="输入 Project ID 查找已有项目" clearable @keyup.enter="lookup">
          <template #prefix><el-icon><Search /></el-icon></template>
          <template #append><el-button :loading="store.loading.lookup" @click="lookup">查询项目</el-button></template>
        </el-input>
        <div v-if="lookupRequested && lookupResult" class="directory-lookup-result">
          <small>projectProxy() 返回值</small>
          <code>{{ lookupResult }}</code>
          <el-button link type="primary" @click="loadLookup">设为当前项目</el-button>
        </div>
      </div>
    </div>

    <div class="request-history-zone">
      <div class="request-zone-label">
        <span>PROJECT & REQUEST HISTORY</span>
        <i v-if="directory.loaded.value">{{ directory.projects.value.length }} 个项目</i>
        <i v-else>{{ directory.loading.value ? "正在读取链上数据…" : "等待读取" }}</i>
      </div>
      <div v-if="directory.error.value" class="console-error">{{ directory.error.value }}</div>
      <div v-if="directory.loading.value && !directory.loaded.value" class="request-directory-empty">
        <Refresh class="loading-ring" />
        <strong>正在读取项目与随机请求</strong>
        <span>先读取 ProjectCreated，再逐个查询 requestId 和 getRequest。</span>
      </div>
      <div v-else-if="directory.loaded.value && !directory.projects.value.length" class="request-directory-empty">
        <Tickets />
        <strong>暂无项目历史</strong>
      </div>

      <div v-else class="project-request-list">
        <article v-for="project in directory.projects.value" :key="project.transactionHash" class="project-request-card" :class="{ current: isCurrent(project) }">
          <header>
            <div class="request-project-identity">
              <span>{{ project.name.slice(0,1).toUpperCase() }}</span>
              <div>
                <small v-if="isCurrent(project)">CURRENT PROJECT</small>
                <h3>{{ project.name }}</h3>
                <button @click="copyText(project.proxy)">{{ project.proxy }} <CopyDocument /></button>
              </div>
            </div>
            <dl>
              <div><dt>OWNER</dt><dd>{{ shortAddress(project.owner,10,6) }}</dd></div>
              <div><dt>REQUESTS</dt><dd>{{ project.requestCount }}</dd></div>
              <div><dt>PROJECT STATUS</dt><dd :class="{ paused: project.paused }">{{ project.paused ? "已暂停" : "运行中" }}</dd></div>
              <div><dt>CREATED BLOCK</dt><dd>{{ project.blockNumber }}</dd></div>
            </dl>
            <div class="request-project-actions">
              <el-button class="launch-request-button" :disabled="project.paused" @click="openWorkspace(project)">{{ project.paused ? "项目已暂停" : "发起随机请求" }}</el-button>
              <el-button v-if="!isCurrent(project)" class="project-current-action set-current-action" link @click="activate(project)">设为当前项目</el-button>
              <el-tag v-else class="project-current-action" type="success" effect="dark" round>当前项目</el-tag>
              <a :href="explorerAddress(project.proxy)" target="_blank">合约 <Position /></a>
              <a :href="explorerTx(project.transactionHash)" target="_blank">创建交易 <Position /></a>
            </div>
          </header>

          <div class="random-request-table">
            <div class="random-request-table-head">
              <span>ID</span><span>用户随机种子</span><span>产生的随机数</span><span>区块</span><span>状态</span>
            </div>
            <div v-if="!project.requests.length" class="no-project-requests">该项目还没有随机数请求</div>
            <div v-for="request in project.requests" :key="request.id" class="random-request-row">
              <strong>#{{ request.id }}</strong>
              <div>
                <span>{{ request.userSeedText }}</span>
                <button @click="copyText(request.userSeed)">{{ shortAddress(request.userSeed,10,6) }} <CopyDocument /></button>
              </div>
              <div class="generated-randomness">
                <span>{{ request.randomness === "0" ? "尚未生成" : request.randomness }}</span>
                <button v-if="request.randomness !== '0'" @click="copyText(request.randomness)"><CopyDocument /></button>
              </div>
              <code>{{ request.blockNumber }}</code>
              <button v-if="request.status === 1 || request.status === 2" class="request-status-link" @click="openRequest(project, request)">
                <el-tag :type="statusType[request.status]" effect="dark" round>{{ statusText[request.status] }}</el-tag>
                <small>{{ request.status === 1 ? "去签名" : "去消费" }}</small>
              </button>
              <el-tag v-else :type="statusType[request.status]" effect="dark" round>{{ statusText[request.status] }}</el-tag>
            </div>
          </div>
        </article>
      </div>
    </div>

    <el-dialog v-model="createDialogVisible" class="create-project-dialog" title="创建项目" width="min(760px, 94vw)" destroy-on-close>
      <el-form label-position="top" class="contract-form">
        <div class="form-grid two">
          <el-form-item label="Project ID">
            <el-input v-model="form.projectName" placeholder="输入项目 ID"><template #prefix><el-icon><DataLine /></el-icon></template></el-input>
          </el-form-item>
          <el-form-item label="用户盐值">
            <el-input v-model="form.salt" placeholder="输入 Salt"><template #prefix><el-icon><Key /></el-icon></template></el-input>
          </el-form-item>
        </div>
        <el-form-item label="项目所有者"><el-input v-model="form.owner" placeholder="0x..." /></el-form-item>
        <div class="subform-heading">
          <div><strong>BLS G2 公钥</strong><span>已填入 P2 演示公钥，可按项目需要修改。</span></div>
          <el-button link type="primary" @click="resetKey">恢复演示公钥</el-button>
        </div>
        <div class="form-grid two compact">
          <el-form-item label="X[0]"><el-input v-model="form.x0" placeholder="uint256" /></el-form-item>
          <el-form-item label="X[1]"><el-input v-model="form.x1" placeholder="uint256" /></el-form-item>
          <el-form-item label="Y[0]"><el-input v-model="form.y0" placeholder="uint256" /></el-form-item>
          <el-form-item label="Y[1]"><el-input v-model="form.y1" placeholder="uint256" /></el-form-item>
        </div>
        <div v-if="prediction.visible" class="prediction-box inline-contract-result">
          <span class="prediction-icon"><Position /></span>
          <div>
            <small>predictProjectAddress() 返回值</small>
            <strong>{{ prediction.address }}</strong>
            <span>makeSalt() · {{ prediction.salt }}</span>
          </div>
          <el-button circle :icon="CopyDocument" @click="copyText(prediction.address)" />
        </div>
      </el-form>
      <template #footer>
        <el-button @click="createDialogVisible = false">取消</el-button>
        <el-button :icon="Position" :loading="store.loading.predict" @click="predict">预测地址</el-button>
        <el-button class="solid-action" :icon="Plus" :loading="store.loading.create" @click="create">创建项目</el-button>
      </template>
    </el-dialog>
  </section>
</template>

<style>
.unified-request-directory { overflow:hidden; border:1px solid rgba(123,150,177,.17); border-radius:24px; background:rgba(9,22,38,.92); box-shadow:0 22px 65px rgba(0,0,0,.2); }
.request-directory-head { display:flex; justify-content:space-between; gap:24px; align-items:flex-end; padding:28px; border-bottom:1px solid rgba(123,150,177,.14); }
.request-directory-head h2 { margin:6px 0; color:#eef7ff; font-size:clamp(25px,3vw,36px); }
.request-directory-head p { margin:0; color:#7993aa; }
.request-current-zone,.request-history-zone { padding:24px 28px 28px; }
.request-history-zone { border-top:1px solid rgba(123,150,177,.14); background:rgba(3,12,22,.24); }
.request-zone-label { display:flex; justify-content:space-between; align-items:center; gap:12px; margin-bottom:15px; }
.request-zone-label span { color:#b8ff5a; font-size:10px; font-weight:900; letter-spacing:.14em; }
.request-zone-label i { color:#69839b; font-size:11px; font-style:normal; }
.request-current-summary { display:grid; grid-template-columns:auto minmax(220px,1fr) minmax(260px,.8fr) auto; gap:20px; align-items:center; padding:20px; border:1px solid rgba(184,255,90,.18); border-radius:17px; background:linear-gradient(120deg,rgba(184,255,90,.08),rgba(9,25,41,.5)); }
.request-current-summary > span,.request-project-identity > span { display:grid; place-items:center; width:54px; height:54px; border-radius:15px; background:#b8ff5a; color:#07111f; font-size:22px; font-weight:900; }
.request-current-summary h3,.request-project-identity h3 { margin:4px 0; color:#eef7ff; }
.request-current-summary small,.request-project-identity small { color:#b8ff5a; font-size:8px; font-weight:900; letter-spacing:.1em; }
.request-current-summary button,.request-project-identity button { display:flex; align-items:center; gap:5px; max-width:100%; padding:0; border:0; background:transparent; color:#7893aa; font:10px monospace; cursor:pointer; overflow-wrap:anywhere; }
.request-current-summary button svg,.request-project-identity button svg { flex:0 0 12px; width:12px; }
.request-current-summary dl,.project-request-card header > dl { display:grid; grid-template-columns:repeat(2,1fr); gap:10px; margin:0; }
.request-current-summary dl div,.project-request-card header > dl div { display:grid; gap:3px; }
.request-current-summary dt,.project-request-card dt { color:#607b94; font-size:8px; letter-spacing:.09em; }
.request-current-summary dd,.project-request-card dd { margin:0; color:#d5e4ef; font-size:11px; }
.request-current-summary > a { display:flex; align-items:center; gap:6px; color:#b8ff5a; font-size:12px; font-weight:700; text-decoration:none; }
.request-directory-tools { display:grid; grid-template-columns:auto minmax(280px,1fr); gap:16px; align-items:start; padding:20px 28px; border-top:1px solid rgba(123,150,177,.14); background:rgba(102,177,255,.035); }
.create-project-button { min-height:40px; border-color:rgba(184,255,90,.34); background:rgba(184,255,90,.1); color:#b8ff5a; }
.directory-lookup { display:grid; gap:9px; }
.directory-lookup-result { display:grid; grid-template-columns:auto minmax(0,1fr) auto; gap:10px; align-items:center; padding:10px 12px; border:1px solid rgba(102,177,255,.18); border-radius:10px; background:rgba(5,15,26,.6); }
.directory-lookup-result small { color:#7893aa; font-size:9px; }
.directory-lookup-result code { overflow:hidden; color:#dbe9f4; font-size:10px; text-overflow:ellipsis; }
.request-directory-empty { display:grid; place-items:center; min-height:150px; gap:7px; border:1px dashed rgba(123,150,177,.2); border-radius:15px; color:#718ba3; text-align:center; }
.request-directory-empty.compact { display:flex; justify-content:center; min-height:auto; padding:20px; }
.request-directory-empty svg { width:27px; color:#66b1ff; }
.request-directory-empty strong { color:#dce9f4; }
.loading-ring { animation:request-spin 1.2s linear infinite; }
@keyframes request-spin { to { transform:rotate(360deg); } }
.project-request-list { display:grid; gap:16px; }
.project-request-card { overflow:hidden; border:1px solid rgba(123,150,177,.14); border-radius:17px; background:rgba(5,15,26,.68); }
.project-request-card.current { border-color:rgba(184,255,90,.34); }
.project-request-card > header { display:grid; grid-template-columns:minmax(260px,1.2fr) minmax(280px,.8fr) auto; gap:20px; align-items:center; padding:18px; }
.request-project-identity { display:flex; gap:12px; align-items:center; min-width:0; }
.request-project-identity > span { width:44px; height:44px; border-radius:12px; font-size:17px; }
.request-project-identity > div { min-width:0; }
.request-project-actions { display:flex; align-items:center; gap:10px; }
.request-project-actions .launch-request-button { border-color:rgba(184,255,90,.28); background:rgba(184,255,90,.08); color:#b8ff5a; }
.request-project-actions .project-current-action { display:inline-flex; width:96px; min-width:96px; justify-content:center; box-sizing:border-box; }
.request-project-actions .set-current-action { color:#607b94; }
.request-project-actions .set-current-action:hover { color:#8ba5bc; }
.request-project-actions a { display:flex; align-items:center; gap:3px; color:#7897b1; font-size:10px; text-decoration:none; }
.request-project-actions a svg { width:11px; }
.project-request-card dd.paused { color:#ff8e82; }
.random-request-table { border-top:1px solid rgba(123,150,177,.12); }
.random-request-table-head,.random-request-row { display:grid; grid-template-columns:55px minmax(130px,.7fr) minmax(260px,1.6fr) 90px 180px; gap:12px; align-items:center; padding:11px 16px; }
.random-request-table-head { background:rgba(102,177,255,.055); color:#627f98; font-size:9px; font-weight:800; letter-spacing:.08em; }
.random-request-table-head > span { text-align:center; }
.random-request-row + .random-request-row { border-top:1px solid rgba(123,150,177,.09); }
.random-request-row > strong,.random-request-row > code { text-align:center; }
.random-request-row > strong { color:#8fc9ff; }
.random-request-row > div { display:grid; min-width:0; gap:3px; }
.random-request-row > div > span { color:#d9e8f4; overflow-wrap:anywhere; }
.random-request-row button { display:flex; align-items:center; gap:4px; width:max-content; padding:0; border:0; background:transparent; color:#6e8aa3; font:9px monospace; cursor:pointer; }
.random-request-row button svg { width:10px; }
.generated-randomness > span { font:11px/1.5 monospace; overflow-wrap:anywhere; }
.random-request-row > code { color:#88a0b5; font-size:10px; }
.random-request-row > .el-tag,.request-status-link { justify-self:center; }
.request-status-link { display:flex; align-items:center; justify-content:center; gap:9px; min-width:145px; padding:0; border:0; background:transparent; cursor:pointer; }
.request-status-link small { color:#8fc9ff; font-size:9px; white-space:nowrap; }
.request-status-link:hover small { color:#b8ff5a; }
.no-project-requests { padding:22px; color:#6f899f; text-align:center; }
.create-project-dialog .prediction-box { margin-top:10px; }
.factory-directory-content { display:block; }
@media (max-width:1050px) { .request-current-summary { grid-template-columns:auto 1fr auto; } .request-current-summary dl { grid-column:1/-1; } .project-request-card > header { grid-template-columns:1fr 1fr; } .request-project-actions { grid-column:1/-1; } .random-request-table { overflow-x:auto; } .random-request-table-head,.random-request-row { min-width:850px; } }
@media (max-width:650px) { .request-directory-head { align-items:stretch; flex-direction:column; } .request-directory-head,.request-current-zone,.request-history-zone,.request-directory-tools { padding:20px; } .request-directory-tools { grid-template-columns:1fr; } .request-current-summary { grid-template-columns:auto 1fr; } .request-current-summary > a { grid-column:1/-1; } .request-zone-label { align-items:flex-start; flex-direction:column; } .directory-lookup-result { grid-template-columns:1fr; } .project-request-card > header { grid-template-columns:1fr; } .request-project-actions { grid-column:auto; flex-wrap:wrap; } }
</style>
