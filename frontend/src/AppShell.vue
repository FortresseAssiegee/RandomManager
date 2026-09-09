<script setup>
import { onMounted, reactive, ref } from "vue";
import { RouterLink, RouterView, useRoute } from "vue-router";
import { Connection, DataLine, HomeFilled, Menu, Setting, Wallet } from "@element-plus/icons-vue";
import { ElNotification } from "element-plus";
import { useRandomManager } from "./composables/useRandomManager";

const route = useRoute();
const showConfig = ref(false);
const showMobileNav = ref(false);
const store = useRandomManager();
const configDraft = reactive({ manager: store.managerAddress.value, rpc: store.rpcUrl.value });
const navItems = [
  { to: "/", label: "首页", icon: HomeFilled },
  { to: "/factory", label: "项目工厂", icon: Connection },
  { to: "/settings", label: "项目设置", icon: Setting },
];

async function saveConfig() {
  try {
    await store.saveConfiguration(configDraft.manager, configDraft.rpc);
    showConfig.value = false;
  } catch (error) {
    ElNotification({ title: "保存配置失败", message: error.message, type: "error" });
  }
}

onMounted(store.initialize);
</script>

<template>
  <div class="app-shell route-shell">
    <header class="topbar route-topbar">
      <RouterLink class="brand" to="/" aria-label="Randora 首页">
        <span class="brand-mark" aria-hidden="true"><i></i><i></i><i></i></span>
        <span><strong>RANDORA</strong><small>VERIFIABLE RANDOMNESS</small></span>
      </RouterLink>

      <nav class="route-nav" aria-label="主导航">
        <RouterLink v-for="item in navItems" :key="item.to" :to="item.to">
          {{ item.label }}
        </RouterLink>
      </nav>

      <div class="header-actions">
        <button
          class="network-pill"
          :class="{ danger: store.walletReady.value && !store.onSepolia.value }"
          @click="showConfig = true"
        >
          <span class="status-dot"></span>
          {{ store.walletReady.value && !store.onSepolia.value ? `Chain ${store.chainId.value}` : "Sepolia" }}
          <el-icon><Setting /></el-icon>
        </button>
        <el-button
          class="wallet-button"
          :class="{ connected: store.walletReady.value }"
          :icon="Wallet"
          @click="store.connectWallet"
        >
          {{ store.walletReady.value ? store.shortAccount.value : "连接钱包" }}
        </el-button>
        <button class="mobile-menu" aria-label="打开导航" @click="showMobileNav = true"><Menu /></button>
      </div>
    </header>

    <RouterView v-slot="{ Component }">
      <transition name="route-fade" mode="out-in">
        <component :is="Component" :key="route.path" />
      </transition>
    </RouterView>

    <footer>
      <div class="brand footer-brand">
        <span class="brand-mark" aria-hidden="true"><i></i><i></i><i></i></span>
        <span><strong>RANDORA</strong><small>RANDOM MANAGER CONSOLE</small></span>
      </div>
      <p>Sepolia 可验证随机数合约控制台 · 受控流程共享同一钱包与项目状态</p>
      <a href="https://sepolia.etherscan.io" target="_blank" rel="noreferrer">SEPOLIA EXPLORER <DataLine /></a>
    </footer>

    <el-dialog v-model="showConfig" title="网络与合约配置" width="min(520px, 92vw)">
      <el-form label-position="top">
        <el-form-item label="RandomManager 地址"><el-input v-model="configDraft.manager" /></el-form-item>
        <el-form-item label="Sepolia RPC"><el-input v-model="configDraft.rpc" /></el-form-item>
      </el-form>
      <div class="config-note"><el-icon><Setting /></el-icon>配置仅保存在当前浏览器，不会读取或上传私钥。</div>
      <template #footer>
        <el-button @click="showConfig = false">取消</el-button>
        <el-button type="primary" @click="saveConfig">保存并刷新</el-button>
      </template>
    </el-dialog>

    <el-drawer v-model="showMobileNav" direction="rtl" size="78%" title="页面导航">
      <nav class="mobile-route-nav">
        <RouterLink v-for="item in navItems" :key="item.to" :to="item.to" @click="showMobileNav = false">
          <span><component :is="item.icon" /></span>
          <div><strong>{{ item.label }}</strong><small>{{ item.to }}</small></div>
        </RouterLink>
      </nav>
    </el-drawer>
  </div>
</template>
