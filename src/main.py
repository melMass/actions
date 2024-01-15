import glob
import json
import os
import subprocess


def build_wheels():
    # - list
    installed_packages = (
        subprocess.check_output(["pip", "freeze"]).decode().splitlines()
    )

    # - install the wheel package
    subprocess.check_call(["pip", "install", "wheel"])

    # -  build each
    wheel_paths = []
    for package in installed_packages:
        package_name = package.split("==")[
            0
        ]  # get the package name, ignore the version
        subprocess.check_call(["pip", "wheel", "--wheel-dir=wheels", package_name])
        wheel_paths.extend(glob.glob(f"wheels/{package_name}*.whl"))

    return wheel_paths


def main():
    wheel_paths = build_wheels()
    output = f"wheel_paths={json.dumps(wheel_paths)}"
    # append the output to the $GITHUB_OUTPUT file
    with open(os.getenv("GITHUB_OUTPUT"), "a") as f:
        f.write(output)


if __name__ == "__main__":
    main()
