from pysz import sz, szConfig, szErrorBoundMode
from pathlib import Path
import matplotlib.pyplot as plt
import numpy as np
from visualization import load_volume, find_input_files


DIM_Z = 100


def original_prefix(path: Path) -> str:
    if path.name.endswith(".fp32"):
        return path.name[: -len(".fp32")]
    if path.name.endswith(".f32"):
        return path.name[: -len(".f32")]
    return path.stem


def save_comparison_figure(
    path: Path,
    original: np.ndarray,
    decompressed: np.ndarray,
    z_index: int,
    output_dir: Path,
) -> Path:
    output_dir.mkdir(parents=True, exist_ok=True)

    original_slice = original[z_index, :, :]
    decompressed_slice = decompressed[z_index, :, :]
    abs_err = np.abs(original_slice - decompressed_slice)

    fig, axes = plt.subplots(1, 3, figsize=(14, 4.6), constrained_layout=True)

    vmin = float(np.percentile(original_slice, 1))
    vmax = float(np.percentile(original_slice, 99))
    im0 = axes[0].imshow(original_slice, origin="lower", cmap="viridis", vmin=vmin, vmax=vmax)
    axes[0].set_title(f"Original ({path.name})\\nz={z_index}")
    axes[0].set_xlabel("x")
    axes[0].set_ylabel("y")
    fig.colorbar(im0, ax=axes[0], fraction=0.046, pad=0.04)

    im1 = axes[1].imshow(decompressed_slice, origin="lower", cmap="viridis", vmin=vmin, vmax=vmax)
    axes[1].set_title("Decompressed")
    axes[1].set_xlabel("x")
    axes[1].set_ylabel("y")
    fig.colorbar(im1, ax=axes[1], fraction=0.046, pad=0.04)

    im2 = axes[2].imshow(abs_err, origin="lower", cmap="magma")
    axes[2].set_title("Absolute Error")
    axes[2].set_xlabel("x")
    axes[2].set_ylabel("y")
    fig.colorbar(im2, ax=axes[2], fraction=0.046, pad=0.04)

    out_path = output_dir / f"{original_prefix(path)}_compare.png"
    fig.savefig(out_path, dpi=170)
    plt.close(fig)
    return out_path


def main():
    config = szConfig()
    config.errorBoundMode = szErrorBoundMode.ABS
    config.absErrorBound = 1e-6
    files = find_input_files(Path("."))
    compare_dir = Path("reconstruction_visualizations")
    z_index = DIM_Z // 2
    for path in files:
        data = load_volume(path)
        compressed, ratio = sz.compress(data, config)
        decompressed, _ = sz.decompress(compressed, np.float32, data.shape)
        max_err, psnr, nrmse = sz.verify(data, decompressed)
        dat_path = compare_dir / f"{original_prefix(path)}.dat"
        decompressed.astype(np.float32, copy=False).tofile(dat_path)
        compare_path = save_comparison_figure(path, data, decompressed, z_index, compare_dir)

        print(f"{path.name}:")
        print(f"  Compression ratio: {ratio:.2f}x")
        print(f"  Max error: {max_err:.2e}, PSNR: {psnr:.2f} dB, NRMSE: {nrmse:.2e}")
        print(f"  Reconstructed data: {dat_path}")
        print(f"  Comparison image:   {compare_path}")

if __name__ == "__main__":
    main()
