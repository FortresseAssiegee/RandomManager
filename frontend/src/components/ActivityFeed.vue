<script setup>
import { Check, DataLine, Lock, MagicStick, Plus, Position, Refresh } from "@element-plus/icons-vue";
import { explorerTx, useRandomManager } from "../composables/useRandomManager";

const store = useRandomManager();
const iconFor = (type) => type === "project" ? Plus : type === "request" ? MagicStick : type === "fulfilled" ? Lock : Check;
const refresh = () => store.projectMeta.valid ? store.loadProjectEvents() : store.loadManagerEvents();
</script>

<template>
  <aside class="activity-panel route-activity">
    <div class="activity-heading">
      <div><span class="section-kicker">ON-CHAIN FEED</span><h3>链上动态</h3></div>
      <el-button circle :icon="Refresh" :loading="store.loading.events" @click="refresh" />
    </div>
    <div v-if="store.activities.value.length" class="activity-list">
      <article v-for="item in store.activities.value" :key="item.key" class="activity-item">
        <span class="activity-dot" :class="item.type"><component :is="iconFor(item.type)" /></span>
        <div><strong>{{ item.title }}</strong><p>{{ item.detail }}</p><span>Block {{ item.block }}</span></div>
        <a :href="explorerTx(item.hash)" target="_blank" aria-label="查看交易"><Position /></a>
      </article>
    </div>
    <div v-else class="activity-empty">
      <span><DataLine /></span><strong>等待链上动态</strong><p>创建项目或发起请求后，交易会显示在这里。</p>
    </div>
  </aside>
</template>
