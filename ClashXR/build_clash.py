import subprocess
import datetime
import plistlib
import os
from add_build_info import write_to_info

def get_version():
    with open('./go.mod') as file:
        for line in file.readlines():
            if "clash" in line and "ClashX" not in line:
                return line.split(" ")[-1].strip()
    return "unknown"


def build_clash(version):
    build_time = datetime.datetime.now().strftime("%Y-%m-%d-%H%M")
    command = f"""CGO_CFLAGS=-mmacosx-version-min=10.12 \
CGO_LDFLAGS=-mmacosx-version-min=10.10 \
GOBUILD=CGO_ENABLED=0 \
go build -ldflags '-X "github.com/whojave/clash/constant.Version={version}" \
-X "github.com/whojave/clash/constant.BuildTime={build_time}"' \
-buildmode=c-archive """
    subprocess.check_output(command, shell=True)

def run():
    version = get_version()
    print("current clash version:", version)
    build_clash(version)
    print("build static library complete!")
    if os.environ.get("CI", False) or os.environ.get("GITHUB_ACTIONS", False):
        print("writing info.plist")
        write_to_info(version)
    print("done")


if __name__ == "__main__":
    run()
