#!/usr/bin/env python3
from __future__ import annotations

import json
import shlex
import shutil
import subprocess
import sys
import threading
from pathlib import Path
import tkinter as tk
from tkinter import filedialog, messagebox, ttk


APP_NAME = "AI Code Launcher"
APP_SUPPORT_DIR = Path.home() / "Library" / "Application Support" / "ai-code-launcher"
CONFIG_PATH = APP_SUPPORT_DIR / "config.json"
EXCLUDED_DIR_NAMES = {
    ".git",
    ".idea",
    ".vscode",
    ".venv",
    "__pycache__",
    "build",
    "dist",
    "node_modules",
    "venv",
}


def default_roots() -> list[str]:
    candidates = [
        Path.home() / "Documents" / "my-projects",
        Path.home() / "Code",
        Path.home() / "Projects",
    ]
    return [str(path) for path in candidates if path.is_dir()]


def default_config() -> dict:
    return {
        "roots": default_roots(),
        "pinned_projects": [],
        "recent_projects": [],
        "commands": {
            "codex": "codex",
            "claude": "claude",
        },
        "scan_depth": 2,
    }


def ensure_dir(path: Path) -> None:
    path.mkdir(parents=True, exist_ok=True)


def normalize_directory(value: str) -> str:
    return str(Path(value).expanduser().resolve())


def load_config() -> dict:
    config = default_config()
    if CONFIG_PATH.exists():
        try:
            loaded = json.loads(CONFIG_PATH.read_text(encoding="utf-8"))
            config.update({key: value for key, value in loaded.items() if key in config})
            commands = loaded.get("commands", {})
            if isinstance(commands, dict):
                config["commands"].update(commands)
        except (OSError, json.JSONDecodeError):
            pass

    config["roots"] = dedupe_existing_dirs(config.get("roots", []))
    config["pinned_projects"] = dedupe_existing_dirs(config.get("pinned_projects", []))
    config["recent_projects"] = dedupe_existing_dirs(config.get("recent_projects", []))
    try:
        config["scan_depth"] = max(1, int(config.get("scan_depth", 2)))
    except (TypeError, ValueError):
        config["scan_depth"] = 2
    return config


def save_config(config: dict) -> None:
    ensure_dir(APP_SUPPORT_DIR)
    CONFIG_PATH.write_text(
        json.dumps(config, indent=2, ensure_ascii=False) + "\n",
        encoding="utf-8",
    )


def dedupe_existing_dirs(values: list[str]) -> list[str]:
    seen: set[str] = set()
    result: list[str] = []
    for value in values:
        try:
            normalized = normalize_directory(value)
        except OSError:
            continue
        if normalized in seen or not Path(normalized).is_dir():
            continue
        seen.add(normalized)
        result.append(normalized)
    return result


def sh_quote(value: str) -> str:
    return shlex.quote(value)


def applescript_quote(value: str) -> str:
    return value.replace("\\", "\\\\").replace('"', '\\"')


def format_display_path(path: str, roots: list[str]) -> str:
    path_obj = Path(path)
    for root in roots:
        root_obj = Path(root)
        try:
            relative = path_obj.relative_to(root_obj)
            return f"{root_obj.name}/{relative}" if str(relative) != "." else root_obj.name
        except ValueError:
            continue
    return path


class LauncherApp(tk.Tk):
    def __init__(self) -> None:
        super().__init__()
        self.title(APP_NAME)
        self.geometry("1080x700")
        self.minsize(900, 560)

        self.config_data = load_config()
        self.search_var = tk.StringVar()
        self.codex_command_var = tk.StringVar(value=self.config_data["commands"]["codex"])
        self.claude_command_var = tk.StringVar(value=self.config_data["commands"]["claude"])
        self.scan_depth_var = tk.StringVar(value=str(self.config_data["scan_depth"]))
        self.status_var = tk.StringVar(value="准备就绪")

        self.projects: list[str] = []
        self.project_source: dict[str, str] = {}
        self.scan_generation = 0

        self._build_ui()
        self.after(50, self.bring_to_front)
        self.refresh_roots()
        self.after(100, self.refresh_projects)

    def bring_to_front(self) -> None:
        self.deiconify()
        self.lift()
        self.attributes("-topmost", True)
        self.after(150, lambda: self.attributes("-topmost", False))
        try:
            self.focus_force()
        except tk.TclError:
            pass

    def _build_ui(self) -> None:
        self.columnconfigure(1, weight=1)
        self.rowconfigure(1, weight=1)

        header = ttk.Frame(self, padding=16)
        header.grid(row=0, column=0, columnspan=2, sticky="ew")
        header.columnconfigure(1, weight=1)

        ttk.Label(
            header,
            text="一键从项目目录启动 Codex / Claude Code",
            font=("SF Pro Display", 18, "bold"),
        ).grid(row=0, column=0, columnspan=4, sticky="w")

        ttk.Label(header, text="搜索项目").grid(row=1, column=0, sticky="w", pady=(12, 0))
        search_entry = ttk.Entry(header, textvariable=self.search_var)
        search_entry.grid(row=1, column=1, sticky="ew", pady=(12, 0), padx=(8, 8))
        search_entry.bind("<KeyRelease>", lambda _event: self.refresh_project_tree())

        ttk.Button(header, text="刷新扫描", command=self.refresh_projects).grid(
            row=1, column=2, sticky="ew", pady=(12, 0)
        )
        ttk.Button(header, text="手动选择目录", command=self.choose_project).grid(
            row=1, column=3, sticky="ew", pady=(12, 0), padx=(8, 0)
        )

        left = ttk.LabelFrame(self, text="项目根目录", padding=12)
        left.grid(row=1, column=0, sticky="nsew", padx=(16, 8), pady=(0, 8))
        left.columnconfigure(0, weight=1)
        left.rowconfigure(0, weight=1)

        self.root_listbox = tk.Listbox(left, exportselection=False, height=10)
        self.root_listbox.grid(row=0, column=0, sticky="nsew")
        root_scroll = ttk.Scrollbar(left, orient="vertical", command=self.root_listbox.yview)
        root_scroll.grid(row=0, column=1, sticky="ns")
        self.root_listbox.configure(yscrollcommand=root_scroll.set)

        root_buttons = ttk.Frame(left)
        root_buttons.grid(row=1, column=0, columnspan=2, sticky="ew", pady=(12, 0))
        root_buttons.columnconfigure(0, weight=1)
        root_buttons.columnconfigure(1, weight=1)
        ttk.Button(root_buttons, text="添加根目录", command=self.add_root).grid(row=0, column=0, sticky="ew")
        ttk.Button(root_buttons, text="移除根目录", command=self.remove_selected_root).grid(
            row=0, column=1, sticky="ew", padx=(8, 0)
        )

        right = ttk.LabelFrame(self, text="项目列表", padding=12)
        right.grid(row=1, column=1, sticky="nsew", padx=(8, 16), pady=(0, 8))
        right.columnconfigure(0, weight=1)
        right.rowconfigure(0, weight=1)

        columns = ("name", "location", "source")
        self.project_tree = ttk.Treeview(right, columns=columns, show="headings", selectmode="browse")
        self.project_tree.heading("name", text="项目")
        self.project_tree.heading("location", text="路径")
        self.project_tree.heading("source", text="来源")
        self.project_tree.column("name", width=220, anchor="w")
        self.project_tree.column("location", width=470, anchor="w")
        self.project_tree.column("source", width=90, anchor="center")
        self.project_tree.grid(row=0, column=0, sticky="nsew")
        self.project_tree.bind("<Double-1>", lambda _event: self.launch_selected("codex"))

        tree_scroll = ttk.Scrollbar(right, orient="vertical", command=self.project_tree.yview)
        tree_scroll.grid(row=0, column=1, sticky="ns")
        self.project_tree.configure(yscrollcommand=tree_scroll.set)

        action_bar = ttk.Frame(right)
        action_bar.grid(row=1, column=0, columnspan=2, sticky="ew", pady=(12, 0))
        for index in range(5):
            action_bar.columnconfigure(index, weight=1)

        ttk.Button(action_bar, text="用 Codex 打开", command=lambda: self.launch_selected("codex")).grid(
            row=0, column=0, sticky="ew"
        )
        ttk.Button(
            action_bar,
            text="用 Claude Code 打开",
            command=lambda: self.launch_selected("claude"),
        ).grid(row=0, column=1, sticky="ew", padx=(8, 0))
        ttk.Button(action_bar, text="在 Finder 中显示", command=self.reveal_selected).grid(
            row=0, column=2, sticky="ew", padx=(8, 0)
        )
        ttk.Button(action_bar, text="收藏 / 取消收藏", command=self.toggle_pin_selected).grid(
            row=0, column=3, sticky="ew", padx=(8, 0)
        )
        ttk.Button(action_bar, text="复制路径", command=self.copy_selected_path).grid(
            row=0, column=4, sticky="ew", padx=(8, 0)
        )

        settings = ttk.LabelFrame(self, text="启动设置", padding=12)
        settings.grid(row=2, column=0, columnspan=2, sticky="ew", padx=16, pady=(0, 8))
        settings.columnconfigure(1, weight=1)
        settings.columnconfigure(3, weight=1)

        ttk.Label(settings, text="Codex 命令").grid(row=0, column=0, sticky="w")
        ttk.Entry(settings, textvariable=self.codex_command_var).grid(row=0, column=1, sticky="ew", padx=(8, 16))
        ttk.Label(settings, text="Claude 命令").grid(row=0, column=2, sticky="w")
        ttk.Entry(settings, textvariable=self.claude_command_var).grid(row=0, column=3, sticky="ew", padx=(8, 16))
        ttk.Label(settings, text="扫描深度").grid(row=0, column=4, sticky="w")
        ttk.Entry(settings, textvariable=self.scan_depth_var, width=6).grid(row=0, column=5, sticky="w", padx=(8, 0))
        ttk.Button(settings, text="保存设置", command=self.save_settings).grid(row=0, column=6, sticky="e", padx=(16, 0))

        status_bar = ttk.Label(self, textvariable=self.status_var, relief="sunken", anchor="w", padding=(8, 6))
        status_bar.grid(row=3, column=0, columnspan=2, sticky="ew", padx=16, pady=(0, 16))

    def refresh_roots(self) -> None:
        self.root_listbox.delete(0, tk.END)
        for root in self.config_data["roots"]:
            self.root_listbox.insert(tk.END, root)

    def add_root(self) -> None:
        selected = filedialog.askdirectory(title="选择一个包含项目的根目录")
        if not selected:
            return
        normalized = normalize_directory(selected)
        if normalized not in self.config_data["roots"]:
            self.config_data["roots"].append(normalized)
            self.config_data["roots"].sort()
            save_config(self.config_data)
            self.refresh_roots()
            self.refresh_projects()

    def remove_selected_root(self) -> None:
        selection = self.root_listbox.curselection()
        if not selection:
            messagebox.showinfo(APP_NAME, "先选中一个根目录。")
            return
        root = self.root_listbox.get(selection[0])
        self.config_data["roots"] = [item for item in self.config_data["roots"] if item != root]
        save_config(self.config_data)
        self.refresh_roots()
        self.refresh_projects()

    def choose_project(self) -> None:
        selected = filedialog.askdirectory(title="选择一个项目目录")
        if not selected:
            return
        self.add_recent_project(normalize_directory(selected))
        self.refresh_projects(selected_path=normalize_directory(selected))

    def save_settings(self) -> None:
        try:
            scan_depth = max(1, int(self.scan_depth_var.get().strip()))
        except ValueError:
            messagebox.showerror(APP_NAME, "扫描深度必须是大于等于 1 的整数。")
            return

        self.config_data["commands"]["codex"] = self.codex_command_var.get().strip() or "codex"
        self.config_data["commands"]["claude"] = self.claude_command_var.get().strip() or "claude"
        self.config_data["scan_depth"] = scan_depth
        save_config(self.config_data)
        self.refresh_projects()
        self.status_var.set("设置已保存")

    def refresh_projects(self, selected_path: str | None = None) -> None:
        self.scan_generation += 1
        generation = self.scan_generation
        roots = list(self.config_data["roots"])
        pinned_projects = list(self.config_data["pinned_projects"])
        recent_projects = list(self.config_data["recent_projects"])
        scan_depth = self.config_data["scan_depth"]

        self.status_var.set("正在扫描项目...")
        scan_thread = threading.Thread(
            target=self._scan_projects_worker,
            args=(generation, roots, pinned_projects, recent_projects, scan_depth, selected_path),
            daemon=True,
        )
        scan_thread.start()

    def _scan_projects_worker(
        self,
        generation: int,
        roots: list[str],
        pinned_projects: list[str],
        recent_projects: list[str],
        scan_depth: int,
        selected_path: str | None,
    ) -> None:
        projects: list[str] = []
        project_source: dict[str, str] = {}

        for path in pinned_projects:
            self.register_project(projects, project_source, path, "收藏")
        for path in recent_projects:
            self.register_project(projects, project_source, path, "最近")

        for root in roots:
            if not Path(root).is_dir():
                continue
            for discovered in self.walk_projects(Path(root), max_depth=scan_depth):
                self.register_project(projects, project_source, discovered, "扫描")

        projects.sort(key=lambda item: self.project_sort_key_for(project_source, item))
        self.after(
            0,
            lambda: self.apply_scan_results(generation, projects, project_source, selected_path),
        )

    def refresh_project_tree(self, selected_path: str | None = None) -> None:
        selected_path = selected_path or self.get_selected_project()
        for item in self.project_tree.get_children():
            self.project_tree.delete(item)

        query = self.search_var.get().strip().lower()
        for path in self.projects:
            haystack = f"{Path(path).name} {path}".lower()
            if query and query not in haystack:
                continue
            source = self.project_source[path]
            title = f"★ {Path(path).name}" if path in self.config_data["pinned_projects"] else Path(path).name
            self.project_tree.insert(
                "",
                tk.END,
                iid=path,
                values=(title, format_display_path(path, self.config_data["roots"]), source),
            )

        if selected_path and self.project_tree.exists(selected_path):
            self.project_tree.selection_set(selected_path)
            self.project_tree.focus(selected_path)

    @staticmethod
    def register_project(
        projects: list[str],
        project_source: dict[str, str],
        path: str,
        source: str,
    ) -> None:
        normalized = normalize_directory(path)
        if not Path(normalized).is_dir():
            return
        if normalized not in project_source:
            projects.append(normalized)
            project_source[normalized] = source
            return

        existing_priority = LauncherApp.source_priority(project_source[normalized])
        new_priority = LauncherApp.source_priority(source)
        if new_priority < existing_priority:
            project_source[normalized] = source

    def walk_projects(self, root: Path, max_depth: int) -> list[str]:
        discovered: list[str] = []

        def visit(path: Path, depth: int) -> None:
            if depth > max_depth:
                return
            try:
                entries = sorted(
                    (entry for entry in path.iterdir() if entry.is_dir()),
                    key=lambda item: item.name.lower(),
                )
            except OSError:
                return

            for entry in entries:
                if entry.name.startswith(".") or entry.name in EXCLUDED_DIR_NAMES:
                    continue
                discovered.append(str(entry.resolve()))
                visit(entry, depth + 1)

        visit(root, 1)
        return discovered

    def project_sort_key(self, path: str) -> tuple[int, str]:
        return (self.source_priority(self.project_source[path]), path.lower())

    def project_sort_key_for(self, project_source: dict[str, str], path: str) -> tuple[int, str]:
        return (self.source_priority(project_source[path]), path.lower())

    @staticmethod
    def source_priority(source: str) -> int:
        order = {"收藏": 0, "最近": 1, "扫描": 2}
        return order.get(source, 9)

    def apply_scan_results(
        self,
        generation: int,
        projects: list[str],
        project_source: dict[str, str],
        selected_path: str | None,
    ) -> None:
        if generation != self.scan_generation:
            return
        self.projects = projects
        self.project_source = project_source
        self.refresh_project_tree(selected_path=selected_path)
        self.status_var.set(f"已载入 {len(self.projects)} 个项目")

    def get_selected_project(self) -> str | None:
        selection = self.project_tree.selection()
        return selection[0] if selection else None

    def ensure_selected_project(self) -> str | None:
        selected = self.get_selected_project()
        if not selected:
            messagebox.showinfo(APP_NAME, "先选中一个项目目录。")
            return None
        return selected

    def launch_selected(self, tool_name: str) -> None:
        project = self.ensure_selected_project()
        if not project:
            return

        command = self.config_data["commands"][tool_name].strip()
        if not command:
            messagebox.showerror(APP_NAME, f"{tool_name} 命令为空，请先在下方设置。")
            return

        try:
            first_token = shlex.split(command)[0]
        except ValueError:
            messagebox.showerror(APP_NAME, "命令格式不合法，请检查引号是否成对。")
            return
        if shutil.which(first_token) is None:
            should_continue = messagebox.askyesno(
                APP_NAME,
                f"没有在 PATH 里找到 `{first_token}`。\n仍然尝试在 Terminal 里启动吗？",
            )
            if not should_continue:
                return

        shell_command = f"cd {sh_quote(project)} && {command}"
        applescript = (
            'tell application "Terminal"\n'
            "activate\n"
            f'do script "{applescript_quote(shell_command)}"\n'
            "end tell\n"
        )

        try:
            subprocess.run(["osascript", "-e", applescript], check=True)
        except subprocess.CalledProcessError as exc:
            messagebox.showerror(APP_NAME, f"启动失败：\n{exc}")
            return

        self.add_recent_project(project)
        self.refresh_projects(selected_path=project)
        tool_label = "Codex" if tool_name == "codex" else "Claude Code"
        self.status_var.set(f"已在 {Path(project).name} 中启动 {tool_label}")

    def add_recent_project(self, path: str) -> None:
        normalized = normalize_directory(path)
        recent = [item for item in self.config_data["recent_projects"] if item != normalized]
        recent.insert(0, normalized)
        self.config_data["recent_projects"] = recent[:20]
        save_config(self.config_data)

    def reveal_selected(self) -> None:
        project = self.ensure_selected_project()
        if not project:
            return

        try:
            subprocess.run(["open", project], check=True)
        except subprocess.CalledProcessError as exc:
            messagebox.showerror(APP_NAME, f"无法打开 Finder：\n{exc}")

    def toggle_pin_selected(self) -> None:
        project = self.ensure_selected_project()
        if not project:
            return

        pinned = self.config_data["pinned_projects"]
        if project in pinned:
            self.config_data["pinned_projects"] = [item for item in pinned if item != project]
            self.status_var.set(f"已取消收藏 {Path(project).name}")
        else:
            pinned.append(project)
            self.config_data["pinned_projects"] = sorted(set(pinned))
            self.status_var.set(f"已收藏 {Path(project).name}")

        save_config(self.config_data)
        self.refresh_projects(selected_path=project)

    def copy_selected_path(self) -> None:
        project = self.ensure_selected_project()
        if not project:
            return

        self.clipboard_clear()
        self.clipboard_append(project)
        self.status_var.set(f"已复制路径：{project}")


def main() -> int:
    app = LauncherApp()
    app.mainloop()
    return 0


if __name__ == "__main__":
    sys.exit(main())
