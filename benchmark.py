#!/usr/bin/env python3

from __future__ import annotations

import argparse
import os
import re
import shutil
import subprocess
import sys
import time
from dataclasses import dataclass
from pathlib import Path


REPO_ROOT = Path(__file__).resolve().parent


@dataclass
class Implementation:
    name: str
    language: str
    run_command_easy: list[str]
    run_command_hard: list[str]
    working_dir_easy: Path
    working_dir_hard: Path
    source_paths: list[Path]
    binary_path: Path | None = None
    build_command: list[str] | None = None
    build_dir: Path | None = None
    build_tool: str | None = None
    build_env: dict[str, str] | None = None


@dataclass
class Result:
    name: str
    status: str
    average_ms: float | None = None
    wall_seconds: float | None = None
    output: str = ""


IMPLEMENTATIONS = [
    Implementation(
        name="c",
        language="C",
        run_command_easy=["./sudoku"],
        run_command_hard=["./c/sudoku"],
        working_dir_easy=REPO_ROOT / "c",
        working_dir_hard=REPO_ROOT,
        source_paths=[REPO_ROOT / "c" / "main.c"],
        binary_path=REPO_ROOT / "c" / "sudoku",
        build_command=["cc", "-O3", "-o", "sudoku", "main.c"],
        build_dir=REPO_ROOT / "c",
        build_tool="cc",
    ),
    Implementation(
        name="zig",
        language="Zig",
        run_command_easy=["./sudoku_zig"],
        run_command_hard=["./zig/sudoku_zig"],
        working_dir_easy=REPO_ROOT / "zig",
        working_dir_hard=REPO_ROOT,
        source_paths=[REPO_ROOT / "zig" / "src" / "main.zig"],
        binary_path=REPO_ROOT / "zig" / "sudoku_zig",
        build_command=["zig", "build-exe", "src/main.zig", "-O", "ReleaseFast", "-femit-bin=sudoku_zig"],
        build_dir=REPO_ROOT / "zig",
        build_tool="zig",
        build_env={
            "ZIG_GLOBAL_CACHE_DIR": str(REPO_ROOT / ".zig-cache"),
            "ZIG_LOCAL_CACHE_DIR": str(REPO_ROOT / "zig" / ".zig-cache"),
        },
    ),
    Implementation(
        name="odin",
        language="Odin",
        run_command_easy=["./sudoku_odin"],
        run_command_hard=["./odin/sudoku_odin"],
        working_dir_easy=REPO_ROOT / "odin",
        working_dir_hard=REPO_ROOT,
        source_paths=[REPO_ROOT / "odin" / "main.odin"],
        binary_path=REPO_ROOT / "odin" / "sudoku_odin",
        build_command=["odin", "build", "main.odin", "-file", "-o:speed", "-out:sudoku_odin"],
        build_dir=REPO_ROOT / "odin",
        build_tool="odin",
    ),
    Implementation(
        name="go",
        language="Go",
        run_command_easy=["./sudoku_go"],
        run_command_hard=["./go/sudoku_go"],
        working_dir_easy=REPO_ROOT / "go",
        working_dir_hard=REPO_ROOT,
        source_paths=[REPO_ROOT / "go" / "go.mod", REPO_ROOT / "go" / "main.go"],
        binary_path=REPO_ROOT / "go" / "sudoku_go",
        build_command=["go", "build", "-o", "sudoku_go", "main.go"],
        build_dir=REPO_ROOT / "go",
        build_tool="go",
    ),
    Implementation(
        name="rust",
        language="Rust",
        run_command_easy=["./target/release/sudoku_rust"],
        run_command_hard=["./rust/target/release/sudoku_rust"],
        working_dir_easy=REPO_ROOT / "rust",
        working_dir_hard=REPO_ROOT,
        source_paths=[REPO_ROOT / "rust" / "Cargo.toml", REPO_ROOT / "rust" / "src" / "main.rs"],
        binary_path=REPO_ROOT / "rust" / "target" / "release" / "sudoku_rust",
        build_command=["cargo", "build", "--release"],
        build_dir=REPO_ROOT / "rust",
        build_tool="cargo",
    ),
]


def command_exists(name: str) -> bool:
    return shutil.which(name) is not None


def binary_is_current(implementation: Implementation) -> bool:
    if implementation.binary_path is None or not implementation.binary_path.exists():
        return False

    binary_mtime = implementation.binary_path.stat().st_mtime
    for source_path in implementation.source_paths:
        if not source_path.exists():
            return False
        if source_path.stat().st_mtime > binary_mtime:
            return False

    return True


def ensure_built(implementation: Implementation) -> tuple[bool, str]:
    if binary_is_current(implementation):
        return True, ""

    if implementation.build_command is None or implementation.build_dir is None:
        return False, "no runnable binary and no build command configured"

    if implementation.build_tool is not None and not command_exists(implementation.build_tool):
        return False, f"missing build tool: {implementation.build_tool}"

    env = os.environ.copy()
    if implementation.build_env is not None:
        env.update(implementation.build_env)

    completed = subprocess.run(
        implementation.build_command,
        cwd=implementation.build_dir,
        capture_output=True,
        text=True,
        env=env,
    )

    if completed.returncode != 0:
        output = (completed.stdout + completed.stderr).strip()
        if not output:
            output = "build failed with no output"
        return False, output

    if implementation.binary_path is not None and not implementation.binary_path.exists():
        return False, "build reported success, but output binary was not found"

    return True, ""


def parse_average_ms(output: str) -> float | None:
    average_match = re.search(r"Average:\s+([0-9]+(?:\.[0-9]+)?)\s+ms per run", output)
    if average_match:
        return float(average_match.group(1))

    single_match = re.search(r"Solved in\s+([0-9]+(?:\.[0-9]+)?)\s+ms", output)
    if single_match:
        return float(single_match.group(1))

    return None


def run_one(implementation: Implementation, puzzle: str, repeat_count: int) -> Result:
    ok, message = ensure_built(implementation)
    if not ok:
        return Result(
            name=implementation.name,
            status=f"skipped ({message})",
        )

    if puzzle == "easy":
        working_dir = implementation.working_dir_easy
        command = [*implementation.run_command_easy, puzzle, str(repeat_count)]
    else:
        working_dir = implementation.working_dir_hard
        command = [*implementation.run_command_hard, puzzle, str(repeat_count)]

    start = time.perf_counter()
    completed = subprocess.run(
        command,
        cwd=working_dir,
        capture_output=True,
        text=True,
    )
    wall_seconds = time.perf_counter() - start

    output = (completed.stdout + completed.stderr).strip()

    if completed.returncode != 0:
        return Result(
            name=implementation.name,
            status=f"failed (exit {completed.returncode})",
            wall_seconds=wall_seconds,
            output=output,
        )

    average_ms = parse_average_ms(output)
    if average_ms is None:
        return Result(
            name=implementation.name,
            status="failed (could not parse timing output)",
            wall_seconds=wall_seconds,
            output=output,
        )

    return Result(
        name=implementation.name,
        status="ok",
        average_ms=average_ms,
        wall_seconds=wall_seconds,
        output=output,
    )


def print_results(results: list[Result], repeat_count: int, puzzle: str) -> None:
    print(f"Sudoku benchmark")
    print(f"Puzzle: {puzzle}")
    print(f"Repeat count: {repeat_count}")
    print()
    print(f"{'impl':<6} {'status':<34} {'avg ms/run':>12} {'puzzles/sec':>12} {'wall sec':>12}")
    print("-" * 82)

    for result in results:
        average_text = f"{result.average_ms:.6f}" if result.average_ms is not None else "-"
        puzzles_per_second = 1000.0 / result.average_ms if result.average_ms not in (None, 0) else None
        puzzles_text = f"{puzzles_per_second:.2f}" if puzzles_per_second is not None else "-"
        wall_text = f"{result.wall_seconds:.3f}" if result.wall_seconds is not None else "-"
        print(f"{result.name:<6} {result.status:<34} {average_text:>12} {puzzles_text:>12} {wall_text:>12}")

    failures = [result for result in results if result.status != "ok" and result.output]
    if failures:
        print()
        print("Details:")
        for result in failures:
            print()
            print(f"[{result.name}] {result.status}")
            print(result.output)


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Run all sudoku implementations and compare timings.")
    parser.add_argument("puzzle", choices=["easy", "hard"], nargs="?", default="hard")
    parser.add_argument("repeat_count", type=int, nargs="?", default=1000)
    return parser.parse_args()


def main() -> int:
    args = parse_args()

    if args.repeat_count < 1:
        print("repeat_count must be at least 1", file=sys.stderr)
        return 1

    results = [run_one(implementation, args.puzzle, args.repeat_count) for implementation in IMPLEMENTATIONS]
    print_results(results, args.repeat_count, args.puzzle)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
