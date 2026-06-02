#include <cmath>
#include <cstdint>
#include <fstream>
#include <iomanip>
#include <iostream>
#include <limits>
#include <stdexcept>
#include <string>
#include <vector>

struct Metrics {
    std::uint64_t count = 0;
    long double mse = 0.0L;
    long double range = 0.0L;
    long double psnr = 0.0L;
    bool psnr_infinite = false;
    bool psnr_negative_infinite = false;
};

enum class DataType {
    F32,
    F64,
    I8,
    U8,
    I16,
    U16,
    I32,
    U32,
    I64,
    U64
};

DataType parse_data_type(const std::string& token) {
    if (token == "f32") return DataType::F32;
    if (token == "f64") return DataType::F64;
    if (token == "i8") return DataType::I8;
    if (token == "u8") return DataType::U8;
    if (token == "i16") return DataType::I16;
    if (token == "u16") return DataType::U16;
    if (token == "i32") return DataType::I32;
    if (token == "u32") return DataType::U32;
    if (token == "i64") return DataType::I64;
    if (token == "u64") return DataType::U64;
    throw std::invalid_argument("Unsupported datatype '" + token + "'.");
}

std::uint64_t file_size_bytes(const std::string& path) {
    std::ifstream in(path, std::ios::binary | std::ios::ate);
    if (!in) {
        throw std::runtime_error("Failed to open file: " + path);
    }
    const std::streampos end = in.tellg();
    if (end < 0) {
        throw std::runtime_error("Failed to determine size for file: " + path);
    }
    return static_cast<std::uint64_t>(end);
}

template <typename T>
Metrics compute_psnr(const std::string& reconstructed_path, const std::string& ground_truth_path) {
    const std::uint64_t reconstructed_bytes = file_size_bytes(reconstructed_path);
    const std::uint64_t ground_truth_bytes = file_size_bytes(ground_truth_path);

    if (reconstructed_bytes != ground_truth_bytes) {
        throw std::runtime_error("File size mismatch: reconstructed=" + std::to_string(reconstructed_bytes) +
                                 " bytes, ground truth=" + std::to_string(ground_truth_bytes) + " bytes.");
    }

    if (reconstructed_bytes % sizeof(T) != 0) {
        throw std::runtime_error("File size is not divisible by datatype size.");
    }

    const std::uint64_t count = reconstructed_bytes / sizeof(T);
    if (count == 0) {
        throw std::runtime_error("Input files are empty.");
    }

    std::ifstream reconstructed(reconstructed_path, std::ios::binary);
    std::ifstream ground_truth(ground_truth_path, std::ios::binary);
    if (!reconstructed) {
        throw std::runtime_error("Failed to open reconstructed file: " + reconstructed_path);
    }
    if (!ground_truth) {
        throw std::runtime_error("Failed to open ground truth file: " + ground_truth_path);
    }

    constexpr std::size_t chunk_elems = 1u << 20;  // 1M elements per chunk.
    std::vector<T> rec_buf(chunk_elems);
    std::vector<T> gt_buf(chunk_elems);

    long double min_gt = std::numeric_limits<long double>::infinity();
    long double max_gt = -std::numeric_limits<long double>::infinity();
    long double sse = 0.0L;

    std::uint64_t processed = 0;
    while (processed < count) {
        const std::uint64_t remaining = count - processed;
        const std::size_t to_read = static_cast<std::size_t>(
            remaining < static_cast<std::uint64_t>(chunk_elems) ? remaining : chunk_elems);

        reconstructed.read(reinterpret_cast<char*>(rec_buf.data()), static_cast<std::streamsize>(to_read * sizeof(T)));
        ground_truth.read(reinterpret_cast<char*>(gt_buf.data()), static_cast<std::streamsize>(to_read * sizeof(T)));

        if (!reconstructed || !ground_truth) {
            throw std::runtime_error("Unexpected EOF or read error while streaming input files.");
        }

        for (std::size_t i = 0; i < to_read; ++i) {
            const long double rec = static_cast<long double>(rec_buf[i]);
            const long double gt = static_cast<long double>(gt_buf[i]);
            const long double diff = rec - gt;

            sse += diff * diff;
            if (gt < min_gt) min_gt = gt;
            if (gt > max_gt) max_gt = gt;
        }

        processed += to_read;
    }

    Metrics m;
    m.count = count;
    m.mse = sse / static_cast<long double>(count);
    m.range = max_gt - min_gt;

    if (m.mse == 0.0L) {
        m.psnr_infinite = true;
    } else if (m.range == 0.0L) {
        m.psnr_negative_infinite = true;
    } else {
        m.psnr = 20.0L * std::log10(m.range) - 10.0L * std::log10(m.mse);
    }

    return m;
}

Metrics dispatch_compute(const std::string& reconstructed_path,
                        const std::string& ground_truth_path,
                        DataType data_type) {
    switch (data_type) {
        case DataType::F32:
            return compute_psnr<float>(reconstructed_path, ground_truth_path);
        case DataType::F64:
            return compute_psnr<double>(reconstructed_path, ground_truth_path);
        case DataType::I8:
            return compute_psnr<std::int8_t>(reconstructed_path, ground_truth_path);
        case DataType::U8:
            return compute_psnr<std::uint8_t>(reconstructed_path, ground_truth_path);
        case DataType::I16:
            return compute_psnr<std::int16_t>(reconstructed_path, ground_truth_path);
        case DataType::U16:
            return compute_psnr<std::uint16_t>(reconstructed_path, ground_truth_path);
        case DataType::I32:
            return compute_psnr<std::int32_t>(reconstructed_path, ground_truth_path);
        case DataType::U32:
            return compute_psnr<std::uint32_t>(reconstructed_path, ground_truth_path);
        case DataType::I64:
            return compute_psnr<std::int64_t>(reconstructed_path, ground_truth_path);
        case DataType::U64:
            return compute_psnr<std::uint64_t>(reconstructed_path, ground_truth_path);
    }
    throw std::runtime_error("Internal error: unknown datatype dispatch.");
}

int main(int argc, char* argv[]) {
    if (argc != 4) {
        std::cerr << "Usage: " << argv[0] << " <reconstructed_file> <ground_truth_file> <datatype>\n";
        std::cerr << "Supported datatypes: f32, f64, i8, u8, i16, u16, i32, u32, i64, u64\n";
        std::cerr << "Example: " << argv[0]
                  << " CLOUDf48.bin.f32.cuszp CLOUDf48.bin.f32 f32\n";
        return 1;
    }

    try {
        const std::string reconstructed_path = argv[1];
        const std::string ground_truth_path = argv[2];
        const DataType data_type = parse_data_type(argv[3]);

        const Metrics m = dispatch_compute(reconstructed_path, ground_truth_path, data_type);

        std::cout << std::scientific << std::setprecision(12);
        std::cout << "Elements: " << m.count << "\n";
        std::cout << "MSE:      " << static_cast<double>(m.mse) << "\n";
        std::cout << "Range:    " << static_cast<double>(m.range) << "\n";
        std::cout << "PSNR:     ";
        if (m.psnr_infinite) {
            std::cout << "inf dB\n";
        } else if (m.psnr_negative_infinite) {
            std::cout << "-inf dB\n";
        } else {
            std::cout << std::fixed << static_cast<double>(m.psnr) << " dB\n";
        }
    } catch (const std::exception& e) {
        std::cerr << "Error: " << e.what() << "\n";
        return 1;
    }

    return 0;
}
