-- All geometry lengths are in mm. Missing dimensions are explicit assumptions.
return {
    L1 = 3.7, L4 = 0.6, L5 = 16.6,
    W1 = 10.2, W2 = 18.4, W6 = 3.2,
    W = 53, L = 53, h = 1.6,
    trace_width = 1.0, radiator_depth = 2.8,
    er = 4.6, tand = 0.02,
    feed_overhang = 0.5, pin_radius = 0.10,
    mesh_edge = 2.0,
    frequency_start = 1e9, frequency_end = 10e9, frequency_count = 91,
    frequency_mode = "adaptive",
}
