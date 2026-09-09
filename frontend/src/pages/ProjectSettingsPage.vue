<script setup>
import { reactive } from "vue";
import { RouterLink } from "vue-router";
import { Key, Link, Lock, Position, Setting, VideoPause, VideoPlay } from "@element-plus/icons-vue";
import { explorerAddress, p2Generator, shortAddress, useRandomManager } from "../composables/useRandomManager";

const store = useRandomManager();
const keyForm = reactive({ ...p2Generator });
const resetKey = () => Object.assign(keyForm, p2Generator);
async function updateKey() { try { await store.updatePublicKey(keyForm); } catch {} }
async function togglePause() { try { await store.togglePause(); } catch {} }
</script>

<template>
  <main class="route-page">
    <section class="page-banner settings-banner">
      <div><span class="page-index">04</span><span class="section-kicker">PROJECT SETTINGS</span><h1>项目设置</h1><p>管理项目运行状态和 BLS 验证公钥。所有写入操作仅对项目 Owner 开放。</p></div>
      <div class="banner-fact"><small>OWNER ACCESS</small><strong>{{ store.isProjectOwner.value ? "已授权" : "只读模式" }}</strong><code>{{ shortAddress(store.account.value, 12, 8) }}</code></div>
    </section>

    <section class="route-content settings-content">
      <div v-if="!store.projectMeta.valid" class="route-main-card empty-route-card">
        <span><Link /></span><h2>尚未载入项目</h2><p>项目设置必须连接到具体的 RandomProject 代理。</p><RouterLink to="/workspace">前往随机工作台</RouterLink>
      </div>

      <template v-else>
        <section class="settings-overview">
          <div><span class="project-monogram">{{ store.projectName.value.slice(0, 1).toUpperCase() }}</span><div><span class="section-kicker">ACTIVE PROJECT</span><h2>{{ store.projectName.value }}</h2><code>{{ store.projectAddress.value }}</code></div></div>
          <el-tag :type="store.projectMeta.paused ? 'danger' : 'success'" effect="dark" round>{{ store.projectMeta.paused ? "PAUSED" : "ACTIVE" }}</el-tag>
        </section>

        <div class="settings-route-grid">
          <section class="route-main-card setting-route-card">
            <div class="setting-route-head"><span class="setting-icon" :class="{ warning: !store.projectMeta.paused }"><component :is="store.projectMeta.paused ? VideoPlay : VideoPause" /></span><div><span class="section-kicker">EMERGENCY CONTROL</span><h2>{{ store.projectMeta.paused ? "恢复项目" : "紧急暂停" }}</h2><p>{{ store.projectMeta.paused ? "恢复后可以继续发起请求和提交签名。" : "暂停后将阻止新的请求和签名提交。" }}</p></div></div>
            <div class="security-note"><Lock /><span><strong>Owner Only</strong><small>当前钱包：{{ shortAddress(store.account.value, 10, 8) }}</small></span></div>
            <el-button class="wide-button" :type="store.projectMeta.paused ? 'success' : 'danger'" plain :disabled="!store.isProjectOwner.value" :loading="store.loading.pause" @click="togglePause">{{ store.projectMeta.paused ? "恢复运行" : "暂停项目" }}</el-button>
          </section>

          <section class="route-main-card setting-route-card key-route-card">
            <div class="setting-route-head"><span class="setting-icon"><Key /></span><div><span class="section-kicker">BLS PUBLIC KEY</span><h2>更新 G2 公钥</h2><p>更换签名服务时，同步轮换链上验证公钥。</p></div></div>
            <div class="subform-heading"><div><strong>BN254 坐标</strong><span>四个 uint256 组成 G2Point。</span></div><el-button link type="primary" @click="resetKey">填入演示公钥</el-button></div>
            <div class="form-grid two compact"><el-form-item label="X[0]"><el-input v-model="keyForm.x0" /></el-form-item><el-form-item label="X[1]"><el-input v-model="keyForm.x1" /></el-form-item><el-form-item label="Y[0]"><el-input v-model="keyForm.y0" /></el-form-item><el-form-item label="Y[1]"><el-input v-model="keyForm.y1" /></el-form-item></div>
            <el-button class="wide-button" :disabled="!store.isProjectOwner.value" :loading="store.loading.key" @click="updateKey">更新链上公钥</el-button>
          </section>
        </div>

        <section class="route-main-card contract-directory">
          <div class="card-title-row compact-title"><div><span class="step-number lime"><Setting /></span><div><h2>合约目录</h2><p>当前项目所依赖的核心合约地址。</p></div></div></div>
          <div class="contract-addresses route-addresses">
            <div><span>PROJECT PROXY</span><a :href="explorerAddress(store.projectAddress.value)" target="_blank">{{ store.projectAddress.value }} <Position /></a></div>
            <div><span>PROJECT OWNER</span><a :href="explorerAddress(store.projectMeta.owner)" target="_blank">{{ store.projectMeta.owner }} <Position /></a></div>
            <div><span>BLS VERIFIER</span><a :href="explorerAddress(store.projectMeta.verifier)" target="_blank">{{ store.projectMeta.verifier }} <Position /></a></div>
            <div><span>RANDOM MANAGER</span><a :href="explorerAddress(store.projectMeta.manager)" target="_blank">{{ store.projectMeta.manager }} <Position /></a></div>
          </div>
        </section>
      </template>
    </section>
  </main>
</template>
