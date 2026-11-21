"""Build the offline decal author against exactly the resource sources used for testing."""

import argparse
from concurrent.futures import ThreadPoolExecutor
from pathlib import Path
import subprocess

ROOT = Path(__file__).resolve().parents[1]
SDK_COMMIT = "8e4aefca153ce9cb622074ae4de05f81fa71d09c"


def build(sdk, llvm):
    sdk, llvm = sdk.resolve(), llvm.resolve()
    revision = subprocess.check_output(["git", "-C", sdk, "rev-parse", "HEAD"], text=True).strip()
    if revision != SDK_COMMIT:
        raise ValueError(f"Expected ReSkate {SDK_COMMIT}, found {revision}")
    out = ROOT / "build" / "native"
    out.mkdir(parents=True, exist_ok=True)
    ext = sdk / "External"
    sources = [sdk / "Engine/Core/Json/json.cpp"]
    sources += [sdk / "Engine/Vfs" / (name + ".cpp") for name in
                ("native_db", "game_archives", "game_bundles")]
    sources += [sdk / "Engine/Resource" / (name + ".cpp") for name in
                ("binary_io", "binary_bundle", "cas_codec", "ebx_document",
                 "ebx_writer", "toc", "texture")]
    sources += [ext / "miniz/miniz.c", ext / "lz4/lz4.c"]
    for group in ("common", "compress", "decompress"):
        sources.extend(sorted((ext / "zstd/lib" / group).glob("*.c")))
    sources.append(ROOT / "tools/author.cpp")
    flags = ["-O1", "-ffunction-sections", "-fdata-sections", "-DNOMINMAX",
             "-DWIN32_LEAN_AND_MEAN", "-DMINIZ_NO_ARCHIVE_WRITING_APIS",
             "-DMINIZ_NO_ZLIB_APIS", "-DMINIZ_NO_STDIO", "-DMINIZ_NO_TIME",
             "-DZSTD_LEGACY_SUPPORT=0", "-DZSTD_DISABLE_ASM"]
    for include in (sdk, ext, ext / "bcdec", ext / "miniz", ext / "lz4", ext / "zstd/lib"):
        flags.extend(["-I", str(include)])

    def compile_one(source):
        obj = out / (source.name + ".o")
        cxx = source.suffix == ".cpp"
        compiler = llvm / "bin" / ("clang++.exe" if cxx else "clang.exe")
        args = ["-std=c++20"] if cxx else []
        subprocess.run([compiler, *flags, *args, "-c", source, "-o", obj], check=True)
        return obj

    with ThreadPoolExecutor(max_workers=4) as pool:
        objects = list(pool.map(compile_one, sources))
    exe = out / "decal-author.exe"
    subprocess.run([llvm / "bin/clang++.exe", "-static", "-Wl,--gc-sections",
                    *objects, "-o", exe], check=True)
    return exe


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--sdk", required=True, type=Path)
    parser.add_argument("--llvm", required=True, type=Path)
    args = parser.parse_args()
    print(build(args.sdk, args.llvm))
