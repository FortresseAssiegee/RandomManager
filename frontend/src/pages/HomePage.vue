<script setup>
import { RouterLink } from "vue-router";
import { ArrowRight, Check, Connection, DataLine, Key, Link, Lock, MagicStick, Plus, Position, Setting, Timer } from "@element-plus/icons-vue";
import { explorerAddress, shortAddress, useRandomManager } from "../composables/useRandomManager";

const store = useRandomManager();
const entries = [
  { to: "/factory", index: "01", title: "项目工厂", text: "预测并部署 CREATE2 项目代理", icon: Plus, tone: "lime" },
  { to: "/settings", index: "04", title: "项目设置", text: "暂停项目或轮换 BLS 公钥", icon: Setting, tone: "navy" },
];
</script>

<template>
  <main>
    <section class="hero home-hero">
      <div class="hero-copy"><div class="eyebrow"><span></span>BLS VERIFIED RANDOMNESS</div><h1>把链下随机，变成<br /><em>链上可信</em>的结果。</h1><p>按前置条件管理 RandomManager 的完整生命周期。</p><div class="hero-actions"><RouterLink class="route-primary-link" to="/factory">创建随机项目 <ArrowRight /></RouterLink><a class="text-link" :href="explorerAddress(store.managerAddress.value)" target="_blank">查看管理合约 <Position /></a></div><div class="trust-row"><span><el-icon><Check /></el-icon>EIP-1167 最小代理</span><span><el-icon><Check /></el-icon>BN254 BLS 验证</span><span><el-icon><Check /></el-icon>CREATE2 可预测地址</span></div></div>
      <div class="hero-visual" aria-label="随机数请求链路"><div class="visual-topline"><span>LIVE CONTRACT FLOW</span><span class="live-indicator"><i></i>{{ store.managerMeta.online ? "ONLINE" : "CHECKING" }}</span></div><div class="flow-canvas"><div class="flow-orbit orbit-one"></div><div class="flow-orbit orbit-two"></div><div class="center-core"><span class="core-index">R</span><strong>Random<br />Manager</strong><small>{{ shortAddress(store.managerAddress.value) }}</small></div><div class="flow-node node-a"><Plus /><span><b>01</b>创建项目</span></div><div class="flow-node node-b"><MagicStick /><span><b>02</b>发起请求</span></div><div class="flow-node node-c"><Lock /><span><b>03</b>BLS 验证</span></div><div class="flow-node node-d"><DataLine /><span><b>04</b>消费随机数</span></div></div><div class="visual-footer"><span>IMPLEMENTATION</span><code>{{ shortAddress(store.managerMeta.implementation,10,8) }}</code><i></i><span>SEPOLIA · 11155111</span></div></div>
    </section>
    <section class="metrics home-metrics"><article><span class="metric-icon navy"><Connection /></span><div><small>网络状态</small><strong>Sepolia</strong></div><span class="metric-note good">{{ store.managerMeta.online ? "合约在线" : "等待连接" }}</span></article><article><span class="metric-icon lime"><Link /></span><div><small>近期发现项目</small><strong>{{ store.managerMeta.projectCount }}</strong></div><span class="metric-note">近 10,000 区块</span></article><article><span class="metric-icon coral"><Timer /></span><div><small>当前项目请求</small><strong>{{ store.projectMeta.requestCount }}</strong></div><span class="metric-note">{{ store.projectMeta.valid ? store.projectName.value : "尚未绑定" }}</span></article><article><span class="metric-icon blue"><Key /></span><div><small>验证方案</small><strong>BN254</strong></div><span class="metric-note">BLS pairing</span></article></section>
    <section class="home-dashboard"><div class="section-heading route-heading"><div><span class="section-kicker">GUIDED CONSOLE</span><h2>选择你的下一步</h2></div><p>所有页面共享钱包、网络与当前项目。</p></div><div class="entry-grid"><RouterLink v-for="entry in entries" :key="entry.to" :to="entry.to" class="entry-card" :class="entry.tone"><span class="entry-index">{{ entry.index }}</span><span class="entry-icon"><component :is="entry.icon" /></span><h3>{{ entry.title }}</h3><p>{{ entry.text }}</p><b>进入页面 <ArrowRight /></b></RouterLink></div></section>
  </main>
</template>
