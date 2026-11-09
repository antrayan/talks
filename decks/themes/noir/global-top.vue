<template>
  <footer
    v-if="$nav.currentLayout !== 'cover' && $nav.currentPage !== $nav.total"
    class="noir-footer"
  >
    {{ String($nav.currentPage).padStart(2, '0') }}
    <span>/ {{ String($nav.total).padStart(2, '0') }}</span>
  </footer>
</template>
