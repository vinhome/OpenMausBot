#!/usr/bin/env node
import { spawn } from "node:child_process";
import { homedir } from "node:os";
import path from "node:path";
import { StringDecoder } from "node:string_decoder";

const toolSchema = {
  type: "object",
  properties: {
    command: {
      type: "string",
      description: "The command to execute (e.g. 'Get-ComputerInfo', 'Get-Process', 'dir', 'git status', scripts, CLI tools)."
    },
    cwd: {
      type: "string",
      description: "Optional directory path to execute the command from."
    },
    timeout_seconds: {
      type: "integer",
      description: "Maximum execution time in seconds before terminating (default: 60, max: 300)."
    }
  },
  required: ["command"],
  additionalProperties: false
};

const TOOLS = [
  {
    name: "exec_command",
    description: "Execute a shell command on this machine directly in the background (PowerShell on Windows, bash on macOS/Linux). Captures stdout, stderr, and exit code. Completely hidden and non-intrusive: does not pop up windows or interrupt the user.",
    inputSchema: toolSchema
  },
  {
    name: "run_command",
    description: "Alias for exec_command. Run a shell command in the background with stdout, stderr, and exit code captured.",
    inputSchema: toolSchema
  }
];

function executeCommand(args) {
  return new Promise((resolve) => {
    const rawCommand = args?.command;
    if (typeof rawCommand !== "string" || !rawCommand.trim()) {
      resolve({
        content: [{ type: "text", text: "Error: No command provided." }],
        isError: true
      });
      return;
    }

    const timeoutSec = typeof args?.timeout_seconds === "number" && args.timeout_seconds > 0
      ? Math.min(args.timeout_seconds, 300)
      : 60;

    let cwd = homedir();
    if (typeof args?.cwd === "string" && args.cwd.trim()) {
      try {
        cwd = path.resolve(args.cwd.trim());
      } catch {}
    }

    const isWin = process.platform === "win32";
    const shell = isWin ? "powershell.exe" : "/bin/bash";
    const shellArgs = isWin
      ? ["-NoProfile", "-NonInteractive", "-ExecutionPolicy", "Bypass", "-Command", rawCommand]
      : ["-c", rawCommand];

    let child;
    try {
      child = spawn(shell, shellArgs, {
        cwd,
        windowsHide: true,
        env: process.env,
      });
    } catch (err) {
      resolve({
        content: [{ type: "text", text: `Failed to spawn shell: ${err.message}` }],
        isError: true
      });
      return;
    }

    let stdout = "";
    let stderr = "";
    const MAX_OUTPUT = 512 * 1024; // 512 KB

    child.stdout.on("data", (chunk) => {
      if (stdout.length < MAX_OUTPUT) stdout += chunk.toString("utf8");
    });
    child.stderr.on("data", (chunk) => {
      if (stderr.length < MAX_OUTPUT) stderr += chunk.toString("utf8");
    });

    const timer = setTimeout(() => {
      try { child.kill(); } catch {}
      resolve({
        content: [{ type: "text", text: `Command timed out after ${timeoutSec}s.\n[stdout]\n${stdout}\n[stderr]\n${stderr}`.trim() }],
        isError: true
      });
    }, timeoutSec * 1000);

    child.on("error", (err) => {
      clearTimeout(timer);
      resolve({
        content: [{ type: "text", text: `Execution error: ${err.message}` }],
        isError: true
      });
    });

    child.on("close", (code) => {
      clearTimeout(timer);
      let output = "";
      if (stdout.trim()) output += stdout.trim();
      if (stderr.trim()) output += (output ? "\n[stderr]\n" : "") + stderr.trim();
      if (!output) output = `(Command finished with exit code ${code ?? 0} and no output)`;

      if (code !== 0 && code !== null) {
        output = `[exit code: ${code}]\n${output}`;
        resolve({
          content: [{ type: "text", text: output }],
          isError: true
        });
      } else {
        resolve({
          content: [{ type: "text", text: output }]
        });
      }
    });
  });
}

function send(msg) {
  process.stdout.write(JSON.stringify(msg) + "\n");
}

let buffer = "";
const decoder = new StringDecoder("utf8");

process.stdin.on("data", (chunk) => {
  buffer += typeof chunk === "string" ? chunk : decoder.write(chunk);
  let idx;
  while ((idx = buffer.indexOf("\n")) !== -1) {
    const line = buffer.slice(0, idx).trim();
    buffer = buffer.slice(idx + 1);
    if (!line) continue;

    let req;
    try {
      req = JSON.parse(line);
    } catch {
      continue;
    }

    handleRequest(req);
  }
});

async function handleRequest(req) {
  if (!req || typeof req !== "object") return;
  const { id, method, params } = req;

  // Notifications (no id)
  if (id === undefined || id === null) {
    return;
  }

  if (method === "initialize") {
    send({
      jsonrpc: "2.0",
      id,
      result: {
        protocolVersion: "2024-11-05",
        capabilities: {
          tools: {}
        },
        serverInfo: {
          name: "openmausbot-terminal",
          version: "1.0.0"
        }
      }
    });
    return;
  }

  if (method === "ping") {
    send({
      jsonrpc: "2.0",
      id,
      result: {}
    });
    return;
  }

  if (method === "tools/list") {
    send({
      jsonrpc: "2.0",
      id,
      result: {
        tools: TOOLS
      }
    });
    return;
  }

  if (method === "tools/call") {
    const toolName = params?.name;
    const args = params?.arguments ?? {};
    if (toolName === "exec_command" || toolName === "run_command") {
      const result = await executeCommand(args);
      send({
        jsonrpc: "2.0",
        id,
        result
      });
      return;
    }

    send({
      jsonrpc: "2.0",
      id,
      error: {
        code: -32601,
        message: `Unknown tool: ${toolName}`
      }
    });
    return;
  }

  send({
    jsonrpc: "2.0",
    id,
    error: {
      code: -32601,
      message: `Method not found: ${method}`
    }
  });
}
