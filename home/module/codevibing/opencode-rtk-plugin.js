import { execFile } from "node:child_process"
import { promisify } from "node:util"

const execFileAsync = promisify(execFile)

async function rtkRewrite(command) {
  try {
    const { stdout } = await execFileAsync("rtk", ["rewrite", command], {
      timeout: 5000,
      maxBuffer: 1024 * 1024,
    })
    const rewritten = stdout.trim()
    return rewritten && rewritten !== command ? rewritten : undefined
  } catch {
    return undefined
  }
}

export default {
  id: "rtk",

  async setup(ctx) {
    try {
      await execFileAsync("rtk", ["--version"], { timeout: 5000 })
    } catch {
      console.warn("[rtk] rtk binary not found in PATH - plugin disabled")
      return
    }

    await ctx.tool.hook("execute.before", async (event) => {
      const tool = String(event?.tool ?? "").toLowerCase()
      if (tool !== "bash" && tool !== "shell") return

      const input = event?.input
      if (!input || typeof input !== "object") return

      const command = input.command
      if (typeof command !== "string" || !command) return

      const rewritten = await rtkRewrite(command)
      if (rewritten) input.command = rewritten
    })
  },
}
