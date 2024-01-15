import glob
import os
import subprocess


def build_wheels(installed_packages):
    # - list
    # installed_packages = (
    #     subprocess.check_output(["pip", "freeze"]).decode().splitlines()
    # )

    # - install the wheel package
    subprocess.check_call(["pip", "install", "wheel"])

    # -  build each
    wheel_paths = []
    for package_name in installed_packages:
        subprocess.check_call(["pip", "wheel", "--wheel-dir=wheels", package_name])
        wheel_paths.extend(glob.glob(f"wheels/{package_name}*.whl"))

    return wheel_paths


def main():
    wheels = os.environ.get("WHEELS", "")
    if not wheels:
        return

    wheels = [x.strip() for x in wheels.split(",")]

    wheel_paths = build_wheels(wheels)
    output = "\n".join(wheel_paths)
    # append the output to the $GITHUB_OUTPUT file
    with open(os.getenv("GITHUB_OUTPUT"), "a") as f:
        f.write(f"wheel_paths={output}")


if __name__ == "__main__":
    main()
