#!/usr/bin/env python3
import argparse
from pathlib import Path

import matplotlib.pyplot as plt
import numpy as np

DIM_X = 500
DIM_Y = 500
DIM_Z = 100
EXPECTED_SIZE = DIM_X * DIM_Y * DIM_Z


def find_input_files(root: Path) -> list[Path]:
    files = sorted(root.glob("*.fp32"))
    # The current dataset uses .f32; include both so the script works as requested.
    files.extend(sorted(root.glob("*.f32")))
    # De-duplicate while preserving order.
    seen = set()
    result = []
    for path in files:
        if path not in seen:
            seen.add(path)
            result.append(path)
    return result


def load_volume(path: Path) -> np.ndarray:
    data = np.fromfile(path, dtype=np.float32)
    if data.size != EXPECTED_SIZE:
        raise ValueError(
            f"{path.name}: expected {EXPECTED_SIZE} float32 values, found {data.size}"
        )

    # Given index = x + dim_x * (y + dim_y * z), x is fastest, then y, then z.
    # For C-order reshape this corresponds to (z, y, x).
    return data.reshape((DIM_Z, DIM_Y, DIM_X))


def save_single_file_figure(
    volume: np.ndarray,
    path: Path,
    output_dir: Path,
    z_index: int,
) -> Path:
    slice_2d = volume[z_index, :, :]

    fig, axes = plt.subplots(1, 2, figsize=(11, 4.5), constrained_layout=True)

    im0 = axes[0].imshow(slice_2d, origin="lower", cmap="viridis")
    axes[0].set_title(f"{path.name}\nz={z_index}")
    axes[0].set_xlabel("x")
    axes[0].set_ylabel("y")
    fig.colorbar(im0, ax=axes[0], fraction=0.046, pad=0.04)

    axes[1].hist(volume.ravel(), bins=100)
    axes[1].set_title("Value distribution")
    axes[1].set_xlabel("value")
    axes[1].set_ylabel("count")

    out_path = output_dir / f"{path.name}.png"
    fig.savefig(out_path, dpi=150)
    plt.close(fig)
    return out_path


def save_comparison_figure(
    slices: list[tuple[str, np.ndarray]],
    output_dir: Path,
    z_index: int,
) -> Path:
    n = len(slices)
    if not (1 <= n <= 4):
        raise ValueError(f"Expected 1 to 4 files for comparison, got {n}")

    flattened = np.concatenate([arr.ravel() for _, arr in slices])
    vmin = float(np.percentile(flattened, 1))
    vmax = float(np.percentile(flattened, 99))
    if vmin == vmax:
        vmin = float(flattened.min())
        vmax = float(flattened.max())

    fig, axes = plt.subplots(1, n, figsize=(4.8 * n, 4.5), constrained_layout=True)
    axes_arr = np.atleast_1d(axes).ravel()

    last_im = None
    for i, (name, arr2d) in enumerate(slices):
        ax = axes_arr[i]
        last_im = ax.imshow(arr2d, origin="lower", cmap="viridis", vmin=vmin, vmax=vmax)
        ax.set_title(name, fontsize=10)
        ax.set_xlabel("x")
        ax.set_ylabel("y")
        ax.set_xticks([])
        ax.set_yticks([])

    if last_im is not None:
        fig.colorbar(last_im, ax=axes_arr.tolist(), fraction=0.025, pad=0.02, label="value")

    out_path = output_dir / f"comparison_z{z_index}.png"
    fig.savefig(out_path, dpi=180)
    plt.close(fig)
    return out_path


def main() -> None:
    parser = argparse.ArgumentParser(
        description="Visualize 1 to 4 .fp32/.f32 files together for side-by-side comparison."
    )
    parser.add_argument(
        "input_files",
        nargs="+",
        type=Path,
        help="Input files to compare (1 to 4 files).",
    )
    parser.add_argument(
        "--output-dir",
        type=Path,
        default=Path("visualizations"),
        help="Directory to write the comparison PNG (default: ./visualizations).",
    )
    parser.add_argument(
        "--z",
        type=int,
        default=DIM_Z // 2,
        help="z-slice index to visualize (default: 50).",
    )
    args = parser.parse_args()

    if not (0 <= args.z < DIM_Z):
        raise ValueError(f"--z must be in [0, {DIM_Z - 1}], got {args.z}")

    if len(args.input_files) > 4:
        raise ValueError(f"At most 4 input files are supported, got {len(args.input_files)}")

    files = args.input_files
    for path in files:
        if not path.exists():
            raise FileNotFoundError(f"Input file not found: {path}")
        if not path.is_file():
            raise ValueError(f"Input path is not a file: {path}")

    args.output_dir.mkdir(parents=True, exist_ok=True)

    comparison_slices: list[tuple[str, np.ndarray]] = []
    print(f"Comparing {len(files)} file(s)")

    for path in files:
        volume = load_volume(path)
        comparison_slices.append((path.name, volume[args.z, :, :]))
        print(
            f"{path.name}: shape={volume.shape} min={volume.min():.6g} max={volume.max():.6g}"
        )

    comparison_path = save_comparison_figure(comparison_slices, args.output_dir, args.z)
    print(f"Comparison image: {comparison_path}")


if __name__ == "__main__":
    main()
