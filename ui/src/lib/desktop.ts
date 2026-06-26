export type ServerConfig = {
  host: string
  port: number
  logLevel: string
  enableWebUI: boolean
  enableOfflineMode: boolean
  workerIdleTimeout: number
  workersPerLanguage: number
  apiToken: string
  logDir: string
  logToFile: boolean
  logConsole: boolean
  logRequests: boolean
  maxSentenceLength: number
  fullwidthZhPunctuation: boolean
  checkUpdate: boolean
  cacheSize: number
  modelDir: string
  configDir: string
}

export type ServerSettings = {
  server: ServerConfig
}

export type SettingsResponse = {
  config: ServerSettings
  status: string
  version: string
}

async function fetchSettings(path: string, body?: unknown) {
  const res = await fetch(`/ui/api/settings${path}`, {
    method: body ? 'POST' : 'GET',
    headers: body ? { 'Content-Type': 'application/json' } : undefined,
    body: body ? JSON.stringify(body) : undefined
  })
  if (!res.ok) {
    throw new Error(`Request failed: ${res.status}`)
  }
  return res.json()
}

export async function getConfig() {
  return fetchSettings('')
}

export async function applyConfig(config: ServerSettings) {
  return fetchSettings('/apply', { config })
}

export async function resetConfig() {
  return fetchSettings('/reset', {})
}

export async function restartServer() {
  return fetchSettings('/restart', {})
}
