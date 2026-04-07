# NewModem
5G NR-Inspired Adaptive OFDM Software Modem for Flawless Image Transmission 
# 📡 5G NR Adaptive Modulation Simulation (MATLAB)

## Overview

This project presents a **5G-inspired link-level simulation framework** for image transmission over wireless channels using MATLAB. The system integrates key physical-layer concepts including **OFDM modulation, adaptive modulation and coding (AMC), and HARQ with Chase combining**, and evaluates performance across **AWGN, Rayleigh, and Rician fading channels**.

The objective is to analyze how adaptive transmission strategies and the channel impact:

* Bit Error Rate (BER)
* Image Quality (PSNR, SSIM)
* Spectral Efficiency (Throughput)

---

## 📁 Project Structure

```
.
├── main_5g_nr_modem_dual.m     % Main simulation entry point
├── images/
│   └── campus.jpg              % Input test image
├── images_updated/             % (Optional) reconstructed outputs
├── README.md
```

---

## 🚀 How to Run

1. Open MATLAB
2. Set the working directory to the project folder
3. Run the main script:

```matlab
main_5g_nr_modem_dual
```

### Execution Flow

* Image is loaded and converted to a bitstream
* Bits are segmented into transport blocks
* Blocks of bits are modulated into blocks of symbols (QAM)
* Blocks of symbols are IFFT into a signal
* Transmission is simulated over:

  * AWGN channel
  * Rayleigh fading channel
  * Rician fading channel
*  Signal is FFT into blocks of symbols
*  Blocks of symbols are demodulated into blocks of bits
*  Performance metrics are computed (BER, PSNR, SSIM, throughput)
* 9 figures are generated for the adaptive MCS, as well as selected fixed MCS:

  * BER vs SNR (3 channels)
  * PSNR vs SNR (3 channels)
  * Throughput vs SNR (3 channels)

---

## ⚙️ Key Parameters

Located at the top of the main script:

```matlab
bitsPerFrame = 8192;        % Transport block size
snrRange_dB  = 0:4:24;      % SNR sweep
modSchemes   = [4 16 64];   % QPSK, 16QAM, 64QAM
codeRates    = [1/2 3/4];   
Nfft         = 64;          
cpLen        = 16;          
harqMaxTx    = 3;           
numPasses    = 3;           
rayleighBlockFading = true;
```

---

## 🧠 System Architecture

### 1. Main Controller

`main_5g_nr_modem_dual` function

* Initializes parameters
* Loads image and prepares bitstream
* Executes simulation for all channel types by calling `sim_fixed_and_adaptive`
* Triggers visualization by calling `plot_results_5g_channel`

---

### 2. Simulation Engine

`sim_fixed_and_adaptive(...)`

Handles:

Using the channel given
* Values given for the parameters 
* Fixed MCS evaluation
* Adaptive MCS evaluation
* HARQ retransmissions
* BER / PSNR / Throughput computation

---

### 3. Adaptive Link Adaptation

`choose_mcs_blertarget(...)`

Implements:

* BLER-driven MCS selection
* Spectral efficiency maximization
* Conservative gating using SNR margin

Key idea:

> Select the highest-efficiency MCS that satisfies reliability constraints.

---

### 4. Channel Models

`apply_channel(...)`

Supports:

* **AWGN** (baseline noise model)
* **Rayleigh fading**

  * Block fading (default)
  * Per-symbol fading (optional)
* **Rician fading**

  * Controlled by K-factor (LOS strength)

---

### 5. OFDM Processing

* `ofdm_modulate()` → IFFT + cyclic prefix
* `ofdm_demodulate()` → FFT + CP removal

---

### 6. Forward Error Correction (FEC)

Either:
* Rate 1/2 → repetition coding
* Rate 3/4 → punctured repetition

functions:
* `fec_encode`
* `fec_decode`
---

### 7. Modulation & Demodulation

* QPSK, 16QAM, 64QAM supported
* LLR-based soft demodulation

functions:
* `qam_mod_bits`
* `qam_demod_llr`

---

### 8. Equalization

`equalize_and_noisevar(...)`

* Channel inversion
* Noise variance scaling for accurate LLR computation

---

### 9. Performance Metrics

| Metric     | Description                  |
| ---------- | ---------------------------- |
| BER        | Bit-level error rate         |
| PSNR       | Image reconstruction quality |
| SSIM       | Image reconstruction quality |
| Throughput | Bits per subcarrier-use      |

functions:
* `psnr_calc`
* `SSIM_calc`

---

### 10. Visualization

`plot_results_5g_channel(...)`

Generates:

* BER vs SNR
* PSNR vs SNR
* Throughput vs SNR

For each channel.

---

## 🖼️ Image Processing Pipeline

### Input

* Stored in:

```
images/campus.jpg
```

### Processing Steps

1. Convert to grayscale
2. Serialize into bitstream
3. Segment into transport blocks
4. Transmit over channel
5. Reconstruct received image

### Output (Optional)

* Can be saved in:

```
images_updated/
```

---

## 📊 Expected Results

### AWGN Channel

* Near-ideal performance
* Rapid convergence to zero BER
* PSNR saturates at 99 dB

### Rayleigh Channel

* Performance degradation due to fading
* Adaptive scheme shows controlled variability
* Realistic link adaptation behavior

### Rician Channel

* Improved reliability due to LOS component
* Performance between AWGN and Rayleigh

---

## ⚠️ Limitations

This is a **simplified 5G-like system**, not a full 3GPP NR implementation:

* No LDPC coding
* No interleaving
* Simplified HARQ
* BLER-based adaptation (not CQI-based)

---

## 📌 Key Features

* Adaptive Modulation and Coding (AMC)
* HARQ with Chase Combining
* Multi-channel modeling
* Image-level QoE evaluation (PSNR)
* Modular and extensible MATLAB design

---

## 👨‍💻 Course Context

Developed for:

**SYSC 5804 X – Software for Mobile Networks (Winter 2026) at Carleton University**

Focus:

* 5G physical layer concepts
* Link adaptation strategies
* Performance evaluation under fading channels

---

## 📄 Usage

This project is intended for:

* Academic study
* Research experimentation
* Educational demonstrations of 5G PHY concepts

---

## 🔚 Summary

This simulation framework demonstrates how adaptive communication strategies impact both **reliability and perceived quality** in wireless systems. By integrating channel modeling, HARQ, and adaptive modulation, it provides a practical platform for understanding trade-offs in modern wireless communication design.
