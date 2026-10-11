# Audio Talkbox & Cross-Synthesis via Linear Predictive Coding (LPC)

A discrete-time audio talkbox and spectral cross-synthesis system implemented in MATLAB using Linear Predictive Coding (LPC) and Overlap-Add (OLA) frame-based resynthesis. The system decouples the spectral envelope of human speech (vocal tract formants) and transfers it onto arbitrary polyphonic musical carriers (e.g., piano chords, synthesizers, electric guitar).

---

## Processing Architecture
The cross-synthesis pipeline operates in four primary stages:

1. **Signal Pre-Processing:**
   * Channel averaging converts multi-channel audio to mono vectors required by autocorrelation routines.
   * Peak normalization (scaled to 0.95) matches input energy levels across speech and carrier sources.
   * Zero-padding synchronizes signals of unequal duration.

2. **Carrier Whitening (Inverse FIR Filtering):**
   * Computes biased autocorrelation via `xcorr` and solves the Yule-Walker equations via the Levinson-Durbin recursion for order `p_music`.
   * The frame is filtered through the prediction error FIR filter:
     `e_music = filter(a_music, 1, padded_music_frame)`
   * This removes the instrument's intrinsic spectral envelope and resonances, flattening the carrier into an equalized harmonic excitation.

3. **Vocal Formant Extraction & Shaping (All-Pole IIR Filtering):**
   * Computes LPC coefficients `a_speech` of order `p_speech` to model vocal tract resonances.
   * The whitened carrier residual excites the all-pole synthesis filter:
     `synthesized_frame = filter(1, a_speech, e_music)`
   * The speech formants are imprinted directly onto the harmonic carrier.

4. **Overlap-Add (OLA) Anti-Aliasing Reconstruction:**
   * To prevent time-domain cyclic convolution aliasing ($L = M + N - 1$), the extracted frame is zero-padded prior to filtering by `total_tail = tail_FIR + tail_IIR`.
   * Reconstructs a continuous output stream using a Hamming window with hop size $R = M / 8$.

---

## Design Parameters & Engineering Justification

| Parameter | Value | Rationale |
| :--- | :--- | :--- |
| **Sampling Frequency ($f_s$)** | $44.1\text{ kHz}$ | Native sample rate for audio fidelity. |
| **Frame Length ($M$)** | $2048$ samples | Balances frequency resolution (tracking carrier pitch and fundamental) with temporal resolution (capturing consonants and rapid vocal tract transitions). A power of 2 optimizes the internal FFTs in `xcorr`. |
| **Hop Size ($R$)** | $M / 8$ ($256$ samples) | 87.5% frame overlap ensures smooth, phase-coherent interpolation between synthesis frames, preventing stepped modulation artifacts. |
| **Speech Order ($p_{\text{speech}}$)** | $44$ | Follows the acoustic rule of thumb $f_s / 1000$ to $f_s / 1000 + 4$. Accurately models major vocal formants without overfitting to high-frequency sibilance or noise. |
| **Music Order ($p_{\text{music}}$)** | $95$ | Higher prediction order flattens dense instrument resonance peaks while preserving pitch and underlying harmonic lines. |
| **FIR Tail (`tail_FIR`)** | $p_{\text{music}}$ ($95$ samples) | Matches the exact length of the FIR whitening filter impulse response. |
| **IIR Tail (`tail_IIR`)** | $R$ ($256$ samples) | Provides sufficient room for the infinite impulse response decay of the all-pole shaping filter. |

---