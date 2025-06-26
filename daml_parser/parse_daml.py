import subprocess
import sys
import os
import json


def run_lint(file_path):
    print(f"🧪 Linting: {file_path}")
    result = subprocess.run(
        ["daml.cmd", "damlc", "lint", file_path], capture_output=True, text=True
    )

    if result.stdout.strip():
        print("📢 Lint Output:")
        print(result.stdout)
    if result.stderr.strip():
        print("📢 Lint Warnings/Errors:")
        print(result.stderr)

    if "ERROR" in result.stdout.upper() or "ERROR" in result.stderr.upper():
        print("❌ Lint failed with errors.")
        return False

    print("✅ Lint completed (no errors).")
    return True


def run_parse(file_path):
    print(f"\n🔍 Parsing (docs JSON): {file_path}")
    output_file = os.path.join(os.path.dirname(file_path), "output.json")

    result = subprocess.run(
        [
            "daml.cmd",
            "damlc",
            "docs",
            file_path,
            "--format",
            "json",
            "--output",
            output_file,
        ],
        capture_output=True,
        text=True,
    )

    if result.stdout.strip():
        print("📢 Output:")
        print(result.stdout)
    if result.stderr.strip():
        print("📢 Warnings/Errors:")
        print(result.stderr)

    if not os.path.exists(output_file):
        print("❌ Output file not created.")
        return None

    try:
        with open(output_file, "r", encoding="utf-8") as f:
            data = json.load(f)
        # os.remove(output_file)
        print("✅ Parsed successfully (even with warnings).")
        return data
    except json.JSONDecodeError:
        print("❌ Failed to decode JSON output.")
        return None


def main():
    if len(sys.argv) != 2:
        print("Usage: python parse_and_lint.py <path-to-daml-file>")
        return

    file_path = sys.argv[1]
    if not os.path.exists(file_path):
        print(f"❌ File not found: {file_path}")
        return

    passed_lint = run_lint(file_path)

    if passed_lint:
        parsed = run_parse(file_path)
        if parsed:
            print("\n📦 Top-level definitions:")
            print(json.dumps(parsed, indent=2))
    else:
        print("⚠️ Skipping parsing due to lint failure.")


if __name__ == "__main__":
    main()
