# Preliminary multiband antenna example

This reconstruction demonstrates the build/solve/export workflow. It is not
an exact reproduction or a validated optimum.

Source: [Palandöken et al. (2024), Computationally Efficient Design Optimization
of Multiband Antenna Using Deep Learning-Based Surrogate Models](https://onlinelibrary.wiley.com/doi/10.1155/mmce/5442768).
The article, figures, and vendor documentation are not distributed.

Reported dimensions (mm): L1=3.7, L4=0.6, L5=16.6, W1=10.2, W2=18.4,
W6=3.2. Relations: L2=L1, L3=L6=2.5 L1, W3=W5=2 W1, W4=0.5 W1.
FR-4 relative permittivity: 4.6; thickness: 1.6 mm.
Target frequencies: 2.4, 3.5, and 7.2 GHz.

## Implementation assumptions

- Two-sided: partial ground and six branches at z=0; feed line, left tuning
  stub, and top rectangle at z=h. Layer assignment is an interpretation.
- Board **53 x 53 mm**, deliberately different from the reported 32 x 53 mm.
  Literal application of the interpreted dimensions requires 45.9 mm width
  and 49.9 mm length, exceeding either orientation of that board.
- Branch/stub width=1 mm; top rectangle depth=2.8 mm; feed width=W6.
- Ground clearances are rectangular cuts under the feed/stub; a 1 mm bottom
  bridge connects the ideal feed pin to the ground.
- Constant loss tangent=0.02; no material dispersion.
- Zero-thickness PEC; no copper loss, roughness, or foil thickness.
- Ideal external wire replaces SMA: y=-0.5 mm, radius=0.1 mm, voltage=1 V,
  reference impedance=50 ohm. Connector body and reference plane are omitted.
- Finite dielectric SEP/MoM; initial mesh edge=2 mm. Spatial mesh convergence
  has not been checked.

L5=16.6 mm also exceeds the source's stated search upper bound of 15 mm.
The reported parameters are not treated as an optimum for this reconstruction.

## Sampling and interpretation

Default: adaptive continuous 1–10 GHz solution, exported at 91 uniform samples
(0.1 GHz spacing). These are samples of a continuous response, not 91
independent solves. Set `frequency_mode="discrete"` in the job's parameters
before rebuilding to request independent frequencies.

An initial Windows FEKO 2026.1 run gave S11=-1.06/-3.24/-6.33 dB at
2.4/3.5/7.2 GHz. The matching of the original antenna is **not reproduced**.
Verify geometry, mesh convergence, feed modelling, and materials before using
results for an engineering decision.
