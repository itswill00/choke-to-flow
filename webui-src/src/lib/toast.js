import { ref } from 'vue'

export const toastMessage = ref('')
let timer = null

export function toast(msg) {
  toastMessage.value = String(msg)
  if (timer) clearTimeout(timer)
  timer = setTimeout(() => { toastMessage.value = '' }, 2800)
}
