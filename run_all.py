import subprocess
import sys
import os


def run_parse_daml(daml_file):
    print("🔧 Running Python linter and parser...")
    result = subprocess.run(
        ["python", "daml_parser/parse_daml.py", daml_file], text=True
    )
    if result.returncode != 0:
        print("❌ Python script failed.")
        sys.exit(1)


def run_property_test(prop_name):
    print(f"\n🚀 Running Haskell property test: {prop_name}")
    result = subprocess.run(
        ["cabal", "run", "haskell-folder", "--", prop_name],
        cwd="haskell_folder",
        text=True,
    )
    if result.returncode != 0:
        print("❌ Haskell test failed.")
        sys.exit(1)


def main():
    if len(sys.argv) != 3:
        print("Usage: python run_all.py <path-to-daml-file> <property-name>")
        sys.exit(1)

    daml_file = sys.argv[1]
    prop_name = sys.argv[2]

    if not os.path.exists(daml_file):
        print(f"❌ Daml file not found: {daml_file}")
        sys.exit(1)

    run_parse_daml(daml_file)
    run_property_test(prop_name)


if __name__ == "__main__":
    main()
